#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"
TARGET_REPO="${TARGET_REPO:-all}"
MANIFEST_FILE=""
LOCK_FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      TARGET_REPO="${2:-}"
      shift 2
      ;;
    --manifest)
      MANIFEST_FILE="${2:-}"
      shift 2
      ;;
    --lock)
      LOCK_FILE="${2:-}"
      shift 2
      ;;
    *)
      echo "DRY_RUN_SPLIT=fail reason=unknown_arg arg=$1"
      exit 1
      ;;
  esac
done

declare -a REPO_ORDER=(
  vpskit-core
  vpskit-installers
  vpskit-contracts
  vpskit-ui
  vpskit-landing
  vpskit-saas
  vpskit-tools
)

declare -A REPO_PATHS=(
  [vpskit-core]="vpskit/core/ vpskit/cli/vpskit.sh vpskit/network/ vpskit/qa/ vpskit/verify/ vpskit/subscription/ vpskit/rotate/ vpskit/demo/ vpskit/templates/ vpskit/README.md vpskit/pyproject.toml vpskit/ARCHITECTURE_POLICY.json vpskit/tests/ docs/public/"
  [vpskit-installers]="vpskit/install/ tests/bats/test_install_commands.bats tests/bats/test_install_hardening.bats tests/bats/test_install_hysteria2.bats tests/bats/test_install_lock.bats tests/bats/test_install_vless_reality.bats tests/bats/test_installer_boundary.bats docs/install-guide.en.md docs/install-guide.zh.md docs/troubleshooting.en.md docs/troubleshooting.zh.md"
  [vpskit-contracts]="vpskit-contracts/"
  [vpskit-ui]="vpskit-ui/"
  [vpskit-landing]="landing-v2/ landing-youtube/ vpskit-client/"
  [vpskit-saas]="vpskit-saas/ docs/architecture/v0.9-saas-boundary.md"
  [vpskit-tools]="scripts/ release/ tests/bats/release_candidate.bats"
)

echo "THIS IS A DRY RUN"
echo "SOURCE TAG: ${FREEZE_TAG}"
echo "READY FOR MANUAL APPROVAL"

git -C "${REPO_ROOT}" rev-parse -q --verify "${FREEZE_TAG}^{commit}" >/dev/null || {
  echo "DRY_RUN_SPLIT=fail reason=missing_freeze_tag"
  exit 1
}

if [ -n "${MANIFEST_FILE}" ] && [ -n "${LOCK_FILE}" ]; then
  bash "${REPO_ROOT}/scripts/ci/manifest-lock.sh" verify --manifest "${MANIFEST_FILE}" --lock "${LOCK_FILE}" >/dev/null || {
    echo "DRY_RUN_SPLIT=fail reason=manifest_lock_mismatch"
    exit 1
  }
fi

for repo in "${REPO_ORDER[@]}"; do
  [ "${TARGET_REPO}" = "all" ] || [ "${TARGET_REPO}" = "${repo}" ] || continue
  echo "TARGET REPO: ${repo}"
  for path in ${REPO_PATHS[$repo]}; do
    git -C "${REPO_ROOT}" cat-file -e "${FREEZE_TAG}:${path%/}" 2>/dev/null || {
      echo "DRY_RUN_SPLIT=fail repo=${repo} reason=missing_path path=${path}"
      exit 1
    }
  done

  echo "PLANNED COMMAND: git filter-repo --force --refs ${FREEZE_TAG} ..."
  echo "PLANNED COMMAND: [repo=${repo}] path filter only, no execution"
done

echo "DRY_RUN_SPLIT=pass"
