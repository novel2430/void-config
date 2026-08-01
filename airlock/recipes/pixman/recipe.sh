pkg_name="pixman"
pkg_version="0.46.4"
pkg_mode="managed"
pkg_type="source"

PIXMANN_TARBALL="pixman-${pkg_version}.tar.xz"

stage_acquire() {
  mkdir -p "$WORKDIR/downloads"

  al_fetch_cached_url \
    "https://www.cairographics.org/releases/${PIXMANN_TARBALL}" \
    "$WORKDIR/downloads/$PIXMANN_TARBALL"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/downloads/$PIXMANN_TARBALL" \
    "$WORKDIR"

  SRCDIR="$WORKDIR/pixman-${pkg_version}"
  BUILDDIR="$WORKDIR/build-pixman-${pkg_version}"
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
