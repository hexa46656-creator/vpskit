#!/usr/bin/env bats

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  export VPSKIT_GLOBAL_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
}

hold_global_lock_forever() {
  vpskit_global_lock_acquire
}

@test "global lock blocks parallel mutation execution" {
  local contender_output="${BATS_TEST_TMPDIR}/contender.log"
  local contender_status=0

  hold_global_lock_forever
  [ "$?" -eq 0 ]

  if env PROJECT_ROOT="${PROJECT_ROOT}" LOCK_PATH="${VPSKIT_GLOBAL_LOCK_PATH}" bash -c 'source "$PROJECT_ROOT/vpskit/core/common.sh"; source "$PROJECT_ROOT/vpskit/core/install_lock.sh"; export VPSKIT_GLOBAL_LOCK_PATH="$LOCK_PATH"; vpskit_global_lock_acquire' >"${contender_output}" 2>&1; then
    contender_status=0
  else
    contender_status=$?
  fi
  [ "${contender_status}" -eq 1 ]
  [[ "$(cat "${contender_output}")" == *"lock already exists"* ]]

  vpskit_global_lock_release
}

@test "mutation requires the full lock chain" {
  VPSKIT_ENFORCE_LOCK_CHAIN=1 run vpskit_run_mutation printf 'mutation\n'

  [ "$status" -eq 1 ]
  [[ "$output" == *"full lock chain is required"* ]]
}

@test "deadlock cleanup allows reacquisition after exit" {
  local reacquire_output="${BATS_TEST_TMPDIR}/reacquire.log"

  hold_global_lock_forever
  [ "$?" -eq 0 ]
  vpskit_global_lock_release

  env PROJECT_ROOT="${PROJECT_ROOT}" LOCK_PATH="${VPSKIT_GLOBAL_LOCK_PATH}" bash -c 'source "$PROJECT_ROOT/vpskit/core/common.sh"; source "$PROJECT_ROOT/vpskit/core/install_lock.sh"; export VPSKIT_GLOBAL_LOCK_PATH="$LOCK_PATH"; vpskit_global_lock_acquire; vpskit_release_lock' >"${reacquire_output}" 2>&1
  [ "$?" -eq 0 ]
}
