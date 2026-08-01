# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="xemu"
pkg_version="0.8.136"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/xemu-project/xemu/releases/download/v$pkg_version/xemu-$pkg_version-x86_64.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"

  al_fetch_cached_url \
    "https://github.com/xemu-project/xemu/blob/master/ui/icons/xemu_128x128.png?raw=true" \
    "$WORKDIR/$pkg_name/$pkg_name.png"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  local optdir="opt/$pkg_name"
  al_stage_install_file "$SRCDIR/$pkg_name.AppImage" "$optdir/$pkg_name.AppImage"

  al_stage_install_cmd_wrapper "$pkg_name" "$optdir/$pkg_name.AppImage"

  al_stage_install_icon "$SRCDIR/$pkg_name.png" "128x128" "xemu" "png"

  al_stage_write_desktop_entry "xemu" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=xemu
Name=xemu
Comment=Emulator for the original Xbox console
Icon=xemu
Categories=Game;Emulator;
Keywords=original;xbox;game;console;emulator;xemu;
EOF
}
