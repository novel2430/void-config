#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(dirname "$SCRIPT_DIR")

COMMON_CONFIG="$REPO_ROOT/dotfiles/config.conf"
HOSTS_DIR="$REPO_ROOT/hosts"
HOST_SELECTOR_FILE="$REPO_ROOT/.host"

host_name=""
common_only=false

usage() {
    cat <<'EOF'
Usage:
  install-dotfiles.sh
  install-dotfiles.sh --host void-vm
  install-dotfiles.sh --common-only
  install-dotfiles.sh --host main-desktop

Default behavior:
  Reads and merges:

    dotfiles/config.conf
    hosts/<host>/dotfiles.conf

  Host-specific entries override common entries when they use the
  same target value.

Host resolution order:
  1. --host NAME
  2. VOID_CONFIG_HOST environment variable
  3. .host file in the repository root
  4. System short hostname

Options:
  --host NAME
      Select a host profile explicitly.

  --common-only
      Process only dotfiles/config.conf.

  -h, --help
      Show this help.

Configuration format:
  local|SOURCE|TARGET
  remote|GIT_URL|TARGET

Examples:
  local|dotfiles/bash/bashrc|~/.bashrc
  remote|https://github.com/user/nvim.git|~/.config/nvim
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

trim() {
    value=$1

    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}

    printf '%s\n' "$value"
}

read_selector() {
    file=$1

    while IFS= read -r line || [ -n "$line" ]; do
        line=$(trim "$line")

        case "$line" in
            ''|'#'*)
                continue
                ;;
        esac

        printf '%s\n' "$line"
        return 0
    done < "$file"

    return 1
}

validate_host_name() {
    value=$1

    case "$value" in
        ''|*[!A-Za-z0-9._-]*)
            die "invalid host name: $value"
            ;;
    esac
}

resolve_host() {
    if [ -n "$host_name" ]; then
        :
    elif [ -n "${VOID_CONFIG_HOST:-}" ]; then
        host_name=$VOID_CONFIG_HOST
    elif [ -r "$HOST_SELECTOR_FILE" ]; then
        host_name=$(read_selector "$HOST_SELECTOR_FILE") ||
            die "no host name found in $HOST_SELECTOR_FILE"
    else
        host_name=$(hostname -s)
    fi

    validate_host_name "$host_name"
}

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

resolve_symlink_target() {
    link_path=$1
    raw_target=$(readlink "$link_path")

    case "$raw_target" in
        /*)
            candidate=$raw_target
            ;;
        *)
            candidate="$(dirname "$link_path")/$raw_target"
            ;;
    esac

    readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate"
}

is_repo_managed_path() {
    path=$1

    case "$path" in
        "$REPO_ROOT"|"$REPO_ROOT"/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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
        printf 'error: local source does not exist: %s\n' \
            "$source_path" >&2
        return 1
    fi

    source_path=$(readlink -f "$source_path")
    mkdir -p "$(dirname "$target_path")"

    if [ -L "$target_path" ]; then
        current_target=$(readlink "$target_path")
        current_resolved=$(resolve_symlink_target "$target_path")

        if [ "$current_resolved" = "$source_path" ]; then
            printf 'ok: %s\n' "$target_path"
            return 0
        fi

        # 允许更新由当前仓库创建的 symlink。
        # 外部 symlink 不自动覆盖。
        if is_repo_managed_path "$current_resolved"; then
            rm "$target_path"
            ln -s "$source_path" "$target_path"

            printf 'relinked: %s -> %s\n' \
                "$target_path" "$source_path"

            return 0
        fi

        printf 'skip: external symlink already exists: %s -> %s\n' \
            "$target_path" "$current_target" >&2

        return 0
    fi

    if [ -e "$target_path" ]; then
        printf 'skip: target already exists: %s\n' \
            "$target_path" >&2

        return 0
    fi

    ln -s "$source_path" "$target_path"

    printf 'linked: %s -> %s\n' \
        "$target_path" "$source_path"
}

install_remote() {
    git_url=$1
    target_value=$2
    target_path=$(expand_target_path "$target_value")

    mkdir -p "$(dirname "$target_path")"

    if [ -d "$target_path/.git" ]; then
        existing_url=$(
            git -C "$target_path" remote get-url origin 2>/dev/null ||
                true
        )

        if [ "$existing_url" = "$git_url" ]; then
            printf 'ok: Git repository already exists: %s\n' \
                "$target_path"
        else
            printf 'skip: different Git repository already exists: %s\n' \
                "$target_path" >&2
            printf '      expected: %s\n' "$git_url" >&2
            printf '      actual:   %s\n' \
                "${existing_url:-unknown}" >&2
        fi

        return 0
    fi

    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        printf '%s\n' \
            "skip: target already exists and is not the expected Git repository: $target_path" \
            >&2

        return 0
    fi

    git clone "$git_url" "$target_path"

    printf 'cloned: %s -> %s\n' \
        "$git_url" "$target_path"
}

merge_configs() {
    output_file=$1
    shift

    awk -F '|' '
        function trim(value) {
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            return value
        }

        function fail(message) {
            printf "error: %s:%d: %s\n", FILENAME, FNR, message \
                > "/dev/stderr"

            failed = 1
            exit 1
        }

        /^[[:space:]]*$/ {
            next
        }

        /^[[:space:]]*#/ {
            next
        }

        {
            if (NF != 3) {
                fail("configuration entry must contain exactly three fields")
            }

            entry_type = trim($1)
            source = trim($2)
            target = trim($3)

            if (entry_type == "") {
                fail("entry type is empty")
            }

            if (source == "") {
                fail("source is empty")
            }

            if (target == "") {
                fail("target is empty")
            }

            if (entry_type != "local" && entry_type != "remote") {
                fail("unknown entry type: " entry_type)
            }

            # target 是合并键。
            # 后读取的 host 配置会覆盖通用配置。
            if (!(target in seen)) {
                order[++count] = target
                seen[target] = 1
            }

            record[target] = entry_type "|" source "|" target
        }

        END {
            if (failed) {
                exit 1
            }

            for (i = 1; i <= count; i++) {
                target = order[i]
                print record[target]
            }
        }
    ' "$@" > "$output_file"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --host)
            [ "$#" -ge 2 ] ||
                die "--host requires a host name"

            host_name=$2
            shift
            ;;

        --common-only)
            common_only=true
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            die "unknown argument: $1"
            ;;
    esac

    shift
done

[ -r "$COMMON_CONFIG" ] ||
    die "common config file not found: $COMMON_CONFIG"

config_files=$COMMON_CONFIG

if [ "$common_only" = false ]; then
    resolve_host

    host_config="$HOSTS_DIR/$host_name/dotfiles.conf"

    if [ -r "$host_config" ]; then
        config_files="$config_files
$host_config"
    else
        printf 'notice: no host-specific dotfiles config: %s\n' \
            "$host_config"
    fi
fi

merged_config=$(mktemp)
trap 'rm -f "$merged_config"' EXIT HUP INT TERM

# 不能直接展开带换行的 config_files 并保持可靠 quoting，
# 因此根据是否存在 host 配置明确调用。
if [ "$common_only" = true ]; then
    merge_configs "$merged_config" "$COMMON_CONFIG"
elif [ -r "$HOSTS_DIR/$host_name/dotfiles.conf" ]; then
    merge_configs \
        "$merged_config" \
        "$COMMON_CONFIG" \
        "$HOSTS_DIR/$host_name/dotfiles.conf"
else
    merge_configs "$merged_config" "$COMMON_CONFIG"
fi

printf 'Dotfiles installation profile\n'

if [ "$common_only" = true ]; then
    printf '  Mode: common only\n'
else
    printf '  Host: %s\n' "$host_name"
    printf '  Mode: common + host overrides\n'
fi

printf '\n'

while IFS='|' read -r entry_type source_value target_value ||
      [ -n "${entry_type}${source_value}${target_value}" ]; do

    case "$entry_type" in
        local)
            install_local "$source_value" "$target_value"
            ;;
        remote)
            install_remote "$source_value" "$target_value"
            ;;
        *)
            die "unknown merged entry type: $entry_type"
            ;;
    esac
done < "$merged_config"
