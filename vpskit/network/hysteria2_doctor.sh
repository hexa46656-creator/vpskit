#!/usr/bin/env bash

VPSKIT_NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_NETWORK_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${VPSKIT_NETWORK_DIR}/../core/system_check.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/hysteria2.sh
source "${VPSKIT_NETWORK_DIR}/../install/hysteria2.sh"

vpskit_hysteria2_installed() {
  local bin_path
  local config_path
  local subscription_file

  bin_path="$(vpskit_system_path "$(vpskit_hysteria2_bin_path)")"
  config_path="$(vpskit_system_path "$(vpskit_hysteria2_config_path)")"
  subscription_file="$(vpskit_system_path "$(vpskit_hysteria2_subscription_file)")"

  [ -x "${bin_path}" ] && [ -f "${config_path}" ] && [ -f "${subscription_file}" ]
}

vpskit_hysteria2_service_state() {
  if ! vpskit_systemd_available; then
    printf 'unknown\n'
    return 0
  fi

  if vpskit_service_active "$(vpskit_hysteria2_service_name)" || vpskit_service_active "$(vpskit_hysteria2_service_unit_name).service"; then
    printf 'active\n'
    return 0
  fi

  if vpskit_service_exists "$(vpskit_hysteria2_service_name)" || vpskit_service_exists "$(vpskit_hysteria2_service_unit_name).service"; then
    printf 'inactive\n'
    return 0
  fi

  printf 'missing\n'
}

vpskit_hysteria2_udp_state() {
  local owner

  owner="$(vpskit_hysteria2_udp_443_owner)"
  case "${owner}" in
    hysteria)
      printf 'bound\n'
      ;;
    unknown | "")
      printf 'unknown\n'
      ;;
    *)
      printf 'not_bound\n'
      ;;
  esac
}

vpskit_hysteria2_subscription_state() {
  local subscription_file

  subscription_file="$(vpskit_system_path "$(vpskit_hysteria2_subscription_file)")"
  if [ -f "${subscription_file}" ]; then
    printf 'present\n'
  else
    printf 'missing\n'
  fi
}

vpskit_hysteria2_doctor_ufw_state() {
  local ufw_status

  ufw_status="$(vpskit_hysteria2_ufw_status 2>/dev/null || true)"
  if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
    printf 'UFW_443_UDP=skip reason=ufw_unavailable\n'
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
    printf 'UFW_443_UDP=skip status=inactive reason=not_enforced\n'
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    if vpskit_hysteria2_ufw_allows_443_udp "${ufw_status}"; then
      printf 'UFW_443_UDP=pass status=active rule=present\n'
    else
      printf 'UFW_443_UDP=fail status=active rule=missing\n'
    fi
    return 0
  fi

  printf 'UFW_443_UDP=skip status=unknown\n'
}

vpskit_hysteria2_doctor() {
  local installed
  local service_state
  local udp_state
  local subscription_state

  installed="no"
  if vpskit_hysteria2_installed; then
    installed="yes"
  fi

  service_state="$(vpskit_hysteria2_service_state)"
  udp_state="$(vpskit_hysteria2_udp_state)"
  subscription_state="$(vpskit_hysteria2_subscription_state)"

  printf 'HYSTERIA2_PORT=%s/udp\n' "$(vpskit_hysteria2_port)"
  printf 'HYSTERIA2_UDP_NOTE=local_listener_and_firewall_state_only\n'
  printf 'HYSTERIA2_INSTALLED=%s\n' "${installed}"
  printf 'HYSTERIA2_SERVICE=%s\n' "${service_state}"
  printf 'HYSTERIA2_UDP_443=%s\n' "${udp_state}"
  printf 'HYSTERIA2_SUBSCRIPTION_FILE=%s\n' "${subscription_state}"
  vpskit_hysteria2_doctor_ufw_state
}
