# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="zig"
pkg_version="0.15.2"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://ziglang.org/download/$pkg_version/zig-x86_64-linux-$pkg_version.tar.xz" \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz"
}

stage_prepare() {
  al_extract_archive_for_recipe "$WORKDIR/$pkg_name/$pkg_version.tar.xz" "$WORKDIR/$pkg_name"
  SRCDIR="$WORKDIR/$pkg_name/zig-x86_64-linux-$pkg_version"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_file "$SRCDIR/zig" "bin/zig"
  al_stage_install_dir "$SRCDIR/lib" "lib/zig"
}
