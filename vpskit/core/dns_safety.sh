#!/usr/bin/env bash

vpskit_dns_safety_normalize_target() {
  local target="${1:-}"
  local host="${target}"

  if [ -z "${host}" ]; then
    printf '\n'
    return 0
  fi

  case "${host}" in
    \[*\]:*)
      host="${host#\[}"
      host="${host%%\]*}"
      ;;
    *:*)
      host="${host%%:*}"
      ;;
  esac

  host="${host%/}"
  printf '%s\n' "${host}"
}

vpskit_validate_dns() {
  local target="${1:-${VPSKIT_DNS_TARGET:-}}"
  local host
  local host_lc

  if [ -z "${target}" ]; then
    vpskit_die "dns target must be explicitly defined"
    return 1
  fi

  host="$(vpskit_dns_safety_normalize_target "${target}")"
  host_lc="$(printf '%s\n' "${host}" | tr '[:upper:]' '[:lower:]')"

  if [ -z "${host_lc}" ]; then
    vpskit_die "dns target must be explicitly defined"
    return 1
  fi

  case "${host_lc}" in
    localhost | 127.0.0.1 | 127.0.0.53)
      vpskit_die "forbidden dns target: ${host}"
      return 1
      ;;
  esac

  printf '%s\n' "${host}"
}

vpskit_assert_dns_safety() {
  local target="${1:-${VPSKIT_DNS_TARGET:-}}"

  vpskit_validate_dns "${target}" >/dev/null
}
