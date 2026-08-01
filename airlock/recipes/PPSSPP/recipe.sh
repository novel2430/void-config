# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="PPSSPP"
pkg_version="1.20.3"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/hrydgard/ppsspp/releases/download/v$pkg_version/PPSSPP-v$pkg_version-anylinux-x86_64.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"

  al_fetch_cached_url \
    "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/PPSSPP_logo.svg/960px-PPSSPP_logo.svg.png" \
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

  al_stage_install_icon "$SRCDIR/$pkg_name.png" "128x128" "org.ppsspp.PPSSPP" "png"

  al_stage_write_desktop_entry "PPSSPPSDL" <<'EOF'
[Desktop Entry]
Version=1.0
Name=PPSSPP
Exec=PPSSPP
Icon=org.ppsspp.PPSSPP
Type=Application
Comment=PPSSPP (fast and portable PSP emulator)
Keywords=Sony;PlayStation;Portable;PSP;handheld;console;
Categories=Game;Emulator;
StartupWMClass=PPSSPPSDL
EOF
}
