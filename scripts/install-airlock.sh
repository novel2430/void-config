#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

REPO_ROOT="$(dirname "$SCRIPT_DIR")"

AIRLOCK_BIN="$REPO_ROOT/airlock/bin/airlock"
COMMON_MANIFEST="$REPO_ROOT/airlock.txt"

HOSTS_DIR="$REPO_ROOT/hosts"
HOST_SELECTOR_FILE="$REPO_ROOT/.host"

host_name=""
common_only=false
dry_run=false
ignore_failures=false

declare -a already_installed_packages=()
declare -a successfully_installed_packages=()
declare -a failed_packages=()
declare -a failed_exit_codes=()

total_count=0

# 由 check_package_installed 设置。
AIRLOCK_INFO_OUTPUT=""
AIRLOCK_PACKAGE_STATUS=""

usage() {
    cat <<'EOF'
Usage:
  install-airlock.sh
  install-airlock.sh --host void-vm
  install-airlock.sh --common-only
  install-airlock.sh --dry-run
  install-airlock.sh --ignore-failures

Default behavior:
  Installs packages in this exact order:

    1. airlock.txt
    2. hosts/<host>/airlock.txt

  Entries are not sorted or deduplicated.

Host resolution order:
  1. --host NAME
  2. VOID_CONFIG_HOST environment variable
  3. .host file in the repository root
  4. System short hostname

Manifest format:
  - One Airlock package name per line.
  - Empty lines are ignored.
  - Lines beginning with # are ignored.
  - Inline comments are not supported.
  - Order is preserved.

Installed-package behavior:
  Before installing each package, the script runs:

    airlock info <package>

  The package is skipped only when the output explicitly contains:

    status installed

Failure behavior:
  - A failed package does not stop later packages.
  - A summary is printed after all packages are attempted.
  - The script exits with status 1 if any installation failed.
  - Use --ignore-failures to return status 0 despite failures.

Options:
  --host NAME
      Select a host profile explicitly.

  --common-only
      Process only the common airlock.txt.

  --dry-run
      Check installed status and print planned install commands,
      but do not install anything.

  --ignore-failures
      Return exit status 0 even when one or more installations fail.

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

trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s\n' "$value"
}

read_selector() {
    local file="$1"
    local line=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(trim "$line")"

        case "$line" in
            ""|\#*)
                continue
                ;;
        esac

        printf '%s\n' "$line"
        return 0
    done < "$file"

    return 1
}

validate_host_name() {
    local value="$1"

    [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] ||
        die "Invalid host name: $value"
}

resolve_host() {
    if [[ -n "$host_name" ]]; then
        :
    elif [[ -n "${VOID_CONFIG_HOST:-}" ]]; then
        host_name="$VOID_CONFIG_HOST"
    elif [[ -r "$HOST_SELECTOR_FILE" ]]; then
        host_name="$(
            read_selector "$HOST_SELECTOR_FILE"
        )" || die "No host name found in: $HOST_SELECTOR_FILE"
    else
        host_name="$(hostname -s)"
    fi

    [[ -n "$host_name" ]] ||
        die "Unable to determine host profile"

    validate_host_name "$host_name"
}

print_command() {
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

extract_package_status() {
    awk '
        $1 == "status" {
            print $2
            exit
        }
    '
}

check_package_installed() {
    local package="$1"

    AIRLOCK_INFO_OUTPUT=""
    AIRLOCK_PACKAGE_STATUS=""

    if AIRLOCK_INFO_OUTPUT="$(
        "$AIRLOCK_BIN" info "$package" 2>&1
    )"; then
        AIRLOCK_PACKAGE_STATUS="$(
            printf '%s\n' "$AIRLOCK_INFO_OUTPUT" |
                extract_package_status
        )"

        if [[ "$AIRLOCK_PACKAGE_STATUS" == "installed" ]]; then
            return 0
        fi

        return 1
    fi

    # “包不存在”是正常的未安装状态，不显示成脚本警告。
    if [[ "$AIRLOCK_INFO_OUTPUT" != *"Package not found in database"* ]]; then
        warn "Unable to query Airlock package cleanly: $package"

        if [[ -n "$AIRLOCK_INFO_OUTPUT" ]]; then
            printf '%s\n' "$AIRLOCK_INFO_OUTPUT" |
                sed 's/^/  /' >&2
        fi

        warn "The script will still attempt to install: $package"
    fi

    return 1
}

install_package() {
    local package="$1"
    local source_file="$2"
    local source_line="$3"
    local exit_code=0

    total_count=$((total_count + 1))

    printf '\n[%d] Airlock package: %s\n' \
        "$total_count" \
        "$package"

    printf '    Declared at: %s:%s\n' \
        "$source_file" \
        "$source_line"

    if check_package_installed "$package"; then
        already_installed_packages+=("$package")

        printf '    Status: already installed\n'
        printf '    Action: skipped\n'
        return 0
    fi

    if [[ -n "$AIRLOCK_PACKAGE_STATUS" ]]; then
        printf '    Existing Airlock status: %s\n' \
            "$AIRLOCK_PACKAGE_STATUS"
    else
        printf '    Status: not installed\n'
    fi

    if "$dry_run"; then
        printf '    Planned command:\n'

        print_command \
            "$AIRLOCK_BIN" \
            install \
            "$package"

        return 0
    fi

    printf '    Installing...\n'

    if "$AIRLOCK_BIN" install "$package"; then
        successfully_installed_packages+=("$package")

        printf '    Result: installed successfully\n'
    else
        exit_code=$?

        failed_packages+=("$package")
        failed_exit_codes+=("$exit_code")

        printf '    Result: failed with exit status %d\n' \
            "$exit_code" >&2

        printf '    Continuing with the next package.\n' >&2
    fi
}

process_manifest() {
    local manifest="$1"
    local raw_line=""
    local package=""
    local line_number=0

    [[ -r "$manifest" ]] ||
        die "Manifest is not readable: $manifest"

    printf '\nProcessing manifest:\n'
    printf '  %s\n' "$manifest"

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        line_number=$((line_number + 1))
        package="$(trim "$raw_line")"

        case "$package" in
            ""|\#*)
                continue
                ;;
        esac

        install_package \
            "$package" \
            "$manifest" \
            "$line_number"
    done < "$manifest"
}

print_summary() {
    local i=0
    local planned_count=0

    printf '\n========================================\n'
    printf 'Airlock installation summary\n'
    printf '========================================\n'

    printf 'Entries processed:  %d\n' "$total_count"
    printf 'Already installed:  %d\n' \
        "${#already_installed_packages[@]}"

    if "$dry_run"; then
        planned_count=$((total_count - ${#already_installed_packages[@]}))

        printf 'Would install:      %d\n' "$planned_count"
        printf 'Mode:               dry run\n'
    else
        printf 'Newly installed:    %d\n' \
            "${#successfully_installed_packages[@]}"

        printf 'Failed:             %d\n' \
            "${#failed_packages[@]}"
    fi

    if ((${#already_installed_packages[@]} > 0)); then
        printf '\nAlready installed:\n'

        for package in "${already_installed_packages[@]}"; do
            printf '  %s\n' "$package"
        done
    fi

    if ((${#successfully_installed_packages[@]} > 0)); then
        printf '\nNewly installed:\n'

        for package in "${successfully_installed_packages[@]}"; do
            printf '  %s\n' "$package"
        done
    fi

    if ((${#failed_packages[@]} > 0)); then
        printf '\nFailed installations:\n' >&2

        for ((i = 0; i < ${#failed_packages[@]}; i++)); do
            printf '  %s (exit status %s)\n' \
                "${failed_packages[$i]}" \
                "${failed_exit_codes[$i]}" \
                >&2
        done
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

        --common-only)
            common_only=true
            ;;

        --dry-run)
            dry_run=true
            ;;

        --ignore-failures)
            ignore_failures=true
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

[[ -x "$AIRLOCK_BIN" ]] ||
    die "Airlock executable was not found or is not executable: $AIRLOCK_BIN"

[[ -r "$COMMON_MANIFEST" ]] ||
    die "Common Airlock manifest not found: $COMMON_MANIFEST"

printf 'Airlock installation profile\n'

if "$common_only"; then
    printf '  Mode: common only\n'
else
    resolve_host

    printf '  Host: %s\n' "$host_name"
    printf '  Mode: common + host-specific\n'
fi

if "$dry_run"; then
    printf '  Execution: dry run\n'
else
    printf '  Execution: install\n'
fi

# 通用清单始终先执行，顺序不会被改变。
process_manifest "$COMMON_MANIFEST"

if ! "$common_only"; then
    HOST_MANIFEST="$HOSTS_DIR/$host_name/airlock.txt"

    if [[ -r "$HOST_MANIFEST" ]]; then
        process_manifest "$HOST_MANIFEST"
    else
        printf '\nNotice: no host-specific Airlock manifest:\n'
        printf '  %s\n' "$HOST_MANIFEST"
    fi
fi

print_summary

if ((${#failed_packages[@]} > 0)) && ! "$ignore_failures"; then
    exit 1
fi

exit 0
