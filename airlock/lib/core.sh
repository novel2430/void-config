#!/usr/bin/env bash
# High-level framework operations.
#
# This module binds recipe loading, validation, pipeline execution, record, and
# commit into the main user-facing actions.

al_resolve_recipe_path() {
  local target="$1"

  if [ -f "$target" ]; then
    al_realpath "$target"
    return 0
  fi

  local candidate="$AIRLOCK_RECIPES_DIR/$target/recipe.sh"
  if [ -f "$candidate" ]; then
    al_realpath "$candidate"
    return 0
  fi

  al_die "Recipe not found: $target"
}

# Clear known recipe lifecycle functions before loading the next recipe file.
#
# Recipes are sourced into the current shell on purpose so stages can share
# variables. This cleanup removes only known recipe runtime functions so stale
# stage/track/hook implementations cannot leak across recipe loads.
al_clear_recipe_lifecycle_functions() {
  local fn

  for fn in \
    stage_acquire \
    stage_prepare \
    stage_patch \
    stage_configure \
    stage_build \
    stage_stage \
    track_install \
    track_remove \
    hook_post_commit \
    hook_post_install \
    hook_pre_remove \
    hook_post_remove
  do
    unset -f "$fn" 2>/dev/null || true
  done
}

# Run an optional recipe hook by function name.
#
# Hook functions are recipe-defined and intentionally optional. When present,
# they are executed in the current shell so they can reuse recipe variables.
al_run_optional_recipe_hook() {
  local hook_name="$1"

  if ! al_is_function_defined "$hook_name"; then
    return 0
  fi

  al_log_info "Running recipe hook: $hook_name"
  "$hook_name"

  al_log_info "Recipe hook completed: $hook_name"
  return 0
}

al_load_recipe() {
  local recipe_path="$1"

  al_log_info "Loading recipe: $recipe_path"

  unset pkg_name pkg_version pkg_mode pkg_type
  unset SRCDIR BUILDDIR
  unset track_backend track_package_name track_package_version
  unset track_source_url track_source_file
  unset track_install_cmd track_remove_cmd track_query_cmd

  RECIPE_DIR="$(cd "$(dirname "$recipe_path")" && pwd)"
  export RECIPE_DIR

  # Prevent stale lifecycle hooks from a previously sourced recipe.
  al_clear_recipe_lifecycle_functions

  # shellcheck source=/dev/null
  . "$recipe_path"

  AIRLOCK_CURRENT_RECIPE="${pkg_name:-unknown}"
}

al_install_target() {
  local target="${1:-}"
  [ -n "$target" ] || al_die "Missing install target"

  local recipe_path
  recipe_path="$(al_resolve_recipe_path "$target")" || return 1

  al_install_recipe "$recipe_path"
}

al_clean_cache() {
  local target="${1:-}"
  [ -n "$target" ] || al_die "Missing cache target"

  local recipe_path
  recipe_path="$(al_resolve_recipe_path "$target")" || return 1

  al_load_recipe "$recipe_path" || return 1
  al_validate_recipe || return 1

  local key cache_root
  key="$(al_compute_work_key)" || return 1
  cache_root="$(al_pkg_cache_root "$key")" || return 1

  if [ -d "$cache_root" ]; then
    rm -rf "$cache_root" || return 1
    al_log_info "Removed cache: $cache_root"
  else
    al_log_info "Cache not found: $cache_root"
  fi
}

al_run_track_install() {
  al_log_info "Running tracked install hook"

  if al_is_function_defined track_install; then
    track_install
  elif al_is_function_defined al_default_track_install; then
    al_default_track_install
  else
    al_log_error "No track_install implementation available for package: $pkg_name"
    return 1
  fi

  al_log_info "Tracked install hook completed"
  return 0
}

al_install_recipe_managed() {
  al_run_pipeline

  al_maybe_check_commit_conflicts

  al_commit_install

  al_record_install

  al_run_optional_recipe_hook hook_post_commit
}

al_install_recipe_tracked() {
  al_run_pipeline

  al_run_track_install

  al_record_install

  al_run_optional_recipe_hook hook_post_install
}

al_install_recipe() {
  local recipe_path="$1"

  al_load_recipe "$recipe_path"
  al_validate_recipe
  al_setup_env

  al_log_info "Installing package: $pkg_name ($pkg_version)"
  al_log_info "Mode: $pkg_mode, Type: $pkg_type"

  case "$pkg_mode" in
    managed)
      al_install_recipe_managed
      ;;
    tracked)
      al_install_recipe_tracked
      ;;
    *)
      al_die "Unsupported pkg_mode: $pkg_mode"
      ;;
  esac

  al_log_info "Install completed: $pkg_name"
}

al_load_pkg_meta_for_dir() {
  local pkgdir="$1"
  local meta="$pkgdir/meta.env"

  unset pkg_name pkg_version pkg_mode pkg_type prefix installed_at recipe_dir
  unset track_backend track_package_name track_package_version track_source_url track_source_file
  unset track_install_cmd track_remove_cmd track_query_cmd

  if [ -f "$meta" ]; then
    # shellcheck disable=SC1090
    . "$meta"
    return 0
  fi

  return 1
}

al_recorded_pkg_status() {
  local pkgdir="$1"
  local files="$pkgdir/files.txt"
  local path
  local saw_present=0
  local saw_missing=0

  if [ "${pkg_mode:-managed}" = "tracked" ]; then
    if [ -n "${track_query_cmd:-}" ]; then
      if bash -lc "$track_query_cmd" >/dev/null 2>&1; then
        printf 'installed\n'
      else
        printf 'missing\n'
      fi
    else
      printf 'unknown\n'
    fi
    return 0
  fi

  if [ ! -f "$files" ]; then
    printf 'record-only\n'
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -e "$path" ] || [ -L "$path" ]; then
      saw_present=1
    else
      saw_missing=1
    fi

    if [ "$saw_present" -eq 1 ] && [ "$saw_missing" -eq 1 ]; then
      printf 'drifted\n'
      return 0
    fi
  done < "$files"

  if [ "$saw_present" -eq 1 ] && [ "$saw_missing" -eq 0 ]; then
    printf 'installed\n'
  elif [ "$saw_present" -eq 0 ] && [ "$saw_missing" -eq 1 ]; then
    printf 'missing\n'
  else
    printf 'record-only\n'
  fi
}

al_colorize_mode() {
  case "$1" in
    managed*) al_ui_color_text "$AL_UI_CYAN" "$1" ;;
    tracked*) al_ui_color_text "$AL_UI_MAGENTA" "$1" ;;
    *)        al_ui_color_text "$AL_UI_YELLOW" "$1" ;;
  esac
}

al_colorize_type() {
  case "$1" in
    source*)   al_ui_color_text "$AL_UI_BLUE" "$1" ;;
    artifact*) al_ui_color_text "$AL_UI_WHITE" "$1" ;;
    *)         al_ui_color_text "$AL_UI_YELLOW" "$1" ;;
  esac
}

al_colorize_status() {
  case "$1" in
    installed*)   al_ui_color_text "$AL_UI_GREEN" "$1" ;;
    drifted*)     al_ui_color_text "$AL_UI_YELLOW" "$1" ;;
    missing*)     al_ui_color_text "$AL_UI_RED" "$1" ;;
    record-only*) al_ui_color_text "$AL_UI_BLUE" "$1" ;;
    unknown*)     al_ui_color_text "$AL_UI_YELLOW" "$1" ;;
    *)            al_ui_color_text "$AL_UI_WHITE" "$1" ;;
  esac
}

al_print_list_header() {
  printf '%s\n' "$(al_ui_color_text "$AL_UI_BOLD$AL_UI_CYAN" "$(printf '%-22s %-14s %-10s %-10s %-12s %-12s %s' 'NAME' 'VERSION' 'MODE' 'TYPE' 'STATUS' 'BACKEND' 'INSTALLED AT')")"
  printf '%s\n' "$(al_ui_color_text "$AL_UI_DIM" "$(printf '%-22s %-14s %-10s %-10s %-12s %-12s %s' \
    "$(al_ui_repeat_char '-' 22)" \
    "$(al_ui_repeat_char '-' 14)" \
    "$(al_ui_repeat_char '-' 10)" \
    "$(al_ui_repeat_char '-' 10)" \
    "$(al_ui_repeat_char '-' 12)" \
    "$(al_ui_repeat_char '-' 12)" \
    "$(al_ui_repeat_char '-' 19)")")"
}

al_print_list_row() {
  local name="$1"
  local version="$2"
  local mode="$3"
  local type="$4"
  local status="$5"
  local backend="$6"
  local installed="$7"

  printf '%s %s %s %s %s %s %s\n' \
    "$(al_ui_color_text "$AL_UI_BOLD" "$(al_ui_fit "$name" 22)")" \
    "$(al_ui_color_text "$AL_UI_WHITE" "$(al_ui_fit "$version" 14)")" \
    "$(al_colorize_mode "$(al_ui_fit "$mode" 10)")" \
    "$(al_colorize_type "$(al_ui_fit "$type" 10)")" \
    "$(al_colorize_status "$(al_ui_fit "$status" 12)")" \
    "$(al_ui_color_text "$AL_UI_BLUE" "$(al_ui_fit "$backend" 12)")" \
    "$(al_ui_color_text "$AL_UI_DIM" "$installed")"
}

al_list_sort_usage() {
  al_die "Unknown list option: $1 (supported: --time-asc, --time-desc)"
}

al_print_list_sort_hint() {
  local sort_mode="$1"
  local label

  case "$sort_mode" in
    time-asc)  label='sorted by install time (oldest first)' ;;
    time-desc) label='sorted by install time (newest first)' ;;
    *)         label='sorted by name (A-Z)' ;;
  esac

  printf '%s\n' "$(al_ui_color_text "$AL_UI_DIM" "$label")"
}

al_emit_list_record() {
  local pkgdir="$1"
  local name version mode type status backend installed installed_key installed_known

  if al_load_pkg_meta_for_dir "$pkgdir"; then
    name="${pkg_name:-$(basename "$pkgdir")}"
    version="${pkg_version:-unknown}"
    mode="${pkg_mode:-managed}"
    type="${pkg_type:-unknown}"
    backend="${track_backend:--}"
    installed="${installed_at:-unknown}"
    status="$(al_recorded_pkg_status "$pkgdir")"
  else
    name="$(basename "$pkgdir")"
    version="unknown"
    mode="unknown"
    type="unknown"
    backend="-"
    installed="unknown"
    status="record-only"
  fi

  if [[ "$installed" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
    installed_known=0
    installed_key="$installed"
  else
    installed_known=1
    installed_key=""
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$installed_known" \
    "$installed_key" \
    "$name" \
    "$version" \
    "$mode" \
    "$type" \
    "$status" \
    "$backend" \
    "$installed"
}

al_sort_list_records() {
  local sort_mode="$1"

  case "$sort_mode" in
    time-asc)
      sort -t $'\t' -k1,1n -k2,2 -k3,3
      ;;
    time-desc)
      sort -t $'\t' -k1,1n -k2,2r -k3,3
      ;;
    *)
      sort -t $'\t' -k3,3
      ;;
  esac
}

al_list_pkgs() {
  local dir="$AIRLOCK_DB_ROOT/packages"
  local pkgdir name version mode type status backend installed
  local sort_mode="name"
  local count=0
  local records_file

  while [ $# -gt 0 ]; do
    case "$1" in
      --time-asc)
        sort_mode="time-asc"
        ;;
      --time-desc)
        sort_mode="time-desc"
        ;;
      *)
        al_list_sort_usage "$1"
        ;;
    esac
    shift
  done

  al_ui_print_title "airlock packages"
  al_ui_print_rule

  if [ ! -d "$dir" ]; then
    printf '%s\n' "$(al_ui_color_text "$AL_UI_YELLOW" 'No package records found.')"
    al_ui_print_rule
    return 0
  fi

  mkdir -p "$AIRLOCK_TMPDIR" || return 1
  records_file="$(mktemp "$AIRLOCK_TMPDIR/airlock-list.XXXXXX")" || return 1

  while IFS= read -r pkgdir; do
    al_emit_list_record "$pkgdir" >> "$records_file" || {
      rm -f "$records_file"
      return 1
    }
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d)

  al_print_list_header
  al_print_list_sort_hint "$sort_mode"

  while IFS=$'\t' read -r _installed_known _installed_key name version mode type status backend installed; do
    count=$((count + 1))

    al_print_list_row "$name" "$version" "$mode" "$type" "$status" "$backend" "$installed"
  done < <(al_sort_list_records "$sort_mode" < "$records_file")

  rm -f "$records_file"

  if [ "$count" -eq 0 ]; then
    printf '%s\n' "$(al_ui_color_text "$AL_UI_YELLOW" 'No package records found.')"
  else
    printf '%s\n' "$(al_ui_color_text "$AL_UI_DIM" "Total packages: $count")"
  fi

  al_ui_print_rule
}

al_show_pkg_info() {
  local name="${1:-}"
  local pkgdir meta files created_dirs status file_count created_dir_count

  [ -n "$name" ] || al_die "Missing package name"

  pkgdir="$AIRLOCK_DB_ROOT/packages/$name"
  meta="$pkgdir/meta.env"
  files="$pkgdir/files.txt"
  created_dirs="$pkgdir/created_dirs.txt"

  [ -d "$pkgdir" ] || al_die "Package not found in database: $name"
  [ -f "$meta" ] || al_die "Missing meta.env for package: $name"

  al_load_pkg_meta_for_dir "$pkgdir" || return 1
  status="$(al_recorded_pkg_status "$pkgdir")"

  if [ -f "$files" ]; then
    file_count="$(wc -l < "$files" | tr -d ' ')"
  else
    file_count='-'
  fi

  if [ -f "$created_dirs" ]; then
    created_dir_count="$(wc -l < "$created_dirs" | tr -d ' ')"
  else
    created_dir_count='-'
  fi

  al_ui_print_title "airlock package info"
  al_ui_print_rule
  printf '%s%s%s\n' "$AL_UI_BOLD$AL_UI_WHITE" "${pkg_name:-$name} ${pkg_version:-unknown}" "$AL_UI_RESET"
  printf '%s%s%s %s\n' "$AL_UI_DIM" 'status' "$AL_UI_RESET" "$(al_colorize_status "$status")"
  printf '\n'

  al_ui_print_section "Identity"
  al_ui_print_kv "name" "${pkg_name:-$name}"
  al_ui_print_kv "version" "${pkg_version:-unknown}"
  al_ui_print_kv "mode" "$(al_colorize_mode "${pkg_mode:-unknown}")"
  al_ui_print_kv "type" "$(al_colorize_type "${pkg_type:-unknown}")"
  al_ui_print_kv "status" "$(al_colorize_status "$status")"
  al_ui_print_kv "installed_at" "${installed_at:-unknown}"

  printf '\n'
  al_ui_print_section "Record"
  al_ui_print_kv "record_dir" "$pkgdir"
  al_ui_print_kv "recipe_dir" "${recipe_dir:-unknown}"
  al_ui_print_kv "prefix" "${prefix:-unknown}"
  al_ui_print_kv "files_txt" "$( [ -f "$files" ] && printf '%s' "$files" || printf '%s' '-' )"
  al_ui_print_kv "file_count" "$file_count"
  al_ui_print_kv "created_dirs" "$( [ -f "$created_dirs" ] && printf '%s' "$created_dirs" || printf '%s' '-' )"
  al_ui_print_kv "created_count" "$created_dir_count"

  if [ "${pkg_mode:-managed}" = "tracked" ]; then
    printf '\n'
    al_ui_print_section "Tracked backend"
    al_ui_print_kv "backend" "$(al_ui_color_text "$AL_UI_BLUE" "${track_backend:-unknown}")"
    al_ui_print_kv "package_name" "${track_package_name:-unknown}"
    al_ui_print_kv "package_version" "${track_package_version:-unknown}"
    al_ui_print_kv "source_url" "${track_source_url:-unknown}"
    al_ui_print_kv "source_file" "${track_source_file:-unknown}"
    al_ui_print_kv "query_cmd" "${track_query_cmd:-unknown}"
    al_ui_print_kv "install_cmd" "${track_install_cmd:-unknown}"
    al_ui_print_kv "remove_cmd" "${track_remove_cmd:-unknown}"
  fi

  al_ui_print_rule
}

al_show_pkg_files() {
  local name="${1:-}"
  [ -n "$name" ] || al_die "Missing package name"

  local pkgdir="$AIRLOCK_DB_ROOT/packages/$name"
  local meta="$pkgdir/meta.env"
  local files="$pkgdir/files.txt"

  [ -d "$pkgdir" ] || al_die "Package files not found: $name"

  if [ -f "$meta" ]; then
    unset pkg_mode
    # shellcheck disable=SC1090
    . "$meta"
    if [ "${pkg_mode:-managed}" = "tracked" ]; then
      al_die "Tracked packages do not maintain files.txt: $name"
    fi
  fi

  [ -f "$files" ] || al_die "Package files not found: $name"

  cat "$files"
}
