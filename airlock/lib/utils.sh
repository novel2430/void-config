#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Utility helper functions used across the airlock framework.
#
# This file contains small, generic shell helpers that are intentionally kept
# independent from package-specific logic. Their purpose is to reduce repeated
# shell patterns in other modules such as:
#
# - checking whether a function exists before calling it
# - resolving an absolute path
# - verifying that an external command is available
# - creating directories safely
# - downloading files from URLs
# - extracting common archive formats
#
# Design notes:
# - These helpers are expected to be sourced by other framework modules.
# - They assume a Bash execution environment.
# - Some helpers call `al_die`, which is expected to be defined by the logging
#   or core error-handling layer of the framework.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# al_is_function_defined
#
# Check whether a shell function with the given name is currently defined.
#
# Parameters:
#   $1 - Function name to check.
#
# Behavior:
# - Returns success (exit code 0) if the function exists.
# - Returns failure (non-zero exit code) if the function does not exist.
#
# Typical usage:
# - Used by the pipeline dispatcher to decide whether a recipe provides
#   `stage_<name>` or whether the framework should fall back to a default
#   implementation.
#
# Example:
#   if al_is_function_defined "stage_build"; then
#     stage_build
#   fi
# -----------------------------------------------------------------------------
al_is_function_defined() {
  declare -F "$1" >/dev/null 2>&1
}


# -----------------------------------------------------------------------------
# al_realpath
#
# Resolve a path into its canonical absolute form.
#
# Parameters:
#   $1 - Input path. Can be relative, absolute, or contain symlinks.
#
# Behavior:
# - Prints the resolved absolute path to stdout.
# - Uses the system `realpath` command if available.
# - Falls back to Python's `os.path.realpath()` if `realpath` is not installed.
#
# Notes:
# - This helper is mainly used when the framework needs a stable absolute path,
#   for example when resolving recipe file paths or storing normalized metadata.
# - The fallback relies on `python3` being available in environments where
#   `realpath` is missing.
#
# Example:
#   abs_recipe="$(al_realpath "$recipe_path")"
# -----------------------------------------------------------------------------
al_realpath() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  else
    # Fallback for environments without realpath.
    python3 - <<PY "$path"
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
  fi
}


# -----------------------------------------------------------------------------
# al_require_cmd
#
# Ensure that a required external command is available in PATH.
#
# Parameters:
#   $1 - Command name to check, for example: curl, tar, unzip, meson.
#
# Behavior:
# - Returns successfully if the command exists.
# - Calls `al_die` and aborts execution if the command is missing.
#
# Notes:
# - This helper is intended for hard requirements, not optional features.
# - It makes failures clearer by stopping early with an explicit error message
#   instead of allowing a later shell command to fail more obscurely.
#
# Example:
#   al_require_cmd tar
#   al_require_cmd ninja
# -----------------------------------------------------------------------------
al_require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || al_die "Required command not found: $cmd"
}


# -----------------------------------------------------------------------------
# al_mkdir
#
# Create a directory path, including any missing parent directories.
#
# Parameters:
#   $1 - Target directory path to create.
#
# Behavior:
# - Equivalent to `mkdir -p`.
# - Succeeds if the directory already exists.
#
# Notes:
# - This helper is mainly a thin wrapper kept for consistency and readability.
# - It can later be extended with logging or validation without changing all
#   call sites.
#
# Example:
#   al_mkdir "$MYPKG_DB_ROOT/packages/$pkg_name"
# -----------------------------------------------------------------------------
al_mkdir() {
  mkdir -p "$1"
}


# -----------------------------------------------------------------------------
# al_fetch_url
#
# Download a file from a URL to a local destination path.
#
# Parameters:
#   $1 - Source URL.
#   $2 - Output file path where the downloaded content should be written.
#
# Behavior:
# - Uses `curl` if available.
# - Falls back to `wget` if `curl` is not available.
# - Calls `al_die` if neither downloader exists.
#
# Notes:
# - `curl -L --fail` is used so redirects are followed and HTTP errors cause
#   the command to fail.
# - Parent directory creation is not handled here; callers should ensure the
#   destination directory exists if needed.
#
# Failure behavior:
# - Returns the downloader's exit status on failure.
# - May also terminate through `al_die` if no supported downloader exists.
#
# Example:
#   al_fetch_url \
#     "https://example.org/foo-1.0.0.tar.gz" \
#     "$WORKDIR/foo-1.0.0.tar.gz"
# -----------------------------------------------------------------------------
al_fetch_url() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --output "$output" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
  else
    al_die "Neither curl nor wget is available for downloading"
  fi
}


# -----------------------------------------------------------------------------
# al_extract_archive
#
# Extract a supported archive file into a destination directory.
#
# Parameters:
#   $1 - Archive file path.
#   $2 - Destination directory where contents should be extracted.
#
# Supported formats:
# - .tar.gz / .tgz
# - .tar.bz2 / .tbz2
# - .tar.xz / .txz
# - .zip
#
# Behavior:
# - Chooses an extraction command based on the archive filename extension.
# - For zip files, verifies that `unzip` exists before extraction.
# - Calls `al_die` if the archive format is unsupported.
#
# Notes:
# - This helper assumes the destination directory already exists.
# - It does not try to inspect archive contents beyond the filename suffix.
#   That keeps it simple, but means incorrectly named files may fail.
#
# Failure behavior:
# - Returns non-zero if extraction fails.
# - May terminate through `al_die` if the format is unsupported or a required
#   extraction tool is missing.
#
# Example:
#   al_extract_archive "$WORKDIR/src.tar.gz" "$WORKDIR"
# -----------------------------------------------------------------------------
al_extract_archive() {
  local archive="$1"
  local dest="$2"

  case "$archive" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$dest"
      ;;
    *.tar.bz2|*.tbz2)
      tar -xjf "$archive" -C "$dest"
      ;;
    *.tar.xz|*.txz)
      tar -xJf "$archive" -C "$dest"
      ;;
    *.zip)
      al_require_cmd unzip
      unzip -q "$archive" -d "$dest"
      ;;
    *)
      al_die "Unsupported archive format: $archive"
      ;;
  esac
}


# -----------------------------------------------------------------------------
# al_nearest_existing_parent
#
# Walk upward until an existing path is found. Used by permission checks for
# create/delete operations.
# -----------------------------------------------------------------------------
al_nearest_existing_parent() {
  local path="$1"

  while [ "$path" != "/" ] && [ ! -e "$path" ] && [ ! -L "$path" ]; do
    path="$(dirname "$path")"
  done

  printf '%s\n' "${path:-/}"
}

# -----------------------------------------------------------------------------
# al_can_create_path_without_sudo
#
# Return success if the nearest existing parent directory of the target is
# writable by the current user.
# -----------------------------------------------------------------------------
al_can_create_path_without_sudo() {
  local target="$1"
  local parent

  parent="$(al_nearest_existing_parent "$(dirname "$target")")"
  [ -w "$parent" ]
}

# -----------------------------------------------------------------------------
# al_can_delete_path_without_sudo
#
# Return success if the parent directory of the target is writable by the
# current user.
# -----------------------------------------------------------------------------
al_can_delete_path_without_sudo() {
  local target="$1"
  local parent

  parent="$(al_nearest_existing_parent "$(dirname "$target")")"
  [ -w "$parent" ]
}

# -----------------------------------------------------------------------------
# al_dir_is_empty
#
# Return success if the given directory exists and contains no entries.
# -----------------------------------------------------------------------------
al_dir_is_empty() {
  local dir="$1"

  [ -d "$dir" ] || return 1
  ! find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .
}

# -----------------------------------------------------------------------------
# al_sort_paths_deepest_first
#
# Read newline-separated paths from stdin and emit them sorted by depth from
# deepest to shallowest.
# -----------------------------------------------------------------------------
al_sort_paths_deepest_first() {
  awk '
    NF {
      depth = gsub(/\//, "/", $0)
      print depth, $0
    }
  ' | sort -rn | cut -d' ' -f2-
}

# -----------------------------------------------------------------------------
# al_run_with_optional_sudo
#
# Run the given command directly when already root; otherwise invoke it via
# sudo. This is useful for tracked backends and selective privileged actions.
# -----------------------------------------------------------------------------
al_run_with_optional_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}


# -----------------------------------------------------------------------------
# al_run_shell_with_optional_sudo
#
# Execute a shell command string through bash -lc, elevating via sudo when the
# current user is not root.
# -----------------------------------------------------------------------------
al_run_shell_with_optional_sudo() {
  local cmd="$1"

  if [ "$(id -u)" -eq 0 ]; then
    bash -lc "$cmd"
  else
    sudo bash -lc "$cmd"
  fi
}
