pkg_name="libdrm"
pkg_version="2.4.134"
pkg_mode="managed"
pkg_type="source"

LIBDRM_TARBALL="libdrm-${pkg_version}.tar.xz"

stage_acquire() {
  mkdir -p "$WORKDIR/downloads"

  al_fetch_cached_url \
    "https://dri.freedesktop.org/libdrm/${LIBDRM_TARBALL}" \
    "$WORKDIR/downloads/$LIBDRM_TARBALL"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/downloads/$LIBDRM_TARBALL" \
    "$WORKDIR"

  SRCDIR="$WORKDIR/libdrm-${pkg_version}"
  BUILDDIR="$WORKDIR/build-libdrm-${pkg_version}"
  PREFIX="/opt/edge"

  mkdir -p "$BUILDDIR"

  export SRCDIR BUILDDIR PREFIX
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" \
    --prefix="$PREFIX" \
    --libdir=lib \
    --buildtype=release
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
}
