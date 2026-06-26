setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "system_check.sh"
  load_core "install_lock.sh"
  load_core "transaction.sh"
  source "${PROJECT_ROOT}/vpskit/install/vless_reality.sh"
}

prepare_vless_env() {
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_TEST_PUBLIC_IP="203.0.113.10"
  export VPSKIT_TEST_UUID="11111111-1111-4111-8111-111111111111"
  export VPSKIT_TEST_X25519_OUTPUT=$'PrivateKey: private-test-key\nPassword (PublicKey): public-test-key'
  export VPSKIT_TEST_SHORT_ID="abcdef1234567890"
  export VPSKIT_TEST_XRAY_BIN="${BATS_TEST_TMPDIR}/xray"
  mkdir -p "${BATS_TEST_TMPDIR}" "${VPSKIT_TEST_ROOT_DIR}"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_XRAY_BIN}"
  chmod +x "${VPSKIT_TEST_XRAY_BIN}"
}

@test "vless reality refuses occupied tcp 443 before writing config" {
  prepare_vless_env
  export VPSKIT_TEST_TCP_PORT_IN_USE=443

  run vpskit_install_vless_reality

  [ "$status" -eq 1 ]
  [[ "$output" == *"tcp port 443 is already in use"* ]]
  [ ! -e "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json" ]
}

@test "vless reality writes config and subscription URI" {
  prepare_vless_env

  run vpskit_install_vless_reality

  [ "$status" -eq 0 ]
  [[ "$output" == *"VLESS_REALITY_URI=vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443"* ]]
  [[ "$output" == *"flow=xtls-rprx-vision"* ]]
  [[ "$output" == *"pbk=public-test-key"* ]]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/vless-reality.txt" ]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/vless-reality.txt")" == vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443* ]]
}

@test "vless reality rolls back config and subscription on simulated failure" {
  prepare_vless_env
  export VPSKIT_TEST_FAIL_AFTER_CONFIG=1

  run vpskit_install_vless_reality

  [ "$status" -eq 1 ]
  [[ "$output" == *"simulated failure after config write"* ]]
  [ ! -e "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json" ]
  [ ! -e "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/vless-reality.txt" ]
}
