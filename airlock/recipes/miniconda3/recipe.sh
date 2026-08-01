#!/usr/bin/env bash
# Miniconda3 recipe
#
# Staging strategy:
#   1. Install installer payload into "$STAGE_DIR$MINICONDA_PREFIX"
#   2. Rewrite text files that still contain "$STAGE_DIR"
#   3. Fail if any text file still contains the staging prefix
#
# Notes:
#   - This follows the same broad idea used by AUR/miniconda3 packaging:
#     package into a fake root, then strip the fake-root prefix from files
#     that embed it.
#   - This only rewrites text files. If future Miniconda builds embed the
#     prefix in binary files too, this recipe may still need extra handling.

pkg_name="miniconda3"
pkg_version="26.1.1"
pkg_mode="managed"
pkg_type="artifact"

MINICONDA_PREFIX="${MINICONDA_PREFIX:-$HOME/.local/opt/miniconda3}"

stage_acquire() {
  al_fetch_cached_url \
    "https://repo.anaconda.com/miniconda/Miniconda3-py313_${pkg_version}-1-Linux-x86_64.sh" \
    "$WORKDIR/$pkg_name/$pkg_version.sh"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"
  STAGED_PREFIX="$STAGE_DIR$MINICONDA_PREFIX"

  export SRCDIR BUILDDIR MINICONDA_PREFIX STAGED_PREFIX
}

al_escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

al_rewrite_staged_prefix_in_text_files() {
  local root="$1"
  local staged_prefix="$2"
  local escaped_staged_prefix
  local text_files

  escaped_staged_prefix="$(al_escape_sed_replacement "$staged_prefix")"

  # grep -rIl: only text-like files, skip binary files
  text_files="$(
    grep -rIl -- "$staged_prefix" "$root" 2>/dev/null || true
  )"

  [ -n "$text_files" ] || return 0

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    sed -i "s|$escaped_staged_prefix||g" "$file" || return 1
  done <<EOF
$text_files
EOF
}

al_verify_no_staged_prefix_in_text_files() {
  local root="$1"
  local staged_prefix="$2"

  if grep -rIl -- "$staged_prefix" "$root" >/dev/null 2>&1; then
    al_log_error "Staging prefix still present in text files under: $root"
    grep -rIl -- "$staged_prefix" "$root" 2>/dev/null | sed 's/^/  - /' >&2 || true
    return 1
  fi
}

stage_stage() {
  mkdir -p "$(dirname "$STAGED_PREFIX")" || exit 1

  bash "$SRCDIR/$pkg_version.sh" \
    -b \
    -p "$STAGED_PREFIX" \
    -f || exit 1

  # Match the AUR-style idea: strip fake-root prefix from installed text files.
  al_rewrite_staged_prefix_in_text_files "$STAGED_PREFIX" "$STAGE_DIR" || exit 1
  al_verify_no_staged_prefix_in_text_files "$STAGED_PREFIX" "$STAGE_DIR" || exit 1

  # Optional: install license in a conventional location
  if [ -f "$STAGED_PREFIX/LICENSE.txt" ]; then
    install -Dm644 \
      "$STAGED_PREFIX/LICENSE.txt" \
      "$STAGE_DIR/usr/share/licenses/$pkg_name/LICENSE.txt" || exit 1
  fi
}
