# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="ryujinx"
pkg_version="1.3.3"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://legacy.git.ryujinx.app/api/v4/projects/1/packages/generic/Ryubing/$pkg_version/ryujinx-$pkg_version-x64.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"

  al_fetch_cached_url \
    "https://raw.githubusercontent.com/Ryubing/Assets/refs/heads/main/RyujinxApp_1024.png" \
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

  al_stage_install_icon "$SRCDIR/$pkg_name.png" "128x128" "ryujinx" "png"

  al_stage_write_desktop_entry "Ryujinx" <<EOF
[Desktop Entry]
Version=1.0
Name=Ryujinx
Type=Application
Icon=ryujinx
Exec=ryujinx %f
Comment=A Nintendo Switch Emulator
GenericName=Nintendo Switch Emulator
Terminal=false
Categories=Game;Emulator;
MimeType=application/x-nx-nca;application/x-nx-nro;application/x-nx-nso;application/x-nx-nsp;application/x-nx-xci;
Keywords=Switch;Nintendo;Emulator;
StartupWMClass=ryujinx
PrefersNonDefaultGPU=true
EOF
}
