#!/usr/bin/env bash

vpskit_require_root() {
  local effective_uid="${VPSKIT_TEST_EUID:-${EUID}}"

  if [ "${effective_uid}" = "0" ]; then
    return 0
  fi

  vpskit_die "root privileges required"
}

vpskit_detect_os_id() {
  if [ -n "${VPSKIT_TEST_OS_ID:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_OS_ID}"
    return 0
  fi

  if [ ! -r /etc/os-release ]; then
    vpskit_die "unable to read os-release"
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  if [ -z "${ID:-}" ]; then
    vpskit_die "unable to detect OS ID"
    return 1
  fi

  printf '%s\n' "${ID}"
}

vpskit_detect_os_version_id() {
  if [ -n "${VPSKIT_TEST_OS_VERSION_ID:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_OS_VERSION_ID}"
    return 0
  fi

  if [ ! -r /etc/os-release ]; then
    vpskit_die "unable to read os-release"
    return 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  if [ -z "${VERSION_ID:-}" ]; then
    vpskit_die "unable to detect OS version"
    return 1
  fi

  printf '%s\n' "${VERSION_ID}"
}

vpskit_detect_os_version_codename() {
  if [ -n "${VPSKIT_TEST_OS_VERSION_CODENAME:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_OS_VERSION_CODENAME}"
    return 0
  fi

  if [ ! -r /etc/os-release ]; then
    printf '\n'
    return 0
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s\n' "${VERSION_CODENAME:-}"
}

vpskit_detect_os_release() {
  local os_id
  local version_id

  os_id="$(vpskit_detect_os_id)" || return 1
  version_id="$(vpskit_detect_os_version_id)" || return 1

  if [ -z "${os_id}" ] || [ -z "${version_id}" ]; then
    vpskit_die "unable to detect OS release"
    return 1
  fi

  printf '%s %s\n' "${os_id}" "${version_id}"
}

vpskit_require_ubuntu() {
  local detected
  local os_id

  detected="$(vpskit_detect_os_release)" || return 1
  os_id="${detected%% *}"

  if [ "${os_id}" = "ubuntu" ]; then
    return 0
  fi

  vpskit_die "Ubuntu is required"
}

vpskit_require_supported_ubuntu() {
  local detected
  local version_id

  detected="$(vpskit_detect_os_release)" || return 1
  version_id="${detected#* }"

  vpskit_require_ubuntu || return 1

  case "${version_id}" in
    22.04 | 24.04)
      return 0
      ;;
    *)
      vpskit_die "unsupported Ubuntu version: ${version_id}"
      ;;
  esac
}

vpskit_require_ubuntu_2404() {
  local detected
  local version_id

  detected="$(vpskit_detect_os_release)" || return 1
  version_id="${detected#* }"

  vpskit_require_ubuntu || return 1

  if [ "${version_id}" = "24.04" ]; then
    return 0
  fi

  vpskit_die "Ubuntu 24.04 LTS is required for Phase 1 install targets"
}

vpskit_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

vpskit_required_commands_report() {
  local commands=("$@")
  local command_name
  local state

  if [ "${#commands[@]}" -eq 0 ]; then
    commands=(bash awk sed grep ss systemctl curl)
  fi

  for command_name in "${commands[@]}"; do
    state="missing"
    if vpskit_command_exists "${command_name}"; then
      state="present"
    fi
    printf 'COMMAND %s=%s\n' "${command_name}" "${state}"
  done
}

vpskit_check_port_available() {
  vpskit_check_tcp_port_available "$1"
}

vpskit_check_tcp_port_available() {
  local port="$1"
  local simulated_port="${VPSKIT_TEST_TCP_PORT_IN_USE:-${VPSKIT_TEST_PORT_IN_USE:-}}"

  if [ "${simulated_port}" = "${port}" ]; then
    vpskit_die "tcp port ${port} is already in use"
    return 1
  fi

  if [ -n "${simulated_port}" ]; then
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .; then
      vpskit_die "tcp port ${port} is already in use"
      return 1
    fi
    return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | grep -q .; then
      vpskit_die "tcp port ${port} is already in use"
      return 1
    fi
    return 0
  fi

  vpskit_die "unable to check tcp port ${port}: ss or lsof is required"
}

vpskit_check_udp_port_available() {
  local port="$1"
  local simulated_port="${VPSKIT_TEST_UDP_PORT_IN_USE:-}"

  if [ "${simulated_port}" = "${port}" ]; then
    vpskit_die "udp port ${port} is already in use"
    return 1
  fi

  if [ -n "${simulated_port}" ]; then
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -H -lun "sport = :${port}" 2>/dev/null | grep -q .; then
      vpskit_die "udp port ${port} is already in use"
      return 1
    fi
    return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iUDP:"${port}" 2>/dev/null | grep -q .; then
      vpskit_die "udp port ${port} is already in use"
      return 1
    fi
    return 0
  fi

  vpskit_die "unable to check udp port ${port}: ss or lsof is required"
}

vpskit_yes_value() {
  case "$1" in
    yes | true | 1 | on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

vpskit_systemd_available() {
  if [ -n "${VPSKIT_TEST_SYSTEMD_AVAILABLE:-}" ]; then
    vpskit_yes_value "${VPSKIT_TEST_SYSTEMD_AVAILABLE}"
    return $?
  fi

  vpskit_command_exists systemctl && [ -d /run/systemd/system ]
}

vpskit_list_contains() {
  local needle="$1"
  local item
  shift

  for item in "$@"; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done

  return 1
}

vpskit_service_exists() {
  local service_name="$1"

  if [ -n "${VPSKIT_TEST_SERVICE_EXISTS:-}" ]; then
    # shellcheck disable=SC2086
    vpskit_list_contains "${service_name}" ${VPSKIT_TEST_SERVICE_EXISTS}
    return $?
  fi

  vpskit_systemd_available || return 1
  systemctl list-unit-files "${service_name}" --no-legend --no-pager 2>/dev/null | grep -q "^${service_name}"
}

vpskit_service_active() {
  local service_name="$1"

  if [ -n "${VPSKIT_TEST_SERVICE_ACTIVE:-}" ]; then
    # shellcheck disable=SC2086
    vpskit_list_contains "${service_name}" ${VPSKIT_TEST_SERVICE_ACTIVE}
    return $?
  fi

  vpskit_systemd_available || return 1
  systemctl is-active --quiet "${service_name}" 2>/dev/null
}

vpskit_ufw_available() {
  if [ -n "${VPSKIT_TEST_UFW_AVAILABLE:-}" ]; then
    vpskit_yes_value "${VPSKIT_TEST_UFW_AVAILABLE}"
    return $?
  fi

  vpskit_command_exists ufw
}

vpskit_ufw_status() {
  if [ -n "${VPSKIT_TEST_UFW_STATUS:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_UFW_STATUS}"
    return 0
  fi

  vpskit_ufw_available || return 1
  ufw status 2>/dev/null | sed -n '1p'
}

vpskit_sshd_config_path() {
  printf '%s\n' "${VPSKIT_TEST_SSHD_CONFIG_PATH:-/etc/ssh/sshd_config}"
}

vpskit_sshd_config_exists() {
  local config_path

  config_path="$(vpskit_sshd_config_path)"
  [ -f "${config_path}" ]
}

vpskit_sshd_effective_value() {
  local key="$1"
  local config_path

  config_path="$(vpskit_sshd_config_path)"
  if [ ! -r "${config_path}" ]; then
    vpskit_die "sshd config is not readable: ${config_path}"
    return 1
  fi

  awk -v key="${key}" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    tolower($1) == tolower(key) { value = $2 }
    END {
      if (value != "") {
        print value
      }
    }
  ' "${config_path}"
}

vpskit_bool_word() {
  if "$@"; then
    printf 'yes\n'
  else
    printf 'no\n'
  fi
}

vpskit_system_inspection_summary() {
  local os_id
  local version_id
  local codename

  os_id="$(vpskit_detect_os_id)" || return 1
  version_id="$(vpskit_detect_os_version_id)" || return 1
  codename="$(vpskit_detect_os_version_codename)"

  printf 'OS_ID=%s\n' "${os_id}"
  printf 'OS_VERSION_ID=%s\n' "${version_id}"
  printf 'OS_VERSION_CODENAME=%s\n' "${codename}"
  printf 'SUPPORTED_OS=%s\n' "$(vpskit_bool_word vpskit_require_supported_ubuntu)"
  printf 'SYSTEMD_AVAILABLE=%s\n' "$(vpskit_bool_word vpskit_systemd_available)"
  printf 'UFW_AVAILABLE=%s\n' "$(vpskit_bool_word vpskit_ufw_available)"
  printf 'TCP_443_AVAILABLE=%s\n' "$(vpskit_bool_word vpskit_check_tcp_port_available 443)"
  printf 'UDP_443_AVAILABLE=%s\n' "$(vpskit_bool_word vpskit_check_udp_port_available 443)"
}
