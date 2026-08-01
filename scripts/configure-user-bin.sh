#!/bin/sh

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE_DIR="$REPO_ROOT/bin"
TARGET_DIR="$HOME/.local/bin"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "error: script directory not found: $SOURCE_DIR" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

for source_path in "$SOURCE_DIR"/*; do
    [ -f "$source_path" ] || continue

    command_name=$(basename "$source_path")
    target_path="$TARGET_DIR/$command_name"

    chmod +x "$source_path"

    if [ -L "$target_path" ]; then
        current_target=$(readlink "$target_path")

        if [ "$current_target" = "$source_path" ]; then
            echo "ok: $command_name"
        else
            echo "skip: $target_path points to $current_target" >&2
        fi

        continue
    fi

    if [ -e "$target_path" ]; then
        echo "skip: target already exists: $target_path" >&2
        continue
    fi

    ln -s "$source_path" "$target_path"
    echo "linked: $target_path -> $source_path"
done
