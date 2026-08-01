#!/usr/bin/env bash

set -euo pipefail

path="$HOME/Pictures/screenshot"
mkdir -p "$path"

now_date="$(date '+%Y%m%d-%H%M%S')"
file_name="${path}/${now_date}.png"

notify() {
  # $1 = title
  dunstify -a "Screenshot" "$1" "saved as\n${file_name}" -r 2003 || true
}

take_full() {
  grim "${file_name}"
}

take_select() {
  region="$(slurp || true)"
  [ -z "${region:-}" ] && exit 0
  grim -g "$region" "${file_name}"
}

do_edit() {
  # 若需要阻塞直到编辑完成，保持前台；否则可在末尾加 &。
  cat "${file_name}" | com.github.phase1geo.annotator -i &
}

  pick="${1:-}"
  if [ -z "$pick" ]; then
    pick="$(rofi -dmenu -p "Screenshot" <<<'full
select
full & edit
select & edit')"
  fi

  case "$pick" in
    "full")
      take_full && notify "Full"
      ;;
    "select")
      take_select && notify "Select"
      ;;
    "full & edit"|"full-edit")
      sleep 1 && take_full && notify "Full + Edit" && do_edit
      ;;
    "select & edit"|"select-edit"|"edit")
      take_select && notify "Select + Edit" && do_edit
      ;;
    *)
      # 未选择或取消
      exit 0
      ;;
  esac

