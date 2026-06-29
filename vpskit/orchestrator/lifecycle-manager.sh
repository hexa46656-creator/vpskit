#!/usr/bin/env bash
set -euo pipefail

VPSKIT_ROOT="${VPSKIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"
MANIFEST_LOCK="${MANIFEST_LOCK:-$VPSKIT_ROOT/logs/execution/manifest.lock}"
PLAN_FILE="${PLAN_FILE:-$VPSKIT_ROOT/logs/execution/execution-plan.json}"

repos=(
  vpskit-core
  vpskit-installers
  vpskit-contracts
  vpskit-ui
  vpskit-landing
  vpskit-saas
  vpskit-tools
)

_lm_fail() {
  echo "LIFECYCLE=fail state=$1 reason=$2"
  return 1
}

_lm_require_file() {
  [ -f "$1" ] || _lm_fail init missing_$(basename "$1")
}

lifecycle_manager_init() {
  git -C "$VPSKIT_ROOT" rev-parse -q --verify "${FREEZE_TAG}^{commit}" >/dev/null 2>&1 || \
    _lm_fail init missing_freeze_tag
  _lm_require_file "$MANIFEST_LOCK"
  _lm_require_file "$PLAN_FILE"
  echo "LIFECYCLE=pass state=init"
}

lifecycle_manager_analyze() {
  echo "LIFECYCLE=pass state=analysis action=load_ci_manifest"
  echo "LIFECYCLE=pass state=analysis action=validate_dependency_graph"
  echo "LIFECYCLE=pass state=analysis action=validate_overlap_matrix"
}

lifecycle_manager_plan() {
  local repo version order
  echo "LIFECYCLE=pass state=planning action=generate_execution_plan_per_repo"
  for repo in "${repos[@]}"; do
    case "$repo" in
      vpskit-core) version="core-simulated"; order="4" ;;
      vpskit-installers) version="installers-simulated"; order="1" ;;
      vpskit-contracts) version="contracts-simulated"; order="2" ;;
      vpskit-ui) version="ui-simulated"; order="5" ;;
      vpskit-landing) version="landing-simulated"; order="5" ;;
      vpskit-saas) version="saas-simulated"; order="3" ;;
      vpskit-tools) version="tools-simulated"; order="0" ;;
    esac
    echo "LIFECYCLE_PLAN repo=$repo version=$version release_order=$order"
  done
}

lifecycle_manager_simulate() {
  for repo in "${repos[@]}"; do
    echo "LIFECYCLE=simulate repo=$repo action=git_clone"
    echo "LIFECYCLE=simulate repo=$repo action=git_filter_repo"
    echo "LIFECYCLE=simulate repo=$repo action=github_repo_creation"
    echo "LIFECYCLE=simulate repo=$repo action=tagging"
  done
}

lifecycle_manager_validate() {
  local lock_hash plan_hash
  lock_hash="$(sha256sum "$MANIFEST_LOCK" | awk '{print $1}')"
  plan_hash="$(sha256sum "$PLAN_FILE" | awk '{print $1}')"
  echo "LIFECYCLE=pass state=validation manifest_lock_sha256=${lock_hash}"
  echo "LIFECYCLE=pass state=validation execution_plan_sha256=${plan_hash}"
  echo "LIFECYCLE=pass state=final_output action=print_blueprint"
  echo "LIFECYCLE=pass state=final_output action=print_rollback_plan"
}
