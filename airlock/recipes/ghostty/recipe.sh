# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="ghostty"
pkg_version="c5a21ed"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/ghostty-org/ghostty.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_build() {
  (
    cd "$SRCDIR"
    unset http_proxy
    unset https_proxy
    zig build -Doptimize=ReleaseFast 
  )
}

stage_stage() {
  mkdir -p "$STAGE_DIR$PREFIX" || exit 1
  cp -r --verbose $SRCDIR/zig-out/* "$STAGE_DIR$PREFIX"

  al_stage_write_desktop_entry "com.mitchellh.ghostty" <<'EOF'
[Desktop Entry]
Version=1.0
Name=Ghostty
Type=Application
Comment=A terminal emulator
Exec=/usr/local/bin/ghostty --gtk-single-instance=true
Icon=com.mitchellh.ghostty
Categories=System;TerminalEmulator;
Keywords=terminal;tty;pty;
StartupNotify=true
StartupWMClass=com.mitchellh.ghostty
Terminal=false
EOF
}
