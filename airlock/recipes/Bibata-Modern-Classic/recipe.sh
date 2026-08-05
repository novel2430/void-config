# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="Bibata-Modern-Classic"
pkg_version="2.0.7"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/ful1e5/Bibata_Cursor/releases/download/v$pkg_version/$pkg_name.tar.xz" \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz" \
    "$WORKDIR/$pkg_name"

  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_dir \
    "$SRCDIR/$pkg_name" \
    "share/icons"
}
