#!/usr/bin/env bash

pkg_name="quickshell"
pkg_version="0.2.1.1"
pkg_mode="tracked"
pkg_type="artifact"
track_backend="deb-apt"

DEB_URL="https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/Debian_13/amd64/quickshell_$pkg_version+pin713.26531fc4.db12_amd64.deb"

stage_acquire() {
  al_fetch_url_uncached \
    "$DEB_URL" \
    "$WORKDIR/$pkg_name/$pkg_version.deb"
}

stage_prepare() {
  track_source_url="$DEB_URL"
  track_source_file="$WORKDIR/$pkg_name/$pkg_version.deb"

  export track_source_url track_source_file
}

track_install() {
  local deb="$track_source_file"

  al_tracked_install_deb_with_apt "$deb" || return 1
}
