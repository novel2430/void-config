# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="riff"
pkg_version="25.11"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/Diegovsky/riff.git" \
    "$WORKDIR/$pkg_name" \
    "v$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/target"
  export SRCDIR BUILDDIR
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" --prefix="$PREFIX" -Dbuildtype=release -Doffline=false
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
}
