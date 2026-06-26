#!/usr/bin/env bash

vpskit_transaction_init() {
  VPSKIT_ROLLBACK_STACK=""
}

vpskit_rollback_add() {
  local rollback_command="$*"

  if [ -z "${rollback_command}" ]; then
    vpskit_die "rollback command is required"
    return 1
  fi

  if [ -z "${VPSKIT_ROLLBACK_STACK:-}" ]; then
    VPSKIT_ROLLBACK_STACK="${rollback_command}"
  else
    VPSKIT_ROLLBACK_STACK="${VPSKIT_ROLLBACK_STACK}
${rollback_command}"
  fi
}

vpskit_rollback_run() {
  local line_count
  local rollback_command
  local status=0

  if [ -z "${VPSKIT_ROLLBACK_STACK:-}" ]; then
    return 0
  fi

  line_count="$(printf '%s\n' "${VPSKIT_ROLLBACK_STACK}" | wc -l | tr -d ' ')"

  while [ "${line_count}" -gt 0 ]; do
    rollback_command="$(printf '%s\n' "${VPSKIT_ROLLBACK_STACK}" | sed -n "${line_count}p")"
    if ! bash -c "${rollback_command}"; then
      status=1
    fi
    line_count=$((line_count - 1))
  done

  VPSKIT_ROLLBACK_STACK=""
  return "${status}"
}

vpskit_transaction_commit() {
  VPSKIT_ROLLBACK_STACK=""
}
