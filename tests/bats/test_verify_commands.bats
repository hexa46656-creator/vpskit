# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_verify_rootfs() {
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_MANAGED_USER="alex"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyExample alex@example\n' >"${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh/authorized_keys"
  chmod 700 "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh"
  chmod 600 "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh/authorized_keys"
  export VPSKIT_TEST_MANAGED_USER_EXISTS=yes
  export VPSKIT_TEST_MANAGED_USER_GROUPS="alex sudo"
  export VPSKIT_TEST_SSH_DIR_OWNER="alex:alex"
  export VPSKIT_TEST_AUTHORIZED_KEYS_OWNER="alex:alex"
}

prepare_verify_vless_rootfs() {
  prepare_verify_rootfs
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  printf 'vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443#VPSKit-Reality\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/vless-reality.txt"
  export VPSKIT_TEST_XRAY_BIN="${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_ACTIVE="xray xray.service"
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/tcp ALLOW Anywhere'
}

@test "verify help lists read-only verification targets" {
  run bash "${CLI_PATH}" verify help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit verify ssh-user"* ]]
  [[ "$output" == *"vpskit verify vless-reality"* ]]
}

@test "verify rejects unknown target" {
  run bash "${CLI_PATH}" verify unknown-target

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown verify target: unknown-target"* ]]
}

@test "verify ssh-user passes when managed user SSH state is correct" {
  prepare_verify_rootfs

  run bash "${CLI_PATH}" verify ssh-user

  [ "$status" -eq 0 ]
  [[ "$output" == *"SSH_USER_EXISTS=pass user=alex"* ]]
  [[ "$output" == *"SSH_USER_SUDO=pass user=alex group=sudo"* ]]
  [[ "$output" == *"SSH_DIR_MODE=pass expected=700 actual=700"* ]]
  [[ "$output" == *"AUTHORIZED_KEYS_MODE=pass expected=600 actual=600"* ]]
  [[ "$output" == *"VERIFY_SSH_USER=pass"* ]]
}

@test "verify ssh-user fails when authorized_keys is missing" {
  prepare_verify_rootfs
  rm "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh/authorized_keys"

  run bash "${CLI_PATH}" verify ssh-user

  [ "$status" -eq 1 ]
  [[ "$output" == *"AUTHORIZED_KEYS=fail"* ]]
  [[ "$output" == *"VERIFY_SSH_USER=fail"* ]]
}

@test "verify vless-reality passes for active xray tcp 443 and subscription" {
  prepare_verify_vless_rootfs

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 0 ]
  [[ "$output" == *"XRAY_BINARY=pass"* ]]
  [[ "$output" == *"XRAY_SERVICE=pass state=active"* ]]
  [[ "$output" == *"TCP_443_LISTENER=pass service=xray"* ]]
  [[ "$output" == *"SUBSCRIPTION_FILE=pass"* ]]
  [[ "$output" == *"UFW_443_TCP=pass status=allow"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=pass"* ]]
}

@test "verify vless-reality fails when tcp 443 is not owned by xray" {
  prepare_verify_vless_rootfs
  export VPSKIT_TEST_TCP_443_OWNER=nginx

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 1 ]
  [[ "$output" == *"TCP_443_LISTENER=fail expected=xray actual=nginx"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=fail"* ]]
}
