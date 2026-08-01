# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="annotator"
pkg_version="2.0.2"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/phase1geo/Annotator.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_configure() {
  # Configure the project for an out-of-tree Meson build.
  meson setup "$BUILDDIR" "$SRCDIR" --prefix="$PREFIX"
}

stage_build() {
  # Build the project artifacts.
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"

  al_stage_install_cmd_wrapper "annotator" "bin/com.github.phase1geo.annotator"
}
