# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_qa_demo_rootfs() {
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  mkdir -p \
    "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" \
    "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray" \
    "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria" \
    "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"

  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"

  cat >"${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json" <<'EOF'
{
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless"
    },
    {
      "port": 8443,
      "protocol": "trojan"
    }
  ]
}
EOF

  printf 'vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/vless-reality.txt"
  printf 'server: 203.0.113.10:443\nauth: test-password\ntls:\n  sni: 203.0.113.10\n  pinSHA256: test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
  printf 'server: 203.0.113.10\nport: 8443\npassword: test-password\nsni: 203.0.113.10\nallowInsecure: 1\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml"
  printf 'VPSKIT_TROJAN_SERVER=203.0.113.10\nVPSKIT_TROJAN_PORT=8443\nVPSKIT_TROJAN_PASSWORD=test-password\nVPSKIT_TROJAN_SNI=203.0.113.10\nVPSKIT_TROJAN_ALLOW_INSECURE=1\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env"
  printf 'listen: :443\nauth:\n  type: password\n  password: test-password\ntls:\n  cert: /etc/hysteria/server.crt\n  key: /etc/hysteria/server.key\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"
  printf 'TEST-HYSTERIA2 PRIVATE\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/server.key"
  printf 'TEST-HYSTERIA2 CERT\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/server.crt"

  export VPSKIT_SUBSCRIPTION_FILE="/var/lib/vpskit/vless-reality.txt"
  export VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE="/var/lib/vpskit/hysteria2.yaml"
  export VPSKIT_TROJAN_SUBSCRIPTION_FILE="/var/lib/vpskit/trojan.yaml"
  export VPSKIT_TEST_XRAY_BIN="${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_EXISTS="xray xray.service hysteria-server hysteria-server.service"
  export VPSKIT_TEST_SERVICE_ACTIVE="xray xray.service hysteria-server hysteria-server.service"
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_TCP_8443_OWNER=xray
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/tcp ALLOW IN Anywhere\n443/udp ALLOW IN Anywhere\n8443/tcp ALLOW IN Anywhere'
  export VPSKIT_TEST_DNS_HEALTH_RESULT=ok
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_OS_VERSION_CODENAME=noble
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

@test "qa help lists qa options" {
  run bash "${CLI_PATH}" qa --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit qa --redact"* ]]
  [[ "$output" == *"vpskit qa --output <path>"* ]]
}

@test "qa pass output is read-only and redacted" {
  prepare_qa_demo_rootfs
  export VPSKIT_TEST_COMMAND_LOG="${BATS_TEST_TMPDIR}/commands.log"

  run bash "${CLI_PATH}" qa

  [ "$status" -eq 0 ]
  [[ "$output" == *"VPSKIT_QA_VERSION=v0.6.3-beta"* ]]
  [[ "$output" == *"QA_MODE=redacted"* ]]
  [[ "$output" == *"QA_READ_ONLY=yes"* ]]
  [[ "$output" == *"SENSITIVE_OUTPUT=redacted"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=pass"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=pass"* ]]
  [[ "$output" == *"VERIFY_TROJAN=pass"* ]]
  [[ "$output" == *"DOCTOR=pass"* ]]
  [[ "$output" == *"XRAY_CONFIG_TEST=pass"* ]]
  [[ "$output" == *"TCP_443=xray"* ]]
  [[ "$output" == *"UDP_443=hysteria"* ]]
  [[ "$output" == *"TCP_8443=xray"* ]]
  [[ "$output" == *"TROJAN_EXPORT_REDACTED=pass"* ]]
  [[ "$output" == *"VPSKIT_QA=pass"* ]]
  [[ "$output" != *"test-password"* ]]
  if [ -f "${VPSKIT_TEST_COMMAND_LOG}" ]; then
    [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"systemctl restart"* ]]
    [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"systemctl stop"* ]]
    [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw allow"* ]]
    [[ "$(cat "${VPSKIT_TEST_COMMAND_LOG}")" != *"ufw reload"* ]]
  fi
}

@test "qa --redact --output writes a report file" {
  prepare_qa_demo_rootfs
  local output_file="${BATS_TEST_TMPDIR}/qa-report.txt"

  run bash "${CLI_PATH}" qa --redact --output "${output_file}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"VPSKIT_QA=pass"* ]]
  [ -f "${output_file}" ]
  [[ "$(cat "${output_file}")" == *"VPSKIT_QA_VERSION=v0.6.3-beta"* ]]
  [[ "$(cat "${output_file}")" == *"QA_READ_ONLY=yes"* ]]
  [[ "$(cat "${output_file}")" == *"SENSITIVE_OUTPUT=redacted"* ]]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "qa fails when vless verification fails" {
  prepare_qa_demo_rootfs
  export VPSKIT_TEST_TCP_443_OWNER=nginx

  run bash "${CLI_PATH}" qa --redact

  [ "$status" -eq 1 ]
  [[ "$output" == *"VERIFY_VLESS_REALITY=fail"* ]]
  [[ "$output" == *"VPSKIT_QA=fail"* ]]
}

@test "qa rejects unknown flags" {
  run bash "${CLI_PATH}" qa --bogus

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown qa option: --bogus"* ]]
}

@test "demo help lists package command" {
  run bash "${CLI_PATH}" demo help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit demo package"* ]]
  [[ "$output" == *"vpskit demo package --force --output <dir>"* ]]
}

@test "demo package creates a redacted handoff bundle" {
  prepare_qa_demo_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/vpskit-demo-package"

  run bash "${CLI_PATH}" demo package --redact --output "${output_dir}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"DEMO_PACKAGE=pass output=${output_dir} redacted=yes"* ]]
  [ -f "${output_dir}/README.en.md" ]
  [ -f "${output_dir}/README.zh.md" ]
  [ -f "${output_dir}/qa-report.txt" ]
  [ -f "${output_dir}/protocol-layout.txt" ]
  [ -f "${output_dir}/client-import-notes.en.md" ]
  [ -f "${output_dir}/client-import-notes.zh.md" ]
  [ -f "${output_dir}/security-notes.en.md" ]
  [ -f "${output_dir}/security-notes.zh.md" ]
  [ -f "${output_dir}/trojan-redacted.uri" ]
  [ -f "${output_dir}/command-checklist.txt" ]
  [[ "$(cat "${output_dir}/protocol-layout.txt")" == *"TCP 443  -> Xray -> VLESS Reality"* ]]
  [[ "$(cat "${output_dir}/protocol-layout.txt")" == *"UDP 443  -> Hysteria2"* ]]
  [[ "$(cat "${output_dir}/protocol-layout.txt")" == *"TCP 8443 -> Xray -> Trojan TLS"* ]]
  [[ "$(cat "${output_dir}/security-notes.en.md")" == *"Do not share the full Trojan URI publicly."* ]]
  [[ "$(cat "${output_dir}/qa-report.txt")" == *"VPSKIT_QA_VERSION=v0.6.3-beta"* ]]
  [[ "$(cat "${output_dir}/trojan-redacted.uri")" == *"REDACTED"* ]]
  [[ "$(cat "${output_dir}/trojan-redacted.uri")" != *"test-password"* ]]
  assert_file_ends_with_single_newline "${output_dir}/README.en.md"
  assert_file_ends_with_single_newline "${output_dir}/qa-report.txt"
  assert_file_ends_with_single_newline "${output_dir}/trojan-redacted.uri"
}

@test "demo package refuses non-empty directories without force" {
  prepare_qa_demo_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/vpskit-demo-package"
  mkdir -p "${output_dir}"
  printf 'sentinel\n' >"${output_dir}/keep.txt"

  run bash "${CLI_PATH}" demo package --redact --output "${output_dir}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"DEMO_PACKAGE=fail reason=output_directory_not_empty output=${output_dir}"* ]]
}

@test "demo package --force updates a non-empty directory" {
  prepare_qa_demo_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/vpskit-demo-package"
  mkdir -p "${output_dir}"
  printf 'sentinel\n' >"${output_dir}/keep.txt"

  run bash "${CLI_PATH}" demo package --redact --force --output "${output_dir}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"DEMO_PACKAGE=pass output=${output_dir} redacted=yes"* ]]
  [ -f "${output_dir}/keep.txt" ]
  [ -f "${output_dir}/qa-report.txt" ]
}

@test "demo package rejects unknown subcommands" {
  run bash "${CLI_PATH}" demo unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown demo command: unknown"* ]]
}
