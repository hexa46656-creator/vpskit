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
  [[ "$output" == *"vpskit install trojan"* ]]
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

prepare_trojan_env() {
  export VPSKIT_TEST_MODE=1
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_EXISTS="xray xray.service"
  export VPSKIT_TEST_SERVICE_ACTIVE="xray xray.service"
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_TEST_PUBLIC_IP=203.0.113.10
  export VPSKIT_TEST_TROJAN_PASSWORD=test-password
  export VPSKIT_TEST_XRAY_BIN="${BATS_TEST_TMPDIR}/xray"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  export VPSKIT_LOCK_METADATA_PATH="${BATS_TEST_TMPDIR}/vpskit.lock.meta"
  export VPSKIT_XRAY_CONFIG_PATH="/usr/local/etc/xray/config.json"
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n8443/tcp ALLOW IN Anywhere'
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART=xray
  export VPSKIT_TEST_TCP_8443_OWNER=not_bound
  mkdir -p "${BATS_TEST_TMPDIR}" \
    "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" \
    "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH%/*}" \
    "${VPSKIT_TEST_ROOT_DIR}/etc/vpskit/trojan" \
    "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_XRAY_BIN}"
  chmod +x "${VPSKIT_TEST_XRAY_BIN}"
  cat >"${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-vision",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "11111111-1111-4111-8111-111111111111",
            "flow": "xtls-rprx-vision",
            "email": "default@vpskit"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.cloudflare.com:443",
          "xver": 0,
          "serverNames": [
            "www.cloudflare.com"
          ],
          "privateKey": "private-test-key",
          "shortIds": [
            "abcdef1234567890"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
EOF
}

@test "install trojan dispatches through CLI and preserves VLESS 443" {
  prepare_trojan_env

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"TROJAN_INSTALL=pass"* ]]
  [[ "$output" == *"TROJAN_PORT=8443/tcp"* ]]
  [[ "$output" == *"TROJAN_SERVICE=active service=xray"* ]]
  [[ "$output" == *"TROJAN_CONFIG=present"* ]]
  [[ "$output" == *"TROJAN_SUBSCRIPTION_FILE=/var/lib/vpskit/trojan.yaml"* ]]
  [[ "$output" == *"TCP_8443_LISTENER=pass service=xray"* ]]
  [[ "$output" == *"UFW_8443_TCP=pass status=active rule=present"* ]]
  grep -q '"port": 443' "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}"
  grep -q '"protocol": "vless"' "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}"
  [ -s "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml" ]
  [ -s "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env" ]
}

@test "install trojan is root only" {
  prepare_trojan_env
  export VPSKIT_TEST_EUID=1000

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"root privileges required"* ]]
}

@test "install trojan treats xray-owned 8443 as reinstall-safe" {
  prepare_trojan_env
  export VPSKIT_TEST_TCP_8443_OWNER=xray
  unset VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"TROJAN_INSTALL=pass"* ]]
  [[ "$output" == *"TCP_8443_LISTENER=pass service=xray"* ]]
}

@test "install trojan adds ufw rule when active rule is missing" {
  prepare_trojan_env
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n22/tcp ALLOW IN Anywhere'

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_8443_TCP=pass status=active rule=present"* ]]
  grep -q 'ufw allow 8443/tcp' "${VPSKIT_TEST_COMMAND_LOG}"
}

@test "install trojan skips ufw when inactive" {
  prepare_trojan_env
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_8443_TCP=skip status=inactive reason=not_enforced"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw allow 8443/tcp"* ]]
}

@test "install trojan fails when service is inactive" {
  prepare_trojan_env
  export VPSKIT_TEST_SERVICE_ACTIVE="other.service"

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_INSTALL=fail reason=service_inactive"* ]]
  [[ "$output" == *"TROJAN_SERVICE=fail state=inactive"* ]]
  [[ "$output" != *"TROJAN_INSTALL=pass"* ]]
}

@test "install trojan fails when tcp 8443 is not bound after restart" {
  prepare_trojan_env
  export VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART=not_bound

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_INSTALL=fail reason=tcp_8443_not_bound"* ]]
  [[ "$output" == *"TCP_8443_LISTENER=fail expected=xray actual=not_bound"* ]]
  [[ "$output" != *"TROJAN_INSTALL=pass"* ]]
}

@test "install trojan fails clearly when tcp 8443 is owned by another process" {
  prepare_trojan_env
  export VPSKIT_TEST_TCP_8443_OWNER=nginx

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_INSTALL=fail reason=tcp_8443_in_use owner=nginx"* ]]
  [[ "$output" != *"TROJAN_INSTALL=pass"* ]]
}
