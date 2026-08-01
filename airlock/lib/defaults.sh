#!/usr/bin/env bash
# Default stage implementations.
#
# v0 intentionally keeps defaults conservative. Safe no-op behavior is used for
# patch/configure when appropriate, while truly required stages fail loudly if
# no recipe-specific implementation exists.

al_default_acquire() {
  al_die "No stage_acquire defined for package: $pkg_name"
}

al_default_prepare() {
  :
}

al_default_patch() {
  :
}

al_default_configure() {
  :
}

al_default_build() {
  :
}

al_default_stage() {
  al_die "No stage_stage defined for package: $pkg_name"
}

al_default_track_install() {
  al_die "No track_install defined for tracked package: $pkg_name"
}

al_default_track_remove() {
  al_die "No track_remove defined for tracked package: $pkg_name"
}
