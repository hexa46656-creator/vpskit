#!/usr/bin/env bash

vpskit_lock_path() {
  printf '%s\n' "${VPSKIT_LOCK_PATH:-/var/lib/vpskit/vpskit.lock}"
}

vpskit_acquire_lock() {
  local lock_path
  local lock_dir

  lock_path="$(vpskit_lock_path)"
  lock_dir="$(dirname "${lock_path}")"

  if [ -e "${lock_path}" ]; then
    vpskit_die "lock already exists: ${lock_path}"
    return 1
  fi

  mkdir -p "${lock_dir}" || return 1
  printf '%s\n' "$$" >"${lock_path}"
}

vpskit_release_lock() {
  local lock_path

  lock_path="$(vpskit_lock_path)"

  if [ -e "${lock_path}" ]; then
    rm -f "${lock_path}"
  fi
}

vpskit_with_lock() {
  vpskit_acquire_lock || return 1
  "$@"
  local command_status=$?
  vpskit_release_lock
  return "${command_status}"
}
