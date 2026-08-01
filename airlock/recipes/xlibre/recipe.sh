# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="xlibre"
pkg_version="25.2.2"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/X11Libre/xserver.git" \
    "$WORKDIR/$pkg_name" \
    "xlibre-xserver-$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  XLIBRE_PREFIX_DIR="$PREFIX/opt/xlibre"
  export SRCDIR BUILDDIR XLIBRE_PREFIX_DIR
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" --prefix="$XLIBRE_PREFIX_DIR" \
    -D ipv6=true \
    -D xvfb=true \
    -D xnest=true \
    -D xcsecurity=true \
    -D xorg=true \
    -Ddri3=true \
    -Dglx_dri=true \
    -D xephyr=true \
    -D xfbdev=true \
    -D glamor=true \
    -D udev=true \
    -D dtrace=false \
    -D systemd_logind=false \
    -D seatd_libseat=true \
    -D suid_wrapper=true \
    -D linux_acpi=false \
    -D legacy_nvidia_padding=true \
    -D legacy_nvidia_340x=true \
    -D suid_wrapper=true \
    -D xkb_dir='/usr/share/X11/xkb' \
    -D xkb_output_dir='/var/lib/xkb' \
    -D libunwind=true
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
  al_stage_install_wrapper "bin/xlibre-run" <<EOF
#!/usr/bin/env bash
if [ -e "$XLIBRE_PREFIX_DIR/bin/X" ]; then
  startx -- $XLIBRE_PREFIX_DIR/bin/X "\$@"
fi
EOF

  cat > "$SRCDIR/99-swcursor.conf" <<'EOF'
Section "Device"
  Identifier "modesetting"
  Option "SWCursor" "true"
EndSection
EOF

  al_stage_install_file "$SRCDIR/99-swcursor.conf" "opt/xlibre/share/X11/xorg.conf.d/99-swcursor.conf" 644

}
