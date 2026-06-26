setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

@test "install command lists supported targets in help" {
  run bash "${CLI_PATH}" help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit install hardening"* ]]
  [[ "$output" == *"vpskit install vless-reality"* ]]
}

@test "install hardening dispatches through CLI" {
  export VPSKIT_DRY_RUN=1
  export VPSKIT_DRY_RUN_MUTATION_FILE="${BATS_TEST_TMPDIR}/dry-run.log"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_OS_VERSION_CODENAME=noble
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_AUTHORIZED_KEYS_VALID=yes
  export VPSKIT_TEST_SSHD_CONFIG_PATH="${BATS_TEST_TMPDIR}/sshd_config"
  printf 'Port 2222\nPermitRootLogin yes\nPasswordAuthentication yes\n' >"${VPSKIT_TEST_SSHD_CONFIG_PATH}"

  run bash "${CLI_PATH}" install hardening

  [ "$status" -eq 0 ]
  [[ "$output" == *"HARDENING_USER=alex"* ]]
  [[ "$output" == *"SSH_PORT=2222"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"ufw allow 2222/tcp"* ]]
}

@test "invalid install target fails safely" {
  run bash "${CLI_PATH}" install unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown install target: unknown"* ]]
}
