# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="wayland-protocols"
pkg_version="1.49"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://gitlab.freedesktop.org/wayland/${pkg_name}.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  PREFIX=/opt/edge
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  CC="$PREFIX/bin/gcc"
  CXX="$PREFIX/bin/g++"
  CPP="$PREFIX/bin/cpp"
  PATH="$PREFIX/bin:$PATH"

  export SRCDIR BUILDDIR PREFIX PKG_CONFIG_PATH CC CXX CPP PATH
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" \
    --prefix="$PREFIX" \
    --buildtype=release \
    --libdir=lib \
    -Dc_link_args="-Wl,-rpath,$PREFIX/lib:$PREFIX/lib64"
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
  mkdir -p "$STAGE_DIR/$PREFIX/lib/pkgconfig"
  cp "$STAGE_DIR/$PREFIX/share/pkgconfig/wayland-protocols.pc" "$STAGE_DIR/$PREFIX/lib/pkgconfig/wayland-protocols.pc" --verbose
}
