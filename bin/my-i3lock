#!/usr/bin/env bash

revert_dpms() {
    # 解鎖或鎖屏失敗後：停止任何自動 DPMS 計時
    xset +dpms dpms 0 0 0
}

indicator_radius=90
indicator_thickness=7
b_color="#3e5f44ff"
f_color="#5e936cff"
text_f_color="#eceff4ff"
wrong_color="#bf616aff"
lock_img="$HOME/.local/share/pics/wallpaper"


trap revert_dpms HUP INT TERM
xset +dpms dpms 0 0 300

i3lock --nofork \
        --ignore-empty-password \
        -i ${lock_img} --fill\
        --clock \
        --indicator \
        --radius $indicator_radius \
        --ring-width $indicator_thickness \
        --ring-color $b_color \
        --ringver-color $b_color \
        --ringwrong-color $wrong_color \
        --inside-color 00000088 \
        --insidever-color 00000088 \
        --insidewrong-color $wrong_color \
        --keyhl-color $f_color \
        --line-color 00000000 \
        --insidewrong-color $wrong_color \
        --verif-color $text_f_color \
        --modif-color $text_f_color \
        --wrong-color $text_f_color \
        --layout-color $text_f_color \
        --time-color $text_f_color \
        --date-color $text_f_color \
        --greeter-color $text_f_color \
        --separator-color 00000000

revert_dpms
