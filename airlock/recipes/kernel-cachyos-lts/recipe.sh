# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="kernel-cachyos-lts"
pkg_version="6.18"
pkg_mode="managed"
pkg_type="source"

MINOR_VER=40
VER=1
SRCNAME="cachyos-${pkg_version}.${MINOR_VER}-${VER}"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/CachyOS/linux/releases/download/${SRCNAME}/${SRCNAME}.tar.gz" \
    "$WORKDIR/$pkg_name/$pkg_version.tar.gz"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.tar.gz" \
    "$WORKDIR/$pkg_name"

  SRCDIR="$WORKDIR/$pkg_name/$SRCNAME"
  BUILDDIR="$SRCDIR/build"

  export SRCDIR BUILDDIR PATCH_DIR
}

stage_configure() {
  (
    cd "$SRCDIR" || exit 1

    KMAKE=(
      make
      LLVM=1
      LLVM_IAS=1
    )

    command -v clang >/dev/null || {
      echo "Missing clang"
      exit 1
    }

    command -v ld.lld >/dev/null || {
      echo "Missing ld.lld"
      exit 1
    }

    command -v llvm-ar >/dev/null || {
      echo "Missing llvm-ar"
      exit 1
    }

    echo "==== LLVM toolchain ===="
    clang --version | head -n1
    ld.lld --version | head -n1

    "${KMAKE[@]}" clean || exit 1

    config_src="$(
      find /boot \
        -maxdepth 1 \
        -type f \
        -name 'config-6.12.*+deb13-amd64' \
        -print \
        -quit
    )"

    test -n "$config_src" || {
      echo "Debian base config not found"
      exit 1
    }

    echo "Using config: $config_src"
    cp "$config_src" .config || exit 1

    # CachyOS tuning
    ./scripts/config \
      -e CACHY \
      -d SCHED_BORE \
      -d SCHED_ALT \
      -d SCHED_BMQ || exit 1

    # 1000 Hz
    ./scripts/config \
      -d HZ_100 \
      -d HZ_250 \
      -d HZ_300 \
      -e HZ_1000 \
      --set-val HZ 1000 || exit 1

    # Tickless idle，普通桌面比 NO_HZ_FULL 穩妥
    ./scripts/config \
      -d HZ_PERIODIC \
      -d NO_HZ_FULL \
      -e NO_HZ_IDLE \
      -e NO_HZ \
      -e NO_HZ_COMMON || exit 1

    # Full preemption
    ./scripts/config \
      -e PREEMPT_DYNAMIC \
      -e PREEMPT \
      -d PREEMPT_VOLUNTARY \
      -d PREEMPT_LAZY \
      -d PREEMPT_NONE || exit 1

    # THP conservative desktop default
    ./scripts/config \
      -d TRANSPARENT_HUGEPAGE_ALWAYS \
      -e TRANSPARENT_HUGEPAGE_MADVISE || exit 1

    # Clang ThinLTO
    ./scripts/config \
      -d LTO_NONE \
      -d LTO_CLANG_FULL \
      -e LTO_CLANG \
      -e LTO_CLANG_THIN || exit 1

    # 第一版不開 kCFI
    ./scripts/config \
      -d CFI_CLANG \
      -d CFI_AUTO_DEFAULT || exit 1

    # 清除 GCC plugin 選項
    ./scripts/config \
      -d GCC_PLUGINS || exit 1

    # O3
    ./scripts/config \
      -d CC_OPTIMIZE_FOR_SIZE \
      -d CC_OPTIMIZE_FOR_PERFORMANCE \
      -e CC_OPTIMIZE_FOR_PERFORMANCE_O3 || exit 1

    # 保留 schedutil
    ./scripts/config \
      -d CPU_FREQ_DEFAULT_GOV_PERFORMANCE \
      -e CPU_FREQ_DEFAULT_GOV_SCHEDUTIL || exit 1

    # 保留 Cubic
    ./scripts/config \
      -e TCP_CONG_CUBIC \
      -e DEFAULT_CUBIC \
      -d DEFAULT_BBR \
      --set-str DEFAULT_TCP_CONG cubic || exit 1

    # 必須用 LLVM toolchain 跑 Kconfig dependency resolution
    "${KMAKE[@]}" olddefconfig || exit 1

    echo "==== Effective config ===="

    required_configs=(
      CONFIG_CACHY=y
      CONFIG_LTO_CLANG=y
      CONFIG_LTO_CLANG_THIN=y
      CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y
      CONFIG_HZ_1000=y
      CONFIG_PREEMPT=y
      CONFIG_PREEMPT_DYNAMIC=y
      CONFIG_NO_HZ_IDLE=y
      CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
    )

    for option in "${required_configs[@]}"; do
      if ! grep -qx "$option" .config; then
        echo "Required config missing: $option"
        exit 1
      fi
    done

    if grep -qx 'CONFIG_CFI_CLANG=y' .config; then
      echo "Unexpected CONFIG_CFI_CLANG=y"
      exit 1
    fi

    grep -E \
      '^(CONFIG_(CACHY|LTO_CLANG|LTO_CLANG_THIN|CC_OPTIMIZE_FOR_PERFORMANCE_O3|HZ_1000|HZ|PREEMPT|PREEMPT_DYNAMIC|NO_HZ_IDLE|TRANSPARENT_HUGEPAGE_MADVISE))=' \
      .config || true
  )
}

stage_build() {
  (
    cd "$SRCDIR" || exit 1

    KMAKE=(
      make
      LLVM=1
      LLVM_IAS=1
    )

    echo "-cachyos-lts" > localversion

    krel="$("${KMAKE[@]}" -s kernelrelease)" || exit 1
    echo "Building kernel: $krel"

    "${KMAKE[@]}" -j8 all || exit 1
  )
}

stage_stage() {
  (
    cd "$SRCDIR" || exit 1

    KMAKE=(
      make
      LLVM=1
      LLVM_IAS=1
    )

    krel="$("${KMAKE[@]}" -s kernelrelease)" || exit 1
    bootdir="$STAGE_DIR/boot"

    mkdir -p "$bootdir" || exit 1

    "${KMAKE[@]}" \
      INSTALL_MOD_PATH="$STAGE_DIR" \
      modules_install || exit 1

    cp -f --verbose \
      arch/x86/boot/bzImage \
      "$bootdir/vmlinuz-$krel" || exit 1

    cp -f --verbose \
      System.map \
      "$bootdir/System.map-$krel" || exit 1

    cp -f --verbose \
      .config \
      "$bootdir/config-$krel" || exit 1
  )
}
