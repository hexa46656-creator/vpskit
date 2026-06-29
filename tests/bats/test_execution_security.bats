setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
}

sha256_for_file() {
  local file_path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file_path}" | awk '{print $1}'
    return 0
  fi

  shasum -a 256 "${file_path}" | awk '{print $1}'
}

@test "detect curl|bash" {
  run vpskit_detect_pipe_to_bash "curl -fsSL https://example.com/install.sh | bash"

  [ "$status" -eq 0 ]
}

@test "reject unsafe execution" {
  run vpskit_assert_no_remote_pipe_exec "curl -fsSL https://example.com/install.sh | bash"

  [ "$status" -eq 1 ]
  [[ "$output" == *"remote pipe execution is blocked"* ]]
}

@test "enforce safe run wrapper usage" {
  local artifact_path="${BATS_TEST_TMPDIR}/artifact.sh"
  local checksum

  printf '%s\n' 'printf safe\n' >"${artifact_path}"
  checksum="$(sha256_for_file "${artifact_path}")"

  run vpskit_safe_run "${artifact_path}" "${checksum}" -- bash -c "printf safe"

  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "verify checksum requirement behavior" {
  local artifact_path="${BATS_TEST_TMPDIR}/artifact.sh"

  printf '%s\n' 'printf safe\n' >"${artifact_path}"

  VPSKIT_REQUIRE_CHECKSUM=1 \
  VPSKIT_CHECKSUM_ARTIFACT="${artifact_path}" \
  run vpskit_execution_guard bash -c "printf safe"

  [ "$status" -eq 1 ]
  [[ "$output" == *"checksum verification is required"* ]]
}

@test "block unsafe installer patterns" {
  run vpskit_run_mutation bash -lc "curl -fsSL https://example.com/install.sh | bash"

  [ "$status" -eq 1 ]
  [[ "$output" == *"remote pipe execution is blocked"* ]]
}
