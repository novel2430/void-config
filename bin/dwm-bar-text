#!/usr/bin/env bash

set -u

INTERVAL=2

# ---------- helpers ----------
path_exists() {
  [ -r "$1" ]
}

read_first_line() {
  local path="$1"
  [ -r "$path" ] || return 1
  IFS= read -r line < "$path" || return 1
  printf '%s' "$line"
}

# ---------- CPU ----------
prev_total=0
prev_idle=0
cpu=" 0%"

read_cpu_stat() {
  local cpu_label user nice system idle iowait irq softirq steal guest guest_nice
  read -r cpu_label user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat

  local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  local idle_total=$((idle + iowait))

  REPLY="$total $idle_total"
}

get_cpu_usage() {
  local total idle_total
  read_cpu_stat
  read -r total idle_total <<< "$REPLY"

  local usage="0"

  if [ "$prev_total" -ne 0 ]; then
    local diff_total=$((total - prev_total))
    local diff_idle=$((idle_total - prev_idle))

    if [ "$diff_total" -gt 0 ]; then
      usage=$(awk -v dt="$diff_total" -v di="$diff_idle" 'BEGIN { printf "%d", (dt - di) * 100 / dt }')
    fi
  fi

  prev_total="$total"
  prev_idle="$idle_total"
  cpu=" $usage%"
}

# ---------- RAM ----------
get_ram_usage() {
  local mem_total mem_available mem_used usage

  mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  mem_available=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)

  if [ -z "${mem_total:-}" ] || [ -z "${mem_available:-}" ] || [ "$mem_total" -eq 0 ]; then
    return 1
  fi

  mem_used=$((mem_total - mem_available))
  usage=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { printf "%d", used * 100 / total }')

  printf ' %d%%' "$usage"
}

# ---------- Battery ----------
get_battery_info() {
  local base_path=""

  if path_exists "/sys/class/power_supply/BAT0/capacity"; then
    base_path="/sys/class/power_supply/BAT0"
  elif path_exists "/sys/class/power_supply/BAT1/capacity"; then
    base_path="/sys/class/power_supply/BAT1"
  else
    return 0
  fi

  local status per icon
  status=$(read_first_line "$base_path/status" 2>/dev/null || printf 'Unknown')
  per=$(read_first_line "$base_path/capacity" 2>/dev/null || printf '0')

  if [ "$per" -ge 90 ]; then
    icon="󰁹"
  elif [ "$per" -ge 70 ]; then
    icon="󰂂"
  elif [ "$per" -ge 50 ]; then
    icon="󰂀"
  elif [ "$per" -ge 30 ]; then
    icon="󰁾"
  else
    icon="󰁺"
  fi

  if [ "$status" = "Charging" ]; then
    icon="󰠠"
    printf "<span foreground='#b1d196'>%s %s%%</span>" "$icon" "$per"
  else
    printf "%s %s%%" "$icon" "$per"
  fi
}

# ---------- Temp ----------
get_cpu_temp() {
  local temp_raw=""
  local path

  for path in \
    /sys/class/thermal/thermal_zone0/temp \
    /sys/class/hwmon/hwmon1/temp1_input
  do
    if path_exists "$path"; then
      temp_raw=$(read_first_line "$path" 2>/dev/null || true)
      [ -n "$temp_raw" ] && break
    fi
  done

  if [ -z "$temp_raw" ]; then
    for path in /sys/class/hwmon/hwmon*/temp1_input; do
      [ -r "$path" ] || continue
      temp_raw=$(read_first_line "$path" 2>/dev/null || true)
      [ -n "$temp_raw" ] && break
    done
  fi

  [ -n "$temp_raw" ] || return 0

  awk -v t="$temp_raw" 'BEGIN { printf " %d°C", t / 1000 }'
}

# ---------- Main ----------
read_cpu_stat
read -r prev_total prev_idle <<< "$REPLY"
sleep "$INTERVAL"

while :; do
  get_cpu_usage
  ram="$(get_ram_usage)"
  temp="$(get_cpu_temp)"
  bat="$(get_battery_info)"
  # now="$(date '+%Y-%m-%d %a %H:%M')"

  # status="$ram $cpu [$now]"
  status="$ram $cpu"

  [ -n "$temp" ] && status="$temp $status"
  [ -n "$bat" ] && status="$bat $status"

  xsetroot -name "$status"
  sleep "$INTERVAL"
done
