#!/usr/bin/env bash

pkg_name="mihomo-ninja"
pkg_version="0.1.10"
pkg_mode="managed"
pkg_type="artifact"

DEB_URL="https://github.com/kachetong1314/ninja/releases/download/${pkg_version}/ninjadesktop-lite_${pkg_version}_amd64.deb"

stage_acquire() {
  al_fetch_cached_url \
    "$DEB_URL" \
    "$WORKDIR/$pkg_name/$pkg_version.deb"
}

stage_prepare() {
  dpkg-deb -x "$WORKDIR/$pkg_name/$pkg_version.deb" "$WORKDIR/$pkg_name"
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  al_stage_install_dir "$SRCDIR/opt/NinjaDesktopLite" "opt/NinjaDesktopLite"
  al_stage_install_wrapper "bin/mihomo-ninja" <<EOF
#!/usr/bin/env bash
exec $PREFIX/opt/NinjaDesktopLite/ninjadesktop-lite \
  "\$@"
EOF
}
