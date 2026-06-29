#!/usr/bin/env bash

vpskit_lock_path() {
  vpskit_global_lock_path
}

vpskit_lock_dir() {
  dirname "$(vpskit_lock_path)"
}

vpskit_acquire_lock() {
  local lock_path

  lock_path="$(vpskit_lock_path)"

  if vpskit_is_dry_run; then
    vpskit_dry_run_log "LOCK ${lock_path}"
    return 0
  fi

  vpskit_global_lock_acquire || return 1
  vpskit_op_lock mutation || {
    vpskit_global_lock_release
    return 1
  }
  if type vpskit_system_dns_safety_check >/dev/null 2>&1; then
    if ! vpskit_system_dns_safety_check; then
      vpskit_op_lock_release
      vpskit_global_lock_release
      return 1
    fi
  fi
  vpskit_bind_transaction_lock || {
    vpskit_op_lock_release
    vpskit_global_lock_release
    return 1
  }

  return 0
}

vpskit_release_lock() {
  local lock_path

  lock_path="$(vpskit_lock_path)"

  if vpskit_is_dry_run; then
    vpskit_dry_run_log "UNLOCK ${lock_path}"
    return 0
  fi

  vpskit_transaction_lock_release
  vpskit_op_lock_release
  vpskit_global_lock_release
  return 0
}

vpskit_lock_is_held() {
  local lock_path

  lock_path="$(vpskit_lock_path)"

  if vpskit_is_dry_run; then
    return 1
  fi

  mkdir -p "$(vpskit_lock_dir)" || return 1

  exec 8>"${lock_path}" || return 1
  if vpskit_lock_fd_try 8; then
    exec 8>&-
    return 1
  fi

  exec 8>&-
  return 0
}

vpskit_with_lock() {
  local command_status=0
  local previous_enforce="${VPSKIT_ENFORCE_LOCK_CHAIN:-}"

  vpskit_acquire_lock || return 1
  VPSKIT_ENFORCE_LOCK_CHAIN=1
  "$@"
  command_status=$?
  if [ -n "${previous_enforce}" ]; then
    VPSKIT_ENFORCE_LOCK_CHAIN="${previous_enforce}"
  else
    unset VPSKIT_ENFORCE_LOCK_CHAIN
  fi
  vpskit_release_lock
  return "${command_status}"
}
