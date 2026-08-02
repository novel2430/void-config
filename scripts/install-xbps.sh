#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

XBPS_DIR="$PROJECT_ROOT/xbps"
HOSTS_DIR="$PROJECT_ROOT/hosts"
HOST_SELECTOR_FILE="$PROJECT_ROOT/.host"

dry_run=false
include_host_extra=false
host_name=""
categories=()

usage() {
    cat <<'EOF'
Usage:
  install-xbps.sh
  install-xbps.sh --host void-vm
  install-xbps.sh desktop gui
  install-xbps.sh --host main-desktop desktop gui
  install-xbps.sh --host-extra desktop
  install-xbps.sh --dry-run
  install-xbps.sh --dry-run --host void-vm

Default behavior:
  When no category arguments are provided, the script reads:

    hosts/<host>/xbps.categories
    hosts/<host>/xbps.txt

  The categories file selects shared manifests from:

    xbps/<category>.txt

Host resolution order:
  1. --host NAME
  2. VOID_CONFIG_HOST environment variable
  3. .host file in the project root
  4. system short hostname

Explicit category behavior:
  When categories are provided, only those shared category manifests
  are installed.

  Use --host-extra to additionally include:

    hosts/<host>/xbps.txt

Options:
  --host NAME
      Select a host profile explicitly.

  --host-extra
      Include the host-specific xbps.txt when explicit categories
      are provided.

  --dry-run
      Ask XBPS to show the planned transaction without installing.

  -h, --help
      Show this help.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

read_manifest() {
    local file="$1"

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
    ' "$file"
}

validate_name() {
    local kind="$1"
    local value="$2"

    [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] ||
        die "Invalid $kind name: $value"
}

resolve_host() {
    if [[ -n "$host_name" ]]; then
        :
    elif [[ -n "${VOID_CONFIG_HOST:-}" ]]; then
        host_name="$VOID_CONFIG_HOST"
    elif [[ -f "$HOST_SELECTOR_FILE" ]]; then
        host_name="$(
            read_manifest "$HOST_SELECTOR_FILE" |
                head -n 1
        )"
    else
        host_name="$(hostname -s)"
    fi

    [[ -n "$host_name" ]] ||
        die "Unable to determine host profile"

    validate_name host "$host_name"
}

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

while (($# > 0)); do
    case "$1" in
        --host)
            (($# >= 2)) ||
                die "--host requires a host name"

            host_name="$2"
            shift
            ;;

        --host-extra)
            include_host_extra=true
            ;;

        --dry-run)
            dry_run=true
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        -*)
            die "Unknown option: $1"
            ;;

        *)
            categories+=("$1")
            ;;
    esac

    shift
done

command -v xbps-install >/dev/null 2>&1 ||
    die "xbps-install was not found"

[[ -d "$XBPS_DIR" ]] ||
    die "XBPS manifest directory not found: $XBPS_DIR"

resolve_host

HOST_DIR="$HOSTS_DIR/$host_name"
HOST_CATEGORY_FILE="$HOST_DIR/xbps.categories"
HOST_PACKAGE_FILE="$HOST_DIR/xbps.txt"

profile_mode=false

if ((${#categories[@]} == 0)); then
    profile_mode=true
    include_host_extra=true

    [[ -f "$HOST_CATEGORY_FILE" ]] ||
        die "Host category file not found: $HOST_CATEGORY_FILE"

    mapfile -t categories < <(
        read_manifest "$HOST_CATEGORY_FILE"
    )
fi

if ((${#categories[@]} == 0)); then
    die "No XBPS categories selected"
fi

temporary_package_list="$(mktemp)"
trap 'rm -f "$temporary_package_list"' EXIT

printf 'XBPS installation profile\n'
printf '  Host: %s\n' "$host_name"

if "$profile_mode"; then
    printf '  Mode: host profile\n'
else
    printf '  Mode: explicit categories\n'
fi

printf '\nSelected categories:\n'

for category in "${categories[@]}"; do
    validate_name category "$category"

    manifest="$XBPS_DIR/$category.txt"

    [[ -f "$manifest" ]] ||
        die "Manifest not found: $manifest"

    printf '  %s\n' "$category"

    read_manifest "$manifest" >> "$temporary_package_list"
done

if "$include_host_extra"; then
    printf '\nHost-specific manifest:\n'

    if [[ -f "$HOST_PACKAGE_FILE" ]]; then
        printf '  %s\n' "$HOST_PACKAGE_FILE"
        read_manifest "$HOST_PACKAGE_FILE" >> "$temporary_package_list"
    else
        printf '  None\n'
    fi
fi

mapfile -t packages < <(
    sort -u "$temporary_package_list"
)

if ((${#packages[@]} == 0)); then
    printf '\nNo packages found in selected manifests.\n'
    exit 0
fi

printf '\nPackages (%d):\n' "${#packages[@]}"
printf '  %s\n' "${packages[@]}"

if ((EUID == 0)); then
    SUDO=()
else
    command -v sudo >/dev/null 2>&1 ||
        die "sudo is required when not running as root"

    SUDO=(sudo)
fi

if "$dry_run"; then
    printf '\nRunning XBPS dry run:\n'

    print_command \
        "${SUDO[@]}" \
        xbps-install \
        --sync \
        --dry-run \
        "${packages[@]}"

    "${SUDO[@]}" xbps-install \
        --sync \
        --dry-run \
        "${packages[@]}"
else
    printf '\nInstalling packages:\n'

    "${SUDO[@]}" xbps-install \
        --sync \
        --yes \
        "${packages[@]}"
fi
