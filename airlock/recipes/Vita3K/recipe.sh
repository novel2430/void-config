# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="Vita3K"
pkg_version="3947-6ed8fbec"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/Vita3K/Vita3K-builds/releases/download/3947/Vita3K-x86_64.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"

  al_fetch_cached_url \
    "https://raw.githubusercontent.com/Vita3K/Vita3K/refs/heads/master/data/image/icon.png" \
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

  al_stage_install_cmd_wrapper "vita3k" "$optdir/$pkg_name.AppImage"

  al_stage_install_icon "$SRCDIR/$pkg_name.png" "128x128" "vita3k" "png"

  al_stage_write_desktop_entry "Vita3K" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Vita3K
GenericName=PSV Emulator
Exec=vita3k
Icon=vita3k
StartupWMClass=Vita3K
Categories=Game;Emulator;
EOF
}
