#!/usr/bin/env bash

pkg_name="lutris"
pkg_version="0.5.22"
pkg_mode="tracked"
pkg_type="artifact"
track_backend="deb-apt"

DEB_URL="https://github.com/lutris/lutris/releases/download/v$pkg_version/lutris_${pkg_version}_all.deb"

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
  al_tracked_install_deb_with_apt "$track_source_file"
}
