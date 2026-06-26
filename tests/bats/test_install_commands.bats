#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

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
  [[ "$output" == *"vpskit install hysteria2"* ]]
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

@test "install hysteria2 dispatches through CLI" {
  export VPSKIT_TEST_MODE=1
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_TEST_PUBLIC_IP=203.0.113.10
  export VPSKIT_TEST_HYSTERIA2_PASSWORD=test-password
  export VPSKIT_TEST_HYSTERIA2_PIN_SHA256=test-pin
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  export VPSKIT_LOCK_METADATA_PATH="${BATS_TEST_TMPDIR}/vpskit.lock.meta"
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}"

  run bash "${CLI_PATH}" install hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_INSTALL=pass"* ]]
  [[ "$output" == *"HYSTERIA2_CONFIG=/etc/hysteria/config.yaml"* ]]
  [[ "$output" == *"HYSTERIA2_SUBSCRIPTION_FILE=/var/lib/vpskit/hysteria2.yaml"* ]]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml" ]
}

@test "install hysteria2 fails when the service is inactive" {
  export VPSKIT_TEST_MODE=1
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_TEST_PUBLIC_IP=203.0.113.10
  export VPSKIT_TEST_HYSTERIA2_PASSWORD=test-password
  export VPSKIT_TEST_HYSTERIA2_PIN_SHA256=test-pin
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="other.service"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  export VPSKIT_LOCK_METADATA_PATH="${BATS_TEST_TMPDIR}/vpskit.lock.meta"
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}"

  run bash "${CLI_PATH}" install hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_INSTALL=fail reason=service_inactive"* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=fail state=inactive"* ]]
  [[ "$output" != *"HYSTERIA2_INSTALL=pass"* ]]
}
