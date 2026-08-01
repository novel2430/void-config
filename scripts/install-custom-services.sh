#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE_DIR="$ROOT/services/custom"
TARGET_DIR=/etc/sv

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must run as root." >&2
    exit 1
fi

for source_path in "$SOURCE_DIR"/*; do
    [ -e "$source_path" ] || continue

    service_name=$(basename "$source_path")
    target_path="$TARGET_DIR/$service_name"

    if [ -f "$source_path" ]; then
        echo "Installing custom service file: $service_name"
        install -d -m 0755 "$target_path"
        install -m 0755 "$source_path" "$target_path/run"

    elif [ -d "$source_path" ]; then
        echo "Installing custom service dir: $service_name"
        rm -rf "$target_path"
        mkdir -p "$target_path"
        cp -a "$source_path/." "$target_path/"

        [ -f "$target_path/run" ] && chmod 0755 "$target_path/run"
        [ -f "$target_path/log/run" ] && chmod 0755 "$target_path/log/run"
    fi
done
