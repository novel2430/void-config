# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="azahar"
pkg_version="2125.0.1"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/azahar-emu/azahar/releases/download/2125.0.1/azahar.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"

  al_fetch_cached_url \
    "https://raw.githubusercontent.com/azahar-emu/azahar/refs/heads/master/dist/azahar.png" \
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

  al_stage_install_icon "$SRCDIR/$pkg_name.png" "128x128" "org.azahar_emu.Azahar" "png"

  al_stage_write_desktop_entry "Azahar" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Azahar
GenericName=3DS Emulator
GenericName[fr]=Émulateur 3DS
Comment=Nintendo 3DS video game console emulator
Comment[fr]=Émulateur de console de jeu Nintendo 3DS
Icon=org.azahar_emu.Azahar
TryExec=azahar
Exec=azahar %f
Categories=Game;Emulator;
MimeType=application/x-ctr-3dsx;application/x-ctr-cci;application/x-ctr-cia;application/x-ctr-cxi;
Keywords=3DS;Nintendo;
EOF
}
