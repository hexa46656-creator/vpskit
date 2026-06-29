#!/usr/bin/env bash

if [ -z "${VPSKIT_TRANSACTION_ACTIVE:-}" ]; then
  VPSKIT_TRANSACTION_ACTIVE=0
fi

vpskit_transaction_init() {
  VPSKIT_ROLLBACK_STACK=""
  VPSKIT_TRANSACTION_ACTIVE=1
  return 0
}

vpskit_transaction_active() {
  [ "${VPSKIT_TRANSACTION_ACTIVE:-0}" = "1" ]
}

vpskit_rollback_add() {
  local rollback_command="$*"

  if ! vpskit_transaction_active; then
    vpskit_die "transaction is not active"
    return 1
  fi

  if [ -z "${rollback_command}" ]; then
    vpskit_die "rollback command is required"
    return 1
  fi

  if [ -z "${VPSKIT_ROLLBACK_STACK:-}" ]; then
    VPSKIT_ROLLBACK_STACK="${rollback_command}"
    return 0
  fi

  VPSKIT_ROLLBACK_STACK="${VPSKIT_ROLLBACK_STACK}
${rollback_command}"
  return 0
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
    if vpskit_is_dry_run; then
      vpskit_dry_run_log "ROLLBACK ${rollback_command}"
    elif ! vpskit_safe_run_script "${rollback_command}"; then
      status=1
    fi
    line_count=$((line_count - 1))
  done

  VPSKIT_ROLLBACK_STACK=""
  return "${status}"
}

vpskit_transaction_commit() {
  VPSKIT_ROLLBACK_STACK=""
  VPSKIT_TRANSACTION_ACTIVE=0
  return 0
}

vpskit_transaction_cleanup() {
  VPSKIT_ROLLBACK_STACK=""
  VPSKIT_TRANSACTION_ACTIVE=0
  return 0
}

vpskit_transaction_abort() {
  local rollback_status=0

  vpskit_rollback_run || rollback_status=$?
  vpskit_transaction_cleanup
  return "${rollback_status}"
}

vpskit_transaction_run_rollback() {
  vpskit_rollback_run
}

vpskit_transaction_stack_empty() {
  [ -z "${VPSKIT_ROLLBACK_STACK:-}" ]
}

vpskit_transaction_has_active_work() {
  vpskit_transaction_active && ! vpskit_transaction_stack_empty
}

vpskit_transaction_state() {
  if vpskit_transaction_active; then
    printf 'active\n'
  else
    printf 'inactive\n'
  fi
}

vpskit_transaction_status_word() {
  if vpskit_transaction_active; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}
