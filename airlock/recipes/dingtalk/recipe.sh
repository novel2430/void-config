pkg_name="dingtalk"
pkg_version="8.1.0.6021101"
pkg_mode="managed"
pkg_type="artifact"

_extract_deb() {
  local debfile outdir
  debfile="$1"
  outdir="$2"

  rm -rf "$outdir"
  mkdir -p "$outdir"

  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$debfile" -C "$outdir"
  else
    (
      cd "$outdir" || exit 1
      ar x "$debfile"
    )
  fi
}

_extract_data_archive() {
  local deb_extract_dir rootdir data_archive
  deb_extract_dir="$1"
  rootdir="$2"

  rm -rf "$rootdir"
  mkdir -p "$rootdir"

  data_archive="$(find "$deb_extract_dir" -maxdepth 1 -type f -name 'data.tar.*' -print -quit)"
  if [ -z "$data_archive" ]; then
    printf 'data.tar.* not found under %s\n' "$deb_extract_dir" >&2
    return 1
  fi

  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$data_archive" -C "$rootdir"
  else
    tar -xf "$data_archive" -C "$rootdir"
  fi
}

stage_acquire() {
  al_fetch_cached_url \
    "https://dtapp-pub.dingtalk.com/dingtalk-desktop/xc_dingtalk_update/linux_deb/Release/com.alibabainc.dingtalk_${pkg_version}_amd64.deb" \
    "$WORKDIR/$pkg_name/${pkg_version}.deb"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/deb"
  ROOTDIR="$SRCDIR/root"
  export SRCDIR BUILDDIR ROOTDIR

  _extract_deb "$SRCDIR/${pkg_version}.deb" "$BUILDDIR" || return 1
  _extract_data_archive "$BUILDDIR" "$ROOTDIR" || return 1
}

stage_stage() {
  mkdir -p "$STAGE_DIR$PREFIX/opt/$pkg_name/release"
  mkdir -p "$STAGE_DIR$PREFIX/share/doc/"

  local pkgname2="com.alibabainc.dingtalk"
  cp -r "$ROOTDIR/opt/apps/${pkgname2}/files/"*-Release.*/* "$STAGE_DIR$PREFIX/opt/${pkg_name}/release"
  cp -r "$ROOTDIR/opt/apps/${pkgname2}/files/version" "$STAGE_DIR$PREFIX/opt/${pkg_name}"
  cp -r "$ROOTDIR/opt/apps/${pkgname2}/files/doc/${pkgname2}" "$STAGE_DIR$PREFIX/share/doc/${pkg_name}"
  cp "$ROOTDIR/opt/apps/com.alibabainc.dingtalk/files/logo.ico" "$STAGE_DIR$PREFIX/opt/${pkg_name}"

  patchelf --clear-execstack "$STAGE_DIR$PREFIX/opt/$pkg_name/release"/{dingtalk_dll,libconference_new}.so
  # fix chinese input in workbench
  rm -rf "$STAGE_DIR$PREFIX/opt/${pkg_name}/release/libgtk-x11-2.0.so."*
  rm -rf "$STAGE_DIR$PREFIX/opt/${pkg_name}/release"/{libm.so.6,Resources/{i18n/tool/*.exe,qss/mac,web_content/NativeWebContent_*.zip},libstdc*}
  rm -rf "$STAGE_DIR$PREFIX/opt/${pkg_name}/release"/{libharfbuzz*,libgbm*}
  # remove unused lib
  rm -rf "$STAGE_DIR$PREFIX/opt/${pkg_name}/release"/{libcurl.so.4,libz*,libGL*}

  al_stage_write_desktop_entry "com.alibabainc.dingtalk" <<EOF
[Desktop Entry]
Categories=Chat;Office;
Comment=
Exec=$PREFIX/bin/dingtalk-bin
GenericName=dingtalk
Icon=$PREFIX/opt/$pkg_name/logo.ico
Keywords=dingtalk;
MimeType=x-scheme-handler/dingtalk;
Name=Dingtalk
Type=Application
X-Deepin-Vendor=user-custom
EOF

  al_stage_install_wrapper "bin/dingtalk-bin" <<EOF
#!/usr/bin/env bash
export QT_QPA_PLATFORM="wayland;xcb"
export QT_AUTO_SCREEN_SCALE_FACTOR=1
cd $PREFIX/opt/$pkg_name/release
./com.alibabainc.dingtalk
EOF

}
