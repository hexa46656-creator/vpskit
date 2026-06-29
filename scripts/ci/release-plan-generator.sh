#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"
TARGET_REPO="all"
MANIFEST_FILE=""
LOCK_FILE=""
RELEASE_VERSION="${RELEASE_VERSION:-vpskit-release-simulated}"

fail() {
  echo "RELEASE_PLAN=fail repo=${TARGET_REPO} reason=$1"
  exit 1
}

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
    --version)
      RELEASE_VERSION="${2:-}"
      shift 2
      ;;
    *)
      fail "unknown_arg_${1}"
      ;;
  esac
done

[ -n "${TARGET_REPO}" ] || fail "missing_repo"
git -C "${REPO_ROOT}" rev-parse -q --verify "${FREEZE_TAG}^{commit}" >/dev/null || fail "missing_freeze_tag"

if [ -n "${MANIFEST_FILE}" ] && [ -n "${LOCK_FILE}" ]; then
  bash "${REPO_ROOT}/scripts/ci/manifest-lock.sh" verify --manifest "${MANIFEST_FILE}" --lock "${LOCK_FILE}" >/dev/null
fi

echo "RELEASE_PLAN=pass repo=${TARGET_REPO} version=${RELEASE_VERSION}"
echo "PLANNED ACTION: create repository ${TARGET_REPO}"
echo "PLANNED ACTION: publish dry-run package for ${TARGET_REPO}"
echo "PLANNED ACTION: git tag ${RELEASE_VERSION}-${TARGET_REPO}"
echo "PLANNED ACTION: git push origin ${RELEASE_VERSION}-${TARGET_REPO}"
echo "PLANNED ACTION: echo no real GitHub operations executed"
