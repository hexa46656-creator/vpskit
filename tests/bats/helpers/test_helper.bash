#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(git -C "${BATS_TEST_DIRNAME}" rev-parse --show-toplevel)"

load_core() {
  source "${PROJECT_ROOT}/vpskit/core/common.sh"
  source "${PROJECT_ROOT}/vpskit/core/$1"
}

reset_vpskit_test_env() {
  unset VPSKIT_DRY_RUN
  unset VPSKIT_TEST_EUID
  unset VPSKIT_TEST_OS_ID
  unset VPSKIT_TEST_OS_VERSION_ID
  unset VPSKIT_TEST_PORT_IN_USE
  unset VPSKIT_LOCK_PATH
  unset VPSKIT_ROLLBACK_STACK
}
