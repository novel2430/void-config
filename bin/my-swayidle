#!/usr/bin/env bash

dpms_off_cmd="wlopm --off HDMI-A-1; wlopm --off eDP-1; wlopm --off VGA-1; wlopm --off LVDS-1; wlopm --off HDMI-A-2; wlopm --off DP-1; wlopm --off DP-3"
dpms_on_cmd="wlopm --on HDMI-A-1; wlopm --on eDP-1; wlopm --on VGA-1; wlopm --on LVDS-1; wlopm --on HDMI-A-2; wlopm --on DP-1; wlopm --on DP-3"
idle_dpms_standby=300

swayidle -w \
  timeout ${idle_dpms_standby} "${dpms_off_cmd}" resume "${dpms_on_cmd}"
