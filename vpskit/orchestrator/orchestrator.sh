#!/usr/bin/env bash
set -euo pipefail

VPSKIT_ROOT="${VPSKIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"
MANIFEST_LOCK="${MANIFEST_LOCK:-$VPSKIT_ROOT/logs/execution/manifest.lock}"

source "$VPSKIT_ROOT/vpskit/orchestrator/lifecycle-manager.sh"
source "$VPSKIT_ROOT/vpskit/orchestrator/release-coordinator.sh"
source "$VPSKIT_ROOT/vpskit/orchestrator/rollback-orchestrator.sh"

orchestrator_main() {
  lifecycle_manager_init
  lifecycle_manager_analyze
  lifecycle_manager_plan
  lifecycle_manager_simulate
  lifecycle_manager_validate

  release_coordinator_plan
  rollback_orchestrator_plan

  echo "ORCHESTRATOR=pass"
  echo "ORCHESTRATOR=stop reason=simulation_only"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  orchestrator_main "$@"
fi
