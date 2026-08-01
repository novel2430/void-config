# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="tabbed"
pkg_version="b9b2032"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/novel2430/tabbed-0.9.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_build() {
  (
    cd "$SRCDIR"
    make
  )
}

stage_stage() {
  (
    cd "$SRCDIR"
    make DESTDIR="$STAGE_DIR" PREFIX="$PREFIX" install
  )
}
