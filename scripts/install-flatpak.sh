#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLATPAK_DIR="$PROJECT_ROOT/flatpak"

FLATHUB_NAME="flathub"

# 使用官方 .flatpakrepo 初始化 remote 和导入 GPG key。
FLATHUB_REPO_FILE="${FLATHUB_REPO_FILE:-https://dl.flathub.org/repo/flathub.flatpakrepo}"

# 实际下载地址切换到 SJTUG 中国镜像。
FLATHUB_MIRROR_URL="${FLATHUB_MIRROR_URL:-https://dl.flathub.org/repo}"

dry_run=false
categories=()

usage() {
    cat <<'EOF'
Usage:
  install-flatpak.sh
  install-flatpak.sh desktop
  install-flatpak.sh desktop development
  install-flatpak.sh --dry-run
  install-flatpak.sh --dry-run media

Behavior:
  - Uses per-user Flatpak installation.
  - Uses the official Flathub repository file to initialize the remote.
  - Changes the Flathub download URL to the SJTUG China mirror.
  - Without category arguments, reads every *.txt manifest directly
    under the flatpak directory.
  - Installs only applications that are not already installed.
  - Does not update, remove, or reset existing applications.

Manifest format:
  - One complete Flatpak application ID per line.
  - Empty lines are ignored.
  - Lines beginning with # are ignored.

Examples:
  org.gimp.GIMP
  org.mozilla.firefox
  com.visualstudio.code

Environment overrides:
  FLATHUB_REPO_FILE
  FLATHUB_MIRROR_URL
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

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

discover_categories() {
    local manifest
    local filename

    shopt -s nullglob

    for manifest in "$FLATPAK_DIR"/*.txt; do
        filename="$(basename "$manifest")"
        printf '%s\n' "${filename%.txt}"
    done
}

remote_exists() {
    flatpak remote-list \
        --user \
        --columns=name 2>/dev/null |
        grep -Fxq "$FLATHUB_NAME"
}

get_remote_url() {
    flatpak remote-list \
        --user \
        --columns=name,url 2>/dev/null |
        awk -v remote="$FLATHUB_NAME" '
            $1 == remote {
                print $2
                exit
            }
        '
}

normalize_url() {
    local url="$1"
    printf '%s\n' "${url%/}"
}

configure_flathub_remote() {
    local current_url=""
    local normalized_current=""
    local normalized_target=""

    printf '\nConfiguring Flathub user remote:\n'

    if ! remote_exists; then
        printf '  Flathub remote is not configured.\n'
        printf '  Initializing it from the official repository file.\n'

        if "$dry_run"; then
            print_command \
                flatpak remote-add \
                --user \
                --if-not-exists \
                "$FLATHUB_NAME" \
                "$FLATHUB_REPO_FILE"

            printf '  Setting mirror URL:\n'
            printf '    %s\n' "$FLATHUB_MIRROR_URL"

            print_command \
                flatpak remote-modify \
                --user \
                "--url=$FLATHUB_MIRROR_URL" \
                "$FLATHUB_NAME"

            return 0
        fi

        flatpak remote-add \
            --user \
            --if-not-exists \
            "$FLATHUB_NAME" \
            "$FLATHUB_REPO_FILE"
    fi

    current_url="$(get_remote_url)"
    normalized_current="$(normalize_url "$current_url")"
    normalized_target="$(normalize_url "$FLATHUB_MIRROR_URL")"

    if [[ "$normalized_current" == "$normalized_target" ]]; then
        printf '  Flathub already uses the configured mirror:\n'
        printf '    %s\n' "$current_url"
        return 0
    fi

    printf '  Current URL:\n'
    printf '    %s\n' "${current_url:-unknown}"

    printf '  New mirror URL:\n'
    printf '    %s\n' "$FLATHUB_MIRROR_URL"

    if "$dry_run"; then
        print_command \
            flatpak remote-modify \
            --user \
            "--url=$FLATHUB_MIRROR_URL" \
            "$FLATHUB_NAME"
    else
        flatpak remote-modify \
            --user \
            "--url=$FLATHUB_MIRROR_URL" \
            "$FLATHUB_NAME"
    fi
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
    die "flatpak is not installed. Add it to xbps/bootstrap.txt first."

[[ -d "$FLATPAK_DIR" ]] ||
    die "Flatpak manifest directory not found: $FLATPAK_DIR"

if ((${#categories[@]} == 0)); then
    mapfile -t categories < <(
        discover_categories | sort -u
    )
fi

if ((${#categories[@]} == 0)); then
    die "No Flatpak manifest files found in: $FLATPAK_DIR"
fi

temporary_app_list="$(mktemp)"
trap 'rm -f "$temporary_app_list"' EXIT

printf 'Selected Flatpak categories:\n'

for category in "${categories[@]}"; do
    manifest="$FLATPAK_DIR/$category.txt"

    [[ -f "$manifest" ]] ||
        die "Manifest not found: $manifest"

    printf '  %s\n' "$category"

    read_manifest "$manifest" >> "$temporary_app_list"
done

mapfile -t requested_apps < <(
    sort -u "$temporary_app_list"
)

# 即使清单暂时为空，也先确保 Flathub 和镜像配置正确。
configure_flathub_remote

if ((${#requested_apps[@]} == 0)); then
    printf '\nNo applications found in the selected manifests.\n'

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
flatpak remote-list \
    --user \
    --columns=name,url |
    awk -v remote="$FLATHUB_NAME" '
        $1 == remote {
            print "  " $1 "  " $2
        }
    '
