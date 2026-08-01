# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="neovim"
pkg_version="0.12.4"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/neovim/neovim.git" \
    "$WORKDIR/$pkg_name" \
    "v$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_configure() {
  (
    cd "$SRCDIR" || exit 1 

    cmake \
      -S cmake.deps \
      -B .deps \
      -G Ninja
    cmake --build .deps

    cmake \
      -Bbuild \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX=$PREFIX \
      -G Ninja \
      -W no-dev
  )
}

stage_build() {
  (
    cd "$SRCDIR" || exit 1 
    cmake --build build 
  )
}

stage_stage() {
  (
    cd "$SRCDIR" || exit 1 
    DESTDIR="$STAGE_DIR" cmake --install build
  )
}
