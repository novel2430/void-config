# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="tree-sitter"
pkg_version="0.25.10"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/tree-sitter/tree-sitter.git" \
    "$WORKDIR/$pkg_name" \
    "v$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_build() {
  (
    cd "$SRCDIR"
    make -j4
  )
}

stage_stage() {
  (
    cd "$SRCDIR"
    make DESTDIR="$STAGE_DIR" PREFIX="$PREFIX" install
  )
}
