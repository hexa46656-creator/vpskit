#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
src_dir = REPO_ROOT / "vpskit" / "src"
if str(src_dir) not in sys.path:
    sys.path.insert(0, str(src_dir))

from stress_suite import print_result, run_failure_injection, run_webhook_stress  # noqa: E402


def main() -> int:
    results = [run_webhook_stress(), run_failure_injection()]
    for result in results:
        print_result(result)

    overall = all(result.passed for result in results)
    print("RELEASE READY" if overall else "NOT READY")
    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
