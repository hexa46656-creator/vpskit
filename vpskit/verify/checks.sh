#!/usr/bin/env bash

VPSKIT_VERIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_VERIFY_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${VPSKIT_VERIFY_DIR}/../core/system_check.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_VERIFY_DIR}/../core/public_surface.sh"

vpskit_verify_managed_user_exists() {
  local managed_user="$1"

  case "${VPSKIT_TEST_MANAGED_USER_EXISTS:-}" in
    yes)
      return 0
      ;;
    no)
      return 1
      ;;
  esac

  id "${managed_user}" >/dev/null 2>&1
}

vpskit_verify_managed_user_groups() {
  local managed_user="$1"

  if [ -n "${VPSKIT_TEST_MANAGED_USER_GROUPS:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_MANAGED_USER_GROUPS}"
    return 0
  fi

  id -nG "${managed_user}" 2>/dev/null
}

vpskit_verify_mode() {
  local path="$1"

  stat -c '%a' "${path}" 2>/dev/null || stat -f '%Lp' "${path}" 2>/dev/null || true
}

vpskit_verify_owner() {
  local path="$1"
  local override="$2"

  if [ -n "${override}" ]; then
    printf '%s\n' "${override}"
    return 0
  fi

  stat -c '%U:%G' "${path}" 2>/dev/null || stat -f '%Su:%Sg' "${path}" 2>/dev/null || true
}

vpskit_verify_emit_check() {
  local label="$1"
  local result="$2"
  shift 2

  printf '%s=%s' "${label}" "${result}"
  if [ "$#" -gt 0 ]; then
    printf ' %s' "$*"
  fi
  printf '\n'
}

vpskit_verify_group_list_contains() {
  local group_list="$1"
  local expected_group="$2"
  local group_name

  for group_name in ${group_list}; do
    if [ "${group_name}" = "${expected_group}" ]; then
      return 0
    fi
  done

  return 1
}

vpskit_verify_ssh_user() {
  local managed_user
  local ssh_dir
  local authorized_keys
  local groups
  local ssh_dir_mode
  local ssh_dir_owner
  local keys_mode
  local keys_owner
  local status=0

  managed_user="$(vpskit_hardening_managed_user)"
  vpskit_validate_managed_user "${managed_user}" || return 1
  ssh_dir="$(vpskit_system_path "/home/${managed_user}/.ssh")"
  authorized_keys="${ssh_dir}/authorized_keys"

  if vpskit_verify_managed_user_exists "${managed_user}"; then
    vpskit_verify_emit_check SSH_USER_EXISTS pass "user=${managed_user}"
  else
    vpskit_verify_emit_check SSH_USER_EXISTS fail "user=${managed_user}"
    status=1
  fi

  groups="$(vpskit_verify_managed_user_groups "${managed_user}" || true)"
  if vpskit_verify_group_list_contains "${groups}" sudo; then
    vpskit_verify_emit_check SSH_USER_SUDO pass "user=${managed_user} group=sudo"
  else
    vpskit_verify_emit_check SSH_USER_SUDO fail "user=${managed_user} group=sudo groups=${groups:-none}"
    status=1
  fi

  if [ -d "${ssh_dir}" ]; then
    vpskit_verify_emit_check SSH_DIR pass "path=${ssh_dir}"
  else
    vpskit_verify_emit_check SSH_DIR fail "path=${ssh_dir}"
    status=1
  fi

  ssh_dir_mode="$(vpskit_verify_mode "${ssh_dir}")"
  if [ "${ssh_dir_mode}" = "700" ]; then
    vpskit_verify_emit_check SSH_DIR_MODE pass "expected=700 actual=${ssh_dir_mode}"
  else
    vpskit_verify_emit_check SSH_DIR_MODE fail "expected=700 actual=${ssh_dir_mode:-missing}"
    status=1
  fi

  ssh_dir_owner="$(vpskit_verify_owner "${ssh_dir}" "${VPSKIT_TEST_SSH_DIR_OWNER:-}")"
  if [ "${ssh_dir_owner}" = "${managed_user}:${managed_user}" ]; then
    vpskit_verify_emit_check SSH_DIR_OWNER pass "expected=${managed_user}:${managed_user} actual=${ssh_dir_owner}"
  else
    vpskit_verify_emit_check SSH_DIR_OWNER fail "expected=${managed_user}:${managed_user} actual=${ssh_dir_owner:-unknown}"
    status=1
  fi

  if [ -f "${authorized_keys}" ]; then
    vpskit_verify_emit_check AUTHORIZED_KEYS pass "path=${authorized_keys}"
  else
    vpskit_verify_emit_check AUTHORIZED_KEYS fail "path=${authorized_keys}"
    status=1
  fi

  keys_mode="$(vpskit_verify_mode "${authorized_keys}")"
  if [ "${keys_mode}" = "600" ]; then
    vpskit_verify_emit_check AUTHORIZED_KEYS_MODE pass "expected=600 actual=${keys_mode}"
  else
    vpskit_verify_emit_check AUTHORIZED_KEYS_MODE fail "expected=600 actual=${keys_mode:-missing}"
    status=1
  fi

  keys_owner="$(vpskit_verify_owner "${authorized_keys}" "${VPSKIT_TEST_AUTHORIZED_KEYS_OWNER:-}")"
  if [ "${keys_owner}" = "${managed_user}:${managed_user}" ]; then
    vpskit_verify_emit_check AUTHORIZED_KEYS_OWNER pass "expected=${managed_user}:${managed_user} actual=${keys_owner}"
  else
    vpskit_verify_emit_check AUTHORIZED_KEYS_OWNER fail "expected=${managed_user}:${managed_user} actual=${keys_owner:-unknown}"
    status=1
  fi

  if [ "${status}" -eq 0 ]; then
    printf 'VERIFY_SSH_USER=pass\n'
  else
    printf 'VERIFY_SSH_USER=fail\n'
  fi

  return "${status}"
}

vpskit_verify_tcp_443_owner() {
  if [ -n "${VPSKIT_TEST_TCP_443_OWNER:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TCP_443_OWNER}"
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    ss -H -ltnp 'sport = :443' 2>/dev/null | awk '
      /xray/ { print "xray"; found = 1; exit }
      NF && !found { print "unknown"; found = 1; exit }
    '
    return 0
  fi

  printf 'unknown\n'
}

vpskit_verify_ufw_allows_443_tcp() {
  local ufw_status="$1"

  printf '%s\n' "${ufw_status}" | awk '
    {
      line = $0
      sub(/^[[:space:]]*\[[[:space:]]*[0-9]+\][[:space:]]*/, "", line)
      if (line ~ /\(v6\)/) {
        next
      }

      field_count = split(line, fields, /[[:space:]]+/)
      if (fields[1] != "443/tcp") {
        next
      }

      for (i = 2; i <= field_count; i++) {
        if (fields[i] == "ALLOW") {
          found = 1
        }
      }
    }
    END { exit !found }
  '
}

vpskit_verify_ufw_allows_443_udp() {
  local ufw_status="$1"

  printf '%s\n' "${ufw_status}" | awk '
    {
      line = $0
      sub(/^[[:space:]]*\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]*/, "", line)
      if (line ~ /\(v6\)/) {
        next
      }

      field_count = split(line, fields, /[[:space:]]+/)
      if (fields[1] != "443/udp") {
        next
      }

      for (i = 2; i <= field_count; i++) {
        if (fields[i] == "ALLOW") {
          found = 1
        }
      }
    }
    END { exit !found }
  '
}

vpskit_verify_ufw_allows_8443_tcp() {
  local ufw_status="$1"

  printf '%s\n' "${ufw_status}" | awk '
    {
      line = $0
      sub(/^[[:space:]]*\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]*/, "", line)
      if (line ~ /\(v6\)/) {
        next
      }

      field_count = split(line, fields, /[[:space:]]+/)
      if (fields[1] != "8443/tcp") {
        next
      }

      for (i = 2; i <= field_count; i++) {
        if (fields[i] == "ALLOW") {
          found = 1
        }
      }
    }
    END { exit !found }
  '
}

vpskit_verify_ufw_status() {
  if [ -n "${VPSKIT_TEST_UFW_STATUS:-}" ]; then
    vpskit_ufw_status
    return 0
  fi

  vpskit_ufw_available || return 1
  ufw status verbose 2>/dev/null || ufw status numbered 2>/dev/null || ufw status 2>/dev/null
}

vpskit_verify_vless_reality() {
  local status=0
  local xray_bin=""
  local tcp_owner
  local subscription_file
  local ufw_status

  if xray_bin="$(vpskit_vless_xray_bin 2>/dev/null)" && [ -x "${xray_bin}" ]; then
    vpskit_verify_emit_check XRAY_BINARY pass "path=${xray_bin}"
  else
    vpskit_verify_emit_check XRAY_BINARY fail "path=missing"
    status=1
  fi

  if vpskit_systemd_available; then
    if vpskit_service_active xray || vpskit_service_active xray.service; then
      vpskit_verify_emit_check XRAY_SERVICE pass "state=active"
    else
      vpskit_verify_emit_check XRAY_SERVICE fail "state=inactive"
      status=1
    fi
  else
    vpskit_verify_emit_check XRAY_SERVICE skip "reason=systemd_unavailable"
  fi

  tcp_owner="$(vpskit_verify_tcp_443_owner)"
  if [ "${tcp_owner}" = "xray" ]; then
    vpskit_verify_emit_check TCP_443_LISTENER pass "service=xray"
  else
    vpskit_verify_emit_check TCP_443_LISTENER fail "expected=xray actual=${tcp_owner:-none}"
    status=1
  fi

  subscription_file="$(vpskit_system_path "$(vpskit_default_subscription_file)")"
  if [ -s "${subscription_file}" ]; then
    vpskit_verify_emit_check SUBSCRIPTION_FILE pass "path=${subscription_file}"
  else
    vpskit_verify_emit_check SUBSCRIPTION_FILE fail "path=${subscription_file}"
    status=1
  fi

  ufw_status="$(vpskit_verify_ufw_status 2>/dev/null || true)"
  if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
    vpskit_verify_emit_check UFW_443_TCP skip "reason=ufw_unavailable"
  elif printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
    vpskit_verify_emit_check UFW_443_TCP skip "status=inactive reason=not_enforced"
  elif printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    if vpskit_verify_ufw_allows_443_tcp "${ufw_status}"; then
      vpskit_verify_emit_check UFW_443_TCP pass "status=active rule=present"
    else
      vpskit_verify_emit_check UFW_443_TCP fail "status=active rule=missing"
      status=1
    fi
  else
    vpskit_verify_emit_check UFW_443_TCP skip "status=unknown"
  fi

  if [ "${status}" -eq 0 ]; then
    printf 'VERIFY_VLESS_REALITY=pass\n'
  else
    printf 'VERIFY_VLESS_REALITY=fail\n'
  fi

  return "${status}"
}

vpskit_verify_trojan_binary() {
  local bin_path

  if bin_path="$(vpskit_vless_xray_bin 2>/dev/null)" && [ -x "${bin_path}" ]; then
    vpskit_verify_emit_check TROJAN_BINARY pass "path=${bin_path}"
    return 0
  fi

  vpskit_verify_emit_check TROJAN_BINARY fail "path=missing"
  return 1
}

vpskit_verify_trojan_config() {
  if [ "$(vpskit_trojan_xray_config_state)" = "present" ]; then
    vpskit_verify_emit_check TROJAN_CONFIG pass
    return 0
  fi

  vpskit_verify_emit_check TROJAN_CONFIG fail
  return 1
}

vpskit_verify_trojan_subscription_file() {
  local subscription_file

  subscription_file="$(vpskit_system_path "$(vpskit_trojan_subscription_file)")"
  if [ -s "${subscription_file}" ]; then
    vpskit_verify_emit_check TROJAN_SUBSCRIPTION_FILE pass "path=${subscription_file}"
    return 0
  fi

  vpskit_verify_emit_check TROJAN_SUBSCRIPTION_FILE fail "path=${subscription_file}"
  return 1
}

vpskit_verify_trojan_service() {
  if ! vpskit_systemd_available; then
    vpskit_verify_emit_check TROJAN_SERVICE fail "state=unknown service=xray"
    return 1
  fi

  if vpskit_service_active "$(vpskit_trojan_service_name)" || vpskit_service_active "$(vpskit_trojan_service_name).service"; then
    vpskit_verify_emit_check TROJAN_SERVICE pass "state=active service=xray"
    return 0
  fi

  if vpskit_service_exists "$(vpskit_trojan_service_name)" || vpskit_service_exists "$(vpskit_trojan_service_name).service"; then
    vpskit_verify_emit_check TROJAN_SERVICE fail "state=inactive"
  else
    vpskit_verify_emit_check TROJAN_SERVICE fail "state=missing"
  fi
  return 1
}

vpskit_verify_trojan_listener() {
  local owner

  owner="$(vpskit_trojan_tcp_8443_owner)"
  case "${owner}" in
    xray)
      vpskit_verify_emit_check TCP_8443_LISTENER pass "service=xray"
      return 0
      ;;
    not_bound)
      vpskit_verify_emit_check TCP_8443_LISTENER fail "expected=xray actual=not_bound"
      return 1
      ;;
    unknown)
      vpskit_verify_emit_check TCP_8443_LISTENER fail "expected=xray actual=unknown"
      return 1
      ;;
    *)
      vpskit_verify_emit_check TCP_8443_LISTENER fail "expected=xray actual=${owner:-none}"
      return 1
      ;;
  esac
}

vpskit_verify_trojan_ufw() {
  local ufw_status

  ufw_status="$(vpskit_trojan_ufw_status 2>/dev/null || true)"
  if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
    vpskit_verify_emit_check UFW_8443_TCP skip "reason=ufw_unavailable"
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
    vpskit_verify_emit_check UFW_8443_TCP skip "status=inactive reason=not_enforced"
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    if vpskit_verify_ufw_allows_8443_tcp "${ufw_status}"; then
      vpskit_verify_emit_check UFW_8443_TCP pass "status=active rule=present"
      return 0
    fi

    vpskit_verify_emit_check UFW_8443_TCP fail "status=active rule=missing"
    return 1
  fi

  vpskit_verify_emit_check UFW_8443_TCP skip "status=unknown"
  return 0
}

vpskit_verify_trojan_vless_preserved() {
  local tcp_owner

  tcp_owner="$(vpskit_verify_tcp_443_owner)"
  if [ "${tcp_owner}" = "xray" ]; then
    vpskit_verify_emit_check VLESS_REALITY_PRESERVED pass "tcp_443=bound service=xray"
    return 0
  fi

  vpskit_verify_emit_check VLESS_REALITY_PRESERVED fail "tcp_443=${tcp_owner:-none}"
  return 1
}

vpskit_verify_trojan() {
  local status=0

  vpskit_verify_trojan_binary || status=1
  vpskit_verify_trojan_config || status=1
  vpskit_verify_trojan_subscription_file || status=1
  vpskit_verify_trojan_service || status=1
  vpskit_verify_trojan_listener || status=1
  vpskit_verify_trojan_ufw || status=1
  vpskit_verify_trojan_vless_preserved || status=1

  if [ "${status}" -eq 0 ]; then
    printf 'VERIFY_TROJAN=pass\n'
  else
    printf 'VERIFY_TROJAN=fail\n'
  fi

  return "${status}"
}

vpskit_verify_hysteria2_binary() {
  local bin_path

  bin_path="$(vpskit_system_path "$(vpskit_hysteria2_bin_path)")"
  if [ -x "${bin_path}" ]; then
    vpskit_verify_emit_check HYSTERIA2_BINARY pass "path=${bin_path}"
    return 0
  fi

  vpskit_verify_emit_check HYSTERIA2_BINARY fail "path=missing"
  return 1
}

vpskit_verify_hysteria2_config() {
  local config_path

  config_path="$(vpskit_system_path "$(vpskit_hysteria2_config_path)")"
  if [ -f "${config_path}" ]; then
    vpskit_verify_emit_check HYSTERIA2_CONFIG pass "path=${config_path}"
    return 0
  fi

  vpskit_verify_emit_check HYSTERIA2_CONFIG fail "path=${config_path}"
  return 1
}

vpskit_verify_hysteria2_subscription_file() {
  local subscription_file

  subscription_file="$(vpskit_system_path "$(vpskit_hysteria2_subscription_file)")"
  if [ -s "${subscription_file}" ]; then
    vpskit_verify_emit_check HYSTERIA2_SUBSCRIPTION_FILE pass "path=${subscription_file}"
    return 0
  fi

  vpskit_verify_emit_check HYSTERIA2_SUBSCRIPTION_FILE fail "path=${subscription_file}"
  return 1
}

vpskit_verify_hysteria2_service() {
  if ! vpskit_systemd_available; then
    vpskit_verify_emit_check HYSTERIA2_SERVICE skip "reason=systemd_unavailable"
    return 0
  fi

  if vpskit_service_active "$(vpskit_hysteria2_service_name)" || vpskit_service_active "$(vpskit_hysteria2_service_unit_name).service"; then
    vpskit_verify_emit_check HYSTERIA2_SERVICE pass "state=active"
    return 0
  fi

  if vpskit_service_exists "$(vpskit_hysteria2_service_name)" || vpskit_service_exists "$(vpskit_hysteria2_service_unit_name).service"; then
    vpskit_verify_emit_check HYSTERIA2_SERVICE fail "state=inactive"
  else
    vpskit_verify_emit_check HYSTERIA2_SERVICE fail "state=missing"
  fi
  return 1
}

vpskit_verify_hysteria2_listener() {
  local owner

  owner="$(vpskit_hysteria2_udp_443_owner)"
  case "${owner}" in
    hysteria)
      vpskit_verify_emit_check UDP_443_LISTENER pass "service=hysteria"
      return 0
      ;;
    not_bound)
      vpskit_verify_emit_check UDP_443_LISTENER fail "expected=hysteria actual=not_bound"
      return 1
      ;;
    unknown)
      vpskit_verify_emit_check UDP_443_LISTENER unknown "reason=ss_unavailable"
      return 1
      ;;
    *)
      vpskit_verify_emit_check UDP_443_LISTENER fail "expected=hysteria actual=${owner:-none}"
      return 1
      ;;
  esac
}

vpskit_verify_hysteria2_ufw() {
  local ufw_status

  ufw_status="$(vpskit_hysteria2_ufw_status 2>/dev/null || true)"
  if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
    vpskit_verify_emit_check UFW_443_UDP skip "reason=ufw_unavailable"
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
    vpskit_verify_emit_check UFW_443_UDP skip "status=inactive reason=not_enforced"
    return 0
  fi

  if printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    if vpskit_verify_ufw_allows_443_udp "${ufw_status}"; then
      vpskit_verify_emit_check UFW_443_UDP pass "status=active rule=present"
      return 0
    fi

    vpskit_verify_emit_check UFW_443_UDP fail "status=active rule=missing"
    return 1
  fi

  vpskit_verify_emit_check UFW_443_UDP skip "status=unknown"
  return 0
}

vpskit_verify_hysteria2() {
  local status=0

  vpskit_verify_hysteria2_binary || status=1
  vpskit_verify_hysteria2_config || status=1
  vpskit_verify_hysteria2_subscription_file || status=1
  vpskit_verify_hysteria2_service || status=1
  vpskit_verify_hysteria2_listener || status=1
  vpskit_verify_hysteria2_ufw || status=1

  if [ "${status}" -eq 0 ]; then
    printf 'VERIFY_HYSTERIA2=pass\n'
  else
    printf 'VERIFY_HYSTERIA2=fail\n'
  fi

  return "${status}"
}
