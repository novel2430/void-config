# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="helium"
pkg_version="0.11.1.1"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/imputnet/helium-linux/releases/download/0.11.1.1/$pkg_name-$pkg_version-x86_64.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"

  al_fetch_cached_url \
    "https://raw.githubusercontent.com/imputnet/helium/refs/heads/main/resources/branding/app_icon/raw.png" \
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

  al_stage_install_icon "$SRCDIR/$pkg_name.png" "128x128" "helium" "png"

  al_stage_write_desktop_entry "Helium" <<EOF
[Desktop Entry]
Version=1.0
Name=Helium
GenericName=Web Browser

# Gnome and KDE 3 uses Comment.
Comment=Access the Internet
Exec=helium %U
StartupNotify=true
StartupWMClass=helium
Terminal=false
Icon=helium
Type=Application
Categories=Network;WebBrowser;
MimeType=application/pdf;application/rdf+xml;application/rss+xml;application/xhtml+xml;application/xhtml_xml;application/xml;image/gif;image/jpeg;image/png;image/webp;text/html;text/xml;x-scheme-handler/http;x-scheme-handler/https;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Exec=helium

[Desktop Action new-private-window]
Name=New Incognito Window
Exec=helium --incognito
EOF
}
