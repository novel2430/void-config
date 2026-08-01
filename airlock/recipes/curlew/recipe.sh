# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="curlew"
pkg_version="f2d7410"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/novel2430/Curlew.git" \
    "$WORKDIR/$pkg_name" \
    "$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  (
    cd "$SRCDIR"
    python3 setup.py install --prefix="$STAGE_DIR/usr"
    mv "$STAGE_DIR/usr/local/lib/python3.13/dist-packages/curlew-0.2.5-py3.13.egg/share" "$STAGE_DIR/usr/local/share"
  )
}
