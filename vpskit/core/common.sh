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

vpskit_run_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
    return $?
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    sudo -n "$@"
    return $?
  fi

  vpskit_die "root access or passwordless sudo is required"
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

  local snippet

  if [ "$#" -eq 0 ]; then
    vpskit_die "mutation command is required"
    return 1
  fi

  snippet="$(vpskit_shell_join_command "$@")"

  if ! vpskit_execution_guard "$@"; then
    return 1
  fi

  if [ "${VPSKIT_ENFORCE_LOCK_CHAIN:-0}" = "1" ] && type vpskit_assert_lock_chain_active >/dev/null 2>&1; then
    vpskit_assert_lock_chain_active || return 1
  fi

  vpskit_safe_run_script "${snippet% }"
}

vpskit_write_managed_file() {
  local path="$1"
  local mode="$2"
  local content="$3"
  local target_path
  local backup_path=""
  local quoted_target
  local quoted_backup
  local payload_path
  local payload_path_quoted
  local parent_dir_quoted

  target_path="$(vpskit_system_path "${path}")"

  if vpskit_is_dry_run; then
    vpskit_dry_run_log "WRITE ${path}"
    vpskit_dry_run_log "${content}"
    return 0
  fi

  quoted_target="$(vpskit_shell_quote "${target_path}")"
  parent_dir_quoted="$(vpskit_shell_quote "$(dirname "${target_path}")")"
  payload_path="$(mktemp "${TMPDIR:-/tmp}/vpskit-write.XXXXXX")" || return 1
  printf '%s\n' "${content}" >"${payload_path}" || {
    rm -f "${payload_path}"
    return 1
  }
  payload_path_quoted="$(vpskit_shell_quote "${payload_path}")"

  if [ -e "${target_path}" ]; then
    backup_path="$(mktemp)"
    vpskit_run_mutation cp -a "${target_path}" "${backup_path}" || {
      rm -f "${payload_path}" "${backup_path}"
      return 1
    }
    quoted_backup="$(vpskit_shell_quote "${backup_path}")"
    vpskit_rollback_add "cp -a ${quoted_backup} ${quoted_target}; rm -f ${quoted_backup}" || return 1
  else
    vpskit_rollback_add "rm -f ${quoted_target}" || return 1
  fi

  if ! vpskit_safe_run_script "mkdir -p ${parent_dir_quoted}; cp ${payload_path_quoted} ${quoted_target}; chmod ${mode} ${quoted_target}"; then
    rm -f "${payload_path}"
    return 1
  fi

  rm -f "${payload_path}"
}

# shellcheck disable=SC1091
if [ -f "${BASH_SOURCE[0]%/*}/execution_security.sh" ]; then
  source "${BASH_SOURCE[0]%/*}/execution_security.sh"
fi

# shellcheck disable=SC1091
if [ -f "${BASH_SOURCE[0]%/*}/dns_safety.sh" ]; then
  source "${BASH_SOURCE[0]%/*}/dns_safety.sh"
fi

# shellcheck disable=SC1091
if [ -f "${BASH_SOURCE[0]%/*}/concurrency_v2.sh" ]; then
  source "${BASH_SOURCE[0]%/*}/concurrency_v2.sh"
fi
