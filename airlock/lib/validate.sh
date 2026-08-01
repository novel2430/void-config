#!/usr/bin/env bash
# Recipe validation logic.
#
# v0 recognizes mode/type explicitly so managed and tracked packages can share
# the same metadata model.

al_validate_recipe() {
  [ -n "${pkg_name:-}" ]    || al_die "Recipe missing pkg_name"
  [ -n "${pkg_version:-}" ] || al_die "Recipe missing pkg_version"
  [ -n "${pkg_mode:-}" ]    || al_die "Recipe missing pkg_mode"
  [ -n "${pkg_type:-}" ]    || al_die "Recipe missing pkg_type"

  case "$pkg_mode" in
    managed|tracked)
      ;;
    *)
      al_die "Invalid pkg_mode: $pkg_mode"
      ;;
  esac

  case "$pkg_type" in
    source|artifact)
      ;;
    *)
      al_die "Invalid or unsupported pkg_type for v0: $pkg_type"
      ;;
  esac
}
