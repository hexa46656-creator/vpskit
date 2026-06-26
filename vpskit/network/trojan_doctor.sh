#!/usr/bin/env bash

VPSKIT_NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../install/trojan.sh
source "${VPSKIT_NETWORK_DIR}/../install/trojan.sh"

vpskit_trojan_binary_state() {
  local bin_path

  bin_path="$(vpskit_vless_xray_bin 2>/dev/null || true)"
  if [ -n "${bin_path}" ] && [ -x "${bin_path}" ]; then
    printf 'present\n'
  else
    printf 'missing\n'
  fi
}

vpskit_trojan_config_state() {
  vpskit_trojan_xray_config_state
}

vpskit_trojan_service_state() {
  if ! vpskit_systemd_available; then
    printf 'unknown\n'
    return 0
  fi

  if vpskit_service_active "$(vpskit_trojan_service_name)" || vpskit_service_active "$(vpskit_trojan_service_name).service"; then
    printf 'active\n'
    return 0
  fi

  if vpskit_service_exists "$(vpskit_trojan_service_name)" || vpskit_service_exists "$(vpskit_trojan_service_name).service"; then
    printf 'inactive\n'
    return 0
  fi

  printf 'missing\n'
}

vpskit_trojan_tcp_state() {
  local owner

  owner="$(vpskit_trojan_tcp_8443_owner)"
  case "${owner}" in
    xray)
      printf 'bound\n'
      ;;
    not_bound)
      printf 'not_bound\n'
      ;;
    unknown | "")
      printf 'unknown\n'
      ;;
    *)
      printf 'owned_by_other\n'
      ;;
  esac
}

vpskit_trojan_subscription_state() {
  local subscription_file

  subscription_file="$(vpskit_system_path "$(vpskit_trojan_subscription_file)")"
  if [ -s "${subscription_file}" ]; then
    printf 'present\n'
  else
    printf 'missing\n'
  fi
}

vpskit_trojan_doctor_ufw_state() {
  local ufw_status

  ufw_status="$(vpskit_trojan_ufw_status 2>/dev/null || true)"
  if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
    printf 'UFW_8443_TCP=skip reason=ufw_unavailable\n'
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
    printf 'UFW_8443_TCP=skip status=inactive reason=not_enforced\n'
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    if vpskit_trojan_ufw_allows_8443_tcp "${ufw_status}"; then
      printf 'UFW_8443_TCP=pass status=active rule=present\n'
    else
      printf 'UFW_8443_TCP=fail status=active rule=missing\n'
    fi
    return 0
  fi

  printf 'UFW_8443_TCP=skip status=unknown\n'
}

vpskit_trojan_doctor() {
  local installed="no"
  local binary_state
  local config_state
  local service_state
  local tcp_state
  local subscription_state

  binary_state="$(vpskit_trojan_binary_state)"
  config_state="$(vpskit_trojan_config_state)"
  service_state="$(vpskit_trojan_service_state)"
  tcp_state="$(vpskit_trojan_tcp_state)"
  subscription_state="$(vpskit_trojan_subscription_state)"

  if [ "${binary_state}" = "present" ] && [ "${config_state}" = "present" ] && [ "${subscription_state}" = "present" ]; then
    installed="yes"
  fi

  printf 'TROJAN_PORT=%s/tcp\n' "$(vpskit_trojan_port)"
  printf 'TROJAN_INSTALLED=%s\n' "${installed}"
  printf 'TROJAN_COMPATIBILITY_MODE=compatibility_fallback\n'
  printf 'TROJAN_RUNTIME=xray\n'
  printf 'TROJAN_TLS_MODE=self_signed\n'
  printf 'TROJAN_BINARY=%s\n' "${binary_state}"
  printf 'TROJAN_CONFIG=%s\n' "${config_state}"
  printf 'TROJAN_SERVICE=%s\n' "${service_state}"
  printf 'TROJAN_TCP_8443=%s\n' "${tcp_state}"
  printf 'TROJAN_SUBSCRIPTION_FILE=%s\n' "${subscription_state}"
  vpskit_trojan_doctor_ufw_state
}
