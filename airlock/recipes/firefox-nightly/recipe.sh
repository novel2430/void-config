pkg_name="firefox-nightly"
pkg_version="155.0a1.20260731.085738"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://ftp.mozilla.org/pub/firefox/nightly/2026/07/2026-07-31-08-57-38-mozilla-central/firefox-155.0a1.en-US.linux-x86_64.tar.xz" \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/$pkg_name/$pkg_version.tar.xz" \
    "$WORKDIR/$pkg_name"

  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  local optdir="opt/$pkg_name"

  al_stage_install_dir \
    "$SRCDIR/firefox" \
    "$optdir"

  al_stage_install_cmd_wrapper "$pkg_name" "$optdir/firefox"

  cat > "$STAGE_DIR$PREFIX/$optdir/distribution/policies.json" <<'EOF'
{
  "policies": {
    "DisableAppUpdate": true
  }
}
EOF

  rm -rf "$STAGE_DIR$PREFIX/$optdir/dictionaries" \
    "$STAGE_DIR$PREFIX/$optdir/hyphenation"
  ln -s /usr/share/hyphen "$STAGE_DIR$PREFIX/$optdir/hyphenation"

  al_stage_install_icon "$SRCDIR/firefox/browser/chrome/icons/default/default128.png" "128x128" "$pkg_name" "png"

  al_stage_write_desktop_entry "$pkg_name" << EOF
[Desktop Entry]
Name=Firefox Nightly
GenericName=Web Browser
GenericName[zh_CN]=网络浏览器
GenericName[zh_TW]=網路瀏覽器
Comment=Browse the Web
Comment[zh_CN]=浏览互联网
Comment[zh_TW]=瀏覽網際網路
Exec=$PREFIX/$optdir/firefox %u
Icon=$pkg_name
Terminal=false
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
StartupWMClass=$pkg_name
Categories=Network;WebBrowser;
Keywords=web;browser;internet;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Name[zh_CN]=新建窗口
Name[zh_TW]=開新視窗
Exec=$PREFIX/$optdir/firefox --new-window %u

[Desktop Action new-private-window]
Name=New Private Window
Name[zh_CN]=新建隐私浏览窗口
Name[zh_TW]=新增隱私視窗
Exec=$PREFIX/$optdir/firefox --private-window %u
EOF
}
