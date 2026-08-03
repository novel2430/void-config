# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="noto-sans-fonts"
pkg_version="2.015"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/notofonts/latin-greek-cyrillic/releases/download/NotoSans-v${pkg_version}/NotoSans-v${pkg_version}.zip" \
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
  al_stage_install_dir \
    "$SRCDIR" \
    "share/fonts/noto-sans-fonts"
}
