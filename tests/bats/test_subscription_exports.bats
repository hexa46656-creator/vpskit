# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_subscription_file() {
  export VPSKIT_SUBSCRIPTION_DIR="${BATS_TEST_TMPDIR}/vpskit"
  mkdir -p "${VPSKIT_SUBSCRIPTION_DIR}"
  export VPSKIT_SUBSCRIPTION_FILE="${VPSKIT_SUBSCRIPTION_DIR}/vless-reality.txt"
  printf '%s\n' \
    'vless://11111111-1111-4111-8111-111111111111@154.26.184.229:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality' \
    >"${VPSKIT_SUBSCRIPTION_FILE}"
}

test_subscription_uri="vless://11111111-1111-4111-8111-111111111111@154.26.184.229:443?encryption=none&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=public-test-key&sid=abcdef1234567890&type=tcp&flow=xtls-rprx-vision#VPSKit-Reality"

@test "sub help lists export commands" {
  run bash "${CLI_PATH}" sub help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit sub show"* ]]
  [[ "$output" == *"vpskit sub formats"* ]]
  [[ "$output" == *"vpskit sub export <format>"* ]]
}

@test "sub formats prints supported formats line" {
  run bash "${CLI_PATH}" sub formats

  [ "$status" -eq 0 ]
  [ "$output" = "SUPPORTED_SUB_FORMATS=raw,base64,shadowrocket,v2rayng,clash-meta,sing-box" ]
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
