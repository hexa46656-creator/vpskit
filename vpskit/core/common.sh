#!/usr/bin/env bash

vpskit_log_info() {
  printf 'INFO %s\n' "$*"
}

vpskit_log_warn() {
  printf 'WARN %s\n' "$*"
}

vpskit_log_error() {
  printf 'ERROR %s\n' "$*"
}

vpskit_die() {
  vpskit_log_error "$*"
  return 1
}

vpskit_require_command() {
  local command_name="$1"

  if command -v "${command_name}" >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "required command not found: ${command_name}"
}

vpskit_is_dry_run() {
  case "${VPSKIT_DRY_RUN:-}" in
    1 | true | TRUE | yes | YES | on | ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

vpskit_dry_run_log() {
  local message="$*"
  local output_path="${VPSKIT_DRY_RUN_MUTATION_FILE:-}"

  if [ -z "${output_path}" ]; then
    output_path="${TMPDIR:-/tmp}/vpskit-dry-run.log"
  fi

  mkdir -p "$(dirname "${output_path}")"
  printf '%s\n' "${message}" >>"${output_path}"
}
