#!/usr/bin/env bash
# Runtime configuration loading.
#
# v0 keeps configuration intentionally small and environment-driven.
# This allows easy testing and avoids committing to a config-file format yet.

al_load_config() {
  AIRLOCK_PREFIX="${AIRLOCK_PREFIX:-/usr/local}"
  AIRLOCK_DB_ROOT="${AIRLOCK_DB_ROOT:-/var/airlock_db}"
  AIRLOCK_RECIPES_DIR="${AIRLOCK_RECIPES_DIR:-$AIRLOCK_BASE_DIR/recipes}"
  AIRLOCK_TMPDIR="${AIRLOCK_TMPDIR:-/tmp/airlock}"
  AIRLOCK_LOG_LEVEL="${AIRLOCK_LOG_LEVEL:-info}"
  AIRLOCK_LOG_FILE="${AIRLOCK_LOG_FILE:-}"
  AIRLOCK_FORCE="${AIRLOCK_FORCE:-0}"
  AIRLOCK_UI_COLOR="${AIRLOCK_UI_COLOR:-1}"

  export AIRLOCK_FORCE
  export AIRLOCK_PREFIX
  export AIRLOCK_DB_ROOT
  export AIRLOCK_RECIPES_DIR
  export AIRLOCK_TMPDIR
  export AIRLOCK_LOG_LEVEL
  export AIRLOCK_LOG_FILE
  export AIRLOCK_UI_COLOR
}
