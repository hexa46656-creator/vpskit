#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
FREEZE_TAG="${FREEZE_TAG:-vpskit-pre-split-freeze}"

commit="$(git -C "${REPO_ROOT}" rev-parse -q --verify "${FREEZE_TAG}^{commit}")" || {
  echo "FREEZE_CHECK=fail reason=missing_tag tag=${FREEZE_TAG}"
  exit 1
}

if [ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]; then
  echo "FREEZE_CHECK=warn reason=dirty_worktree"
else
  echo "FREEZE_CHECK=pass reason=clean_worktree"
fi

echo "FREEZE_CHECK=pass tag=${FREEZE_TAG} commit=${commit}"

