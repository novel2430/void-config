# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="hmcl"
pkg_version="3.15.2"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  local JAVAFX_VERSION="21.0.8"
  local hmcl_jar_url="https://github.com/HMCL-dev/HMCL/releases/download/v${pkg_version}/HMCL-${pkg_version}.jar"
  local javafx_base_url="https://repo1.maven.org/maven2/org/openjfx/javafx-base/${JAVAFX_VERSION}/javafx-base-${JAVAFX_VERSION}-linux.jar"
  local javafx_graphics_url="https://repo1.maven.org/maven2/org/openjfx/javafx-graphics/${JAVAFX_VERSION}/javafx-graphics-${JAVAFX_VERSION}-linux.jar"
  local javafx_controls_url="https://repo1.maven.org/maven2/org/openjfx/javafx-controls/${JAVAFX_VERSION}/javafx-controls-${JAVAFX_VERSION}-linux.jar"

  al_fetch_cached_url "$hmcl_jar_url" "$WORKDIR/$pkg_name/HMCL-$pkg_version.jar"
  al_fetch_cached_url "$javafx_base_url" "$WORKDIR/$pkg_name/hmcl-javafx/javafx-base.jar"
  al_fetch_cached_url "$javafx_graphics_url" "$WORKDIR/$pkg_name/hmcl-javafx/javafx-graphics.jar"
  al_fetch_cached_url "$javafx_controls_url" "$WORKDIR/$pkg_name/hmcl-javafx/javafx-controls.jar"
  al_fetch_cached_url \
    "https://raw.githubusercontent.com/HMCL-dev/HMCL/refs/heads/main/HMCL/image/hmcl.png" \
    "$WORKDIR/$pkg_name/hmcl.png"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_dir "$SRCDIR" "opt/hmcl"

  al_stage_write_desktop_entry "org.jackhuang.hmcl.Launcher" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=org.jackhuang.hmcl.Launcher
Exec=hmcl
Icon=hmcl
StartupWMClass=org.jackhuang.hmcl.Launcher
GenericName=HMCL
Comment=Hello Minecraft! Launcher
Categories=Game;
EOF
  al_stage_write_desktop_entry "minecraft" <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=minecraft
Exec=hmcl
Icon=minecraft
StartupWMClass=minecraft
GenericName=minecraft
Comment=minecraft
Categories=Game;
EOF

  al_stage_install_wrapper "bin/hmcl" <<EOF
#!/usr/bin/env bash
exec java \
  --module-path "$PREFIX/opt/hmcl/hmcl-javafx" \
  --add-modules javafx.controls \
  -Dprism.verbose=true \
  -Djavafx.verbose=true \
  -Dprism.forceGPU=true \
  -jar "$PREFIX/opt/hmcl/HMCL-$pkg_version.jar" \
  "\$@"
EOF

  al_stage_install_icon "$SRCDIR/hmcl.png" "128x128" "hmcl" "png"
}
