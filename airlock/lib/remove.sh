#!/usr/bin/env bash
# Package removal.
#
# Managed removal is record-driven:
# - files.txt: recorded file/symlink payload
# - created_dirs.txt: directories created during install
#
# Tracked removal is backend-driven:
# - track_remove_cmd if present
# - otherwise a backend-specific fallback based on recorded metadata

AIRLOCK_PROTECTED_DIRS_DEFAULT=(
  /
  /bin
  /boot
  /dev
  /etc
  /home
  /lib
  /lib64
  /media
  /mnt
  /opt
  /proc
  /root
  /run
  /sbin
  /srv
  /sys
  /tmp
  /usr
  /usr/local
  /var
)

# Managed-remove pruning uses in-memory sets to avoid repeated grep/scan work
# for each directory in large file lists.
declare -A AIRLOCK_REMOVE_PROTECTED_DIR_SET=()
declare -A AIRLOCK_REMOVE_CREATED_DIR_SET=()
declare -A AIRLOCK_REMOVE_BLOCKED_DIR_SET=()

al_print_protected_dirs() {
  local dir

  for dir in "${AIRLOCK_PROTECTED_DIRS_DEFAULT[@]}"; do
    printf '%s\n' "$dir"
  done

  if [ -n "${HOME:-}" ]; then
    printf '%s\n' "$HOME"
    printf '%s\n' "$HOME/.local"
    printf '%s\n' "$HOME/.config"
    printf '%s\n' "$HOME/.local/bin"
    printf '%s\n' "$HOME/.local/share"
    printf '%s\n' "$HOME/.local/state"
    printf '%s\n' "$HOME/.local/lib"
  fi

  if [ -n "${AIRLOCK_PROTECTED_DIRS_EXTRA:-}" ]; then
    printf '%s\n' "$AIRLOCK_PROTECTED_DIRS_EXTRA" | tr ':' '\n'
  fi
}

al_prepare_protected_dir_set() {
  local dir

  AIRLOCK_REMOVE_PROTECTED_DIR_SET=()

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    AIRLOCK_REMOVE_PROTECTED_DIR_SET["$dir"]=1
  done < <(al_print_protected_dirs)
}

al_prepare_created_dir_set() {
  local created_dirs_txt="$1"
  local dir

  AIRLOCK_REMOVE_CREATED_DIR_SET=()

  [ -f "$created_dirs_txt" ] || return 0

  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    AIRLOCK_REMOVE_CREATED_DIR_SET["$dir"]=1
  done < "$created_dirs_txt"
}

al_is_protected_dir() {
  local dir="$1"
  [ -n "${AIRLOCK_REMOVE_PROTECTED_DIR_SET[$dir]+_}" ]
}

al_created_dir_belongs_to_pkg() {
  local dir="$1"
  [ -n "${AIRLOCK_REMOVE_CREATED_DIR_SET[$dir]+_}" ]
}

al_remove_file_auto() {
  local path="$1"

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return 0
  fi

  if al_can_delete_path_without_sudo "$path"; then
    rm -f -- "$path" || return 1
  else
    sudo rm -f -- "$path" || return 1
  fi

  al_log_debug "Removed file: $path"
}

al_rmdir_auto() {
  local dir="$1"

  if al_can_delete_path_without_sudo "$dir"; then
    rmdir -- "$dir" || return 1
  else
    sudo rmdir -- "$dir" || return 1
  fi

  al_log_debug "Removed empty directory: $dir"
}

al_collect_direct_parent_dirs() {
  local files_txt="$1"

  # Emit unique direct parent directories sorted deepest-first.
  # This keeps pruning order equivalent to previous behavior while reducing
  # process overhead and repeated chain traversals.
  awk '
    NF {
      path = $0
      parent = path

      sub(/\/[^\/]*$/, "", parent)
      if (parent == "") parent = "/"

      if (!(parent in seen)) {
        seen[parent] = 1
        depth = gsub(/\//, "/", parent)
        print depth "\t" parent
      }
    }
  ' "$files_txt" | sort -rn -k1,1 | cut -f2-
}

al_parent_dir() {
  local dir="$1"

  if [ "$dir" = "/" ]; then
    printf '/\n'
    return 0
  fi

  dir="${dir%/*}"
  if [ -z "$dir" ]; then
    dir="/"
  fi

  printf '%s\n' "$dir"
}

al_prune_dir_chain() {
  local start_dir="$1"
  local dir="$start_dir"

  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    # If a directory is known protected or not owned by this package, every
    # future prune chain must also stop at that point.
    if [ -n "${AIRLOCK_REMOVE_BLOCKED_DIR_SET[$dir]+_}" ]; then
      break
    fi

    [ -d "$dir" ] || break

    if al_is_protected_dir "$dir"; then
      AIRLOCK_REMOVE_BLOCKED_DIR_SET["$dir"]=1
      break
    fi

    if ! al_created_dir_belongs_to_pkg "$dir"; then
      AIRLOCK_REMOVE_BLOCKED_DIR_SET["$dir"]=1
      break
    fi

    al_dir_is_empty "$dir" || break

    al_rmdir_auto "$dir" || break
    dir="$(al_parent_dir "$dir")"
  done
}

al_load_pkg_meta() {
  local pkgdir="$1"
  local meta="$pkgdir/meta.env"

  [ -f "$meta" ] || al_die "Missing meta.env for package: $(basename "$pkgdir")"

  unset pkg_name pkg_version pkg_mode pkg_type prefix installed_at recipe_dir
  unset track_backend track_package_name track_package_version
  unset track_source_url track_source_file
  unset track_install_cmd track_remove_cmd track_query_cmd
  # shellcheck disable=SC1090
  . "$meta"
}

al_try_load_recorded_recipe_for_hooks() {
  local pkgdir="$1"
  local recipe_path=""

  # Hooks are defined in recipe files. During remove we load the recorded
  # recipe when available so pre/post-remove hooks can run.
  if [ -n "${recipe_dir:-}" ] && [ -f "${recipe_dir}/recipe.sh" ]; then
    recipe_path="${recipe_dir}/recipe.sh"
  else
    recipe_path="$pkgdir/recipe.sh"
  fi

  if [ ! -f "$recipe_path" ]; then
    al_log_debug "Recipe file not found for remove hooks; skipping hook load"
    return 1
  fi

  al_load_recipe "$recipe_path" || {
    al_log_warn "Failed to load recipe hooks from: $recipe_path"
    return 1
  }

  return 0
}

al_remove_pkg_record_dir() {
  local pkgdir="$1"

  if al_can_delete_path_without_sudo "$pkgdir"; then
    rm -rf -- "$pkgdir" || return 1
  else
    sudo rm -rf -- "$pkgdir" || return 1
  fi
}

al_run_recorded_track_remove() {
  if [ -n "${track_remove_cmd:-}" ]; then
    al_run_shell_with_optional_sudo "$track_remove_cmd"
    return $?
  fi

  case "${track_backend:-}" in
    dpkg|deb-dpkg|deb-apt)
      al_run_with_optional_sudo dpkg -r "${track_package_name:-$pkg_name}"
      ;;
    pacman)
      al_run_with_optional_sudo pacman -R --noconfirm "${track_package_name:-$pkg_name}"
      ;;
    *)
      al_die "Tracked package has no removable backend command recorded: ${track_backend:-unknown}"
      ;;
  esac
}

al_remove_managed_pkg() {
  local pkgdir="$1"
  local files="$pkgdir/files.txt"
  local created_dirs="$pkgdir/created_dirs.txt"
  local path
  local dir

  [ -f "$files" ] || al_die "Missing files.txt for package: $pkg_name"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    al_remove_file_auto "$path" || return 1
  done < "$files"

  if [ -f "$created_dirs" ]; then
    AIRLOCK_REMOVE_BLOCKED_DIR_SET=()
    al_prepare_protected_dir_set
    al_prepare_created_dir_set "$created_dirs"

    while IFS= read -r dir; do
      [ -n "$dir" ] || continue
      al_prune_dir_chain "$dir" || return 1
    done < <(al_collect_direct_parent_dirs "$files")
  else
    al_log_warn "created_dirs.txt not found; skipping directory prune"
  fi

  al_remove_pkg_record_dir "$pkgdir" || return 1
  al_log_info "Removed package record: $pkg_name"
}

al_remove_tracked_pkg() {
  local pkgdir="$1"

  if [ -n "${track_query_cmd:-}" ]; then
    if ! bash -lc "$track_query_cmd" >/dev/null 2>&1; then
      al_log_warn "Tracked backend no longer reports package as installed; removing record only"
      al_remove_pkg_record_dir "$pkgdir" || return 1
      al_log_info "Removed package record: $pkg_name"
      return 0
    fi
  fi

  al_run_recorded_track_remove || return 1
  al_remove_pkg_record_dir "$pkgdir" || return 1
  al_log_info "Removed tracked package record: $pkg_name"
}

al_remove_pkg() {
  local name="${1:-}"
  local pkgdir
  local recorded_pkg_name
  local recorded_pkg_version
  local recorded_pkg_mode
  local recorded_pkg_type
  local recorded_prefix
  local recorded_installed_at
  local recorded_recipe_dir
  local recorded_track_backend
  local recorded_track_package_name
  local recorded_track_package_version
  local recorded_track_source_url
  local recorded_track_source_file
  local recorded_track_install_cmd
  local recorded_track_remove_cmd
  local recorded_track_query_cmd

  [ -n "$name" ] || al_die "Missing package name"

  pkgdir="$AIRLOCK_DB_ROOT/packages/$name"
  [ -d "$pkgdir" ] || al_die "Package not found in database: $name"

  al_load_pkg_meta "$pkgdir"

  # Keep recorded metadata authoritative for remove decisions, even if we load
  # the recipe file only to pick up optional remove hooks.
  recorded_pkg_name="${pkg_name:-}"
  recorded_pkg_version="${pkg_version:-}"
  recorded_pkg_mode="${pkg_mode:-}"
  recorded_pkg_type="${pkg_type:-}"
  recorded_prefix="${prefix:-}"
  recorded_installed_at="${installed_at:-}"
  recorded_recipe_dir="${recipe_dir:-}"
  recorded_track_backend="${track_backend:-}"
  recorded_track_package_name="${track_package_name:-}"
  recorded_track_package_version="${track_package_version:-}"
  recorded_track_source_url="${track_source_url:-}"
  recorded_track_source_file="${track_source_file:-}"
  recorded_track_install_cmd="${track_install_cmd:-}"
  recorded_track_remove_cmd="${track_remove_cmd:-}"
  recorded_track_query_cmd="${track_query_cmd:-}"

  al_try_load_recorded_recipe_for_hooks "$pkgdir" || true

  pkg_name="$recorded_pkg_name"
  pkg_version="$recorded_pkg_version"
  pkg_mode="$recorded_pkg_mode"
  pkg_type="$recorded_pkg_type"
  prefix="$recorded_prefix"
  installed_at="$recorded_installed_at"
  recipe_dir="$recorded_recipe_dir"
  track_backend="$recorded_track_backend"
  track_package_name="$recorded_track_package_name"
  track_package_version="$recorded_track_package_version"
  track_source_url="$recorded_track_source_url"
  track_source_file="$recorded_track_source_file"
  track_install_cmd="$recorded_track_install_cmd"
  track_remove_cmd="$recorded_track_remove_cmd"
  track_query_cmd="$recorded_track_query_cmd"

  al_log_info "Removing package: $name"
  al_log_info "Mode: ${pkg_mode:-managed}, Type: ${pkg_type:-unknown}"

  al_run_optional_recipe_hook hook_pre_remove || return 1

  case "${pkg_mode:-managed}" in
    managed)
      al_remove_managed_pkg "$pkgdir" || return 1
      ;;
    tracked)
      al_remove_tracked_pkg "$pkgdir" || return 1
      ;;
    *)
      al_die "Unsupported recorded pkg_mode: ${pkg_mode:-unknown}"
      ;;
  esac

  al_run_optional_recipe_hook hook_post_remove || return 1
}
