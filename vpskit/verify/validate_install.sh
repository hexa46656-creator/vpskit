#!/usr/bin/env bash
set -euo pipefail

VPSKIT_VALIDATE_INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_VALIDATE_INSTALL_DIR}/../core/public_surface.sh"
# shellcheck disable=SC1091
source "${VPSKIT_VALIDATE_INSTALL_DIR}/../core/state_engine.sh"

vpskit_validate_install_service_active() {
  local service_name="$1"

  vpskit_run_root systemctl is-active --quiet "${service_name}"
}

vpskit_validate_install_port_listening() {
  local port="$1"

  ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .
}

vpskit_validate_install_subscription_file() {
  local subscription_file line

  subscription_file="${VPSKIT_SUBSCRIPTION_OUTPUT_ROOT:-/root/vpskit}/sub.txt"
  vpskit_run_root test -s "${subscription_file}" || return 1

  line="$(vpskit_run_root awk 'NF { print; exit }' "${subscription_file}")"
  case "${line}" in
    vless://* | trojan://* | hysteria2://*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

vpskit_validate_install_config_exists() {
  local config_path="$1"

  vpskit_run_root test -s "${config_path}"
}

vpskit_validate_install() {
  local status=0
  local vpn_stack

  vpskit_state_load || {
    vpskit_die "missing VPN state"
    return 1
  }

  vpn_stack="$(vpskit_state_get vpn_stack)"

  case "${vpn_stack}" in
    xray)
      vpskit_validate_install_service_active xray.service || status=1
      vpskit_validate_install_port_listening 443 || status=1
      vpskit_validate_install_config_exists "$(vpskit_vless_config_path)" || status=1
      ;;
    trojan)
      vpskit_validate_install_service_active xray.service || status=1
      vpskit_validate_install_port_listening 8443 || status=1
      vpskit_validate_install_config_exists "$(vpskit_trojan_config_path)" || status=1
      ;;
    hysteria2)
      vpskit_validate_install_service_active hysteria-server.service || status=1
      vpskit_validate_install_port_listening 443 || status=1
      vpskit_validate_install_config_exists "$(vpskit_hysteria2_config_path)" || status=1
      ;;
    *)
      vpskit_die "unsupported VPN stack mode: ${vpn_stack}"
      return 1
      ;;
  esac

  vpskit_validate_install_subscription_file || status=1

  if [[ "${VPSKIT_VALIDATE_HTTP_PORT:-0}" = "1" ]]; then
    vpskit_validate_install_port_listening 80 || status=1
  fi

  return "${status}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_validate_install "$@"
fi
