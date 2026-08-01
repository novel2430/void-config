# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="xlibre-xf86-input-libinput"
pkg_version="1.5.0"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://gitlab.freedesktop.org/xorg/driver/xf86-input-libinput.git" \
    "$WORKDIR/$pkg_name" \
    "xf86-input-libinput-$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  XLIBRE_PREFIX_DIR="$PREFIX/opt/xlibre"
  export SRCDIR BUILDDIR XLIBRE_PREFIX_DIR
}

stage_configure() {
  export PKG_CONFIG_PATH="$XLIBRE_PREFIX_DIR/lib/x86_64-linux-gnu/pkgconfig/"
  rm -rf "$BUILDDIR"
  meson setup "$BUILDDIR" "$SRCDIR" --prefix="$XLIBRE_PREFIX_DIR" 
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
}
