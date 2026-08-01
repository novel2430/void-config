#!/usr/bin/env bash

pkg_name="mihomo"
pkg_version="1.19.29"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/MetaCubeX/mihomo/releases/download/v$pkg_version/mihomo-linux-amd64-compatible-v$pkg_version.gz" \
    "$WORKDIR/$pkg_name/$pkg_version.gz"
}

stage_prepare() {
  gzip -cd \
    "$WORKDIR/$pkg_name/$pkg_version.gz" \
    > "$WORKDIR/$pkg_name/mihomo"


  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_file \
    "$SRCDIR/mihomo" \
    "bin/mihomo" 755
}
