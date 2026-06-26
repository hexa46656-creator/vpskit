setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "install_lock.sh"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
}

@test "lock path uses configured override" {
  run vpskit_lock_path

  [ "$status" -eq 0 ]
  [ "$output" = "${VPSKIT_LOCK_PATH}" ]
}

@test "lock acquire and release use only configured path" {
  run vpskit_acquire_lock
  [ "$status" -eq 0 ]
  [ -f "${VPSKIT_LOCK_PATH}" ]

  run vpskit_release_lock
  [ "$status" -eq 0 ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
}

@test "lock acquisition fails when lock exists" {
  printf "locked\n" >"${VPSKIT_LOCK_PATH}"

  run vpskit_acquire_lock

  [ "$status" -eq 1 ]
  [[ "$output" == *"lock already exists"* ]]
}

@test "with_lock releases lock after successful command" {
  run vpskit_with_lock bash -c "test -f '${VPSKIT_LOCK_PATH}'"

  [ "$status" -eq 0 ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
}
