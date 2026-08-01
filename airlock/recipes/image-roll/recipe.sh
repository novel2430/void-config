#!/usr/bin/env bash

pkg_name="image-roll"
pkg_version="2.1.0"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_fetch_cached_url \
    "https://github.com/weclaw1/image-roll/releases/download/$pkg_version/image-roll-$pkg_version" \
    "$WORKDIR/$pkg_name/$pkg_name"

  al_fetch_cached_url \
    "https://raw.githubusercontent.com/weclaw1/image-roll/main/src/resources/com.github.weclaw1.ImageRoll.svg" \
    "$WORKDIR/$pkg_name/com.github.weclaw1.ImageRoll.svg"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}


stage_stage() {
  al_stage_install_file "$SRCDIR/$pkg_name" "bin/image-roll" 755 || return 1

  al_stage_install_icon \
    "$SRCDIR/com.github.weclaw1.ImageRoll.svg" \
    "scalable" \
    "com.github.weclaw1.ImageRoll" \
    "svg" || return 1

  al_stage_write_desktop_entry "com.github.weclaw1.ImageRoll" <<'EOF'
[Desktop Entry]
Type=Application
Name=Image Roll
Comment=Image viewer with basic image manipulation tools
Exec=image-roll %U
Icon=com.github.weclaw1.ImageRoll
Terminal=false
StartupWMClass=image-roll
TryExec=image-roll
Categories=Graphics;
EOF
}
