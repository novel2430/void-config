#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

FLATPAK_DIR="$PROJECT_ROOT/flatpak"
HOSTS_DIR="$PROJECT_ROOT/hosts"
HOST_SELECTOR_FILE="$PROJECT_ROOT/.host"

FLATHUB_NAME="flathub"
FLATHUB_REPO_FILE="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATHUB_OFFICIAL_URL="https://dl.flathub.org/repo"

dry_run=false
include_host_extra=false
host_name=""
categories=()

usage() {
    cat <<'EOF'
Usage:
  install-flatpak.sh
  install-flatpak.sh --host void-vm
  install-flatpak.sh desktop
  install-flatpak.sh desktop development
  install-flatpak.sh --host-extra desktop
  install-flatpak.sh --dry-run
  install-flatpak.sh --dry-run --host void-vm

Default behavior:
  When no category arguments are provided, read:

    hosts/<host>/flatpak.categories
    hosts/<host>/flatpak.txt

  The category file selects shared manifests from:

    flatpak/<category>.txt

Host resolution order:
  1. --host NAME
  2. VOID_CONFIG_HOST environment variable
  3. .host file in the project root
  4. System short hostname

Explicit category behavior:
  When categories are explicitly provided, only those shared category
  manifests are processed.

  Use --host-extra to additionally include:

    hosts/<host>/flatpak.txt

Behavior:
  - Uses the per-user Flatpak installation.
  - Uses only the official Flathub repository.
  - Restores an existing Flathub remote to the official URL if needed.
  - Installs only applications that are not already installed.
  - Does not update, remove, or reset existing applications.
  - Ignores empty lines and lines beginning with #.

Options:
  --host NAME
      Select a host profile explicitly.

  --host-extra
      Include the host-specific flatpak.txt when explicit categories
      are provided.

  --dry-run
      Print planned operations without changing Flatpak.

  -h, --help
      Show this help.

Environment:
  VOID_CONFIG_HOST
      Select the host profile when --host is not supplied.
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
        die "Unable to determine the host profile"

    validate_name host "$host_name"
}

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

normalize_url() {
    local url="$1"
    printf '%s\n' "${url%/}"
}

remote_exists() {
    flatpak remotes \
        --user \
        --columns=name 2>/dev/null |
        grep -Fxq "$FLATHUB_NAME"
}

get_remote_url() {
    flatpak remotes \
        --user \
        --columns=name,url 2>/dev/null |
        awk -v remote="$FLATHUB_NAME" '
            $1 == remote {
                print $2
                exit
            }
        '
}

configure_flathub_remote() {
    local current_url=""
    local normalized_current=""
    local normalized_official=""

    printf '\nConfiguring official Flathub user remote:\n'

    if ! remote_exists; then
        printf '  Flathub remote is not configured.\n'
        printf '  Adding the official Flathub remote:\n'
        printf '    %s\n' "$FLATHUB_REPO_FILE"

        if "$dry_run"; then
            print_command \
                flatpak remote-add \
                --user \
                --if-not-exists \
                "$FLATHUB_NAME" \
                "$FLATHUB_REPO_FILE"
        else
            flatpak remote-add \
                --user \
                --if-not-exists \
                "$FLATHUB_NAME" \
                "$FLATHUB_REPO_FILE"
        fi

        return 0
    fi

    current_url="$(get_remote_url)"
    normalized_current="$(normalize_url "$current_url")"
    normalized_official="$(normalize_url "$FLATHUB_OFFICIAL_URL")"

    if [[ "$normalized_current" == "$normalized_official" ]]; then
        printf '  Flathub already uses the official repository:\n'
        printf '    %s\n' "$current_url"
        return 0
    fi

    printf '  Current non-official URL:\n'
    printf '    %s\n' "${current_url:-unknown}"

    printf '  Restoring official URL:\n'
    printf '    %s\n' "$FLATHUB_OFFICIAL_URL"

    if "$dry_run"; then
        print_command \
            flatpak remote-modify \
            --user \
            "--url=$FLATHUB_OFFICIAL_URL" \
            "$FLATHUB_NAME"
    else
        flatpak remote-modify \
            --user \
            "--url=$FLATHUB_OFFICIAL_URL" \
            "$FLATHUB_NAME"
    fi
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
            categories+=("${1%.txt}")
            ;;
    esac

    shift
done

command -v flatpak >/dev/null 2>&1 ||
    die "flatpak is not installed; add it to xbps/bootstrap.txt first"

[[ -d "$FLATPAK_DIR" ]] ||
    die "Flatpak manifest directory not found: $FLATPAK_DIR"

resolve_host

HOST_DIR="$HOSTS_DIR/$host_name"
HOST_CATEGORY_FILE="$HOST_DIR/flatpak.categories"
HOST_APP_FILE="$HOST_DIR/flatpak.txt"

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

temporary_app_list="$(mktemp)"
trap 'rm -f "$temporary_app_list"' EXIT

printf 'Flatpak installation profile\n'
printf '  Host: %s\n' "$host_name"

if "$profile_mode"; then
    printf '  Mode: host profile\n'
else
    printf '  Mode: explicit categories\n'
fi

printf '\nSelected categories:\n'

if ((${#categories[@]} == 0)); then
    printf '  None\n'
else
    for category in "${categories[@]}"; do
        validate_name category "$category"

        manifest="$FLATPAK_DIR/$category.txt"

        [[ -f "$manifest" ]] ||
            die "Manifest not found: $manifest"

        printf '  %s\n' "$category"

        read_manifest "$manifest" >> "$temporary_app_list"
    done
fi

if "$include_host_extra"; then
    printf '\nHost-specific manifest:\n'

    if [[ -f "$HOST_APP_FILE" ]]; then
        printf '  %s\n' "$HOST_APP_FILE"
        read_manifest "$HOST_APP_FILE" >> "$temporary_app_list"
    else
        printf '  None\n'
    fi
fi

mapfile -t requested_apps < <(
    sort -u "$temporary_app_list"
)

# 即使清单为空，也确保 Flathub remote 使用官方地址。
configure_flathub_remote

if ((${#requested_apps[@]} == 0)); then
    printf '\nNo applications found in selected manifests.\n'

    if "$dry_run"; then
        printf 'Dry run completed. No changes were made.\n'
    fi

    exit 0
fi

declare -A installed_set=()

while IFS= read -r app_id; do
    [[ -n "$app_id" ]] || continue
    installed_set["$app_id"]=1
done < <(
    flatpak list \
        --user \
        --app \
        --columns=application 2>/dev/null
)

already_installed=()
missing_apps=()

for app_id in "${requested_apps[@]}"; do
    if [[ -n "${installed_set[$app_id]+present}" ]]; then
        already_installed+=("$app_id")
    else
        missing_apps+=("$app_id")
    fi
done

printf '\nManaged applications (%d):\n' "${#requested_apps[@]}"
printf '  %s\n' "${requested_apps[@]}"

if ((${#already_installed[@]} > 0)); then
    printf '\nAlready installed (%d):\n' "${#already_installed[@]}"
    printf '  %s\n' "${already_installed[@]}"
fi

if ((${#missing_apps[@]} == 0)); then
    printf '\nAll managed Flatpak applications are already installed.\n'

    if "$dry_run"; then
        printf 'Dry run completed. No changes were made.\n'
    fi

    exit 0
fi

printf '\nApplications to install (%d):\n' "${#missing_apps[@]}"
printf '  %s\n' "${missing_apps[@]}"

if "$dry_run"; then
    printf '\nInstallation command:\n'

    print_command \
        flatpak install \
        --user \
        --assumeyes \
        "$FLATHUB_NAME" \
        "${missing_apps[@]}"

    printf '\nDry run completed. No changes were made.\n'
    exit 0
fi

printf '\nInstalling Flatpak applications...\n'

flatpak install \
    --user \
    --assumeyes \
    "$FLATHUB_NAME" \
    "${missing_apps[@]}"

printf '\nFlatpak installation completed.\n'

printf '\nConfigured Flathub remote:\n'

flatpak remotes \
    --user \
    --columns=name,url |
    awk -v remote="$FLATHUB_NAME" '
        $1 == remote {
            print "  " $1 "  " $2
        }
    '
