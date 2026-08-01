# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="river"
pkg_version="0.3.17"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://codeberg.org/river/river-classic.git" \
    "$WORKDIR/$pkg_name" \
    v"$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  PREFIX=/opt/edge
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export SRCDIR BUILDDIR PREFIX PKG_CONFIG_PATH
}

stage_build() {
  (
    cd "$SRCDIR"
    unset http_proxy
    unset https_proxy
    zig build -Doptimize=ReleaseFast 
  )
}

stage_stage() {
  mkdir -p "$STAGE_DIR$PREFIX" || exit 1
  cp -r --verbose $SRCDIR/zig-out/* "$STAGE_DIR$PREFIX"
  al_make_wrapper "$STAGE_DIR/usr/local/bin/river" \
    "$PREFIX/bin/river"
}
