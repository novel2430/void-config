# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="hyprgraphics"
pkg_version="0.5.1"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/hyprwm/$pkg_name.git" \
    "$WORKDIR/$pkg_name" \
    v"$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  PREFIX=/opt/edge
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  CC="$PREFIX/bin/gcc"
  CXX="$PREFIX/bin/g++"
  CPP="$PREFIX/bin/cpp"

  export SRCDIR BUILDDIR PREFIX PKG_CONFIG_PATH CC CXX CPP
}

stage_configure() {
  (
    cd "$SRCDIR"
    cmake -S . -B build \
      --no-warn-unused-cli \
      -DCMAKE_BUILD_TYPE:STRING=Release \
      -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX \
      -DCMAKE_INSTALL_RPATH="$PREFIX/lib;$PREFIX/lib64" \
      -DCMAKE_BUILD_RPATH="$PREFIX/lib;$PREFIX/lib64" \
      -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
      -DNO_SYSTEMD:STRING=true \
      -DNO_UWSM:STRING=true \
      -DNO_HYPRPM:STRING=true
  )
}

stage_build() {
  (
    cd "$SRCDIR"
    cmake --build build --config Release --target all -j6
  )
}

stage_stage() {
  (
    cd "$SRCDIR"
    DESTDIR="$STAGE_DIR" cmake --install build
  )
}
