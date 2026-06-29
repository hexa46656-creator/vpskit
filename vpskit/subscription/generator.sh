#!/usr/bin/env bash
set -euo pipefail

VPSKIT_SUBSCRIPTION_GENERATOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_SUBSCRIPTION_GENERATOR_DIR}/../core/public_surface.sh"
# shellcheck disable=SC1091
source "${VPSKIT_SUBSCRIPTION_GENERATOR_DIR}/../core/state_engine.sh"
# shellcheck disable=SC1091
source "${VPSKIT_SUBSCRIPTION_GENERATOR_DIR}/../core/secret_engine.sh"

vpskit_subscription_generator_root() {
  printf '%s\n' "${VPSKIT_SUBSCRIPTION_OUTPUT_ROOT:-/root/vpskit}"
}

vpskit_subscription_generator_write_root_file() {
  local target_path="$1"
  local mode="$2"
  local content="$3"
  local tmp_file

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-subscription.XXXXXX")"
  printf '%s\n' "${content}" > "${tmp_file}"
  vpskit_run_root install -d -m 0755 "$(dirname "${target_path}")"
  vpskit_run_root install -m "${mode}" "${tmp_file}" "${target_path}"
  rm -f "${tmp_file}"
}

vpskit_subscription_generator_state_value() {
  local key="$1"
  local secret_name="${2:-}"
  local value=""

  if [[ -n "${secret_name}" ]]; then
    value="$(vpskit_secret_get "${secret_name}" 2>/dev/null || true)"
    if [[ -n "${value}" ]]; then
      printf '%s\n' "${value}"
      return 0
    fi
  fi

  vpskit_state_get "${key}"
}

vpskit_subscription_generator_primary_uri() {
  local vpn_stack server_ip server_name xray_uuid xray_public_key xray_short_id trojan_password hysteria2_password

  vpn_stack="$(vpskit_subscription_generator_state_value vpn_stack)"
  server_ip="$(vpskit_subscription_generator_state_value server_ip)"
  server_name="$(vpskit_subscription_generator_state_value server_name)"
  xray_uuid="$(vpskit_subscription_generator_state_value xray_uuid)"
  xray_public_key="$(vpskit_subscription_generator_state_value xray_public_key xray_public_key)"
  xray_short_id="$(vpskit_subscription_generator_state_value xray_short_id)"
  trojan_password="$(vpskit_subscription_generator_state_value trojan_password trojan_password)"
  hysteria2_password="$(vpskit_subscription_generator_state_value hysteria2_password hysteria2_password)"

  case "${vpn_stack}" in
    xray)
      printf 'vless://%s@%s:443?type=tcp&security=reality&encryption=none&flow=xtls-rprx-vision&pbk=%s&sid=%s&sni=www.cloudflare.com#VPSKit\n' \
        "${xray_uuid}" "${server_ip}" "${xray_public_key}" "${xray_short_id}"
      ;;
    trojan)
      printf 'trojan://%s@%s:8443?security=tls&sni=%s#VPSKit\n' \
        "${trojan_password}" "${server_ip}" "${server_name}"
      ;;
    hysteria2)
      printf 'hysteria2://%s@%s:443?insecure=0&sni=%s#VPSKit\n' \
        "${hysteria2_password}" "${server_ip}" "${server_name}"
      ;;
    *)
      vpskit_die "unsupported VPN stack mode: ${vpn_stack}"
      return 1
      ;;
  esac
}

vpskit_subscription_generator_write_shadowrocket() {
  local output_path="$1"
  local uri="$2"
  local content

  content="$(cat <<EOF
# Shadowrocket
${uri}
EOF
)"

  vpskit_subscription_generator_write_root_file "${output_path}" 644 "${content}"
}

vpskit_subscription_generator_write_v2rayng() {
  local output_path="$1"
  local uri="$2"
  local tmp_file

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-v2rayng.XXXXXX")"
  python3 - "${tmp_file}" "${uri}" <<'PY'
from pathlib import Path
import json
import sys

output = Path(sys.argv[1])
uri = sys.argv[2]

data = {
    "profiles": [
        {
            "name": "VPSKit",
            "uri": uri,
        }
    ]
}

output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
  vpskit_run_root install -d -m 0755 "$(dirname "${output_path}")"
  vpskit_run_root install -m 644 "${tmp_file}" "${output_path}"
  rm -f "${tmp_file}"
}

vpskit_subscription_generator_write_clash() {
  local output_path="$1"
  local uri="$2"
  local server_ip xray_uuid xray_public_key xray_short_id
  local content

  server_ip="$(vpskit_subscription_generator_state_value server_ip)"
  xray_uuid="$(vpskit_subscription_generator_state_value xray_uuid)"
  xray_public_key="$(vpskit_subscription_generator_state_value xray_public_key xray_public_key)"
  xray_short_id="$(vpskit_subscription_generator_state_value xray_short_id)"

  content="$(cat <<EOF
proxies:
  - name: VPSKit
    type: vless
    server: ${server_ip}
    port: 443
    uuid: ${xray_uuid}
    network: tcp
    tls: true
    servername: www.cloudflare.com
    reality-opts:
      public-key: ${xray_public_key}
      short-id: ${xray_short_id}
      spider-x: /
    client-fingerprint: chrome
    udp: true
    uri: ${uri}
EOF
)"

  vpskit_subscription_generator_write_root_file "${output_path}" 644 "${content}"
}

vpskit_generate_subscription() {
  local output_root subscription_dir sub_file shadowrocket_file v2rayng_file clash_file uri

  vpskit_state_load || {
    vpskit_die "missing VPN state"
    return 1
  }

  output_root="$(vpskit_subscription_generator_root)"
  subscription_dir="${output_root}/subscriptions"
  sub_file="${output_root}/sub.txt"
  shadowrocket_file="${subscription_dir}/shadowrocket.conf"
  v2rayng_file="${subscription_dir}/v2rayng.json"
  clash_file="${subscription_dir}/clash.yaml"
  uri="$(vpskit_subscription_generator_primary_uri)"

  vpskit_run_root install -d -m 0755 "${subscription_dir}"

  vpskit_subscription_generator_write_root_file "${sub_file}" 600 "$(cat <<EOF
${uri}
EOF
)"
  vpskit_subscription_generator_write_shadowrocket "${shadowrocket_file}" "${uri}"
  vpskit_subscription_generator_write_v2rayng "${v2rayng_file}" "${uri}"
  vpskit_subscription_generator_write_clash "${clash_file}" "${uri}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_generate_subscription "$@"
fi
