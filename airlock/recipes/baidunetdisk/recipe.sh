#!/usr/bin/env bash

pkg_name="baidunetdisk"
pkg_version="4.17.8"
pkg_mode="tracked"
pkg_type="artifact"
track_backend="deb-apt"

DEB_URL="http://wppkg.baidupcs.com/issue/netdisk/Linuxguanjia/$pkg_version/baidunetdisk_${pkg_version}_amd64.deb"

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

hook_post_install() {
  local custom_bin="/usr/local/bin/baidunetdisk"
  local desktop_dir="/usr/share/applications/baidunetdisk.desktop"

  # Install integration files after backend installation succeeds.
  al_install_text_file_with_optional_sudo "$custom_bin" 755 <<'EOF'
#!/usr/bin/env bash
cd /opt/baidunetdisk
GDK_BACKEND=x11 HOME="${HOME:-/tmp}/.local/share/baidu" ./baidunetdisk "$@"
EOF

  al_install_text_file_with_optional_sudo "$desktop_dir" 644 <<'EOF'
[Desktop Entry]
Name=Baidu Netdisk
Name[zh_CN]=百度网盘
Name[zh_TW]=百度网盘
Exec=/usr/local/bin/baidunetdisk --no-sandbox %U
Terminal=false
Type=Application
Icon=baidunetdisk
StartupWMClass=baidunetdisk
Comment=百度网盘
Comment[zh_CN]=百度网盘
Comment[zh_TW]=百度网盘
MimeType=x-scheme-handler/baiduyunguanjia;
Categories=Network;
EOF
}

hook_post_remove() {
  # Remove files created by hook_post_install that are outside package manager
  # ownership.
  al_remove_file_with_optional_sudo /usr/local/bin/baidunetdisk
  al_remove_file_with_optional_sudo /usr/share/applications/baidunetdisk.desktop
}
