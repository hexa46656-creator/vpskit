setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "install_lock.sh"
  load_core "transaction.sh"
  load_core "safety.sh"
  export EVENTS_FILE="${BATS_TEST_TMPDIR}/events"
  export FAIL_FILE="${BATS_TEST_TMPDIR}/fail"
}

@test "transaction init marks active state" {
  vpskit_transaction_init

  [ "${VPSKIT_TRANSACTION_ACTIVE}" = "1" ]
  [ -z "${VPSKIT_ROLLBACK_STACK}" ]
}

@test "rollback add fails when transaction is inactive" {
  run vpskit_rollback_add "printf 'nope\n' >>'${EVENTS_FILE}'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"transaction is not active"* ]]
}

@test "rollback runs commands in reverse order" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'first\n' >>'${EVENTS_FILE}'"
  vpskit_rollback_add "printf 'second\n' >>'${EVENTS_FILE}'"

  run vpskit_rollback_run

  [ "$status" -eq 0 ]
  [ "$(cat "${EVENTS_FILE}")" = $'second\nfirst' ]
}

@test "rollback command failure is deterministic" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'first\n' >>'${EVENTS_FILE}'"
  vpskit_rollback_add "printf 'fail\n' >>'${FAIL_FILE}'; exit 7"

  run vpskit_rollback_run

  [ "$status" -eq 1 ]
  [ "$(cat "${EVENTS_FILE}")" = "first" ]
  [ -f "${FAIL_FILE}" ]
}

@test "transaction commit clears rollback stack" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'should-not-run\n' >>'${EVENTS_FILE}'"
  vpskit_transaction_commit

  run vpskit_rollback_run

  [ "$status" -eq 0 ]
  [ ! -e "${EVENTS_FILE}" ]
  [ "${VPSKIT_TRANSACTION_ACTIVE}" = "0" ]
}

@test "transaction abort runs rollback and clears state" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'abort\n' >>'${EVENTS_FILE}'"

  vpskit_transaction_abort

  [ "$?" -eq 0 ]
  [ "$(cat "${EVENTS_FILE}")" = "abort" ]
  [ "${VPSKIT_TRANSACTION_ACTIVE}" = "0" ]
}

@test "transaction cleanup is idempotent" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'cleanup\n' >>'${EVENTS_FILE}'"

  run vpskit_transaction_cleanup
  [ "$status" -eq 0 ]

  run vpskit_transaction_cleanup
  [ "$status" -eq 0 ]
}

@test "dry run logs intended mutation command without executing it" {
  export VPSKIT_DRY_RUN=1
  export VPSKIT_DRY_RUN_MUTATION_FILE="${BATS_TEST_TMPDIR}/dry-run"
  vpskit_transaction_init
  vpskit_rollback_add "printf 'mutated\n' >>'${EVENTS_FILE}'"

  run vpskit_transaction_run_rollback

  [ "$status" -eq 0 ]
  [ ! -e "${EVENTS_FILE}" ]
  [ -f "${VPSKIT_DRY_RUN_MUTATION_FILE}" ]
}

@test "safety cleanup clears transaction state and lock" {
  skip "legacy lock cleanup path pending execution-security consolidation"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  vpskit_transaction_init
  vpskit_rollback_add "printf 'cleanup\n' >>'${EVENTS_FILE}'"
  vpskit_acquire_lock

  vpskit_safety_cleanup

  [ "$?" -eq 0 ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
  [ "${VPSKIT_TRANSACTION_ACTIVE}" = "0" ]
}

@test "safety abort runs rollback and releases lock" {
  skip "legacy lock cleanup path pending execution-security consolidation"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  vpskit_transaction_init
  vpskit_rollback_add "printf 'safety\n' >>'${EVENTS_FILE}'"
  vpskit_acquire_lock

  vpskit_safety_abort

  [ "$?" -eq 0 ]
  [ "$(cat "${EVENTS_FILE}")" = "safety" ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
  [ "${VPSKIT_TRANSACTION_ACTIVE}" = "0" ]
}
