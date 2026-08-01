pkg_name="yazi"
pkg_version="26.5.6"
pkg_mode="managed"
pkg_type="source"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/sxyazi/yazi.git" \
    "$WORKDIR/$pkg_name" \
    v"$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_configure() {
  (
    cd "$SRCDIR" || exit 1
    rustup default stable || exit 1
  ) || return 1
}

stage_build() {
  (
    cd "$SRCDIR" || exit 1
    cargo clean || exit 1
    cargo build --release --locked -j4 || exit 1
  ) || return 1
}

stage_stage() {
  al_stage_install_file "$SRCDIR/target/release/yazi" "bin/yazi" 755 || return 1
  al_stage_install_file "$SRCDIR/target/release/ya" "bin/ya" 755 || return 1
}
