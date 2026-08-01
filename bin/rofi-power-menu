#!/usr/bin/env bash
reboot_menu="Reboot"
shutdown_menu="Shutdown"
logout_menu="Logout"
res=$(printf '%s\n%s\n%s\n%s' $reboot_menu $shutdown_menu $logout_menu | rofi -dmenu -i)

if [ $res = $reboot_menu ]; then
  loginctl reboot
elif [ $res = $shutdown_menu ]; then
  loginctl poweroff
elif [ $res = $logout_menu ]; then
  pkill -KILL -u "$USER"
fi
