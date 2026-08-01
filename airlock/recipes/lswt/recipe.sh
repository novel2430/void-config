# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="lswt"
pkg_version="2.0.0"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_fetch_cached_url \
    "https://git.sr.ht/~leon_plickat/lswt/archive/v$pkg_version.tar.gz" \
    "$WORKDIR/$pkg_version.tar.gz"
}

stage_prepare() {
  al_extract_archive_for_recipe "$WORKDIR/$pkg_version.tar.gz" "$WORKDIR" || exit 1
  SRCDIR="$WORKDIR/$pkg_name-v$pkg_version"
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
