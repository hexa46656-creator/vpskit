#!/usr/bin/env bash
set -euo pipefail

repos=(
  vpskit-tools
  vpskit-installers
  vpskit-core
  vpskit-contracts
  vpskit-saas
  vpskit-ui
  vpskit-landing
)

execution_scheduler() {
  local index repo
  echo "SCHEDULER=pass mode=simulation_only"
  echo "SCHEDULER=info order=leaf_to_root"
  for index in "${!repos[@]}"; do
    repo="${repos[$index]}"
    echo "SCHEDULE slot=$index repo=$repo execution=simulated"
  done
  echo "SCHEDULER=pass conflict_check=none"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  execution_scheduler
fi
