# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="kernel"
pkg_version="7.0"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_fetch_cached_url \
    "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$pkg_version.tar.xz" \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz" \
    "$WORKDIR/$pkg_name"

  SRCDIR="$WORKDIR/$pkg_name/linux-$pkg_version"
  BUILDDIR="$SRCDIR/build"

  export SRCDIR BUILDDIR
}

stage_configure() {
  (
    cd "$SRCDIR"
    make clean
    cp /boot/config-$(uname -r) .config || exit 1
    make olddefconfig || exit 1
  )
}

stage_build() {
  (
    cd "$SRCDIR"
    echo "-custom" > localversion
    make -s kernelrelease
    make -j8
  )
}

stage_stage() {
  (
    cd "$SRCDIR" || exit 1

    krel="$(make -s kernelrelease)" || exit 1
    bootdir="$STAGE_DIR/boot"

    mkdir -p "$bootdir" || exit 1

    make INSTALL_MOD_PATH="$STAGE_DIR" modules_install || exit 1

    cp -f --verbose arch/x86/boot/bzImage "$bootdir/vmlinuz-$krel" || exit 1
    cp -f --verbose System.map "$bootdir/System.map-$krel" || exit 1
    cp -f --verbose .config "$bootdir/config-$krel" || exit 1
  )
}
