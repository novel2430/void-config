# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="i3lock-color"
pkg_version="2.13.c.5"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/Raymo111/i3lock-color.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_configure() {
  (
    cd "$SRCDIR" || exit 1
    autoreconf -fiv
    mkdir -p "$BUILDDIR" || exit 1
    cd "$BUILDDIR" || exit 1
    ../configure --prefix=$PREFIX --sysconfdir=$PREFIX/etc
  )
}

stage_build() {
  (
    cd "$BUILDDIR" || exit 1
    make -j4
  )
}

stage_stage() {
  (
    cd "$BUILDDIR" || exit 1
    make DESTDIR="$STAGE_DIR" install
  )
}
