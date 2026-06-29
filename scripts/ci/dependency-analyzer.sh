#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"

warn() { echo "DEPENDENCY_CHECK=warn repo=$1 reason=$2"; }
fail() { echo "DEPENDENCY_CHECK=fail repo=$1 reason=$2"; exit 1; }

grep_tree() {
  local pattern="$1"
  shift
  git -C "${REPO_ROOT}" grep -nE -e "${pattern}" "${FREEZE_TAG}" -- "$@" 2>/dev/null || true
}

check_core() {
  local hits
  hits="$(grep_tree 'source .*install/|source .*subscription/|source .*demo/|source .*vpskit-ui/|source .*landing|source .*scripts/|source .*release/' \
    vpskit/core/ vpskit/cli/vpskit.sh vpskit/network/ vpskit/qa/ vpskit/verify/ vpskit/subscription/ vpskit/rotate/ vpskit/demo/)" || true
  [ -z "${hits}" ] || fail "vpskit-core" "reverse_dependency_leak"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-core"
}

check_installers() {
  local cross_installer
  local forbidden_core_sources
  cross_installer="$(grep_tree 'source .*../install/' vpskit/install/)"
  forbidden_core_sources="$(grep_tree 'source .*../core/' vpskit/install/)"
  cross_installer="$(printf '%s\n%s' "${cross_installer}" "${forbidden_core_sources}" | grep -v 'installer_runtime.sh' || true)"
  [ -z "${cross_installer}" ] || fail "vpskit-installers" "installer_boundary_leak"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-installers"
}

check_contracts() {
  local hits
  hits="$(grep_tree '^#!|source |import ' vpskit-contracts/)" || true
  [ -z "${hits}" ] || fail "vpskit-contracts" "non_schema_content"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-contracts reason=schema_only"
}

check_ui() {
  local hits
  hits="$(grep_tree 'source .*install/|source .*core/|source .*subscription/|source .*demo/' vpskit-ui/)" || true
  [ -z "${hits}" ] || fail "vpskit-ui" "runtime_leak"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-ui"
}

check_landing() {
  local hits
  hits="$(grep_tree 'source .*install/|source .*core/|source .*subscription/|source .*demo/' landing-v2/ landing-youtube/ vpskit-client/)" || true
  [ -z "${hits}" ] || fail "vpskit-landing" "runtime_leak"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-landing reason=static_only"
}

check_saas() {
  local hits
  hits="$(grep_tree 'source .*install/|source .*core/|source .*subscription/|source .*demo/' vpskit-saas/)" || true
  [ -z "${hits}" ] || fail "vpskit-saas" "installer_leak"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-saas"
}

check_tools() {
  local hits
  hits="$(grep_tree 'source .*install/|source .*core/|source .*subscription/|source .*demo/' scripts/ release/)" || true
  [ -z "${hits}" ] || fail "vpskit-tools" "runtime_leak"
  echo "DEPENDENCY_CHECK=pass repo=vpskit-tools reason=automation_only"
}

check_core
check_installers
check_contracts
check_ui
check_landing
check_saas
check_tools
