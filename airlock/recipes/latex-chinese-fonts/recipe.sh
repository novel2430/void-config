# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="latex-chinese-fonts"
pkg_version="2873993"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/Haixing-Hu/latex-chinese-fonts/archive/$pkg_version.zip" \
    "$WORKDIR/$pkg_name/$pkg_version.zip"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.zip" \
    "$WORKDIR/$pkg_name"

  rm -rf "$WORKDIR/$pkg_name/latex-chinese-fonts-287399335ec1beb72062ce67c36eaa8bec35f386/.gitattributes"
  rm -rf "$WORKDIR/$pkg_name/latex-chinese-fonts-287399335ec1beb72062ce67c36eaa8bec35f386/LICENSE"
  rm -rf "$WORKDIR/$pkg_name/latex-chinese-fonts-287399335ec1beb72062ce67c36eaa8bec35f386/README.md"

  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_dir \
    "$SRCDIR/latex-chinese-fonts-287399335ec1beb72062ce67c36eaa8bec35f386" \
    "share/fonts/latex-chinese-fonts"
}
