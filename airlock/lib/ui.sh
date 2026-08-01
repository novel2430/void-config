#!/usr/bin/env bash
# UI helpers for colorful, aligned terminal output.

al_ui_init_colors() {
  if [ "${AIRLOCK_UI_COLOR:-1}" != "1" ]; then
    AL_UI_RESET=""
    AL_UI_BOLD=""
    AL_UI_DIM=""
    AL_UI_RED=""
    AL_UI_GREEN=""
    AL_UI_YELLOW=""
    AL_UI_BLUE=""
    AL_UI_MAGENTA=""
    AL_UI_CYAN=""
    AL_UI_WHITE=""
    return
  fi

  if [ -t 1 ]; then
    AL_UI_RESET=$'\033[0m'
    AL_UI_BOLD=$'\033[1m'
    AL_UI_DIM=$'\033[2m'
    AL_UI_RED=$'\033[31m'
    AL_UI_GREEN=$'\033[32m'
    AL_UI_YELLOW=$'\033[33m'
    AL_UI_BLUE=$'\033[34m'
    AL_UI_MAGENTA=$'\033[35m'
    AL_UI_CYAN=$'\033[36m'
    AL_UI_WHITE=$'\033[37m'
  else
    AL_UI_RESET=""
    AL_UI_BOLD=""
    AL_UI_DIM=""
    AL_UI_RED=""
    AL_UI_GREEN=""
    AL_UI_YELLOW=""
    AL_UI_BLUE=""
    AL_UI_MAGENTA=""
    AL_UI_CYAN=""
    AL_UI_WHITE=""
  fi
}

al_ui_color_text() {
  local color="$1"
  shift
  printf '%s%s%s' "$color" "$*" "$AL_UI_RESET"
}

al_ui_fit() {
  local text="$1"
  local width="$2"

  if [ "$width" -le 1 ]; then
    printf '%s' "$text"
    return 0
  fi

  if [ "${#text}" -gt "$width" ]; then
    if [ "$width" -le 3 ]; then
      printf '%.*s' "$width" "$text"
    else
      printf '%s…' "${text:0:$((width - 1))}"
    fi
  else
    printf '%-*s' "$width" "$text"
  fi
}

al_ui_repeat_char() {
  local char="$1"
  local count="$2"
  local i

  for ((i = 0; i < count; i++)); do
    printf '%s' "$char"
  done
}

al_ui_terminal_width() {
  local width

  if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    width="$(tput cols 2>/dev/null || true)"
  else
    width=""
  fi

  case "$width" in
    ''|*[!0-9]*) width=100 ;;
  esac

  if [ "$width" -lt 60 ]; then
    width=60
  fi

  printf '%s\n' "$width"
}

al_ui_print_rule() {
  local width
  width="$(al_ui_terminal_width)"
  al_ui_repeat_char '─' "$width"
  printf '\n'
}

al_ui_print_title() {
  local title="$1"
  printf '%s%s%s\n' "$AL_UI_BOLD$AL_UI_CYAN" "$title" "$AL_UI_RESET"
}

al_ui_print_section() {
  local title="$1"
  printf '%s%s%s\n' "$AL_UI_BOLD$AL_UI_MAGENTA" "$title" "$AL_UI_RESET"
}

al_ui_print_kv() {
  local label="$1"
  local value="$2"
  printf '  %s%-18s%s %s\n' "$AL_UI_BOLD$AL_UI_BLUE" "$label" "$AL_UI_RESET" "$value"
}

al_ui_color() {
  local name="${1:-}"

  [ "${AIRLOCK_UI_COLOR:-1}" = "1" ] || return 0

  case "$name" in
    reset) printf '\033[0m' ;;
    bold) printf '\033[1m' ;;
    dim) printf '\033[2m' ;;
    cyan) printf '\033[36m' ;;
    blue) printf '\033[34m' ;;
    bold_blue) printf '\033[1;34m' ;;
    *) printf '' ;;
  esac
}

al_ui_reset() {
  al_ui_color reset
}

al_ui_init_colors
