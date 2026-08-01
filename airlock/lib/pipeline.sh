#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Pipeline resolution and stage dispatch.
#
# This module is responsible for:
# - selecting the default pipeline from pkg_mode/pkg_type
# - dispatching each stage in order
# - preferring recipe-defined stage implementations
# - falling back to framework defaults when needed
# -----------------------------------------------------------------------------

al_pipeline_for_recipe() {
  case "${pkg_mode}/${pkg_type}" in
    managed/source)
      echo "acquire prepare patch configure build stage"
      ;;
    managed/artifact)
      echo "acquire prepare patch configure stage"
      ;;
    tracked/source)
      echo "acquire prepare patch configure build"
      ;;
    tracked/artifact)
      echo "acquire prepare patch configure"
      ;;
    *)
      al_die "No pipeline for ${pkg_mode}/${pkg_type}"
      ;;
  esac
}

al_run_stage() {
  local stage="$1"
  local recipe_func="stage_${stage}"
  local default_func="al_default_${stage}"

  AIRLOCK_CURRENT_STAGE="$stage"
  al_log_stage "BEGIN $stage"

  if al_is_function_defined "$recipe_func"; then
    "$recipe_func"
  elif al_is_function_defined "$default_func"; then
    "$default_func"
  else
    al_log_error "No implementation available for stage: $stage"
    return 1
  fi

  al_log_stage "OK $stage"
}

al_run_pipeline() {
  local stage pipeline

  pipeline="$(al_pipeline_for_recipe)" || return 1

  for stage in $pipeline; do
    al_run_stage "$stage"
  done
}
