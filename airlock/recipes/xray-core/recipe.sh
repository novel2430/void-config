# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="xray-core"
pkg_version="26.3.27"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip" \
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
  al_stage_install_file "$SRCDIR/xray" "opt/xray/xray"
  al_stage_install_file "$SRCDIR/geoip.dat" "opt/xray/geoip.dat"
  al_stage_install_file "$SRCDIR/geosite.dat" "opt/xray/geosite.dat"
  mkdir "$STAGE_DIR$PREFIX/bin"
  ln -sf "$STAGE_DIR$PREFIX/opt/xray/xray" "$STAGE_DIR$PREFIX/bin/xray"
}
