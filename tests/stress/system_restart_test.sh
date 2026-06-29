#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PYTHONPATH="${REPO_ROOT}/tests/stress:${REPO_ROOT}/vpskit/src:${PYTHONPATH:-}"

python3 - <<'PY'
from stress_suite import print_result, run_system_restart

result = run_system_restart()
print_result(result)
print("RELEASE READY" if result.passed else "NOT READY")
raise SystemExit(0 if result.passed else 1)
PY
