#!/usr/bin/env bash

vpskit_require_root() {
  local effective_uid="${VPSKIT_TEST_EUID:-${EUID}}"

  if [ "${effective_uid}" = "0" ]; then
    return 0
  fi

  vpskit_die "root privileges required"
}

vpskit_detect_os_release() {
  local os_id="${VPSKIT_TEST_OS_ID:-}"
  local version_id="${VPSKIT_TEST_OS_VERSION_ID:-}"

  if [ -z "${os_id}" ] || [ -z "${version_id}" ]; then
    if [ ! -r /etc/os-release ]; then
      vpskit_die "unable to read os-release"
      return 1
    fi

    os_id="$(
      . /etc/os-release
      printf '%s' "${ID:-}"
    )"
    version_id="$(
      . /etc/os-release
      printf '%s' "${VERSION_ID:-}"
    )"
  fi

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
    20.04 | 22.04 | 24.04)
      return 0
      ;;
    *)
      vpskit_die "unsupported Ubuntu version: ${version_id}"
      ;;
  esac
}

vpskit_check_port_available() {
  local port="$1"
  local simulated_port="${VPSKIT_TEST_PORT_IN_USE:-}"

  if [ "${simulated_port}" = "${port}" ]; then
    vpskit_die "port ${port} is already in use"
    return 1
  fi

  if [ -n "${simulated_port}" ]; then
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .; then
      vpskit_die "port ${port} is already in use"
      return 1
    fi
    return 0
  fi

  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | grep -q .; then
      vpskit_die "port ${port} is already in use"
      return 1
    fi
    return 0
  fi

  vpskit_die "unable to check port ${port}: ss or lsof is required"
}
