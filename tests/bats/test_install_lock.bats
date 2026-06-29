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

@test "lock dir resolves to parent directory" {
  run vpskit_lock_dir

  [ "$status" -eq 0 ]
  [ "$output" = "${BATS_TEST_TMPDIR}" ]
}

@test "lock acquisition uses flock without metadata files" {
  vpskit_acquire_lock
  [ "$?" -eq 0 ]
  [ -f "${VPSKIT_LOCK_PATH}" ]
  [ ! -e "${BATS_TEST_TMPDIR}/vpskit.lock.meta" ]
  vpskit_release_lock
}

@test "lock acquire and release use only configured path" {
  vpskit_acquire_lock
  [ "$?" -eq 0 ]
  [ -f "${VPSKIT_LOCK_PATH}" ]
  run vpskit_lock_is_held
  [ "$status" -eq 0 ]

  vpskit_release_lock
  [ "$?" -eq 0 ]
  run vpskit_lock_is_held
  [ "$status" -eq 1 ]
}

@test "lock acquisition fails when lock exists" {
  vpskit_acquire_lock
  [ "$?" -eq 0 ]

  run bash -c 'source "$1/vpskit/core/common.sh"; source "$1/vpskit/core/install_lock.sh"; VPSKIT_LOCK_PATH="$2"; vpskit_acquire_lock' _ "${PROJECT_ROOT}" "${VPSKIT_LOCK_PATH}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"lock already exists"* ]]

  vpskit_release_lock
  [ "$?" -eq 0 ]
}

@test "lock state reports held and released correctly" {
  run vpskit_lock_is_held
  [ "$status" -eq 1 ]

  vpskit_acquire_lock
  [ "$?" -eq 0 ]

  run vpskit_lock_is_held
  [ "$status" -eq 0 ]

  vpskit_release_lock
  [ "$?" -eq 0 ]

  run vpskit_lock_is_held
  [ "$status" -eq 1 ]
}

@test "with_lock releases lock after successful command" {
  run vpskit_with_lock bash -c "test -f '${VPSKIT_LOCK_PATH}'"

  [ "$status" -eq 0 ]
  run vpskit_lock_is_held
  [ "$status" -eq 1 ]
}

@test "with_lock releases lock after failed command" {
  run vpskit_with_lock bash -c "exit 9"

  [ "$status" -eq 9 ]
  run vpskit_lock_is_held
  [ "$status" -eq 1 ]
}

@test "release lock is idempotent" {
  run vpskit_release_lock
  [ "$status" -eq 0 ]

  run vpskit_release_lock
  [ "$status" -eq 0 ]
}
