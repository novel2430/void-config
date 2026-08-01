#!/usr/bin/env bash
# Execution environment setup.
#
# The framework owns these paths and exports them to recipes. Recipes may set
# SRCDIR and BUILDDIR later, but they should not redefine the managed roots.

al_compute_work_key() {
  local raw short
  raw="$(printf '%s\n' \
    "$AIRLOCK_PREFIX" \
    "$pkg_name" \
    "$pkg_version" \
    "$pkg_mode" \
    "$pkg_type" \
    | sha256sum | awk '{print $1}')"

  short="${raw:0:16}"
  printf '%s-%s-%s\n' "$pkg_name" "$pkg_version" "$short"
}

al_pkg_cache_root() {
  local key="$1"
  echo "$AIRLOCK_TMPDIR/cache/$key"
}

al_setup_env() {
  al_mkdir "$AIRLOCK_TMPDIR" || return 1
  al_mkdir "$AIRLOCK_TMPDIR/cache" || return 1

  local work_key cache_root
  work_key="$(al_compute_work_key)" || return 1
  al_log_info "Current Calculate Hash = $work_key"
  cache_root="$(al_pkg_cache_root "$work_key")" || return 1

  WORKDIR="$cache_root"
  STAGE_DIR="$(mktemp -d "$AIRLOCK_TMPDIR/${pkg_name}.stage.XXXXXX")" || return 1
  PREFIX="$AIRLOCK_PREFIX"
  SRCDIR=""
  BUILDDIR=""

  COMMIT_STATE_DIR="$WORKDIR/.airlock-state"
  COMMIT_CREATED_DIRS_FILE="$COMMIT_STATE_DIR/created_dirs.txt"

  al_mkdir "$COMMIT_STATE_DIR" || return 1
  : > "$COMMIT_CREATED_DIRS_FILE" || return 1

  al_mkdir "$WORKDIR" || return 1

  export WORKDIR
  export STAGE_DIR
  export PREFIX
  export SRCDIR
  export BUILDDIR
  export AIRLOCK_WORK_KEY="$work_key"
  export COMMIT_STATE_DIR
  export COMMIT_CREATED_DIRS_FILE

  al_log_info "WORKDIR=$WORKDIR"
  al_log_info "STAGE_DIR=$STAGE_DIR"
  al_log_info "PREFIX=$PREFIX"
  al_log_info "WORK_KEY=$AIRLOCK_WORK_KEY"
}
