# CachyOS stable kernel with BORE, Clang ThinLTO and O3.

pkg_name="kernel-cachyos-bore"
pkg_version="7.1"
pkg_mode="managed"
pkg_type="source"

MINOR_VER=5
VER=1

SRCNAME="cachyos-${pkg_version}.${MINOR_VER}-${VER}"
ARCHIVE_FILE="$pkg_version.tar.gz"
PATCH_FILE="0001-bore-cachy.patch"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/CachyOS/linux/releases/download/${SRCNAME}/${SRCNAME}.tar.gz" \
    "$WORKDIR/$pkg_name/$ARCHIVE_FILE"

  al_fetch_cached_url \
    "https://raw.githubusercontent.com/cachyos/kernel-patches/master/${pkg_version}/sched/${PATCH_FILE}" \
    "$WORKDIR/$pkg_name/$PATCH_FILE"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$ARCHIVE_FILE" \
    "$WORKDIR/$pkg_name"

  SRCDIR="$WORKDIR/$pkg_name/$SRCNAME"
  BUILDDIR="$SRCDIR/build"
  PATCH_PATH="$WORKDIR/$pkg_name/$PATCH_FILE"

  test -d "$SRCDIR" || {
    echo "Missing kernel source directory: $SRCDIR"
    exit 1
  }

  test -f "$SRCDIR/Makefile" || {
    echo "Invalid kernel source directory: $SRCDIR"
    exit 1
  }

  test -s "$PATCH_PATH" || {
    echo "Missing or empty BORE patch: $PATCH_PATH"
    exit 1
  }

  export SRCDIR BUILDDIR PATCH_PATH
}

stage_configure() {
  (
    set -e

    cd "$SRCDIR"

    # Every Kbuild invocation must use the same LLVM toolchain.
    KMAKE=(
      make
      LLVM=1
      LLVM_IAS=1
    )

    echo "==== LLVM toolchain ===="

    command -v clang >/dev/null || {
      echo "Missing compiler: clang"
      exit 1
    }

    command -v ld.lld >/dev/null || {
      echo "Missing linker: ld.lld"
      exit 1
    }

    command -v llvm-ar >/dev/null || {
      echo "Missing tool: llvm-ar"
      exit 1
    }

    command -v llvm-nm >/dev/null || {
      echo "Missing tool: llvm-nm"
      exit 1
    }

    clang --version | head -n1
    ld.lld --version | head -n1
    llvm-ar --version | head -n1

    echo "==== Applying BORE patch ===="
    echo "Source: $SRCDIR"
    echo "Patch:  $PATCH_PATH"

    if ! patch --batch --forward --dry-run -Np1 < "$PATCH_PATH"; then
      echo "==== BORE PATCH DRY-RUN FAILED ===="
      sha256sum "$PATCH_PATH" || true
      exit 1
    fi

    patch --batch --forward -Np1 < "$PATCH_PATH"

    "${KMAKE[@]}" clean

    config_src="$(
      find /boot \
        -maxdepth 1 \
        -type f \
        -name 'config-6.18.41_1' \
        -print \
        -quit
    )"

    test -n "$config_src" || {
      echo "base kernel config not found"
      exit 1
    }

    echo "Using base config: $config_src"
    cp "$config_src" .config

    # ---------------------------------------------------------
    # CachyOS and BORE
    # ---------------------------------------------------------

    ./scripts/config \
      -e CACHY \
      -e SCHED_BORE \
      -d SCHED_ALT \
      -d SCHED_BMQ

    # ---------------------------------------------------------
    # Timer and preemption
    # ---------------------------------------------------------

    ./scripts/config \
      -d HZ_100 \
      -d HZ_250 \
      -d HZ_300 \
      -d HZ_500 \
      -d HZ_600 \
      -d HZ_750 \
      -e HZ_1000 \
      --set-val HZ 1000

    # Tickless idle is safer for a general desktop than NO_HZ_FULL.
    ./scripts/config \
      -d HZ_PERIODIC \
      -d NO_HZ_FULL \
      -e NO_HZ_IDLE \
      -e NO_HZ \
      -e NO_HZ_COMMON

    ./scripts/config \
      -e PREEMPT_DYNAMIC \
      -e PREEMPT \
      -d PREEMPT_VOLUNTARY \
      -d PREEMPT_LAZY \
      -d PREEMPT_NONE

    # ---------------------------------------------------------
    # Memory policy
    # ---------------------------------------------------------

    ./scripts/config \
      -d TRANSPARENT_HUGEPAGE_ALWAYS \
      -e TRANSPARENT_HUGEPAGE_MADVISE

    # ---------------------------------------------------------
    # Clang + ThinLTO
    # ---------------------------------------------------------

    ./scripts/config \
      -d LTO_NONE \
      -d LTO_CLANG_FULL \
      -d LTO_CLANG_THIN_DIST \
      -e LTO_CLANG \
      -e LTO_CLANG_THIN

    # kCFI is intentionally disabled in this performance-oriented build.
    ./scripts/config \
      -d CFI_CLANG \
      -d CFI_AUTO_DEFAULT

    # Avoid inheriting GCC-only plugin configuration from Debian.
    ./scripts/config \
      -d GCC_PLUGINS

    # ---------------------------------------------------------
    # O3 compiler optimization
    # ---------------------------------------------------------

    ./scripts/config \
      -d CC_OPTIMIZE_FOR_SIZE \
      -d CC_OPTIMIZE_FOR_PERFORMANCE \
      -e CC_OPTIMIZE_FOR_PERFORMANCE_O3

    # ---------------------------------------------------------
    # Power and networking defaults
    # ---------------------------------------------------------

    ./scripts/config \
      -d CPU_FREQ_DEFAULT_GOV_PERFORMANCE \
      -e CPU_FREQ_DEFAULT_GOV_SCHEDUTIL

    ./scripts/config \
      -e TCP_CONG_CUBIC \
      -e DEFAULT_CUBIC \
      -d DEFAULT_BBR \
      --set-str DEFAULT_TCP_CONG cubic

    # Resolve Kconfig dependencies using Clang/LLVM.
    "${KMAKE[@]}" olddefconfig

    echo "==== Verifying effective configuration ===="

    required_configs=(
      "CONFIG_CACHY=y"
      "CONFIG_SCHED_BORE=y"
      "CONFIG_LTO_CLANG=y"
      "CONFIG_LTO_CLANG_THIN=y"
      "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y"
      "CONFIG_HZ_1000=y"
      "CONFIG_HZ=1000"
      "CONFIG_PREEMPT=y"
      "CONFIG_PREEMPT_DYNAMIC=y"
      "CONFIG_NO_HZ_IDLE=y"
      "CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y"
      "CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y"
    )

    for option in "${required_configs[@]}"; do
      if ! grep -qx "$option" .config; then
        echo "Required config missing after olddefconfig: $option"
        exit 1
      fi
    done

    forbidden_configs=(
      "CONFIG_LTO_NONE=y"
      "CONFIG_LTO_CLANG_FULL=y"
      "CONFIG_CFI_CLANG=y"
      "CONFIG_SCHED_BMQ=y"
      "CONFIG_NO_HZ_FULL=y"
    )

    for option in "${forbidden_configs[@]}"; do
      if grep -qx "$option" .config; then
        echo "Unexpected config enabled: $option"
        exit 1
      fi
    done

    echo "==== Effective kernel configuration ===="

    grep -E \
      '^(CONFIG_(CACHY|SCHED_BORE|LTO_CLANG|LTO_CLANG_THIN|CC_OPTIMIZE_FOR_PERFORMANCE_O3|HZ_1000|HZ|PREEMPT|PREEMPT_DYNAMIC|NO_HZ_IDLE|TRANSPARENT_HUGEPAGE_MADVISE|CPU_FREQ_DEFAULT_GOV_SCHEDUTIL))=' \
      .config || true
  )
}

stage_build() {
  (
    set -e

    cd "$SRCDIR"

    KMAKE=(
      make
      LLVM=1
      LLVM_IAS=1
    )

    echo "-cachyos-bore" > localversion

    krel="$("${KMAKE[@]}" -s kernelrelease)"

    echo "==== Building kernel ===="
    echo "Kernel release: $krel"
    echo "Compiler:       $(clang --version | head -n1)"
    echo "Linker:         $(ld.lld --version | head -n1)"

    "${KMAKE[@]}" -j10 all
  )
}

stage_stage() {
  (
    set -e

    cd "$SRCDIR"

    KMAKE=(
      make
      LLVM=1
      LLVM_IAS=1
    )

    krel="$("${KMAKE[@]}" -s kernelrelease)"
    bootdir="$STAGE_DIR/boot"

    mkdir -p "$bootdir"

    "${KMAKE[@]}" \
      INSTALL_MOD_PATH="$STAGE_DIR" \
      modules_install

    cp -f --verbose \
      arch/x86/boot/bzImage \
      "$bootdir/vmlinuz-$krel"

    cp -f --verbose \
      System.map \
      "$bootdir/System.map-$krel"

    cp -f --verbose \
      .config \
      "$bootdir/config-$krel"
  )
}
