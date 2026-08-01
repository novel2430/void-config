#!/bin/sh

set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_FILE="$REPO_ROOT/dotfiles/config.conf"

if [ ! -r "$CONFIG_FILE" ]; then
    echo "error: config file not found: $CONFIG_FILE" >&2
    exit 1
fi

expand_target_path() {
    path=$1

    case "$path" in
        "~")
            printf '%s\n' "$HOME"
            ;;
        "~/"*)
            printf '%s/%s\n' "$HOME" "${path#~/}"
            ;;
        '$HOME')
            printf '%s\n' "$HOME"
            ;;
        '$HOME/'*)
            printf '%s/%s\n' "$HOME" "${path#\$HOME/}"
            ;;
        /*)
            printf '%s\n' "$path"
            ;;
        *)
            # 相对 target 默认相对于 HOME。
            printf '%s/%s\n' "$HOME" "$path"
            ;;
    esac
}

trim() {
    value=$1

    # 删除开头和结尾的空白。
    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}

    printf '%s\n' "$value"
}

install_local() {
    source_value=$1
    target_value=$2

    case "$source_value" in
        /*)
            source_path=$source_value
            ;;
        *)
            source_path="$REPO_ROOT/$source_value"
            ;;
    esac

    target_path=$(expand_target_path "$target_value")

    if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
        echo "error: local source does not exist: $source_path" >&2
        return 1
    fi

    mkdir -p "$(dirname "$target_path")"

    if [ -L "$target_path" ]; then
        current_target=$(readlink "$target_path")

        if [ "$current_target" = "$source_path" ]; then
            echo "ok: $target_path"
        else
            echo "skip: symlink already exists: $target_path -> $current_target" >&2
        fi

        return 0
    fi

    if [ -e "$target_path" ]; then
        echo "skip: target already exists: $target_path" >&2
        return 0
    fi

    ln -s "$source_path" "$target_path"
    echo "linked: $target_path -> $source_path"
}

install_remote() {
    git_url=$1
    target_value=$2
    target_path=$(expand_target_path "$target_value")

    mkdir -p "$(dirname "$target_path")"

    if [ -d "$target_path/.git" ]; then
        existing_url=$(git -C "$target_path" remote get-url origin 2>/dev/null || true)

        if [ "$existing_url" = "$git_url" ]; then
            echo "ok: Git repository already exists: $target_path"
        else
            echo "skip: different Git repository already exists: $target_path" >&2
            echo "      expected: $git_url" >&2
            echo "      actual:   ${existing_url:-unknown}" >&2
        fi

        return 0
    fi

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        echo "skip: target already exists and is not the expected Git repository: $target_path" >&2
        return 0
    fi

    git clone "$git_url" "$target_path"
    echo "cloned: $git_url -> $target_path"
}

while IFS='|' read -r raw_type raw_source raw_target extra ||
      [ -n "${raw_type}${raw_source}${raw_target}${extra}" ]; do

    entry_type=$(trim "$raw_type")
    source_value=$(trim "$raw_source")
    target_value=$(trim "$raw_target")
    extra=$(trim "$extra")

    case "$entry_type" in
        ''|'#'*)
            continue
            ;;
    esac

    if [ -n "$extra" ]; then
        echo "error: too many fields in config entry:" >&2
        echo "       $raw_type|$raw_source|$raw_target|$extra" >&2
        exit 1
    fi

    if [ -z "$source_value" ] || [ -z "$target_value" ]; then
        echo "error: source or target is empty:" >&2
        echo "       $raw_type|$raw_source|$raw_target" >&2
        exit 1
    fi

    case "$entry_type" in
        local)
            install_local "$source_value" "$target_value"
            ;;
        remote)
            install_remote "$source_value" "$target_value"
            ;;
        *)
            echo "error: unknown entry type: $entry_type" >&2
            exit 1
            ;;
    esac
done < "$CONFIG_FILE"
