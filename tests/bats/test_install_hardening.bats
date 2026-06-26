# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "system_check.sh"
  load_core "install_lock.sh"
  load_core "transaction.sh"
  source "${PROJECT_ROOT}/vpskit/install/hardening.sh"
}

@test "hardening dry-run preserves SSH port and configures fail2ban jail" {
  export VPSKIT_DRY_RUN=1
  export VPSKIT_DRY_RUN_MUTATION_FILE="${BATS_TEST_TMPDIR}/dry-run.log"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SSHD_CONFIG_PATH="${BATS_TEST_TMPDIR}/sshd_config"
  printf 'Port 2200\nPermitRootLogin yes\nPasswordAuthentication yes\n' >"${VPSKIT_TEST_SSHD_CONFIG_PATH}"

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$output" == *"HARDENING_USER=alex"* ]]
  [[ "$output" == *"SSH_PORT=2200"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"useradd --create-home --shell /bin/bash alex"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"ufw allow 2200/tcp"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"maxretry = 5"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"findtime = 10m"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"bantime = 1h"* ]]
}

@test "hardening rejects unsafe managed user names" {
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_MANAGED_USER="bad user"

  run vpskit_install_hardening

  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid managed user"* ]]
}
