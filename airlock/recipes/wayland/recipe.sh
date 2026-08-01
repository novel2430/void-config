pkg_name="wayland"
pkg_version="1.25.0"
pkg_mode="managed"
pkg_type="source"

WAYLAND_TARBALL="wayland-${pkg_version}.tar.xz"

stage_acquire() {
  mkdir -p "$WORKDIR/downloads"

  al_fetch_cached_url \
    "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${pkg_version}/downloads/${WAYLAND_TARBALL}" \
    "$WORKDIR/downloads/$WAYLAND_TARBALL"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/downloads/$WAYLAND_TARBALL" \
    "$WORKDIR"

  SRCDIR="$WORKDIR/wayland-${pkg_version}"
  BUILDDIR="$WORKDIR/build-wayland-${pkg_version}"
  PREFIX="/opt/edge"

  mkdir -p "$BUILDDIR"

  export SRCDIR BUILDDIR PREFIX
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" \
    --prefix="$PREFIX" \
    --libdir=lib \
    --buildtype=release \
    -D documentation=false
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
}
