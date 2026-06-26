setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "install_lock.sh"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  export VPSKIT_LOCK_METADATA_PATH="${BATS_TEST_TMPDIR}/vpskit.lock.meta"
}

@test "lock path uses configured override" {
  run vpskit_lock_path

  [ "$status" -eq 0 ]
  [ "$output" = "${VPSKIT_LOCK_PATH}" ]
}

@test "lock dir resolves to parent directory" {
  run vpskit_lock_dir

  [ "$status" -eq 0 ]
  [ "$output" = "${BATS_TEST_TMPDIR}" ]
}

@test "lock metadata is written on acquire" {
  run vpskit_acquire_lock
  [ "$status" -eq 0 ]
  [ -f "${VPSKIT_LOCK_PATH}" ]
  [ -f "${VPSKIT_LOCK_METADATA_PATH}" ]
  [[ "$(cat "${VPSKIT_LOCK_METADATA_PATH}")" == *"PID="* ]]
  [[ "$(cat "${VPSKIT_LOCK_METADATA_PATH}")" == *"TIMESTAMP="* ]]
}

@test "lock acquire and release use only configured path" {
  run vpskit_acquire_lock
  [ "$status" -eq 0 ]
  [ -f "${VPSKIT_LOCK_PATH}" ]

  run vpskit_release_lock
  [ "$status" -eq 0 ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
  [ ! -e "${VPSKIT_LOCK_METADATA_PATH}" ]
}

@test "lock acquisition fails when lock exists" {
  printf "locked\n" >"${VPSKIT_LOCK_PATH}"

  run vpskit_acquire_lock

  [ "$status" -eq 1 ]
  [[ "$output" == *"lock already exists"* ]]
}

@test "lock state reports held and released correctly" {
  run vpskit_lock_is_held
  [ "$status" -eq 1 ]

  run vpskit_acquire_lock
  [ "$status" -eq 0 ]

  run vpskit_lock_is_held
  [ "$status" -eq 0 ]

  run vpskit_release_lock
  [ "$status" -eq 0 ]

  run vpskit_lock_is_held
  [ "$status" -eq 1 ]
}

@test "with_lock releases lock after successful command" {
  run vpskit_with_lock bash -c "test -f '${VPSKIT_LOCK_PATH}'"

  [ "$status" -eq 0 ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
}

@test "with_lock releases lock after failed command" {
  run vpskit_with_lock bash -c "exit 9"

  [ "$status" -eq 9 ]
  [ ! -e "${VPSKIT_LOCK_PATH}" ]
}

@test "release lock is idempotent" {
  run vpskit_release_lock
  [ "$status" -eq 0 ]

  run vpskit_release_lock
  [ "$status" -eq 0 ]
}
