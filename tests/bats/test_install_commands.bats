#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  skip "legacy installer command matrix pending execution-security consolidation"
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/vpskit/install/trojan.sh"
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
  [[ "$output" == *"VLESS_REALITY_PRESERVED=pass tcp_443=bound service=xray"* ]]
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

@test "install trojan resolves nobody runtime ownership and restrictive tls modes" {
  prepare_trojan_env
  export VPSKIT_TEST_XRAY_USER=nobody
  export VPSKIT_TEST_XRAY_GROUP=nogroup

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"VLESS_REALITY_PRESERVED=pass tcp_443=bound service=xray"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" == *"RUN chown -R nobody:nogroup /etc/vpskit/trojan"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" == *"RUN chmod 750 /etc/vpskit/trojan"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" == *"RUN chmod 644 /etc/vpskit/trojan/server.crt"* ]]
  [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" == *"RUN chmod 600 /etc/vpskit/trojan/server.key"* ]]
  python3 - "${VPSKIT_TEST_ROOT_DIR}/etc/vpskit/trojan/server.key" <<'PY'
from pathlib import Path
import sys

mode = Path(sys.argv[1]).stat().st_mode & 0o777
assert mode == 0o600, oct(mode)
PY
  python3 - "${VPSKIT_TEST_ROOT_DIR}/etc/vpskit/trojan/server.crt" <<'PY'
from pathlib import Path
import sys

mode = Path(sys.argv[1]).stat().st_mode & 0o777
assert mode == 0o644, oct(mode)
PY
  [ -r "${VPSKIT_TEST_ROOT_DIR}/etc/vpskit/trojan/server.crt" ]
}

@test "trojan candidate xray config path ends with json suffix" {
  local candidate_config_path

  candidate_config_path="$(vpskit_trojan_candidate_xray_config_path)"

  [[ "${candidate_config_path}" == *.json ]]
  rm -f "${candidate_config_path}"
}

@test "install trojan validates candidate config before live replacement" {
  prepare_trojan_env
  export VPSKIT_TEST_XRAY_LOG="${BATS_TEST_TMPDIR}/xray.log"
  cat >"${VPSKIT_TEST_XRAY_BIN}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${VPSKIT_TEST_XRAY_LOG}"
live_config="${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json"
config_path=""

printf '%s\n' "$*" >>"${log_file}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -config)
      shift
      config_path="${1:-}"
      ;;
  esac
  shift || true
done

if [ -z "${config_path}" ]; then
  exit 1
fi

case "${config_path}" in
  *.json)
    ;;
  *)
    printf 'NON_JSON_CANDIDATE_PATH=%s\n' "${config_path}" >>"${log_file}"
    exit 4
    ;;
esac

if grep -q '"protocol": "trojan"' "${live_config}"; then
  printf 'LIVE_CONFIG_REPLACED_EARLY\n' >>"${log_file}"
  exit 3
fi

if [ "${config_path}" = "${live_config}" ]; then
  printf 'LIVE_CONFIG_USED_FOR_VALIDATION\n' >>"${log_file}"
  exit 4
fi

exit 0
EOF
  chmod +x "${VPSKIT_TEST_XRAY_BIN}"

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"TROJAN_INSTALL=pass"* ]]
  [[ "$output" != *"LIVE_CONFIG_REPLACED_EARLY"* ]]
  [[ "$output" != *"LIVE_CONFIG_USED_FOR_VALIDATION"* ]]
  [[ "$(cat "${VPSKIT_TEST_XRAY_LOG}")" == *"run -test -config"*".json"* ]]
  [[ "$(cat "${VPSKIT_TEST_XRAY_LOG}")" == *"run -test -config"* ]]
}

@test "vpskit trojan validation fails for genuinely invalid candidate config" {
  prepare_trojan_env
  export VPSKIT_TEST_XRAY_BIN="${BATS_TEST_TMPDIR}/xray-json-validate"
  cat >"${VPSKIT_TEST_XRAY_BIN}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config_path=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -config)
      shift
      config_path="${1:-}"
      ;;
  esac
  shift || true
done

if [ -z "${config_path}" ]; then
  exit 1
fi

python3 - "${config_path}" <<'PY'
from pathlib import Path
import json
import sys

path = Path(sys.argv[1])
json.loads(path.read_text(encoding="utf-8"))
PY
EOF
  chmod +x "${VPSKIT_TEST_XRAY_BIN}"

  local invalid_candidate
  invalid_candidate="${BATS_TEST_TMPDIR}/invalid-candidate.json"
  printf '{not valid json\n' >"${invalid_candidate}"

  run vpskit_trojan_validate_candidate_xray_config "${VPSKIT_TEST_XRAY_BIN}" "${invalid_candidate}"

  [ "$status" -eq 1 ]
}

@test "install trojan rolls back old config when post-restart validation fails" {
  prepare_trojan_env
  local original_config
  original_config="$(cat "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json")"
  export VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART=not_bound

  run bash "${CLI_PATH}" install trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_INSTALL=fail reason=tcp_8443_not_bound"* ]]
  [[ "$output" == *"XRAY_ROLLBACK=pass reason=trojan_install_failed"* ]]
  [[ "$output" != *"TROJAN_INSTALL=pass"* ]]
  [ "$(cat "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json")" = "${original_config}" ]
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
