#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XBPS_DIR="$PROJECT_ROOT/xbps"

usage() {
    cat <<'EOF'
Usage:
  install-xbps.sh
  install-xbps.sh base
  install-xbps.sh base desktop development
  install-xbps.sh --dry-run
  install-xbps.sh --dry-run desktop

Without category arguments, all managed categories are installed.

Managed categories:
  base
  desktop
  development
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

dry_run=false
categories=()

while (($# > 0)); do
    case "$1" in
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

if ((${#categories[@]} == 0)); then
    categories=(
        bootstrap
        base
        development
	      cli
        desktop
	      gui
    )
fi

temporary_package_list="$(mktemp)"
trap 'rm -f "$temporary_package_list"' EXIT

for category in "${categories[@]}"; do
    manifest="$XBPS_DIR/$category.txt"

    [[ -f "$manifest" ]] ||
        die "Manifest not found: $manifest"

    read_manifest "$manifest" >> "$temporary_package_list"
done

mapfile -t packages < <(
    sort -u "$temporary_package_list"
)

if ((${#packages[@]} == 0)); then
    printf 'No packages found in selected manifests.\n'
    exit 0
fi

printf 'Selected categories:\n'
printf '  %s\n' "${categories[@]}"

printf '\nPackages (%d):\n' "${#packages[@]}"
printf '  %s\n' "${packages[@]}"

if "$dry_run"; then
    printf '\nRunning XBPS dry run...\n'

    sudo xbps-install \
        --sync \
        --dry-run \
        "${packages[@]}"
else
    printf '\nInstalling packages...\n'

    sudo xbps-install \
        --sync \
        --yes \
        "${packages[@]}"
fi
