#!/usr/bin/env bash

pkg_name="wemeet"
pkg_version="b01e69a"
pkg_mode="tracked"
pkg_type="artifact"
track_backend="flatpak"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/novel2430/com.tencent.wemeet.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  export SRCDIR
}

track_install() {

  track_package_name="com.tencent.wemeet"
  track_package_version="3.26.10.401"

  track_query_cmd="flatpak info $(printf '%q' "$track_package_name")"
  track_remove_cmd="flatpak remove $(printf '%q' "$track_package_name")"
  track_install_cmd=""

  (
    cd $SRCDIR
    flatpak --user install -y flathub \
      org.freedesktop.Platform//24.08 \
      org.freedesktop.Sdk//24.08
    flatpak-builder build-dir com.tencent.wemeet.yml --install --user --force-clean
  )

  export track_package_name track_package_version
  export track_query_cmd track_remove_cmd track_install_cmd
}
