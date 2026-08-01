#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$PROJECT_ROOT/services"

ENABLED_FILE="$SERVICES_DIR/enabled.txt"
DISABLED_FILE="$SERVICES_DIR/disabled.txt"

dry_run=false

usage() {
    cat <<'EOF'
Usage:
  configure-runit.sh
  configure-runit.sh --dry-run

Behavior:
  - Disables services declared in services/disabled.txt.
  - Enables services declared in services/enabled.txt.
  - Preserves the order of enabled.txt.
  - Safely supports repeated execution.
  - Refuses to overwrite unexpected files or conflicting symlinks.

Manifest format:
  - One runit service name per line.
  - Empty lines are ignored.
  - Lines beginning with # are ignored.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

read_manifest() {
    local manifest="$1"

    awk '
        {
            sub(/^[[:space:]]+/, "")
            sub(/[[:space:]]+$/, "")
        }

        $0 == "" {
            next
        }

        /^#/ {
            next
        }

        {
            print
        }
    ' "$manifest"
}

validate_service_name() {
    local service="$1"

    [[ "$service" =~ ^[A-Za-z0-9._@+-]+$ ]] ||
        die "Invalid service name: $service"
}

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

if ((EUID == 0)); then
    SUDO=()
else
    command -v sudo >/dev/null 2>&1 ||
        die "This script requires root privileges or sudo"

    SUDO=(sudo)
fi

run_root() {
    if "$dry_run"; then
        print_command "${SUDO[@]}" "$@"
    else
        "${SUDO[@]}" "$@"
    fi
}

disable_service() {
    local service="$1"
    local active_path="/var/service/$service"

    validate_service_name "$service"

    printf '\nDisabling service: %s\n' "$service"

    if [[ -L "$active_path" ]]; then
        printf '  Stopping supervised service.\n'

        if "$dry_run"; then
            print_command "${SUDO[@]}" sv down "$active_path"
        else
            # 服务可能本来就已经停止；这种情况不阻断配置。
            "${SUDO[@]}" sv down "$active_path" || true
        fi

        printf '  Removing service link.\n'
        run_root rm -f "$active_path"
        return
    fi

    if [[ -e "$active_path" ]]; then
        die "Refusing to remove non-symlink path: $active_path"
    fi

    printf '  Already disabled.\n'
}

enable_service() {
    local service="$1"
    local service_dir="/etc/sv/$service"
    local active_path="/var/service/$service"
    local expected_target
    local current_target

    validate_service_name "$service"

    printf '\nEnabling service: %s\n' "$service"

    [[ -d "$service_dir" ]] ||
        die "Service directory does not exist: $service_dir"

    expected_target="$(
        readlink -f "$service_dir"
    )"

    if [[ -L "$active_path" ]]; then
        current_target="$(
            readlink -f "$active_path" 2>/dev/null || true
        )"

        if [[ "$current_target" == "$expected_target" ]]; then
            printf '  Correct service link already exists.\n'
        else
            die \
                "Conflicting symlink: $active_path -> $(readlink "$active_path")"
        fi
    elif [[ -e "$active_path" ]]; then
        die "Refusing to overwrite non-symlink path: $active_path"
    else
        printf '  Creating service link.\n'
        run_root ln -s "$service_dir" "$active_path"
    fi

    if [[ -e "$service_dir/down" ]]; then
        printf >&2 \
            'Warning: %s contains a down file and may not start automatically after reboot.\n' \
            "$service_dir"
    fi

    printf '  Requesting service startup.\n'

    if "$dry_run"; then
        print_command "${SUDO[@]}" sv up "$active_path"
        return
    fi

    "${SUDO[@]}" sv up "$active_path"
    "${SUDO[@]}" sv status "$active_path"
}

while (($# > 0)); do
    case "$1" in
        --dry-run)
            dry_run=true
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            die "Unknown argument: $1"
            ;;
    esac

    shift
done

[[ -d "$SERVICES_DIR" ]] ||
    die "Services directory not found: $SERVICES_DIR"

printf 'Runit configuration\n'
printf '  Service directory: /var/service\n'

if "$dry_run"; then
    printf '  Mode: dry run\n'
else
    printf '  Mode: apply\n'
fi

if [[ -f "$DISABLED_FILE" ]]; then
    while IFS= read -r service; do
        disable_service "$service"
    done < <(read_manifest "$DISABLED_FILE")
fi

if [[ -f "$ENABLED_FILE" ]]; then
    while IFS= read -r service; do
        enable_service "$service"
    done < <(read_manifest "$ENABLED_FILE")
fi

printf '\nConfigured service status:\n'

if [[ -f "$ENABLED_FILE" ]]; then
    while IFS= read -r service; do
        if "$dry_run"; then
            printf '  %s: status not checked during dry run\n' "$service"
        else
            "${SUDO[@]}" sv status "/var/service/$service" || true
        fi
    done < <(read_manifest "$ENABLED_FILE")
fi

printf '\nRunit configuration completed.\n'
