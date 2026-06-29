#!/usr/bin/env bash
set -euo pipefail

VPSKIT_ROOT="${VPSKIT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"

repos=(
  vpskit-core
  vpskit-installers
  vpskit-contracts
  vpskit-ui
  vpskit-landing
  vpskit-saas
  vpskit-tools
)

release_coordinator_plan() {
  local repo version
  echo "RELEASE_COORDINATOR=pass mode=simulation_only"
  for repo in "${repos[@]}"; do
    case "$repo" in
      vpskit-core) version="0.1.0-core-simulated" ;;
      vpskit-installers) version="0.1.0-installers-simulated" ;;
      vpskit-contracts) version="0.1.0-contracts-simulated" ;;
      vpskit-ui) version="0.1.0-ui-simulated" ;;
      vpskit-landing) version="0.1.0-landing-simulated" ;;
      vpskit-saas) version="0.1.0-saas-simulated" ;;
      vpskit-tools) version="0.1.0-tools-simulated" ;;
    esac
    echo "RELEASE_PLAN repo=$repo action=create_repository_simulation"
    echo "RELEASE_PLAN repo=$repo action=bind_ci_pipeline"
    echo "RELEASE_PLAN repo=$repo action=artifact_publication_planning"
    echo "RELEASE_PLAN repo=$repo action=version_tagging_strategy version=$version"
    echo "RELEASE_PLAN repo=$repo action=git_push_simulation source_tag=$FREEZE_TAG"
  done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  release_coordinator_plan
fi
