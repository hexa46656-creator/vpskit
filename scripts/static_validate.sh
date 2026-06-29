#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCK_PATH="${REPO_ROOT}/.vpskit.lock"
SNAPSHOT_ROOT="${REPO_ROOT}/releases/v1.1.0"

fail() {
  printf 'STATIC_VALIDATE=fail reason=%s\n' "$1"
  exit 1
}

require_file() {
  local path="$1"

  [ -f "${path}" ] || fail "missing_file path=${path}"
}

main() {
  local current_commit
  local locked_commit

  require_file "${LOCK_PATH}"
  require_file "${SNAPSHOT_ROOT}/manifest.json"
  require_file "${SNAPSHOT_ROOT}/README.md"

  locked_commit="$(tr -d '\n' < "${LOCK_PATH}")"
  current_commit="$(git -C "${REPO_ROOT}" rev-parse HEAD)"

  [ -n "${locked_commit}" ] || fail "empty_lock_commit"
  [ "${current_commit}" = "${locked_commit}" ] || fail "commit_mismatch current=${current_commit} locked=${locked_commit}"

  [ ! -e "${REPO_ROOT}/release/v1.1" ] || fail "legacy_release_path_present"
  [ ! -e "${REPO_ROOT}/vpskit/core/guardrails.sh" ] || fail "legacy_guardrails_present"
  [ ! -e "${REPO_ROOT}/scripts/arch_guard.sh" ] || fail "legacy_arch_guard_present"
  [ ! -e "${REPO_ROOT}/scripts/guard_check.sh" ] || fail "legacy_guard_check_present"

  if rg -n "ARCHITECTURE_LOCK" "${REPO_ROOT}/vpskit" "${REPO_ROOT}/scripts" \
    -g '!**/*.md' -g '!static_validate.sh' >/dev/null; then
    fail "runtime_lock_usage_present"
  fi

  if rg -n "vpskit-client|vpskit-saas" "${REPO_ROOT}/vpskit" "${REPO_ROOT}/scripts" \
    -g '!**/*.md' -g '!static_validate.sh' >/dev/null; then
    fail "frozen_architecture_terms_present"
  fi

  printf 'STATIC_VALIDATE=pass\n'
  printf 'LOCK_COMMIT=%s\n' "${locked_commit}"
  printf 'SNAPSHOT_ROOT=%s\n' "${SNAPSHOT_ROOT}"
}

main "$@"
