# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "system_check.sh"
  load_core "install_lock.sh"
  load_core "transaction.sh"
  source "${PROJECT_ROOT}/vpskit/install/hysteria2.sh"
}

prepare_hysteria2_env() {
  export VPSKIT_TEST_MODE=1
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_PUBLIC_IP=203.0.113.10
  export VPSKIT_TEST_HYSTERIA2_PASSWORD=test-password
  export VPSKIT_TEST_HYSTERIA2_PIN_SHA256=test-pin
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}"
}

assert_file_ends_with_single_newline() {
  python3 - "$1" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert data.endswith(b"\n"), "missing trailing newline"
assert not data.endswith(b"\n\n"), "found extra trailing newline"
PY
}

@test "hysteria2 install writes config and subscription files in test mode" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run vpskit_install_hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_INSTALL=pass"* ]]
  [[ "$output" == *"HYSTERIA2_PORT=443/udp"* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=active"* ]]
  [[ "$output" == *"HYSTERIA2_CONFIG=/etc/hysteria/config.yaml"* ]]
  [[ "$output" == *"HYSTERIA2_SUBSCRIPTION_FILE=/var/lib/vpskit/hysteria2.yaml"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml")" == *$'auth:\n  type: password\n  password: test-password'* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml")" != *"auth: test-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml")" == *"auth: test-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml")" != *"type: password"* ]]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/server.crt" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/server.key" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.env" ]
  assert_file_ends_with_single_newline "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
}

@test "hysteria2 install fails when the service stays inactive after restart" {
  prepare_hysteria2_env
  export VPSKIT_TEST_SERVICE_ACTIVE="other.service"
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run vpskit_install_hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_INSTALL=fail reason=service_inactive"* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=fail state=inactive"* ]]
  [[ "$output" != *"HYSTERIA2_INSTALL=pass"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" == *"systemctl stop hysteria-server.service"* ]]
}

@test "hysteria2 install fails when udp 443 is not bound by hysteria after restart" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UDP_443_OWNER=not_bound
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run vpskit_install_hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"UDP_443_LISTENER=fail expected=hysteria actual=nginx"* ]]
  [[ "$output" == *"HYSTERIA2_INSTALL=fail reason=udp_443_not_bound"* ]]
  [[ "$output" != *"HYSTERIA2_INSTALL=pass"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" == *"systemctl stop hysteria-server.service"* ]]
}

@test "hysteria2 install is safe when udp 443 is already owned by hysteria" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UDP_PORT_IN_USE=443
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run vpskit_install_hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_INSTALL=pass"* ]]
  [[ "$output" == *"UDP_443_LISTENER=pass service=hysteria"* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=active"* ]]
}

@test "hysteria2 install fails clearly when udp 443 is owned by another process" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UDP_PORT_IN_USE=443
  export VPSKIT_TEST_UDP_443_OWNER=nginx
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run vpskit_install_hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_INSTALL=fail reason=udp_443_in_use owner=nginx"* ]]
  [[ "$output" != *"HYSTERIA2_INSTALL=pass"* ]]
}

@test "hysteria2 install keeps an existing active UFW rule without re-adding it" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/udp ALLOW IN Anywhere'

  run vpskit_install_hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_443_UDP=pass status=active rule=present"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw allow 443/udp"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw reload"* ]]
}

@test "hysteria2 install skips inactive UFW without enabling it" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run vpskit_install_hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_443_UDP=skip status=inactive reason=not_enforced"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw allow 443/udp"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw reload"* ]]
}

@test "hysteria2 install fails when udp 443 listener owner is unknown" {
  prepare_hysteria2_env
  unset VPSKIT_TEST_UDP_443_OWNER
  unset VPSKIT_TEST_UDP_443_LISTENERS
  export PATH="/usr/bin:/bin"

  run vpskit_install_hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"UDP_443_LISTENER=unknown reason=ss_unavailable"* ]]
  [[ "$output" == *"HYSTERIA2_INSTALL=fail reason=udp_443_listener_unknown"* ]]
  [[ "$output" != *"HYSTERIA2_INSTALL=pass"* ]]
}

@test "hysteria2 install output ends with exactly one newline" {
  prepare_hysteria2_env
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"
  local output_file="${BATS_TEST_TMPDIR}/hysteria2-install.txt"

  run bash -c '
    set -euo pipefail
    source "$1/vpskit/core/common.sh"
    source "$1/vpskit/core/system_check.sh"
    source "$1/vpskit/core/install_lock.sh"
    source "$1/vpskit/core/transaction.sh"
    source "$1/vpskit/install/hysteria2.sh"
    vpskit_install_hysteria2 >"$2"
  ' _ "${PROJECT_ROOT}" "${output_file}"

  [ "$status" -eq 0 ]
  assert_file_ends_with_single_newline "${output_file}"
}
