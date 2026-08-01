pkg_name="gcc"
pkg_version="16.1.0"
pkg_mode="managed"
pkg_type="source"

GCC_TARBALL="gcc-${pkg_version}.tar.xz"

stage_acquire() {
  mkdir -p "$WORKDIR/downloads"

  al_fetch_cached_url \
    "https://ftp.gnu.org/gnu/gcc/gcc-${pkg_version}/${GCC_TARBALL}" \
    "$WORKDIR/downloads/$GCC_TARBALL"
}

stage_prepare() {
  al_extract_archive_for_recipe \
    "$WORKDIR/downloads/$GCC_TARBALL" \
    "$WORKDIR"

  SRCDIR="$WORKDIR/gcc-${pkg_version}"
  BUILDDIR="$WORKDIR/build-gcc-${pkg_version}"
  PREFIX="/opt/edge"

  (
    cd "$SRCDIR"
    ./contrib/download_prerequisites
  )

  mkdir -p "$BUILDDIR"

  export SRCDIR BUILDDIR PREFIX
}

stage_configure() {
  (
    cd "$BUILDDIR"

    "$SRCDIR/configure" \
      --prefix="$PREFIX" \
      --enable-languages=c,c++ \
      --disable-multilib \
      --disable-bootstrap \
      --enable-threads=posix \
      --enable-shared \
      --enable-__cxa_atexit \
      --with-system-zlib
  )
}

stage_build() {
  make -C "$BUILDDIR" -j8
}

stage_stage() {
  make -C "$BUILDDIR" \
    DESTDIR="$STAGE_DIR" \
    install
}
