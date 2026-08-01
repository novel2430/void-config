#!/usr/bin/env bash
# Official rustup recipe
#
# Staging strategy:
#   1. Download pinned rustup-init from official archive
#   2. Install into "$STAGE_DIR$RUSTUP_CARGO_HOME" and "$STAGE_DIR$RUSTUP_RUSTUP_HOME"
#   3. Rewrite text files that contain "$STAGE_DIR"
#   4. Fail if any file still contains "$STAGE_DIR"
#   5. Install wrappers that set final CARGO_HOME/RUSTUP_HOME
#
# Notes:
#   - rustup itself is pinned by RUSTUP_VERSION.
#   - Rust toolchain can also be pinned by RUST_TOOLCHAIN.
#   - rustup automatic self-update is disabled.
#   - Explicit `rustup self update` is blocked by wrapper.

pkg_name="rustup"
pkg_version="${pkg_version:-1.29.0}"
pkg_mode="managed"
pkg_type="artifact"

RUSTUP_VERSION="${RUSTUP_VERSION:-$pkg_version}"
RUSTUP_TARGET="${RUSTUP_TARGET:-x86_64-unknown-linux-gnu}"

# Pin Rust compiler/toolchain too.
# Use "stable" if you want channel behavior, but explicit version is cleaner.
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-1.87.0}"
RUSTUP_PROFILE="${RUSTUP_PROFILE:-default}"

RUSTUP_PREFIX="${RUSTUP_PREFIX:-$HOME/.local/opt/rustup}"
RUSTUP_CARGO_HOME="${RUSTUP_CARGO_HOME:-$RUSTUP_PREFIX/cargo}"
RUSTUP_RUSTUP_HOME="${RUSTUP_RUSTUP_HOME:-$RUSTUP_PREFIX/rustup}"

stage_acquire() {
  mkdir -p "$WORKDIR/$pkg_name" || exit 1

  al_fetch_cached_url \
    "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${RUSTUP_TARGET}/rustup-init" \
    "$WORKDIR/$pkg_name/rustup-init"

  al_fetch_cached_url \
    "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${RUSTUP_TARGET}/rustup-init.sha256" \
    "$WORKDIR/$pkg_name/rustup-init.sha256"
}

stage_prepare() {
  SRCDIR="$WORKDIR/$pkg_name"
  BUILDDIR="$SRCDIR"

  STAGED_CARGO_HOME="$STAGE_DIR$RUSTUP_CARGO_HOME"
  STAGED_RUSTUP_HOME="$STAGE_DIR$RUSTUP_RUSTUP_HOME"

  export SRCDIR BUILDDIR
  export RUSTUP_VERSION RUSTUP_TARGET RUST_TOOLCHAIN RUSTUP_PROFILE
  export RUSTUP_PREFIX RUSTUP_CARGO_HOME RUSTUP_RUSTUP_HOME
  export STAGED_CARGO_HOME STAGED_RUSTUP_HOME
}

al_verify_sha256_file() {
  local file="$1"
  local sha_file="$2"
  local expected
  local actual

  expected="$(awk '{print $1}' "$sha_file")"
  actual="$(sha256sum "$file" | awk '{print $1}')"

  if [ "$expected" != "$actual" ]; then
    al_log_error "sha256 mismatch for: $file"
    al_log_error "expected: $expected"
    al_log_error "actual:   $actual"
    return 1
  fi
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

al_verify_no_staged_prefix_any_file() {
  local root="$1"
  local staged_prefix="$2"
  local hits

  hits="$(
    grep -rIla -- "$staged_prefix" "$root" 2>/dev/null || true
  )"

  if [ -n "$hits" ]; then
    al_log_error "Staging prefix still present under: $root"
    printf '%s\n' "$hits" | sed 's/^/  - /' >&2
    return 1
  fi
}

al_install_rustup_wrappers() {
  local bindir="$STAGE_DIR/usr/local/bin"
  local tool

  install -d "$bindir" || return 1

  for tool in rustup rustc cargo rustdoc rustfmt clippy cargo-clippy cargo-fmt; do
    cat > "$bindir/$tool" <<EOF
#!/usr/bin/env bash
export CARGO_HOME="$RUSTUP_CARGO_HOME"
export RUSTUP_HOME="$RUSTUP_RUSTUP_HOME"

# This package pins rustup itself. Use the package manager to upgrade rustup.
if [ "$tool" = "rustup" ] && [ "\${1:-}" = "self" ] && [ "\${2:-}" = "update" ]; then
  echo "rustup self-update is disabled for this managed package." >&2
  echo "Upgrade rustup through the package recipe instead." >&2
  exit 1
fi

exec "$RUSTUP_CARGO_HOME/bin/$tool" "\$@"
EOF
    chmod +x "$bindir/$tool" || return 1
  done
}

al_install_rustup_env_file() {
  local env_file="$STAGE_DIR/usr/local/share/$pkg_name/env"

  install -d "$(dirname "$env_file")" || return 1

  cat > "$env_file" <<EOF
# rustup managed environment
export CARGO_HOME="$RUSTUP_CARGO_HOME"
export RUSTUP_HOME="$RUSTUP_RUSTUP_HOME"

case ":\$PATH:" in
  *:"$RUSTUP_CARGO_HOME/bin":*) ;;
  *) export PATH="$RUSTUP_CARGO_HOME/bin:\$PATH" ;;
esac
EOF
}

stage_stage() {
  chmod +x "$SRCDIR/rustup-init" || exit 1
  al_verify_sha256_file "$SRCDIR/rustup-init" "$SRCDIR/rustup-init.sha256" || exit 1

  mkdir -p "$STAGED_CARGO_HOME" "$STAGED_RUSTUP_HOME" || exit 1

  CARGO_HOME="$STAGED_CARGO_HOME" \
  RUSTUP_HOME="$STAGED_RUSTUP_HOME" \
  "$SRCDIR/rustup-init" \
    -y \
    --no-modify-path \
    --profile "$RUSTUP_PROFILE" \
    --default-toolchain "$RUST_TOOLCHAIN" || exit 1

  # Disable automatic rustup self-update.
  CARGO_HOME="$STAGED_CARGO_HOME" \
  RUSTUP_HOME="$STAGED_RUSTUP_HOME" \
  "$STAGED_CARGO_HOME/bin/rustup" set auto-self-update disable || exit 1

  # Rewrite files like cargo/env that may contain "$STAGE_DIR$RUSTUP_CARGO_HOME".
  al_rewrite_staged_prefix_in_text_files "$STAGE_DIR$RUSTUP_PREFIX" "$STAGE_DIR" || exit 1

  # Strong check: no text or binary file should still contain the staging prefix.
  al_verify_no_staged_prefix_any_file "$STAGE_DIR$RUSTUP_PREFIX" "$STAGE_DIR" || exit 1

  al_install_rustup_env_file || exit 1
  al_install_rustup_wrappers || exit 1

  # Sanity check using final paths, but still inside staged files.
  # Use the staged binary directly, with final prefix rewritten.
  CARGO_HOME="$STAGED_CARGO_HOME" \
  RUSTUP_HOME="$STAGED_RUSTUP_HOME" \
  "$STAGED_CARGO_HOME/bin/rustup" --version || exit 1

  CARGO_HOME="$STAGED_CARGO_HOME" \
  RUSTUP_HOME="$STAGED_RUSTUP_HOME" \
  "$STAGED_CARGO_HOME/bin/rustc" --version || exit 1

  CARGO_HOME="$STAGED_CARGO_HOME" \
  RUSTUP_HOME="$STAGED_RUSTUP_HOME" \
  "$STAGED_CARGO_HOME/bin/cargo" --version || exit 1
}
