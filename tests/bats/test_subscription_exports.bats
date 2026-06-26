# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_subscription_file() {
  prepare_subscription_file_with_uri \
    'vless://11111111-1111-4111-8111-111111111111@154.26.184.229:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality'
}

prepare_subscription_file_with_uri() {
  local uri="$1"

  export VPSKIT_SUBSCRIPTION_DIR="${BATS_TEST_TMPDIR}/vpskit"
  mkdir -p "${VPSKIT_SUBSCRIPTION_DIR}"
  export VPSKIT_SUBSCRIPTION_FILE="${VPSKIT_SUBSCRIPTION_DIR}/vless-reality.txt"
  printf '%s\n' "${uri}" >"${VPSKIT_SUBSCRIPTION_FILE}"
}

prepare_hysteria2_subscription_file() {
  export VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE="${BATS_TEST_TMPDIR}/hysteria2.yaml"
  cat >"${VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE}" <<'EOF'
server: 203.0.113.10:443
auth: test-password
tls:
  sni: 203.0.113.10
  pinSHA256: test-pin
EOF
}

prepare_trojan_subscription_file() {
  export VPSKIT_TROJAN_SUBSCRIPTION_FILE="${BATS_TEST_TMPDIR}/trojan.yaml"
  cat >"${VPSKIT_TROJAN_SUBSCRIPTION_FILE}" <<'EOF'
server: 203.0.113.10
port: 8443
password: trojan-password
sni: 203.0.113.10
allowInsecure: 1
EOF
}

prepare_trojan_subscription_file_with_values() {
  local server="$1"
  local password="$2"
  local sni="$3"
  local allow_insecure="${4:-1}"

  export VPSKIT_TROJAN_SUBSCRIPTION_FILE="${BATS_TEST_TMPDIR}/trojan-custom.yaml"
  cat >"${VPSKIT_TROJAN_SUBSCRIPTION_FILE}" <<EOF
server: ${server}
port: 8443
password: ${password}
sni: ${sni}
allowInsecure: ${allow_insecure}
EOF
}

test_subscription_uri="vless://11111111-1111-4111-8111-111111111111@154.26.184.229:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality"

assert_file_ends_with_single_newline() {
  python3 - "$1" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert data.endswith(b"\n"), "missing trailing newline"
assert not data.endswith(b"\n\n"), "found extra trailing newline"
PY
}

@test "sub help lists export commands" {
  run bash "${CLI_PATH}" sub help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit sub show"* ]]
  [[ "$output" == *"vpskit sub formats"* ]]
  [[ "$output" == *"vpskit sub export <format>"* ]]
  [[ "$output" == *"vpskit sub export <format> --output <path>"* ]]
  [[ "$output" == *"vpskit sub export hysteria2"* ]]
  [[ "$output" == *"vpskit sub validate"* ]]
}

@test "sub formats prints supported formats line" {
  run bash "${CLI_PATH}" sub formats

  [ "$status" -eq 0 ]
  [ "$output" = "SUPPORTED_SUB_FORMATS=raw,base64,shadowrocket,v2rayng,clash-meta,sing-box,hysteria2,trojan" ]
}

@test "sub export raw returns the stored uri" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export raw

  [ "$status" -eq 0 ]
  [ "$output" = "${test_subscription_uri}" ]
}

@test "sub export shadowrocket returns the stored uri" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export shadowrocket

  [ "$status" -eq 0 ]
  [ "$output" = "${test_subscription_uri}" ]
}

@test "sub export v2rayng returns the stored uri" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export v2rayng

  [ "$status" -eq 0 ]
  [ "$output" = "${test_subscription_uri}" ]
}

@test "sub export base64 returns the encoded uri" {
  prepare_subscription_file
  local expected_base64
  expected_base64="$(python3 -c 'import base64,sys; print(base64.b64encode(sys.argv[1].encode()).decode())' "${test_subscription_uri}")"

  run bash "${CLI_PATH}" sub export base64

  [ "$status" -eq 0 ]
  [ "$output" = "${expected_base64}" ]
}

@test "sub export raw --output writes file and prints status only" {
  prepare_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/raw.txt"

  run bash "${CLI_PATH}" sub export raw --output "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=raw output=${output_file}" ]
  [ "$(tr -d '\n' < "${output_file}")" = "${test_subscription_uri}" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export base64 --output writes file and prints status only" {
  prepare_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/base64.txt"
  local expected_base64
  expected_base64="$(python3 -c 'import base64,sys; print(base64.b64encode(sys.argv[1].encode()).decode())' "${test_subscription_uri}")"

  run bash "${CLI_PATH}" sub export base64 --output "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=base64 output=${output_file}" ]
  [ "$(tr -d '\n' < "${output_file}")" = "${expected_base64}" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export clash-meta --output writes yaml file" {
  prepare_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/clash-meta.yaml"

  run bash "${CLI_PATH}" sub export clash-meta --output "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=clash-meta output=${output_file}" ]
  [[ "$(cat "${output_file}")" == *"proxies:"* ]]
  [[ "$(cat "${output_file}")" == *"client-fingerprint: chrome"* ]]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export sing-box --output writes json file" {
  prepare_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/sing-box.json"

  run bash "${CLI_PATH}" sub export sing-box --output "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=sing-box output=${output_file}" ]
  printf '%s' "$(cat "${output_file}")" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
outbound = data["outbounds"][0]

assert outbound["type"] == "vless"
assert outbound["tag"] == "VPSKit-Reality"
'
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export -o alias works" {
  prepare_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/alias.txt"

  run bash "${CLI_PATH}" sub export raw -o "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=raw output=${output_file}" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export fails clearly when output path is missing" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export raw --output

  [ "$status" -eq 1 ]
  [ "$output" = "SUB_EXPORT=fail reason=missing_output_path" ]
}

@test "sub export fails clearly when output parent directory is missing" {
  prepare_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/missing-dir/export.txt"

  run bash "${CLI_PATH}" sub export raw --output "${output_file}"

  [ "$status" -eq 1 ]
  [ "$output" = "SUB_EXPORT=fail format=raw reason=parent_directory_missing output=${output_file}" ]
}

@test "sub export fails clearly when output path is a directory" {
  prepare_subscription_file
  local output_dir="${BATS_TEST_TMPDIR}/export-dir"
  mkdir -p "${output_dir}"

  run bash "${CLI_PATH}" sub export raw --output "${output_dir}"

  [ "$status" -eq 1 ]
  [ "$output" = "SUB_EXPORT=fail format=raw reason=output_path_is_directory output=${output_dir}" ]
}

@test "sub export fails clearly for unsupported format" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export unknown

  [ "$status" -eq 1 ]
  [ "$output" = "SUB_EXPORT=fail reason=unsupported_format format=unknown" ]
}

@test "sub export clash-meta includes parsed reality fields" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export clash-meta

  [ "$status" -eq 0 ]
  [[ "$output" == *"name: VPSKit-Reality"* ]]
  [[ "$output" == *"server: 154.26.184.229"* ]]
  [[ "$output" == *"port: 443"* ]]
  [[ "$output" == *"uuid: 11111111-1111-4111-8111-111111111111"* ]]
  [[ "$output" == *"servername: www.cloudflare.com"* ]]
  [[ "$output" == *"client-fingerprint: chrome"* ]]
  [[ "$output" == *"public-key: public-test-key"* ]]
  [[ "$output" == *"short-id: abcdef1234567890"* ]]
  [[ "$output" == *"flow: xtls-rprx-vision"* ]]
}

@test "sub export sing-box returns valid json with parsed fields" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub export sing-box

  [ "$status" -eq 0 ]
  printf '%s' "$output" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
outbound = data["outbounds"][0]
tls = outbound["tls"]
utls = tls["utls"]
reality = tls["reality"]

assert outbound["type"] == "vless"
assert outbound["tag"] == "VPSKit-Reality"
assert outbound["server"] == "154.26.184.229"
assert outbound["server_port"] == 443
assert outbound["uuid"] == "11111111-1111-4111-8111-111111111111"
assert outbound["flow"] == "xtls-rprx-vision"
assert tls["enabled"] is True
assert tls["server_name"] == "www.cloudflare.com"
assert utls["enabled"] is True
assert utls["fingerprint"] == "chrome"
assert reality["enabled"] is True
assert reality["public_key"] == "public-test-key"
assert reality["short_id"] == "abcdef1234567890"
'
}

@test "sub export file-backed formats end with exactly one newline" {
  prepare_subscription_file

  for format in raw shadowrocket v2rayng; do
    local output_file="${BATS_TEST_TMPDIR}/${format}.txt"

    run bash -c 'bash "$1" sub export "$2" >"$3"' _ "${CLI_PATH}" "${format}" "${output_file}"

    [ "$status" -eq 0 ]
    assert_file_ends_with_single_newline "${output_file}"
  done
}

@test "sub export rendered formats end with exactly one newline" {
  prepare_subscription_file

  for format in base64 clash-meta sing-box; do
    local output_file="${BATS_TEST_TMPDIR}/${format}.txt"

    run bash -c 'bash "$1" sub export "$2" >"$3"' _ "${CLI_PATH}" "${format}" "${output_file}"

    [ "$status" -eq 0 ]
    assert_file_ends_with_single_newline "${output_file}"
  done
}

@test "sequential sub exports do not concatenate without separators" {
  prepare_subscription_file

  local output_file="${BATS_TEST_TMPDIR}/sequential.txt"

  run bash -c '
    set -euo pipefail
    bash "$1" sub export base64 >"$2"
    bash "$1" sub export clash-meta >>"$2"
    bash "$1" sub export sing-box >>"$2"
  ' _ "${CLI_PATH}" "${output_file}"

  [ "$status" -eq 0 ]
  assert_file_ends_with_single_newline "${output_file}"
  python3 - "${output_file}" <<'PY'
from pathlib import Path
import sys

data = Path(sys.argv[1]).read_bytes()
assert b"==vless://" not in data
assert b"rules:\n  - MATCH,PROXY{" not in data
PY
}

@test "sub export fails clearly when the subscription file is missing" {
  export VPSKIT_SUBSCRIPTION_FILE="${BATS_TEST_TMPDIR}/missing-vless-reality.txt"

  run bash "${CLI_PATH}" sub export raw

  [ "$status" -eq 1 ]
  [[ "$output" == *"subscription file not found"* ]]
}

@test "sub export fails clearly for malformed vless uri" {
  export VPSKIT_SUBSCRIPTION_DIR="${BATS_TEST_TMPDIR}/vpskit"
  mkdir -p "${VPSKIT_SUBSCRIPTION_DIR}"
  export VPSKIT_SUBSCRIPTION_FILE="${VPSKIT_SUBSCRIPTION_DIR}/vless-reality.txt"
  printf '%s\n' 'vless://example' >"${VPSKIT_SUBSCRIPTION_FILE}"

  run bash "${CLI_PATH}" sub export clash-meta

  [ "$status" -eq 1 ]
  [[ "$output" == *"malformed VLESS Reality URI"* ]]
}

@test "sub export hysteria2 returns the stored yaml config" {
  prepare_hysteria2_subscription_file

  run bash "${CLI_PATH}" sub export hysteria2

  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "${VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE}")" ]
  [[ "$output" == *"server: 203.0.113.10:443"* ]]
  [[ "$output" == *"auth: test-password"* ]]
  [[ "$output" == *"pinSHA256: test-pin"* ]]
}

@test "sub export hysteria2 --output writes file and prints status only" {
  prepare_hysteria2_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/hysteria2.yaml.out"

  run bash "${CLI_PATH}" sub export hysteria2 --output "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=hysteria2 output=${output_file}" ]
  cmp -s "${output_file}" "${VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE}"
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export hysteria2 -o alias works" {
  prepare_hysteria2_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/hysteria2-alias.yaml"

  run bash "${CLI_PATH}" sub export hysteria2 -o "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=hysteria2 output=${output_file}" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export hysteria2 stdout ends with exactly one newline" {
  prepare_hysteria2_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/hysteria2-stdout.yaml"

  run bash -c 'bash "$1" sub export hysteria2 >"$2"' _ "${CLI_PATH}" "${output_file}"

  [ "$status" -eq 0 ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export hysteria2 fails clearly when the subscription file is missing" {
  export VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE="${BATS_TEST_TMPDIR}/missing-hysteria2.yaml"

  run bash "${CLI_PATH}" sub export hysteria2

  [ "$status" -eq 1 ]
  [ "$output" = "SUB_EXPORT=fail format=hysteria2 reason=missing_subscription_file" ]
}

@test "sub export trojan returns the stored trojan uri" {
  prepare_trojan_subscription_file

  run bash "${CLI_PATH}" sub export trojan

  [ "$status" -eq 0 ]
  [ "$output" = "trojan://trojan-password@203.0.113.10:8443?sni=203.0.113.10&allowInsecure=1#VPSKit-Trojan" ]
}

@test "sub export trojan stdout ends with exactly one newline" {
  prepare_trojan_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/trojan-stdout.txt"

  run bash -c 'bash "$1" sub export trojan >"$2"' _ "${CLI_PATH}" "${output_file}"

  [ "$status" -eq 0 ]
  [ "$(tr -d '\n' < "${output_file}")" = "trojan://trojan-password@203.0.113.10:8443?sni=203.0.113.10&allowInsecure=1#VPSKit-Trojan" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export trojan --output writes file and prints status only" {
  prepare_trojan_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/trojan.txt"

  run bash "${CLI_PATH}" sub export trojan --output "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=trojan output=${output_file}" ]
  [ "$(tr -d '\n' < "${output_file}")" = "trojan://trojan-password@203.0.113.10:8443?sni=203.0.113.10&allowInsecure=1#VPSKit-Trojan" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export trojan -o alias works" {
  prepare_trojan_subscription_file
  local output_file="${BATS_TEST_TMPDIR}/trojan-alias.txt"

  run bash "${CLI_PATH}" sub export trojan -o "${output_file}"

  [ "$status" -eq 0 ]
  [ "$output" = "SUB_EXPORT=pass format=trojan output=${output_file}" ]
  [ "$(tr -d '\n' < "${output_file}")" = "trojan://trojan-password@203.0.113.10:8443?sni=203.0.113.10&allowInsecure=1#VPSKit-Trojan" ]
  assert_file_ends_with_single_newline "${output_file}"
}

@test "sub export trojan fails clearly when the subscription file is missing" {
  export VPSKIT_TROJAN_SUBSCRIPTION_FILE="${BATS_TEST_TMPDIR}/missing-trojan.yaml"

  run bash "${CLI_PATH}" sub export trojan

  [ "$status" -eq 1 ]
  [ "$output" = "SUB_EXPORT=fail format=trojan reason=missing_subscription_file" ]
}

@test "sub export trojan encodes special characters and ipv6 server values" {
  prepare_trojan_subscription_file_with_values \
    '2001:db8::1' \
    'p@ss word/!' \
    'sni.example.com/needs encoding?and=yes'

  local expected_uri
  expected_uri="$(
    python3 - <<'PY'
from urllib.parse import quote

server = "2001:db8::1"
password = "p@ss word/!"
sni = "sni.example.com/needs encoding?and=yes"

if ":" in server and not server.startswith("["):
    server = f"[{server}]"

print(
    f"trojan://{quote(password, safe='')}@{quote(server, safe='[]:.')}:8443?sni={quote(sni, safe='')}&allowInsecure=1#VPSKit-Trojan"
)
PY
  )"

  run bash "${CLI_PATH}" sub export trojan

  [ "$status" -eq 0 ]
  [ "$output" = "${expected_uri}" ]
  [[ "$output" == *"@[2001:db8::1]:8443?"* ]]
  [[ "$output" == *"allowInsecure=1#VPSKit-Trojan" ]]
}

@test "sub validate passes with valid vless reality uri" {
  prepare_subscription_file

  run bash "${CLI_PATH}" sub validate

  [ "$status" -eq 0 ]
  [[ "$output" == *"SUB_URI=pass scheme=vless"* ]]
  [[ "$output" == *"SUB_UUID=pass"* ]]
  [[ "$output" == *"SUB_SERVER=pass value=154.26.184.229"* ]]
  [[ "$output" == *"SUB_PORT=pass value=443"* ]]
  [[ "$output" == *"SUB_SECURITY=pass value=reality"* ]]
  [[ "$output" == *"SUB_SNI=pass value=www.cloudflare.com"* ]]
  [[ "$output" == *"SUB_FP=pass value=chrome"* ]]
  [[ "$output" == *"SUB_PBK=pass"* ]]
  [[ "$output" == *"SUB_SID=pass"* ]]
  [[ "$output" == *"SUB_TYPE=pass value=tcp"* ]]
  [[ "$output" == *"SUB_FLOW=pass value=xtls-rprx-vision"* ]]
  [[ "$output" == *"SUB_VALIDATE=pass"* ]]
}

@test "sub validate fails clearly for missing pbk" {
  prepare_subscription_file_with_uri \
    'vless://11111111-1111-4111-8111-111111111111@154.26.184.229:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality'

  run bash "${CLI_PATH}" sub validate

  [ "$status" -eq 1 ]
  [[ "$output" == *"SUB_PBK=fail reason=missing"* ]]
  [[ "$output" == *"SUB_VALIDATE=fail"* ]]
}

@test "sub validate fails clearly for non-vless uri" {
  prepare_subscription_file_with_uri \
    'http://example.com:443?security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision'

  run bash "${CLI_PATH}" sub validate

  [ "$status" -eq 1 ]
  [[ "$output" == *"SUB_URI=fail reason=unsupported_scheme value=http"* ]]
  [[ "$output" == *"SUB_VALIDATE=fail"* ]]
}

@test "sub validate fails clearly for non-numeric port" {
  prepare_subscription_file_with_uri \
    'vless://11111111-1111-4111-8111-111111111111@example.com:not-a-port?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality'

  run bash "${CLI_PATH}" sub validate

  [ "$status" -eq 1 ]
  [[ "$output" == *"SUB_PORT=fail reason=non_numeric value=not-a-port"* ]]
  [[ "$output" == *"SUB_VALIDATE=fail"* ]]
}
