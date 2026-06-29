#!/usr/bin/env bash

vpskit_join_command_text() {
  local command_text=""
  local arg

  for arg in "$@"; do
    if [ -z "${command_text}" ]; then
      command_text="${arg}"
    else
      command_text="${command_text} ${arg}"
    fi
  done

  printf '%s\n' "${command_text}"
}

vpskit_shell_join_command() {
  local arg

  for arg in "$@"; do
    printf '%q ' "${arg}"
  done
  printf '\n'
}

vpskit_hash_file() {
  local file_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file_path}" | awk '{print $1}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file_path}" | awk '{print $1}'
    return 0
  fi

  vpskit_die "sha256 command not available"
  return 1
}

vpskit_detect_pipe_to_bash() {
  local command_text="${1:-}"

  if [[ "${command_text}" =~ (curl|wget)[[:space:]].*\|[[:space:]]*(bash|sh)([[:space:]]|$) ]]; then
    return 0
  fi

  return 1
}

vpskit_assert_no_remote_pipe_exec() {
  local command_text

  command_text="$(vpskit_join_command_text "$@")"

  if vpskit_detect_pipe_to_bash "${command_text}"; then
    vpskit_die "remote pipe execution is blocked"
    return 1
  fi

  return 0
}

vpskit_verify_checksum() {
  local artifact_path="${1:-}"
  local expected_checksum="${2:-}"
  local actual_checksum=""

  if [ -z "${artifact_path}" ] || [ -z "${expected_checksum}" ]; then
    vpskit_die "checksum path and expected value are required"
    return 1
  fi

  if [ ! -f "${artifact_path}" ]; then
    vpskit_die "checksum artifact not found: ${artifact_path}"
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual_checksum="$(sha256sum "${artifact_path}" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual_checksum="$(shasum -a 256 "${artifact_path}" | awk '{print $1}')"
  else
    vpskit_die "sha256 command not available"
    return 1
  fi

  if [ "${actual_checksum}" != "${expected_checksum}" ]; then
    vpskit_die "checksum mismatch for ${artifact_path}"
    return 1
  fi

  return 0
}

vpskit_execution_guard() {
  local command_text

  command_text="$(vpskit_join_command_text "$@")"

  if vpskit_detect_pipe_to_bash "${command_text}"; then
    vpskit_die "remote pipe execution is blocked"
    return 1
  fi

  if [ "${VPSKIT_REQUIRE_CHECKSUM:-0}" = "1" ]; then
    if [ -z "${VPSKIT_CHECKSUM_ARTIFACT:-}" ] || [ -z "${VPSKIT_CHECKSUM_EXPECTED:-}" ]; then
      vpskit_die "checksum verification is required"
      return 1
    fi

    vpskit_verify_checksum "${VPSKIT_CHECKSUM_ARTIFACT}" "${VPSKIT_CHECKSUM_EXPECTED}" || return 1
  fi

  return 0
}

vpskit_safe_run_script() {
  local snippet="${1:-}"
  local script_path
  local checksum
  local status=0

  if [ -z "${snippet}" ]; then
    vpskit_die "script snippet is required"
    return 1
  fi

  script_path="$(mktemp "${TMPDIR:-/tmp}/vpskit-safe-run.XXXXXX.sh")" || return 1
  printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "${snippet}" >"${script_path}" || {
    rm -f "${script_path}"
    return 1
  }
  chmod 0700 "${script_path}"

  checksum="$(vpskit_hash_file "${script_path}")" || {
    rm -f "${script_path}"
    return 1
  }

  vpskit_safe_run "${script_path}" "${checksum}" -- bash "${script_path}"
  status=$?
  rm -f "${script_path}"
  return "${status}"
}

vpskit_safe_run() {
  local artifact_path="${1:-}"
  local expected_checksum="${2:-}"

  if [ -z "${artifact_path}" ] || [ -z "${expected_checksum}" ]; then
    vpskit_die "safe execution requires an artifact path and checksum"
    return 1
  fi

  shift 2
  if [ "${1:-}" = "--" ]; then
    shift
  fi

  if [ "$#" -eq 0 ]; then
    vpskit_die "command is required"
    return 1
  fi

  VPSKIT_REQUIRE_CHECKSUM=1 \
    VPSKIT_CHECKSUM_ARTIFACT="${artifact_path}" \
    VPSKIT_CHECKSUM_EXPECTED="${expected_checksum}" \
    vpskit_execution_guard "$@" || return 1

  "$@"
}
