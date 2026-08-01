#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
target_dir="$HOME/.config/xdg-desktop-portal-wlr"

if [ ! -e "$target_dir/config" ]; then
	mkdir -p $target_dir
	ln -s $SCRIPT_DIR/config $target_dir/config
fi
