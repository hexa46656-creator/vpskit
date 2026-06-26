setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "transaction.sh"
  export EVENTS_FILE="${BATS_TEST_TMPDIR}/events"
}

@test "rollback runs commands in reverse order" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'first\n' >>'${EVENTS_FILE}'"
  vpskit_rollback_add "printf 'second\n' >>'${EVENTS_FILE}'"

  run vpskit_rollback_run

  [ "$status" -eq 0 ]
  [ "$(cat "${EVENTS_FILE}")" = $'second\nfirst' ]
}

@test "transaction commit clears rollback stack" {
  vpskit_transaction_init
  vpskit_rollback_add "printf 'should-not-run\n' >>'${EVENTS_FILE}'"
  vpskit_transaction_commit

  run vpskit_rollback_run

  [ "$status" -eq 0 ]
  [ ! -e "${EVENTS_FILE}" ]
}
