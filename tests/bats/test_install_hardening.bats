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

prepare_hardening_env() {
  export VPSKIT_DRY_RUN=1
  export VPSKIT_DRY_RUN_MUTATION_FILE="${BATS_TEST_TMPDIR}/dry-run.log"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_AUTHORIZED_KEYS_VALID=yes
}

@test "hardening dry-run preserves SSH port and configures fail2ban jail" {
  prepare_hardening_env
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

@test "hardening detects SSH port from sshd -T output" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022\npermitrootlogin yes'

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$output" == *"SSH_PORT=2022"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"ufw allow 2022/tcp"* ]]
}

@test "hardening detects SSH port from sshd_config.d drop-in" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_CONFIG_PATH="${BATS_TEST_TMPDIR}/sshd_config"
  export VPSKIT_TEST_SSHD_CONFIG_DIR="${BATS_TEST_TMPDIR}/sshd_config.d"
  mkdir -p "${VPSKIT_TEST_SSHD_CONFIG_DIR}"
  printf '# no port here\n' >"${VPSKIT_TEST_SSHD_CONFIG_PATH}"
  printf 'Port 2400\n' >"${VPSKIT_TEST_SSHD_CONFIG_DIR}/10-port.conf"

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$output" == *"SSH_PORT=2400"* ]]
}

@test "hardening falls back to active sshd listener detection" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=""
  export VPSKIT_TEST_SSHD_CONFIG_PATH="${BATS_TEST_TMPDIR}/sshd_config"
  printf '# no port here\n' >"${VPSKIT_TEST_SSHD_CONFIG_PATH}"
  export VPSKIT_TEST_SSHD_LISTENERS=$'LISTEN 0 128 0.0.0.0:2522 0.0.0.0:* users:(("sshd",pid=99,fd=3))'

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$output" == *"SSH_PORT=2522"* ]]
}

@test "hardening fails closed when SSH port cannot be detected" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=""
  export VPSKIT_TEST_SSHD_CONFIG_PATH="${BATS_TEST_TMPDIR}/sshd_config"
  printf '# no port here\n' >"${VPSKIT_TEST_SSHD_CONFIG_PATH}"

  run vpskit_install_hardening

  [ "$status" -eq 1 ]
  [[ "$output" == *"unable to confidently detect SSH port"* ]]
  [ ! -e "${VPSKIT_DRY_RUN_MUTATION_FILE}" ]
}

@test "hardening fails before SSH changes when authorized_keys verification fails" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'
  export VPSKIT_TEST_AUTHORIZED_KEYS_VALID=no

  run vpskit_install_hardening

  [ "$status" -eq 1 ]
  [[ "$output" == *"managed user authorized_keys verification failed"* ]]
  [ ! -e "${VPSKIT_DRY_RUN_MUTATION_FILE}" ]
}

@test "hardening package preflight installs missing packages in dry-run" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'
  export VPSKIT_TEST_MISSING_COMMANDS="ufw fail2ban-client curl openssl ss"

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"apt-get update"* ]]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"apt-get install -y ufw fail2ban curl openssl iproute2"* ]]
}

@test "hardening installs explicit VPSKIT_AUTHORIZED_KEY for managed user" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'
  export VPSKIT_AUTHORIZED_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyExample explicit@example"

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyExample explicit@example"* ]]
}

@test "hardening installs explicit VPSKIT_AUTHORIZED_KEY_FILE for managed user" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'
  export VPSKIT_AUTHORIZED_KEY_FILE="${BATS_TEST_TMPDIR}/alex.pub"
  printf 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtestkey file@example\n' >"${VPSKIT_AUTHORIZED_KEY_FILE}"

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$(cat "${VPSKIT_DRY_RUN_MUTATION_FILE}")" == *"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtestkey file@example"* ]]
}

@test "hardening rejects invalid explicit authorized key format" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'
  export VPSKIT_AUTHORIZED_KEY="not-a-valid-key"

  run vpskit_install_hardening

  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid SSH public key format"* ]]
}

@test "hardening prints second terminal SSH verification guidance" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'
  export VPSKIT_SERVER_IP="203.0.113.10"

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  [[ "$output" == *"Open a second terminal and verify: ssh -i <matching-private-key> -p 2022 alex@203.0.113.10"* ]]
}

@test "hardening allows SSH before enabling UFW" {
  prepare_hardening_env
  export VPSKIT_TEST_SSHD_T_OUTPUT=$'port 2022'

  run vpskit_install_hardening

  [ "$status" -eq 0 ]
  awk '/ufw allow 2022\/tcp/ {allow=NR} /ufw --force enable/ {enable=NR} END {exit !(allow && enable && allow < enable)}' "${VPSKIT_DRY_RUN_MUTATION_FILE}"
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
