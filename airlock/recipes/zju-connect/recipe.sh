# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="zju-connect"
pkg_version="1.0.0"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/Mythologyli/zju-connect/releases/download/v$pkg_version/zju-connect-linux-amd64.zip" \
    "$WORKDIR/$pkg_name/$pkg_version.zip"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.zip" \
    "$WORKDIR/$pkg_name"

  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  local optdir="opt/$pkg_name"
  al_stage_install_file "$SRCDIR/zju-connect" "bin/zju-connect"
}
