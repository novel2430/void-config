# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="openttd"
pkg_version="15.2"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://cdn.openttd.org/openttd-releases/$pkg_version/openttd-$pkg_version-linux-generic-amd64.tar.xz" \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz" \
    "$WORKDIR/$pkg_name"
  
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/openttd-$pkg_version-linux-generic-amd64"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_dir "$BUILDDIR" "opt/openttd"
  al_stage_install_dir "$BUILDDIR/share" "share"
  al_stage_install_wrapper "bin/openttd" <<EOF
#!/usr/bin/env bash
cd "$PREFIX/opt/openttd"
exec ./openttd "\$@"
EOF
  rm -rf "$STAGE_DIR$PREFIX/opt/openttd/share"
}
