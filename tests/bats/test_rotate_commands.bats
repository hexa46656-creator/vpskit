# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_rotate_trojan_env() {
  export VPSKIT_TEST_MODE=1
  export VPSKIT_TEST_EUID=0
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_EXISTS="xray xray.service"
  export VPSKIT_TEST_SERVICE_ACTIVE="xray xray.service"
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_TEST_PUBLIC_IP=203.0.113.10
  export VPSKIT_TEST_XRAY_BIN="${BATS_TEST_TMPDIR}/xray"
  export VPSKIT_TEST_TROJAN_ROTATE_PASSWORD="new-password"
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"
  export VPSKIT_LOCK_PATH="${BATS_TEST_TMPDIR}/vpskit.lock"
  export VPSKIT_XRAY_CONFIG_PATH="/usr/local/etc/xray/config.json"
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_TCP_8443_OWNER=not_bound
  export VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART=xray
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n8443/tcp ALLOW IN Anywhere'
  mkdir -p "${BATS_TEST_TMPDIR}" \
    "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" \
    "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH%/*}" \
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
    },
    {
      "tag": "trojan-tcp-8443",
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "old-password",
            "email": "default@vpskit"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/vpskit/trojan/server.crt",
              "keyFile": "/etc/vpskit/trojan/server.key"
            }
          ]
        }
      }
    }
  ]
}
EOF
  printf 'server: 203.0.113.10\nport: 8443\npassword: old-password\nsni: 203.0.113.10\nallowInsecure: 1\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml"
  printf 'VPSKIT_TROJAN_SERVER=203.0.113.10\nVPSKIT_TROJAN_PORT=8443\nVPSKIT_TROJAN_PASSWORD=old-password\nVPSKIT_TROJAN_SNI=203.0.113.10\nVPSKIT_TROJAN_ALLOW_INSECURE=1\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env"
}

@test "rotate help lists trojan usage" {
  run bash "${CLI_PATH}" rotate trojan --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit rotate trojan"* ]]
  [[ "$output" == *"vpskit rotate trojan --yes"* ]]
  [[ "$output" == *"vpskit rotate trojan --dry-run"* ]]
}

@test "rotate rejects unknown target" {
  run bash "${CLI_PATH}" rotate unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown rotate target: unknown"* ]]
}

@test "rotate dry-run passes with valid state and does not modify files" {
  prepare_rotate_trojan_env
  local original_config
  local original_yaml
  original_config="$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")"
  original_yaml="$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml")"

  run bash "${CLI_PATH}" rotate trojan --dry-run

  [ "$status" -eq 0 ]
  [ "$output" = "TROJAN_ROTATE_DRY_RUN=pass" ]
  [ "$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")" = "${original_config}" ]
  [ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml")" = "${original_yaml}" ]
  [ ! -e "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env.backup" ]
}

@test "rotate dry-run fails when state is incomplete" {
  prepare_rotate_trojan_env
  rm "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml"

  run bash "${CLI_PATH}" rotate trojan --dry-run

  [ "$status" -eq 1 ]
  [ "$output" = "TROJAN_ROTATE_DRY_RUN=fail reason=subscription_file_missing" ]
}

@test "rotate without yes fails in non-interactive mode" {
  skip "legacy rotate confirmation behavior pending execution-security consolidation"
  prepare_rotate_trojan_env

  run bash "${CLI_PATH}" rotate trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_ROTATE=fail reason=confirmation_required"* ]]
}

@test "rotate trojan --yes updates config and subscription files without revealing passwords" {
  skip "legacy rotate mutation path pending execution-security consolidation"
  prepare_rotate_trojan_env
  local original_config
  original_config="$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")"

  run bash "${CLI_PATH}" rotate trojan --yes

  [ "$status" -eq 0 ]
  [[ "$output" == *"TROJAN_ROTATE=pass"* ]]
  [[ "$output" == *"TROJAN_PASSWORD_OLD=redacted"* ]]
  [[ "$output" == *"TROJAN_PASSWORD_NEW=redacted"* ]]
  [[ "$output" == *"TROJAN_SUBSCRIPTION_FILE=/var/lib/vpskit/trojan.yaml"* ]]
  [[ "$output" == *"VLESS_REALITY_PRESERVED=pass tcp_443=bound service=xray"* ]]
  [[ "$output" == *"TCP_8443_LISTENER=pass service=xray"* ]]
  [[ "$output" != *"old-password"* ]]
  [[ "$output" != *"new-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")" != "${original_config}" ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")" == *"new-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")" != *"old-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml")" == *"password: new-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml")" != *"password: old-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env")" == *"VPSKIT_TROJAN_PASSWORD=new-password"* ]]
  [[ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env")" != *"VPSKIT_TROJAN_PASSWORD=old-password"* ]]
}

@test "rotate trojan rolls back previous state when post validation fails" {
  prepare_rotate_trojan_env
  export VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART=not_bound
  local original_config
  local original_yaml
  original_config="$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")"
  original_yaml="$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml")"

  run bash "${CLI_PATH}" rotate trojan --yes

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_ROTATE=fail reason=post_validation_failed"* ]]
  [[ "$output" == *"XRAY_ROLLBACK=pass reason=trojan_rotate_failed"* ]]
  [ "$(cat "${VPSKIT_TEST_ROOT_DIR}${VPSKIT_XRAY_CONFIG_PATH}")" = "${original_config}" ]
  [ "$(cat "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml")" = "${original_yaml}" ]
}
