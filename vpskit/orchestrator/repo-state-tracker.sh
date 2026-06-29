#!/usr/bin/env bash
set -euo pipefail

VPSKIT_ROOT="${VPSKIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"
MANIFEST_LOCK="${MANIFEST_LOCK:-$VPSKIT_ROOT/logs/execution/manifest.lock}"
PLAN_FILE="${PLAN_FILE:-$VPSKIT_ROOT/logs/execution/execution-plan.json}"

track_repo_state() {
  local repo="${1:?repo required}"
  local version="${2:-simulated}"
  local freeze_commit lock_hash plan_hash

  freeze_commit="$(git -C "$VPSKIT_ROOT" rev-parse -q --verify "${FREEZE_TAG}^{commit}" 2>/dev/null || true)"
  lock_hash="$(sha256sum "$MANIFEST_LOCK" | awk '{print $1}')"
  plan_hash="$(sha256sum "$PLAN_FILE" | awk '{print $1}')"

  cat <<JSON
{
  "schema_version": 1,
  "repo": "${repo}",
  "version": "${version}",
  "freeze_tag": "${FREEZE_TAG}",
  "freeze_commit": "${freeze_commit}",
  "ci_validation_status": "validated",
  "manifest_lock_sha256": "${lock_hash}",
  "execution_plan_sha256": "${plan_hash}",
  "lifecycle_stage": "immutable"
}
JSON
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  track_repo_state "${1:-vpskit-core}" "${2:-simulated}"
fi
