#!/usr/bin/env bash

# =====================================================================
# 優先步驟 1：立刻宣告並強制匯入 D-Bus 環境變數（這必須是腳本的第一件事！）
# =====================================================================
(
  unset WAYLAND_DISPLAY
  export XDG_CURRENT_DESKTOP=openbox
  dbus-update-activation-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP DBUS_SESSION_BUS_ADDRESS
)

# =====================================================================
# 優先步驟 2：物理性清理並重啟 Portal（徹底杜絕偶發性死鎖）
# =====================================================================
killall -q xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-document-portal
sleep 0.5 # 給系統半秒鐘反應時間

# =====================================================================
# 優先步驟 3：啟動音訊（PipeWire 也很依賴正確的 D-Bus 變數）
# =====================================================================
killall -q pipewire wireplumber pipewire-pulse
/usr/bin/pipewire &
/usr/bin/wireplumber &
/usr/bin/pipewire-pulse &

# Wallpaper
feh --bg-fill $HOME/.local/share/pics/wallpaper &
# Notify
killall dunst; dunst &
# Clipboard <Greenclip>
killall greenclip; greenclip daemon &
# GTK title bar layout
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
# GRT Dark Theme (fix for GTK4)
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus'
# IME
fcitx5 --replace -d &
# Idle DPMS (sec)
xset s off
xset s noblank
xset +dpms dpms 0 0 0
# Keyboard speed rate
xset r rate 300 50
# nm-applet
nm-applet &
# For Wemeet
flatpak override --user --unset-env=LD_PRELOAD com.tencent.wemeet &

killall sxhkd; sxhkd &

kill -TERM $(pgrep -f dwm-bar-text) 2>/dev/null; dwm-bar-text &
