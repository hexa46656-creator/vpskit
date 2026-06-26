#!/usr/bin/env bash

vpskit_safety_init() {
  if [ "${VPSKIT_SAFETY_ENABLE_TRAPS:-0}" = "1" ]; then
    trap 'vpskit_safety_cleanup' EXIT INT TERM
  fi

  return 0
}

vpskit_safety_cleanup() {
  vpskit_transaction_cleanup
  vpskit_release_lock
  return 0
}

vpskit_safety_abort() {
  vpskit_transaction_abort
  vpskit_release_lock
  return 0
}
