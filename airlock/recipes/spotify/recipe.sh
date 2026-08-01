#!/usr/bin/env bash

pkg_name="spotify"
pkg_version="1.2.90.451"
pkg_mode="tracked"
pkg_type="artifact"
track_backend="deb-apt"

DEB_URL="https://repository.spotify.com/pool/non-free/s/spotify-client/spotify-client_1.2.90.451.gb094aab0_amd64.deb"

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
  al_tracked_install_deb_with_apt "$track_source_file"
}

hook_post_install() {
  local desktop_dir="/usr/local/share/applications/Spotify.desktop"

  al_install_text_file_with_optional_sudo "$desktop_dir" 644 <<'EOF'
[Desktop Entry]
Type=Application
Name=Spotify
GenericName=Music Player
Icon=spotify-client
TryExec=spotify
Exec=spotify %U
Terminal=false
MimeType=x-scheme-handler/spotify;
Categories=Audio;Music;Player;AudioVideo;
StartupWMClass=spotify
EOF
}

hook_post_remove() {
  # Remove files created by hook_post_install that are outside package manager
  # ownership.
  al_remove_file_with_optional_sudo /usr/local/share/applications/Spotify.desktop
}
