pkg_name="wezterm"
pkg_version="76b606e"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_require_recipe_cmd cargo
  al_require_recipe_cmd rustup

  al_git_checkout_repo_with_submodules \
    "https://github.com/wezterm/wezterm.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_configure() {
  (
    cd "$SRCDIR" || exit 1

    # v0 pragmatic choice:
    # keep toolchain selection here instead of inventing a separate toolchain stage
    rustup default stable || exit 1

    ./get-deps || exit 1
  ) || return 1
}

stage_build() {
  (
    cd "$SRCDIR" || exit 1

    # cargo clean || exit 1
    cargo build --release -j4 || exit 1
  ) || return 1
}

stage_stage() {
  al_stage_install_file "$SRCDIR/target/release/wezterm" "bin/wezterm" 755 || return 1
  al_stage_install_file "$SRCDIR/target/release/wezterm-gui" "bin/wezterm-gui" 755 || return 1
  al_stage_install_file "$SRCDIR/target/release/wezterm-mux-server" "bin/wezterm-mux-server" 755 || return 1

  local libdir="lib/x86_64-linux-gnu"
  al_stage_install_file "$SRCDIR/target/release/libwezterm_config_derive.so" "$libdir/libwezterm_config_derive.so" 755 || return 1
  al_stage_install_file "$SRCDIR/target/release/libwezterm_dynamic_derive.so" "$libdir/libwezterm_dynamic_derive.so" 755 || return 1

  al_stage_install_icon \
    "$SRCDIR/assets/icon/wezterm-icon.svg" \
    "scalable" \
    "org.wezfurlong.wezterm" \
    "svg" || return 1

  al_stage_install_icon \
    "$SRCDIR/assets/icon/terminal.png" \
    "128x128" \
    "org.wezfurlong.wezterm" \
    "png" || return 1

  al_stage_write_desktop_entry "org.wezfurlong.wezterm" <<'EOF'
[Desktop Entry]
Version=1.0
Name=WezTerm
Comment=Wez's Terminal Emulator
Keywords=shell;prompt;command;commandline;cmd;
Icon=wezterm
StartupWMClass=org.wezfurlong.wezterm
TryExec=wezterm
Exec=wezterm
Type=Application
Categories=System;TerminalEmulator;Utility;
Terminal=false
EOF
}
