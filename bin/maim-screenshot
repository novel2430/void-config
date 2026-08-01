#!/usr/bin/env bash

set -euo pipefail

path="$HOME/Pictures/screenshot"
mkdir -p "$path"

now_date="$(date '+%Y%m%d-%H%M%S')"
file_name="${path}/${now_date}.png"

notify() {
  dunstify -a "Screenshot" "$1" "saved as\n${file_name}" -r 2003 || true
}

take_full() {
  maim "${file_name}"
}

take_select() {
  # maim -s: 取消会返回非 0；我们静默退出
  if ! maim -s "${file_name}"; then
    exit 0
  fi
}

do_edit() {
  cat "${file_name}" | com.github.phase1geo.annotator -i &
}

pick="${1:-}"
if [ -z "$pick" ]; then
  pick="$(rofi -dmenu -p "Screenshot (maim)" <<<'full
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
    exit 0
    ;;
esac
