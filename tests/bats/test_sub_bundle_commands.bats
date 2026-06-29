# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_bundle_rootfs() {
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
  export VPSKIT_BUNDLE_GENERATED_AT="2026-06-26T00:00:00Z"
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

@test "sub bundle help lists bundle options" {
  run bash "${CLI_PATH}" sub bundle --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit sub bundle --redact"* ]]
  [[ "$output" == *"vpskit sub bundle --force --output <dir>"* ]]
}

@test "sub bundle creates the default redacted bundle" {
  prepare_bundle_rootfs

  run bash -c 'cd "$1" && bash "$2" sub bundle' _ "${BATS_TEST_TMPDIR}" "${CLI_PATH}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"SUB_BUNDLE=pass output=./vpskit-bundle redacted=yes"* ]]
  [[ "$output" == *"SUB_BUNDLE_FILES=23"* ]]
  [[ "$output" == *"SENSITIVE_OUTPUT=redacted"* ]]
  [[ "$output" != *"test-password"* ]]
  [ -d "${BATS_TEST_TMPDIR}/vpskit-bundle" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/README.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/README.zh.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/protocol-layout.txt" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/security-notes.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/security-notes.zh.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-shadowrocket.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-shadowrocket.zh.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-v2rayng.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-v2rayng.zh.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-clash-meta.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-clash-meta.zh.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-sing-box.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/import-sing-box.zh.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/qa-summary.txt" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/command-checklist.txt" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/vless-reality.txt" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/hysteria2.yaml" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/trojan-redacted.uri" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/clash-meta.yaml" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/sing-box.json" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/troubleshooting/common-issues.en.md" ]
  [ -f "${BATS_TEST_TMPDIR}/vpskit-bundle/troubleshooting/common-issues.zh.md" ]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"VPSKIT_BUNDLE_VERSION=v0.7.0-beta"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"BUNDLE_MODE=redacted"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"VLESS_REALITY=present"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"HYSTERIA2=present"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"TROJAN=present"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"CLASH_META=present"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"SING_BOX=present"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt")" == *"SENSITIVE_OUTPUT=redacted"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/protocol-layout.txt")" == *"TCP 443  -> Xray -> VLESS Reality"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/protocol-layout.txt")" == *"UDP 443  -> Hysteria2"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/protocol-layout.txt")" == *"TCP 8443 -> Xray -> Trojan TLS"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/qa-summary.txt")" == *"VPSKIT_QA=pass"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/qa-summary.txt")" == *"VPSKIT_QA_VERSION=v0.7.0-beta"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/trojan-redacted.uri")" == *"REDACTED"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/trojan-redacted.uri")" != *"test-password"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/clash-meta.yaml")" == *"proxies:"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/sing-box.json")" == *"\"outbounds\""* ]]
  run bash -c 'find "$1" -type f \( -name "server.key" -o -name "*.env" \) | grep -q .' _ "${BATS_TEST_TMPDIR}/vpskit-bundle"
  [ "$status" -eq 1 ]
  assert_file_ends_with_single_newline "${BATS_TEST_TMPDIR}/vpskit-bundle/manifest.txt"
  assert_file_ends_with_single_newline "${BATS_TEST_TMPDIR}/vpskit-bundle/qa-summary.txt"
  assert_file_ends_with_single_newline "${BATS_TEST_TMPDIR}/vpskit-bundle/subscriptions/trojan-redacted.uri"
}

@test "sub bundle --output writes to the requested directory" {
  prepare_bundle_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/bundle-out"

  run bash "${CLI_PATH}" sub bundle --output "${output_dir}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"SUB_BUNDLE=pass output=${output_dir} redacted=yes"* ]]
  [ -d "${output_dir}" ]
}

@test "sub bundle --redact --output writes a redacted bundle" {
  prepare_bundle_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/bundle-redacted"

  run bash "${CLI_PATH}" sub bundle --redact --output "${output_dir}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"SUB_BUNDLE=pass output=${output_dir} redacted=yes"* ]]
  [[ "$output" == *"SENSITIVE_OUTPUT=redacted"* ]]
  [[ "$output" != *"test-password"* ]]
  [[ "$(cat "${output_dir}/subscriptions/trojan-redacted.uri")" == *"REDACTED"* ]]
  [[ "$(cat "${output_dir}/manifest.txt")" == *"VPSKIT_BUNDLE_VERSION=v0.7.0-beta"* ]]
}

@test "sub bundle refuses non-empty output directories without force" {
  prepare_bundle_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/bundle-existing"
  mkdir -p "${output_dir}"
  printf 'sentinel\n' >"${output_dir}/keep.txt"

  run bash "${CLI_PATH}" sub bundle --output "${output_dir}"

  [ "$status" -eq 1 ]
  [[ "$output" == *"SUB_BUNDLE=fail reason=output_directory_not_empty output=${output_dir}"* ]]
}

@test "sub bundle --force overwrites non-empty output directories" {
  prepare_bundle_rootfs
  local output_dir="${BATS_TEST_TMPDIR}/bundle-force"
  mkdir -p "${output_dir}"
  printf 'sentinel\n' >"${output_dir}/keep.txt"

  run bash "${CLI_PATH}" sub bundle --force --output "${output_dir}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"SUB_BUNDLE=pass output=${output_dir} redacted=yes"* ]]
  [ ! -f "${output_dir}/keep.txt" ]
  [ -f "${output_dir}/manifest.txt" ]
}

@test "sub bundle rejects unknown flags" {
  run bash "${CLI_PATH}" sub bundle --bogus

  [ "$status" -eq 1 ]
  [[ "$output" == *"SUB_BUNDLE=fail reason=unexpected_argument value=--bogus"* ]]
}

@test "sub unknown still fails" {
  run bash "${CLI_PATH}" sub unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown sub command: unknown"* ]]
}
