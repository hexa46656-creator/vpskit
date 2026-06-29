#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PYTHONPATH="${REPO_ROOT}/tests/stress:${REPO_ROOT}/vpskit/src:${PYTHONPATH:-}"

python3 - <<'PY'
from stress_suite import print_result, run_job_duplication, run_provisioning_safety, run_worker_restart

results = [run_worker_restart(), run_job_duplication(), run_provisioning_safety()]
for result in results:
    print_result(result)

overall = all(result.passed for result in results)
print("RELEASE READY" if overall else "NOT READY")
raise SystemExit(0 if overall else 1)
PY
