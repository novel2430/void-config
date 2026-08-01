#!/usr/bin/env bash
# Install record generation.

al_db_pkg_dir() {
  echo "$AIRLOCK_DB_ROOT/packages/$pkg_name"
}

al_write_files_list() {
  local outfile="$1"

  (
    cd "$STAGE_DIR" || exit 1
    find . \( -type f -o -type l \) | LC_ALL=C sort | sed 's#^\./#/#'
  ) > "$outfile"
}

al_write_created_dirs_list() {
  local outfile="$1"

  if [ -f "$COMMIT_CREATED_DIRS_FILE" ]; then
    LC_ALL=C sort -u "$COMMIT_CREATED_DIRS_FILE" > "$outfile"
  else
    : > "$outfile"
  fi
}

al_check_commit_conflicts() {
  local tmp_list path found=0

  tmp_list="$(mktemp "$AIRLOCK_TMPDIR/conflicts.XXXXXX")" || return 1
  al_write_files_list "$tmp_list" || {
    rm -f "$tmp_list"
    return 1
  }

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -e "$path" ] || [ -L "$path" ]; then
      al_log_error "File conflict: $path"
      found=1
    fi
  done < "$tmp_list"

  rm -f "$tmp_list"

  if [ "$found" -ne 0 ]; then
    al_log_error "Commit aborted because file conflicts were found"
    return 1
  fi
}

al_maybe_check_commit_conflicts() {
  if [ "${AIRLOCK_FORCE:-0}" = "1" ]; then
    al_log_warn "Force mode enabled: skipping commit conflict checks"
    return 0
  fi

  al_check_commit_conflicts
}

al_write_meta_field() {
  local outfile="$1"
  local key="$2"
  local value="${3-}"

  printf '%s=%q\n' "$key" "$value" >> "$outfile"
}

al_write_meta() {
  local outfile="$1"

  : > "$outfile" || return 1

  al_write_meta_field "$outfile" pkg_name "$pkg_name"
  al_write_meta_field "$outfile" pkg_version "$pkg_version"
  al_write_meta_field "$outfile" pkg_mode "$pkg_mode"
  al_write_meta_field "$outfile" pkg_type "$pkg_type"
  al_write_meta_field "$outfile" installed_at "$(date '+%Y-%m-%d %H:%M:%S')"
  al_write_meta_field "$outfile" recipe_dir "$RECIPE_DIR"
  al_write_meta_field "$outfile" prefix "$PREFIX"

  if [ "$pkg_mode" = "tracked" ]; then
    al_write_meta_field "$outfile" track_backend "${track_backend:-}"
    al_write_meta_field "$outfile" track_package_name "${track_package_name:-$pkg_name}"
    al_write_meta_field "$outfile" track_package_version "${track_package_version:-$pkg_version}"
    al_write_meta_field "$outfile" track_source_url "${track_source_url:-}"
    al_write_meta_field "$outfile" track_source_file "${track_source_file:-}"
    al_write_meta_field "$outfile" track_install_cmd "${track_install_cmd:-}"
    al_write_meta_field "$outfile" track_remove_cmd "${track_remove_cmd:-}"
    al_write_meta_field "$outfile" track_query_cmd "${track_query_cmd:-}"
  fi
}

al_prepare_record_staging_managed() {
  local outdir="$WORKDIR/.airlock-record"

  mkdir -p "$outdir" || return 1
  al_write_files_list "$outdir/files.txt" || return 1
  al_write_created_dirs_list "$outdir/created_dirs.txt" || return 1
  al_write_meta "$outdir/meta.env" || return 1
}

al_prepare_record_staging_tracked() {
  local outdir="$WORKDIR/.airlock-record"

  mkdir -p "$outdir" || return 1
  al_write_meta "$outdir/meta.env" || return 1
}

al_prepare_record_staging() {
  case "$pkg_mode" in
    managed)
      al_prepare_record_staging_managed
      ;;
    tracked)
      al_prepare_record_staging_tracked
      ;;
    *)
      al_die "Unsupported pkg_mode for record: $pkg_mode"
      ;;
  esac
}

al_record_install() {
  local pkgdir
  local staged_record_dir

  pkgdir="$(al_db_pkg_dir)" || return 1
  staged_record_dir="$WORKDIR/.airlock-record"

  al_prepare_record_staging || return 1

  if al_can_create_path_without_sudo "$pkgdir/meta.env"; then
    mkdir -p "$pkgdir" || return 1
    if [ "$pkg_mode" = "managed" ]; then
      cp "$staged_record_dir/files.txt" "$pkgdir/files.txt" || return 1
      cp "$staged_record_dir/created_dirs.txt" "$pkgdir/created_dirs.txt" || return 1
    fi
    cp "$staged_record_dir/meta.env" "$pkgdir/meta.env" || return 1
  else
    sudo mkdir -p "$pkgdir" || return 1
    if [ "$pkg_mode" = "managed" ]; then
      sudo cp "$staged_record_dir/files.txt" "$pkgdir/files.txt" || return 1
      sudo cp "$staged_record_dir/created_dirs.txt" "$pkgdir/created_dirs.txt" || return 1
    fi
    sudo cp "$staged_record_dir/meta.env" "$pkgdir/meta.env" || return 1
  fi

  al_log_info "Recorded package: $pkg_name"
}
