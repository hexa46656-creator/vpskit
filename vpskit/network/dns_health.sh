#!/usr/bin/env bash

vpskit_dns_health_field_value() {
  local line="$1"
  local key="$2"
  local token

  for token in ${line}; do
    case "${token}" in
      "${key}="*)
        printf '%s\n' "${token#*=}"
        return 0
        ;;
    esac
  done

  return 1
}

vpskit_dns_health_resolve_a() {
  local host="$1"
  local resolver="${2:-}"
  local command=(dig +short A "${host}")

  if [ -n "${resolver}" ]; then
    command+=("@${resolver}")
  fi

  if ! command -v dig >/dev/null 2>&1; then
    return 1
  fi

  "${command[@]}" 2>/dev/null | awk 'NF { print; exit }'
}

vpskit_dns_health_emit() {
  local status="$1"
  local host="$2"
  local system_dns="$3"
  local cloudflare_dns="$4"
  local google_dns="$5"

  printf 'DNS_HEALTH=%s host=%s system=%s cloudflare=%s google=%s\n' \
    "${status}" "${host}" "${system_dns}" "${cloudflare_dns}" "${google_dns}"
}

vpskit_dns_health() {
  local host="${1:-${VPSKIT_DNS_HEALTH_HOST:-localhost}}"
  local system_dns
  local cloudflare_dns
  local google_dns

  if [ -n "${VPSKIT_TEST_DNS_HEALTH_RESULT:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_DNS_HEALTH_RESULT}"
    case "${VPSKIT_TEST_DNS_HEALTH_RESULT}" in
      DNS_HEALTH=drift*|drift|DNS_HEALTH=fail*|fail)
        return 1
        ;;
      *)
        return 0
        ;;
    esac
  fi

  if [ -n "${VPSKIT_TEST_DNS_HEALTH_FAIL:-}" ]; then
    vpskit_dns_health_emit fail "${host}" empty empty empty
    return 1
  fi

  system_dns="$(vpskit_dns_health_resolve_a "${host}")"
  cloudflare_dns="$(vpskit_dns_health_resolve_a "${host}" 1.1.1.1)"
  google_dns="$(vpskit_dns_health_resolve_a "${host}" 8.8.8.8)"

  if [ -z "${system_dns}" ] || [ -z "${cloudflare_dns}" ] || [ -z "${google_dns}" ]; then
    vpskit_dns_health_emit fail "${host}" empty empty empty
    return 1
  fi

  if [ "${system_dns}" != "${cloudflare_dns}" ] || [ "${system_dns}" != "${google_dns}" ] || [ "${cloudflare_dns}" != "${google_dns}" ]; then
    vpskit_dns_health_emit drift "${host}" "${system_dns}" "${cloudflare_dns}" "${google_dns}"
    return 1
  fi

  vpskit_dns_health_emit ok "${host}" "${system_dns}" "${cloudflare_dns}" "${google_dns}"
}
