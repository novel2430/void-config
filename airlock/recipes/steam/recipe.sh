# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="steam"
pkg_version="1.0.0.85"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/ivan-hc/Steam-appimage/releases/download/1.0.0.85-6%402026-04-01_1775027745/Steam-1.0.0.85-6-anylinux-x86_64.AppImage" \
    "$WORKDIR/$pkg_name/$pkg_name.AppImage"
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

  al_stage_write_desktop_entry "Steam" <<EOF
[Desktop Entry]
Name=Steam
Comment=Application for managing and playing games on Steam
Exec=$PREFIX/bin/steam %U
Icon=steam
Terminal=false
Type=Application
Categories=Network;FileTransfer;Game;
MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;
Actions=Store;Community;Library;Servers;Screenshots;News;Settings;BigPicture;Friends;
PrefersNonDefaultGPU=true
X-KDE-RunOnDiscreteGpu=true

[Desktop Action Store]
Name=Store
Exec=$PREFIX/bin/steam steam://store

[Desktop Action Community]
Name=Community
Exec=$PREFIX/bin/steam steam://url/CommunityHome/

[Desktop Action Library]
Name=Library
Exec=$PREFIX/bin/steam steam://open/games

[Desktop Action Servers]
Name=Servers
Exec=$PREFIX/bin/steam steam://open/servers

[Desktop Action Screenshots]
Name=Screenshots
Exec=$PREFIX/bin/steam steam://open/screenshots

[Desktop Action News]
Name=News
Exec=$PREFIX/bin/steam steam://openurl/https://store.steampowered.com/news

[Desktop Action Settings]
Name=Settings
Exec=$PREFIX/bin/steam steam://open/settings

[Desktop Action BigPicture]
Name=Big Picture
Exec=$PREFIX/bin/steam steam://open/bigpicture

[Desktop Action Friends]
Name=Friends
Exec=$PREFIX/bin/steam steam://open/friends
EOF
}
