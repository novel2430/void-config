# Example recipe for a source-based package.
#
# This recipe demonstrates the minimal v0 metadata and per-stage overrides.

pkg_name="nvm"
pkg_version="0.40.4"
pkg_mode="managed"
pkg_type="artifact"

stage_acquire() {
  al_git_checkout_repo \
    "https://github.com/nvm-sh/nvm.git" \
    "$WORKDIR/$pkg_name" \
    "v$pkg_version"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  export SRCDIR BUILDDIR
}

stage_stage() {
  local local_share_dir="$HOME/.local/opt"
  mkdir -p "$STAGE_DIR/$local_share_dir"
  cp -r --verbose $SRCDIR "$STAGE_DIR/$local_share_dir/nvm"
}
