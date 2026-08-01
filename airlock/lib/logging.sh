#!/usr/bin/env bash
# Logging helpers.
#
# Features:
# - human-readable logs
# - stderr output by default
# - optional file duplication
# - optional color output on TTY only
# - colors are centralized for easy tweaking

al__log_level_to_num() {
  case "$1" in
    error) echo 0 ;;
    warn)  echo 1 ;;
    info)  echo 2 ;;
    debug) echo 3 ;;
    *)     echo 2 ;;
  esac
}

al__should_log() {
  local current target
  current="$(al__log_level_to_num "$AIRLOCK_LOG_LEVEL")"
  target="$(al__log_level_to_num "$1")"
  [ "$target" -le "$current" ]
}

al__timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# ------------------------------------------------------------
# Color settings
#
# Easy to change:
# - use ANSI escape codes
# - only applied when stderr is a TTY
# - file logs remain plain text
# ------------------------------------------------------------

al__init_log_colors() {
  # Allow manual disable: AIRLOCK_LOG_COLOR=0
  if [ "${AIRLOCK_LOG_COLOR:-1}" != "1" ]; then
    AL_COLOR_RESET=""
    AL_COLOR_ERROR=""
    AL_COLOR_WARN=""
    AL_COLOR_INFO=""
    AL_COLOR_DEBUG=""
    AL_COLOR_STAGE=""
    return
  fi

  # Only colorize interactive terminal output
  if [ -t 2 ]; then
    AL_COLOR_RESET=$'\033[0m'

    # Easy-to-edit palette
    AL_COLOR_ERROR=$'\033[1;31m'  # bold red
    AL_COLOR_WARN=$'\033[1;33m'   # bold yellow
    AL_COLOR_INFO=$'\033[1;32m'   # bold green
    AL_COLOR_DEBUG=$'\033[1;34m'  # bold blue
    AL_COLOR_STAGE=$'\033[1;35m'  # bold magenta
  else
    AL_COLOR_RESET=""
    AL_COLOR_ERROR=""
    AL_COLOR_WARN=""
    AL_COLOR_INFO=""
    AL_COLOR_DEBUG=""
    AL_COLOR_STAGE=""
  fi
}

al__color_for_level() {
  case "$1" in
    error) printf '%s' "$AL_COLOR_ERROR" ;;
    warn)  printf '%s' "$AL_COLOR_WARN" ;;
    info)  printf '%s' "$AL_COLOR_INFO" ;;
    debug) printf '%s' "$AL_COLOR_DEBUG" ;;
    stage) printf '%s' "$AL_COLOR_STAGE" ;;
    *)     printf '%s' "" ;;
  esac
}

al__emit_log_line() {
  local level="$1"
  shift
  local msg="$*"
  local plain_line color colored_line

  plain_line="[$(al__timestamp)] [${level^^}] $msg"

  color="$(al__color_for_level "$level")"
  if [ -n "$color" ]; then
    colored_line="${color}${plain_line}${AL_COLOR_RESET}"
  else
    colored_line="$plain_line"
  fi

  # terminal output: colored if enabled
  printf '%s\n' "$colored_line" >&2

  # file output: always plain text
  if [ -n "${AIRLOCK_LOG_FILE:-}" ]; then
    mkdir -p "$(dirname "$AIRLOCK_LOG_FILE")"
    printf '%s\n' "$plain_line" >> "$AIRLOCK_LOG_FILE"
  fi
}

al_log_debug() {
  if al__should_log debug; then
    al__emit_log_line debug "$@"
  fi
  return 0
}

al_log_info() {
  if al__should_log info; then
    al__emit_log_line info "$@"
  fi
  return 0
}

al_log_warn() {
  if al__should_log warn; then
    al__emit_log_line warn "$@"
  fi
  return 0
}

al_log_error() {
  if al__should_log error; then
    al__emit_log_line error "$@"
  fi
  return 0
}

al_log_stage() {
  if al__should_log info; then
    al__emit_log_line stage "[stage] $*"
  fi
  return 0
}

al_die() {
  al_log_error "$*"
  exit 1
}

# Initialize color palette when sourced
al__init_log_colors
