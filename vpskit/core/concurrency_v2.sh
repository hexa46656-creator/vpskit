#!/usr/bin/env bash

vpskit_concurrency_lock_dir() {
  dirname "$(vpskit_global_lock_path)"
}

vpskit_global_lock_path() {
  printf '%s\n' "${VPSKIT_GLOBAL_LOCK_PATH:-${VPSKIT_LOCK_PATH:-/var/lib/vpskit/vpskit.lock}}"
}

vpskit_op_lock_path() {
  local operation_name="${1:-mutation}"
  local lock_dir

  lock_dir="${VPSKIT_OP_LOCK_DIR:-$(vpskit_concurrency_lock_dir)}"
  printf '%s/%s.lock\n' "${lock_dir}" "${operation_name}"
}

vpskit_transaction_lock_path() {
  local lock_dir

  lock_dir="${VPSKIT_TRANSACTION_LOCK_DIR:-$(vpskit_concurrency_lock_dir)}"
  printf '%s/vpskit.transaction.lock\n' "${lock_dir}"
}

vpskit_lock_fd_try() {
  local file_descriptor="$1"

  python3 - "${file_descriptor}" <<'PY'
import fcntl
import sys

fd = int(sys.argv[1])

try:
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(1)
PY
}

vpskit_deadlock_guard() {
  local requested_lock="${1:-global}"

  case "${requested_lock}" in
    global)
      if [ -n "${VPSKIT_GLOBAL_LOCK_FD:-}" ]; then
        vpskit_die "global lock already held"
        return 1
      fi
      ;;
    op)
      if [ -z "${VPSKIT_GLOBAL_LOCK_FD:-}" ] || [ -n "${VPSKIT_OP_LOCK_FD:-}" ]; then
        vpskit_die "operation lock requires a held global lock"
        return 1
      fi
      ;;
    transaction)
      if [ -z "${VPSKIT_OP_LOCK_FD:-}" ] || [ -n "${VPSKIT_TRANSACTION_LOCK_FD:-}" ]; then
        vpskit_die "transaction lock requires an operation lock"
        return 1
      fi
      ;;
  esac

  return 0
}

vpskit_assert_lock_chain_active() {
  if [ -z "${VPSKIT_GLOBAL_LOCK_FD:-}" ] || [ -z "${VPSKIT_OP_LOCK_FD:-}" ] || [ -z "${VPSKIT_TRANSACTION_LOCK_FD:-}" ]; then
    vpskit_die "full lock chain is required"
    return 1
  fi

  return 0
}

vpskit_global_lock_acquire() {
  local lock_path

  lock_path="$(vpskit_global_lock_path)"

  vpskit_deadlock_guard global || return 1

  mkdir -p "$(dirname "${lock_path}")" || return 1
  exec 9>"${lock_path}" || return 1

  if ! vpskit_lock_fd_try 9; then
    exec 9>&-
    vpskit_die "lock already exists: ${lock_path}"
    return 1
  fi

  VPSKIT_GLOBAL_LOCK_FD=9
  return 0
}

vpskit_op_lock() {
  local operation_name="${1:-mutation}"
  local lock_path

  lock_path="$(vpskit_op_lock_path "${operation_name}")"

  vpskit_deadlock_guard op || return 1

  mkdir -p "$(dirname "${lock_path}")" || return 1
  exec 8>"${lock_path}" || return 1

  if ! vpskit_lock_fd_try 8; then
    exec 8>&-
    vpskit_die "operation lock already exists: ${lock_path}"
    return 1
  fi

  VPSKIT_OP_LOCK_FD=8
  return 0
}

vpskit_bind_transaction_lock() {
  local lock_path

  lock_path="$(vpskit_transaction_lock_path)"

  vpskit_deadlock_guard transaction || return 1

  mkdir -p "$(dirname "${lock_path}")" || return 1
  exec 7>"${lock_path}" || return 1

  if ! vpskit_lock_fd_try 7; then
    exec 7>&-
    vpskit_die "transaction lock already exists: ${lock_path}"
    return 1
  fi

  VPSKIT_TRANSACTION_LOCK_FD=7
  return 0
}

vpskit_global_lock_release() {
  if [ -n "${VPSKIT_GLOBAL_LOCK_FD:-}" ]; then
    eval "exec ${VPSKIT_GLOBAL_LOCK_FD}>&-"
    unset VPSKIT_GLOBAL_LOCK_FD
  fi
}

vpskit_op_lock_release() {
  if [ -n "${VPSKIT_OP_LOCK_FD:-}" ]; then
    eval "exec ${VPSKIT_OP_LOCK_FD}>&-"
    unset VPSKIT_OP_LOCK_FD
  fi
}

vpskit_transaction_lock_release() {
  if [ -n "${VPSKIT_TRANSACTION_LOCK_FD:-}" ]; then
    eval "exec ${VPSKIT_TRANSACTION_LOCK_FD}>&-"
    unset VPSKIT_TRANSACTION_LOCK_FD
  fi
}
