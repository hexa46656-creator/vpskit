#!/usr/bin/env bash
set -euo pipefail

VPSKIT_ROOT="${VPSKIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"

rollback_orchestrator_plan() {
  local repo
  echo "ROLLBACK_ORCHESTRATOR=pass mode=simulation_only"
  echo "ROLLBACK_PLAN action=full_system_rollback"
  echo "ROLLBACK_PLAN action=freeze_tag_reversion_model tag=${FREEZE_TAG}"
  echo "ROLLBACK_PLAN action=ci_reset_strategy"
  for repo in vpskit-core vpskit-installers vpskit-contracts vpskit-ui vpskit-landing vpskit-saas vpskit-tools; do
    echo "ROLLBACK_PLAN repo=$repo action=per_repo_rollback_simulation"
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  rollback_orchestrator_plan
fi
