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

vpskit_is_test_mode() {
  case "${VPSKIT_TEST_MODE:-}" in
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

vpskit_shell_quote() {
  printf '%q' "$1"
}

vpskit_system_path() {
  local path="$1"
  local root_dir="${VPSKIT_TEST_ROOT_DIR:-}"

  if [ -n "${root_dir}" ] && [ "${path#/}" != "${path}" ]; then
    printf '%s%s\n' "${root_dir}" "${path}"
    return 0
  fi

  printf '%s\n' "${path}"
}

vpskit_default_subscription_file() {
  if [ -n "${VPSKIT_SUBSCRIPTION_FILE:-}" ]; then
    printf '%s\n' "${VPSKIT_SUBSCRIPTION_FILE}"
    return 0
  fi

  printf '%s/vless-reality.txt\n' "${VPSKIT_SUBSCRIPTION_DIR:-/var/lib/vpskit}"
}

vpskit_redact_sensitive_value() {
  local value="${1:-}"
  local prefix_length="${2:-4}"
  local suffix_length="${3:-4}"
  local value_length
  local suffix_start

  if [ -z "${value}" ]; then
    printf 'REDACTED\n'
    return 0
  fi

  value_length="${#value}"
  if [ "${value_length}" -le $((prefix_length + suffix_length + 3)) ]; then
    printf 'REDACTED\n'
    return 0
  fi

  suffix_start=$((value_length - suffix_length))
  printf '%s...%s\n' "${value:0:prefix_length}" "${value:suffix_start:suffix_length}"
}

vpskit_run_mutation() {
  if vpskit_is_dry_run; then
    vpskit_dry_run_log "RUN $*"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
    mkdir -p "$(dirname "${VPSKIT_TEST_COMMAND_LOG}")"
    printf 'RUN %s\n' "$*" >>"${VPSKIT_TEST_COMMAND_LOG}"
    return 0
  fi

  "$@"
}

vpskit_write_managed_file() {
  local path="$1"
  local mode="$2"
  local content="$3"
  local target_path
  local backup_path=""
  local quoted_target
  local quoted_backup

  target_path="$(vpskit_system_path "${path}")"

  if vpskit_is_dry_run; then
    vpskit_dry_run_log "WRITE ${path}"
    vpskit_dry_run_log "${content}"
    return 0
  fi

  mkdir -p "$(dirname "${target_path}")"
  quoted_target="$(vpskit_shell_quote "${target_path}")"

  if [ -e "${target_path}" ]; then
    backup_path="$(mktemp)"
    cp -a "${target_path}" "${backup_path}"
    quoted_backup="$(vpskit_shell_quote "${backup_path}")"
    vpskit_rollback_add "cp -a ${quoted_backup} ${quoted_target}; rm -f ${quoted_backup}" || return 1
  else
    vpskit_rollback_add "rm -f ${quoted_target}" || return 1
  fi

  printf '%s\n' "${content}" >"${target_path}"
  chmod "${mode}" "${target_path}"
}
