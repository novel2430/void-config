# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="wlroots-20"
pkg_version="0.20.1"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://gitlab.freedesktop.org/wlroots/wlroots.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  PREFIX=/opt/edge
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export SRCDIR BUILDDIR PREFIX PKG_CONFIG_PATH
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" \
    --prefix="$PREFIX" \
    --libdir=lib \
    -Dc_link_args="-Wl,-rpath,$PREFIX/lib" \
    -Dcpp_link_args="-Wl,-rpath,$PREFIX/lib"
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
}
