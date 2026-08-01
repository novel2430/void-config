# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="emacs"
pkg_version="29.4"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_fetch_cached_url \
    "https://ftp.gnu.org/gnu/emacs/emacs-$pkg_version.tar.gz" \
    "$WORKDIR/$pkg_version.tar.gz"
}

stage_prepare() {
  al_extract_archive_for_recipe "$WORKDIR/$pkg_version.tar.gz" "$WORKDIR" || exit 1
  SRCDIR="$WORKDIR/$pkg_name-$pkg_version"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_configure() {
  (
    cd "$SRCDIR"
    ./configure \
      --without-build-details \
      --with-modules \
      --with-x \
      --with-x-toolkit=gtk3 \
      --with-cairo \
      --with-xinput2 \
      --without-pgtk \
      --with-xwidgets \
      --with-compress-install \
      --with-toolkit-scroll-bars \
      --with-native-compilation=no \
      --with-mailutils \
      --with-tree-sitter \
      --with-sqlite3 \
      --with-dbus \
      --with-selinux \
      --prefix="$PREFIX"
  )
}

stage_build() {
  (
    cd "$SRCDIR"
    make -j4
  )
}

stage_stage() {
  (
    cd "$SRCDIR"
    make DESTDIR="$STAGE_DIR" install
    rm -rf "$STAGE_DIR$PREFIX/bin/emacs"
    al_stage_install_wrapper "bin/emacs" <<EOF
#!/usr/bin/env bash
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export JSC_SIGNAL_FOR_GC=34
exec "$PREFIX/bin/emacs-29.4" "\$@"
EOF
  )
}
