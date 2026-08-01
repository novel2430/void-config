#!/usr/bin/env bash
# Commit logic for managed packages.
#
# v1 uses manifest-driven copy instead of whole-tree copy.
# Each staged file/symlink is committed individually, and parent directories
# created during commit are recorded into COMMIT_CREATED_DIRS_FILE.

al_iterate_staged_entries() {
  (
    cd "$STAGE_DIR" || exit 1
    find . \( -type f -o -type l \) | LC_ALL=C sort
  )
}

al_record_created_dir() {
  local dir="$1"
  printf '%s\n' "$dir" >> "$COMMIT_CREATED_DIRS_FILE"
}

al_ensure_parent_dirs_for_target() {
  local target="$1"
  local dir
  local missing=()
  local i

  dir="$(dirname "$target")"

  while [ "$dir" != "/" ] && [ ! -e "$dir" ] && [ ! -L "$dir" ]; do
    missing+=("$dir")
    dir="$(dirname "$dir")"
  done

  for (( i=${#missing[@]} - 1; i >= 0; i-- )); do
    dir="${missing[$i]}"

    if [ -e "$dir" ] || [ -L "$dir" ]; then
      continue
    fi

    if al_can_create_path_without_sudo "$dir"; then
      mkdir -p -- "$dir" || return 1
    else
      sudo mkdir -p -- "$dir" || return 1
    fi

    al_record_created_dir "$dir"
    al_log_debug "Created directory during commit: $dir"
  done
}

al_commit_one_entry() {
  local rel="$1"
  local src="$STAGE_DIR/${rel#./}"
  local dst="/${rel#./}"

  al_ensure_parent_dirs_for_target "$dst" || return 1

  if al_can_create_path_without_sudo "$dst"; then
    cp -P -- "$src" "$dst" || return 1
  else
    sudo cp -P -- "$src" "$dst" || return 1
  fi

  al_log_debug "Committed staged entry: $dst"
}

al_commit_install() {
  local rel

  : > "$COMMIT_CREATED_DIRS_FILE" || return 1

  al_log_info "Committing staged files to real system"

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    al_commit_one_entry "$rel" || return 1
  done < <(al_iterate_staged_entries)

  if [ -f "$COMMIT_CREATED_DIRS_FILE" ]; then
    LC_ALL=C sort -u -o "$COMMIT_CREATED_DIRS_FILE" "$COMMIT_CREATED_DIRS_FILE" || return 1
  fi

  al_log_info "Commit complete"
}
