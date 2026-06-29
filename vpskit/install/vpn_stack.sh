#!/usr/bin/env bash
set -euo pipefail

VPSKIT_VPN_STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_VPN_STACK_DIR}/../core/public_surface.sh"
# shellcheck disable=SC1091
source "${VPSKIT_VPN_STACK_DIR}/../core/state_engine.sh"
# shellcheck disable=SC1091
source "${VPSKIT_VPN_STACK_DIR}/../core/secret_engine.sh"

vpskit_vpn_stack_subscription_root() {
  printf '%s\n' "${VPSKIT_SUBSCRIPTION_OUTPUT_ROOT:-/root/vpskit}"
}

vpskit_vpn_stack_require_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "VPN stack installation requires root or passwordless sudo"
}

vpskit_vpn_stack_write_root_file() {
  local target_path="$1"
  local mode="$2"
  local content="$3"
  local tmp_file

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-vpn.XXXXXX")"

  printf '%s\n' "${content}" > "${tmp_file}"
  vpskit_run_root install -d -m 0755 "$(dirname "${target_path}")"
  vpskit_run_root install -m "${mode}" "${tmp_file}" "${target_path}"
  rm -f "${tmp_file}"
}

vpskit_vpn_stack_download_verified() {
  local url="$1"
  local sha256="$2"
  local output_path="$3"
  local tmp_file

  if [[ -z "${url}" || -z "${sha256}" ]]; then
    vpskit_die "download URL and SHA256 are required"
    return 1
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-download.XXXXXX")"

  curl -fsSL -o "${tmp_file}" "${url}"
  printf '%s  %s\n' "${sha256}" "${tmp_file}" | sha256sum -c - >/dev/null
  vpskit_run_root install -d -m 0755 "$(dirname "${output_path}")"
  vpskit_run_root install -m 0755 "${tmp_file}" "${output_path}"
  rm -f "${tmp_file}"
}

vpskit_vpn_stack_xray_binary() {
  if command -v xray >/dev/null 2>&1; then
    command -v xray
    return 0
  fi

  if [[ -x /usr/local/bin/xray ]]; then
    printf '%s\n' /usr/local/bin/xray
    return 0
  fi

  return 1
}

vpskit_vpn_stack_hysteria_binary() {
  if command -v hysteria >/dev/null 2>&1; then
    command -v hysteria
    return 0
  fi

  if [[ -x /usr/local/bin/hysteria ]]; then
    printf '%s\n' /usr/local/bin/hysteria
    return 0
  fi

  return 1
}

vpskit_vpn_stack_ensure_xray() {
  if vpskit_vpn_stack_xray_binary >/dev/null 2>&1; then
    return 0
  fi

  vpskit_vpn_stack_download_verified \
    "${VPSKIT_XRAY_BINARY_URL:-}" \
    "${VPSKIT_XRAY_BINARY_SHA256:-}" \
    /usr/local/bin/xray
}

vpskit_vpn_stack_ensure_hysteria() {
  if vpskit_vpn_stack_hysteria_binary >/dev/null 2>&1; then
    return 0
  fi

  vpskit_vpn_stack_download_verified \
    "${VPSKIT_HYSTERIA_BINARY_URL:-}" \
    "${VPSKIT_HYSTERIA_BINARY_SHA256:-}" \
    /usr/local/bin/hysteria
}

vpskit_vpn_stack_state_value() {
  local key="$1"
  local default_value="${2:-}"
  local value=""

  value="$(vpskit_state_get "${key}" 2>/dev/null || true)"
  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
    return 0
  fi

  printf '%s\n' "${default_value}"
}

vpskit_vpn_stack_secret_or_state() {
  local secret_name="$1"
  local state_key="$2"
  local default_value="${3:-}"
  local value=""

  value="$(vpskit_secret_get "${secret_name}" 2>/dev/null || true)"
  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
    return 0
  fi

  value="$(vpskit_state_get "${state_key}" 2>/dev/null || true)"
  if [[ -n "${value}" ]]; then
    printf '%s\n' "${value}"
    return 0
  fi

  printf '%s\n' "${default_value}"
}

vpskit_vpn_stack_generate_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
    return 0
  fi

  cat /proc/sys/kernel/random/uuid
}

vpskit_vpn_stack_generate_short_id() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 4
    return 0
  fi

  printf 'a1b2c3d4\n'
}

vpskit_vpn_stack_generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
    return 0
  fi

  vpskit_vpn_stack_generate_uuid | tr -d '-'
}

vpskit_vpn_stack_host_name() {
  if [[ -n "${VPSKIT_SERVER_NAME:-}" ]]; then
    printf '%s\n' "${VPSKIT_SERVER_NAME}"
    return 0
  fi

  hostname -f 2>/dev/null || hostname
}

vpskit_vpn_stack_public_ip() {
  if [[ -n "${VPSKIT_SERVER_IP:-}" ]]; then
    printf '%s\n' "${VPSKIT_SERVER_IP}"
    return 0
  fi

  if [[ -n "${VPSKIT_PUBLIC_IPV4:-}" ]]; then
    printf '%s\n' "${VPSKIT_PUBLIC_IPV4}"
    return 0
  fi

  hostname -I 2>/dev/null | awk '{print $1}'
}

vpskit_vpn_stack_generate_xray_keys() {
  local xray_bin keypair private_key public_key

  xray_bin="$(vpskit_vpn_stack_xray_binary)" || {
    vpskit_die "xray binary is required before generating Reality keys"
    return 1
  }

  keypair="$("${xray_bin}" x25519 2>/dev/null || true)"
  private_key="$(printf '%s\n' "${keypair}" | awk '/Private key/ {print $3; exit}')"
  public_key="$(printf '%s\n' "${keypair}" | awk '/Public key/ {print $3; exit}')"

  if [[ -z "${private_key}" || -z "${public_key}" ]]; then
    vpskit_die "failed to generate Reality keypair"
    return 1
  fi

  printf '%s\n%s\n' "${private_key}" "${public_key}"
}

vpskit_vpn_stack_bootstrap_state() {
  local vpn_stack server_ip server_name xray_uuid xray_short_id xray_private_key xray_public_key
  local trojan_password hysteria2_password generated_keys

  vpn_stack="$(vpskit_vpn_stack_state_value vpn_stack "${VPSKIT_VPN_STACK:-xray}")"
  server_ip="$(vpskit_vpn_stack_state_value server_ip "$(vpskit_vpn_stack_public_ip)")"
  server_name="$(vpskit_vpn_stack_state_value server_name "$(vpskit_vpn_stack_host_name)")"
  xray_uuid="$(vpskit_vpn_stack_secret_or_state xray_uuid xray_uuid "$(vpskit_vpn_stack_generate_uuid)")"
  xray_short_id="$(vpskit_vpn_stack_secret_or_state xray_short_id xray_short_id "$(vpskit_vpn_stack_generate_short_id)")"
  xray_private_key="$(vpskit_vpn_stack_secret_or_state xray_private_key xray_private_key "")"
  xray_public_key="$(vpskit_vpn_stack_secret_or_state xray_public_key xray_public_key "")"
  trojan_password="$(vpskit_vpn_stack_secret_or_state trojan_password trojan_password "$(vpskit_vpn_stack_generate_password)")"
  hysteria2_password="$(vpskit_vpn_stack_secret_or_state hysteria2_password hysteria2_password "$(vpskit_vpn_stack_generate_password)")"

  if [[ -z "${server_ip}" || -z "${server_name}" ]]; then
    vpskit_die "server_ip and server_name are required"
    return 1
  fi

  if [[ "${vpn_stack}" = "xray" ]]; then
    if [[ -z "${xray_private_key}" || -z "${xray_public_key}" ]]; then
      generated_keys="$(vpskit_vpn_stack_generate_xray_keys)" || return 1
      xray_private_key="$(printf '%s\n' "${generated_keys}" | sed -n '1p')"
      xray_public_key="$(printf '%s\n' "${generated_keys}" | sed -n '2p')"
    fi
  fi

  vpskit_state_save \
    vpn_stack "${vpn_stack}" \
    server_ip "${server_ip}" \
    server_name "${server_name}" \
    xray_uuid "${xray_uuid}" \
    xray_short_id "${xray_short_id}" \
    xray_private_key "${xray_private_key}" \
    xray_public_key "${xray_public_key}" \
    trojan_password "${trojan_password}" \
    hysteria2_password "${hysteria2_password}"
}

vpskit_vpn_stack_ensure_tls_material() {
  local cert_path="$1"
  local key_path="$2"
  local cert_secret="$3"
  local key_secret="$4"
  local cert_content key_content

  cert_content="$(vpskit_secret_get "${cert_secret}" 2>/dev/null || true)"
  key_content="$(vpskit_secret_get "${key_secret}" 2>/dev/null || true)"

  if [[ -n "${cert_content}" && -n "${key_content}" ]]; then
    vpskit_vpn_stack_write_root_file "${cert_path}" 644 "${cert_content}"
    vpskit_vpn_stack_write_root_file "${key_path}" 600 "${key_content}"
    return 0
  fi

  if [[ -s "${cert_path}" && -s "${key_path}" ]]; then
    return 0
  fi

  vpskit_run_root install -d -m 0755 "$(dirname "${cert_path}")"
  vpskit_run_root openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout "${key_path}" \
    -out "${cert_path}" \
    -subj "/CN=$(vpskit_state_get server_name)" >/dev/null 2>&1
  vpskit_run_root chmod 600 "${key_path}"
  vpskit_run_root chmod 644 "${cert_path}"
}

vpskit_vpn_stack_validate_xray_config() {
  local config_path="$1"
  local xray_bin

  xray_bin="$(vpskit_vpn_stack_xray_binary)" || return 1
  vpskit_run_root "${xray_bin}" run -test -config "${config_path}" >/dev/null 2>&1
}

vpskit_vpn_stack_validate_hysteria_config() {
  local config_path="$1"
  local hysteria_bin

  hysteria_bin="$(vpskit_vpn_stack_hysteria_binary)" || return 1
  vpskit_run_root "${hysteria_bin}" server -c "${config_path}" --log-level error --dry-run >/dev/null 2>&1
}

install_xray() {
  local server_ip xray_uuid xray_short_id xray_private_key xray_public_key config_path config_content

  vpskit_state_load || {
    vpskit_die "missing VPN state"
    return 1
  }

  server_ip="$(vpskit_state_get server_ip)"
  xray_uuid="$(vpskit_state_get xray_uuid)"
  xray_short_id="$(vpskit_state_get xray_short_id)"
  xray_private_key="$(vpskit_vpn_stack_secret_or_state xray_private_key xray_private_key)"
  xray_public_key="$(vpskit_vpn_stack_secret_or_state xray_public_key xray_public_key)"
  config_path="$(vpskit_vless_config_path)"

  config_content="$(cat <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${xray_uuid}",
            "flow": "xtls-rprx-vision"
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
          "privateKey": "${xray_private_key}",
          "shortIds": [
            "${xray_short_id}"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
)"

  vpskit_vpn_stack_write_root_file "${config_path}" 644 "${config_content}"
  vpskit_vpn_stack_validate_xray_config "${config_path}" || {
    vpskit_die "xray config validation failed"
    return 1
  }
  vpskit_state_save xray_public_key "${xray_public_key}" server_ip "${server_ip}"
  vpskit_run_root systemctl enable --now xray.service
}

install_trojan() {
  local server_ip server_name trojan_password config_path config_content

  vpskit_state_load || {
    vpskit_die "missing VPN state"
    return 1
  }

  server_ip="$(vpskit_state_get server_ip)"
  server_name="$(vpskit_state_get server_name)"
  trojan_password="$(vpskit_vpn_stack_secret_or_state trojan_password trojan_password)"
  config_path="$(vpskit_trojan_config_path)"

  vpskit_vpn_stack_ensure_tls_material \
    "$(vpskit_trojan_cert_path)" \
    "$(vpskit_trojan_key_path)" \
    trojan_cert_pem \
    trojan_key_pem

  config_content="$(cat <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${trojan_password}"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "serverName": "${server_name}",
          "certificates": [
            {
              "certificateFile": "$(vpskit_trojan_cert_path)",
              "keyFile": "$(vpskit_trojan_key_path)"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
)"

  vpskit_vpn_stack_write_root_file "${config_path}" 644 "${config_content}"
  vpskit_vpn_stack_validate_xray_config "${config_path}" || {
    vpskit_die "trojan config validation failed"
    return 1
  }
  vpskit_state_save server_ip "${server_ip}" trojan_password "${trojan_password}"
  vpskit_run_root systemctl enable --now xray.service
}

install_hysteria2() {
  local server_name hysteria2_password config_path config_content

  vpskit_state_load || {
    vpskit_die "missing VPN state"
    return 1
  }

  server_name="$(vpskit_state_get server_name)"
  hysteria2_password="$(vpskit_vpn_stack_secret_or_state hysteria2_password hysteria2_password)"
  config_path="$(vpskit_hysteria2_config_path)"

  vpskit_vpn_stack_ensure_tls_material \
    "$(vpskit_hysteria2_cert_path)" \
    "$(vpskit_hysteria2_key_path)" \
    hysteria2_cert_pem \
    hysteria2_key_pem

  config_content="$(cat <<EOF
listen: :443

tls:
  cert: $(vpskit_hysteria2_cert_path)
  key: $(vpskit_hysteria2_key_path)

auth:
  type: password
  password: ${hysteria2_password}

masquerade:
  type: proxy
  proxy:
    url: https://www.cloudflare.com
EOF
)"

  vpskit_vpn_stack_write_root_file "${config_path}" 644 "${config_content}"
  vpskit_vpn_stack_validate_hysteria_config "${config_path}" || {
    vpskit_die "hysteria2 config validation failed"
    return 1
  }
  vpskit_state_save server_name "${server_name}" hysteria2_password "${hysteria2_password}"
  vpskit_run_root systemctl enable --now hysteria-server.service
}

vpskit_install_vpn_stack() {
  local vpn_stack

  vpskit_vpn_stack_require_root
  vpn_stack="${VPSKIT_VPN_STACK:-$(vpskit_state_get vpn_stack 2>/dev/null || printf 'xray')}"

  case "${vpn_stack}" in
    xray)
      vpskit_vpn_stack_ensure_xray || return 1
      ;;
    trojan)
      vpskit_vpn_stack_ensure_xray || return 1
      ;;
    hysteria2)
      vpskit_vpn_stack_ensure_hysteria || return 1
      ;;
    *)
      vpskit_die "unsupported VPN stack mode: ${vpn_stack}"
      return 1
      ;;
  esac

  vpskit_state_save vpn_stack "${vpn_stack}"
  vpskit_vpn_stack_bootstrap_state || return 1

  case "${vpn_stack}" in
    xray)
      install_xray || return 1
      ;;
    trojan)
      install_trojan || return 1
      ;;
    hysteria2)
      install_hysteria2 || return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_install_vpn_stack "$@"
fi
