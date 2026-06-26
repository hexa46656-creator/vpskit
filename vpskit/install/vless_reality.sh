#!/usr/bin/env bash

vpskit_vless_xray_port() {
  printf '%s\n' "${VPSKIT_XRAY_PORT:-443}"
}

vpskit_vless_server_name() {
  printf '%s\n' "${VPSKIT_REALITY_SERVER_NAME:-www.cloudflare.com}"
}

vpskit_vless_dest() {
  printf '%s\n' "${VPSKIT_REALITY_DEST:-www.cloudflare.com:443}"
}

vpskit_vless_config_path() {
  printf '%s\n' "${VPSKIT_XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}"
}

vpskit_vless_subscription_file() {
  if [ -n "${VPSKIT_SUBSCRIPTION_FILE:-}" ]; then
    printf '%s\n' "${VPSKIT_SUBSCRIPTION_FILE}"
    return 0
  fi

  printf '%s/vless-reality.txt\n' "${VPSKIT_SUBSCRIPTION_DIR:-/var/lib/vpskit}"
}

vpskit_vless_xray_bin() {
  if [ -n "${VPSKIT_TEST_XRAY_BIN:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_XRAY_BIN}"
    return 0
  fi

  if command -v xray >/dev/null 2>&1; then
    command -v xray
    return 0
  fi

  if [ -x /usr/local/bin/xray ]; then
    printf '%s\n' "/usr/local/bin/xray"
    return 0
  fi

  return 1
}

vpskit_install_or_prepare_xray() {
  local installer_url="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
  local tmp_installer=""

  if vpskit_vless_xray_bin >/dev/null 2>&1; then
    return 0
  fi

  if vpskit_is_dry_run || [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
    vpskit_run_mutation curl -fsSL -o /tmp/vpskit-xray-install.sh "${installer_url}" || return 1
    vpskit_run_mutation bash /tmp/vpskit-xray-install.sh install || return 1
    return 0
  fi

  tmp_installer="$(mktemp)"
  if ! curl -fsSL -o "${tmp_installer}" "${installer_url}"; then
    rm -f "${tmp_installer}"
    return 1
  fi
  if ! bash "${tmp_installer}" install; then
    rm -f "${tmp_installer}"
    return 1
  fi
  rm -f "${tmp_installer}"
  vpskit_vless_xray_bin >/dev/null 2>&1 || vpskit_die "xray binary is not available after install"
}

vpskit_generate_uuid() {
  local xray_bin="$1"

  if [ -n "${VPSKIT_TEST_UUID:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_UUID}"
    return 0
  fi

  "${xray_bin}" uuid
}

vpskit_generate_x25519_output() {
  local xray_bin="$1"

  if [ -n "${VPSKIT_TEST_X25519_OUTPUT:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_X25519_OUTPUT}"
    return 0
  fi

  "${xray_bin}" x25519
}

vpskit_parse_reality_private_key() {
  awk -F': ' '
    /^PrivateKey:/ {print $2}
    /^Private key:/ {print $2}
    /^Private Key:/ {print $2}
  ' | head -n1
}

vpskit_parse_reality_public_key() {
  awk -F': ' '
    /^Password \(PublicKey\):/ {print $2}
    /^PublicKey:/ {print $2}
    /^Public key:/ {print $2}
    /^Public Key:/ {print $2}
  ' | head -n1
}

vpskit_generate_short_id() {
  if [ -n "${VPSKIT_TEST_SHORT_ID:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_SHORT_ID}"
    return 0
  fi

  openssl rand -hex 8
}

vpskit_detect_public_ip() {
  if [ -n "${VPSKIT_TEST_PUBLIC_IP:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_PUBLIC_IP}"
    return 0
  fi

  curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

vpskit_url_encode_label() {
  printf '%s\n' "$1" | sed 's/ /%20/g'
}

vpskit_render_vless_uri() {
  local uuid="$1"
  local public_ip="$2"
  local port="$3"
  local server_name="$4"
  local public_key="$5"
  local short_id="$6"
  local label

  label="$(vpskit_url_encode_label "${VPSKIT_CLIENT_NAME:-VPSKit-Reality}")"
  printf 'vless://%s@%s:%s?encryption=none&security=reality&sni=%s&fp=chrome&pbk=%s&sid=%s&type=tcp&flow=xtls-rprx-vision#%s\n' \
    "${uuid}" "${public_ip}" "${port}" "${server_name}" "${public_key}" "${short_id}" "${label}"
}

vpskit_render_xray_config() {
  local port="$1"
  local uuid="$2"
  local private_key="$3"
  local short_id="$4"
  local server_name="$5"
  local dest="$6"
  local install_dir
  local module_root
  local template_path

  install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  module_root="$(cd "${install_dir}/.." && pwd)"
  template_path="${VPSKIT_XRAY_TEMPLATE_PATH:-${VPSKIT_ROOT:-${module_root}}/templates/xray-vless-reality.json.tpl}"

  sed \
    -e "s|__XRAY_PORT__|${port}|g" \
    -e "s|__UUID__|${uuid}|g" \
    -e "s|__PRIVATE_KEY__|${private_key}|g" \
    -e "s|__SHORT_ID__|${short_id}|g" \
    -e "s|__REALITY_SERVER_NAME__|${server_name}|g" \
    -e "s|__REALITY_DEST__|${dest}|g" \
    "${template_path}"
}

vpskit_install_vless_reality() {
  local port
  local server_name
  local dest
  local xray_bin
  local uuid
  local key_output
  local private_key
  local public_key
  local short_id
  local public_ip
  local config
  local uri
  local status=0

  vpskit_require_root || return 1
  vpskit_require_ubuntu_2404 || return 1
  port="$(vpskit_vless_xray_port)"
  vpskit_check_tcp_port_available "${port}" || return 1

  vpskit_transaction_init
  vpskit_install_or_prepare_xray || status=$?
  if [ "${status}" -eq 0 ]; then
    xray_bin="$(vpskit_vless_xray_bin)" || status=$?
  fi
  if [ "${status}" -eq 0 ]; then
    uuid="$(vpskit_generate_uuid "${xray_bin}")" || status=$?
    key_output="$(vpskit_generate_x25519_output "${xray_bin}")" || status=$?
    private_key="$(printf '%s\n' "${key_output}" | vpskit_parse_reality_private_key)"
    public_key="$(printf '%s\n' "${key_output}" | vpskit_parse_reality_public_key)"
    short_id="$(vpskit_generate_short_id)" || status=$?
    public_ip="$(vpskit_detect_public_ip)" || status=$?
  fi

  if [ "${status}" -eq 0 ] && { [ -z "${uuid}" ] || [ -z "${private_key}" ] || [ -z "${public_key}" ] || [ -z "${short_id}" ] || [ -z "${public_ip}" ]; }; then
    vpskit_die "failed to generate VLESS Reality values"
    status=1
  fi

  if [ "${status}" -eq 0 ]; then
    server_name="$(vpskit_vless_server_name)"
    dest="$(vpskit_vless_dest)"
    config="$(vpskit_render_xray_config "${port}" "${uuid}" "${private_key}" "${short_id}" "${server_name}" "${dest}")" || status=$?
    uri="$(vpskit_render_vless_uri "${uuid}" "${public_ip}" "${port}" "${server_name}" "${public_key}" "${short_id}")"
  fi

  if [ "${status}" -eq 0 ]; then
    vpskit_write_managed_file "$(vpskit_vless_config_path)" 0644 "${config}" || status=$?
    vpskit_write_managed_file "$(vpskit_vless_subscription_file)" 0600 "${uri}" || status=$?
  fi

  if [ "${status}" -eq 0 ] && [ "${VPSKIT_TEST_FAIL_AFTER_CONFIG:-0}" = "1" ]; then
    vpskit_die "simulated failure after config write"
    status=1
  fi

  if [ "${status}" -eq 0 ]; then
    vpskit_run_mutation "${xray_bin}" run -test -config "$(vpskit_system_path "$(vpskit_vless_config_path)")" || status=$?
    vpskit_rollback_add "systemctl stop xray >/dev/null 2>&1 || true" || status=$?
    vpskit_rollback_add "systemctl disable xray >/dev/null 2>&1 || true" || status=$?
    vpskit_run_mutation systemctl daemon-reload || status=$?
    vpskit_run_mutation systemctl enable xray || status=$?
    vpskit_run_mutation systemctl restart xray || status=$?
    vpskit_run_mutation systemctl is-active --quiet xray || status=$?
  fi

  if [ "${status}" -ne 0 ]; then
    vpskit_transaction_abort
    return "${status}"
  fi

  vpskit_transaction_commit
  printf 'VLESS_REALITY_URI=%s\n' "${uri}"
  printf 'SUBSCRIPTION_FILE=%s\n' "$(vpskit_vless_subscription_file)"
}
