#!/usr/bin/env bash

vpskit_lock_path() {
  printf '%s\n' "${VPSKIT_LOCK_PATH:-/var/lib/vpskit/vpskit.lock}"
}

vpskit_lock_dir() {
  dirname "$(vpskit_lock_path)"
}

vpskit_lock_metadata_path() {
  printf '%s\n' "${VPSKIT_LOCK_METADATA_PATH:-$(vpskit_lock_path).meta}"
}

vpskit_lock_is_held() {
  local lock_path

  lock_path="$(vpskit_lock_path)"
  [ -f "${lock_path}" ]
}

vpskit_write_lock_metadata() {
  local metadata_path

  metadata_path="$(vpskit_lock_metadata_path)"
  printf 'PID=%s\nTIMESTAMP=%s\n' "$$" "$(date -u +%Y%m%dT%H%M%SZ)" >"${metadata_path}"
}

vpskit_acquire_lock() {
  local lock_path
  local lock_dir

  lock_path="$(vpskit_lock_path)"
  lock_dir="$(vpskit_lock_dir)"

  if vpskit_is_dry_run; then
    vpskit_dry_run_log "LOCK ${lock_path}"
    return 0
  fi

  if vpskit_lock_is_held; then
    vpskit_die "lock already exists: ${lock_path}"
    return 1
  fi

  mkdir -p "${lock_dir}" || return 1
  printf '%s\n' "$$" >"${lock_path}"
  vpskit_write_lock_metadata
}

vpskit_release_lock() {
  local lock_path
  local metadata_path

  lock_path="$(vpskit_lock_path)"
  metadata_path="$(vpskit_lock_metadata_path)"

  if vpskit_is_dry_run; then
    vpskit_dry_run_log "UNLOCK ${lock_path}"
    return 0
  fi

  rm -f "${lock_path}" "${metadata_path}"
  return 0
}

vpskit_with_lock() {
  vpskit_acquire_lock || return 1
  "$@"
  local command_status=$?
  vpskit_release_lock
  return "${command_status}"
}
