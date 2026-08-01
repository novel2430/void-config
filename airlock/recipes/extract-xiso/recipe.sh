# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="extract-xiso"
pkg_version="b72e5b6"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/XboxDev/extract-xiso.git" \
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
    cd "$SRCDIR"
    cmake -S . -B build \
      -DCMAKE_INSTALL_PREFIX=$PREFIX
  )
}

stage_build() {
  (
    cd "$SRCDIR"
    cmake --build build
  )
}

stage_stage() {
  (
    cd "$SRCDIR"
    DESTDIR="$STAGE_DIR" cmake --install build
  )
}
