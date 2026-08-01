# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="greenclip"
pkg_version="4.2"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/erebe/greenclip/releases/download/v$pkg_version/greenclip" \
    "$WORKDIR/$pkg_name/greenclip"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  chmod +x "$SRCDIR/greenclip"
  al_stage_install_file "$SRCDIR/greenclip" "bin/greenclip"
}
