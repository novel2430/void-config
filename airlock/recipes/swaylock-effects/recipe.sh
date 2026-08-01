# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="swaylock-effects"
pkg_version="1.7.0.0"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/jirutka/swaylock-effects.git" \
    "$WORKDIR/$pkg_name" \
    "v$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR/build"
  export SRCDIR BUILDDIR
}

stage_configure() {
  meson setup "$BUILDDIR" "$SRCDIR" --prefix="$PREFIX"
}

stage_build() {
  meson compile -C "$BUILDDIR"
}

stage_stage() {
  DESTDIR="$STAGE_DIR" meson install -C "$BUILDDIR"
  mkdir -p "$STAGE_DIR$PREFIX/usr/share"
  cp -r --verbose "$STAGE_DIR/usr/share/bash-completion" "$STAGE_DIR$PREFIX/share/bash-completion"
  rm -rf "$STAGE_DIR/usr/share/bash-completion"
}
