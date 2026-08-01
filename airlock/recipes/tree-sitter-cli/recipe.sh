pkg_name="tree-sitter-cli"
pkg_version="0.26.8"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/tree-sitter/tree-sitter/releases/download/v0.26.8/tree-sitter-linux-x64.gz" \
    "$WORKDIR/$pkg_name/${pkg_version}.gz"
}

stage_prepare() {
  gzip -d "$WORKDIR/$pkg_name/${pkg_version}.gz" -c > "$WORKDIR/$pkg_name/tree-sitter"

  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  TS_CLIDIR="$WORKDIR/$pkg_name/tree-sitter"

  export SRCDIR BUILDDIR TS_CLIDIR
}

stage_stage() {
  al_stage_install_file "$TS_CLIDIR" "bin/tree-sitter" 755
}
