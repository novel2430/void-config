#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLATPAK_DIR="$PROJECT_ROOT/flatpak"
SETTINGS_FILE="$FLATPAK_DIR/settings.conf"
OVERRIDES_DIR="$FLATPAK_DIR/overrides"

dry_run=false
sync_mode=false

usage() {
    cat <<'EOF'
Usage:
  configure-flatpak.sh
  configure-flatpak.sh --dry-run
  configure-flatpak.sh --sync
  configure-flatpak.sh --sync --dry-run

Modes:
  default
      Apply the declared settings and overrides additively.
      Overrides removed from manifest files are not automatically removed
      from the live Flatpak configuration.

  --sync
      Reset each managed override target before applying its manifest.
      This makes the repository authoritative for managed applications,
      but removes manual changes made through Flatseal or flatpak override.

Options:
  --dry-run
      Print the operations without modifying Flatpak configuration.

  --sync
      Reset managed override targets before applying them.

  -h, --help
      Show this help.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
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

read_setting() {
    local key="$1"
    local file="$2"

    awk -v wanted="$key" '
        /^[[:space:]]*(#|$)/ {
            next
        }

        {
            separator = index($0, "=")

            if (separator == 0) {
                next
            }

            key = substr($0, 1, separator - 1)
            value = substr($0, separator + 1)

            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)

            if (key == wanted) {
                print value
                exit
            }
        }
    ' "$file"
}

validate_override_option() {
    local option="$1"

    case "$option" in
        --filesystem=*|\
        --nofilesystem=*|\
        --persist=*|\
        --env=*|\
        --unset-env=*|\
        --socket=*|\
        --nosocket=*|\
        --device=*|\
        --nodevice=*|\
        --share=*|\
        --unshare=*|\
        --talk-name=*|\
        --no-talk-name=*|\
        --system-talk-name=*|\
        --no-system-talk-name=*|\
        --own-name=*|\
        --no-own-name=*)
            return 0
            ;;

        *)
            die "Unsupported override option: $option"
            ;;
    esac
}

print_command() {
    printf '  '

    printf '%q ' "$@"

    printf '\n'
}

apply_global_override() {
    local file="$OVERRIDES_DIR/global.txt"
    local options=()

    [[ -f "$file" ]] || return 0

    mapfile -t options < <(read_manifest "$file")

    for option in "${options[@]}"; do
        validate_override_option "$option"
    done

    printf '\nGlobal overrides:\n'

    if "$sync_mode"; then
        if "$dry_run"; then
            print_command flatpak override --user --reset
        else
            flatpak override --user --reset
        fi
    fi

    if ((${#options[@]} == 0)); then
        printf '  No global override options declared.\n'
        return 0
    fi

    if "$dry_run"; then
        print_command flatpak override --user "${options[@]}"
    else
        flatpak override --user "${options[@]}"
    fi
}

apply_app_override() {
    local file="$1"
    local filename
    local app_id
    local options=()

    filename="$(basename "$file")"
    app_id="${filename%.txt}"

    if [[ "$app_id" == "global" ]]; then
        return 0
    fi

    if ! flatpak info --user "$app_id" >/dev/null 2>&1; then
        warn "Skipping override for uninstalled user application: $app_id"
        return 0
    fi

    mapfile -t options < <(read_manifest "$file")

    for option in "${options[@]}"; do
        validate_override_option "$option"
    done

    printf '\nApplication override: %s\n' "$app_id"

    if "$sync_mode"; then
        if "$dry_run"; then
            print_command flatpak override --user --reset "$app_id"
        else
            flatpak override --user --reset "$app_id"
        fi
    fi

    if ((${#options[@]} == 0)); then
        printf '  No override options declared.\n'
        return 0
    fi

    if "$dry_run"; then
        print_command \
            flatpak override \
            --user \
            "${options[@]}" \
            "$app_id"
    else
        flatpak override \
            --user \
            "${options[@]}" \
            "$app_id"
    fi
}

while (($# > 0)); do
    case "$1" in
        --dry-run)
            dry_run=true
            ;;

        --sync)
            sync_mode=true
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

command -v flatpak >/dev/null 2>&1 ||
    die "flatpak is not installed"

[[ -d "$OVERRIDES_DIR" ]] ||
    die "Overrides directory not found: $OVERRIDES_DIR"

printf 'Flatpak configuration mode: '

if "$sync_mode"; then
    printf 'synchronized\n'
else
    printf 'additive\n'
fi

if [[ -f "$SETTINGS_FILE" ]]; then
    languages="$(read_setting languages "$SETTINGS_FILE")"

    if [[ -n "$languages" ]]; then
        printf '\nLanguages:\n'
        printf '  %s\n' "$languages"

        if "$dry_run"; then
            print_command \
                flatpak config \
                --user \
                --set \
                languages \
                "$languages"
        else
            flatpak config \
                --user \
                --set \
                languages \
                "$languages"
        fi
    fi
fi

apply_global_override

shopt -s nullglob

override_files=(
    "$OVERRIDES_DIR"/*.txt
)

for file in "${override_files[@]}"; do
    apply_app_override "$file"
done

printf '\nFlatpak configuration completed.\n'
