#!/usr/bin/env bash

VPSKIT_NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_NETWORK_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=dns_health.sh
source "${VPSKIT_NETWORK_DIR}/dns_health.sh"

vpskit_trojan_doctor() {
  local domain="${VPSKIT_TROJAN_DOMAIN:-}"
  local public_ipv4="${VPSKIT_PUBLIC_IPV4:-}"
  local dns_line
  local system_dns
  local cloudflare_dns
  local google_dns
  local mismatch=0

  if [ -z "${domain}" ]; then
    printf 'TROJAN_DOMAIN=missing\n'
    printf 'TROJAN_DNS_CHECK=skipped reason=no_domain\n'
    return 0
  fi

  printf 'TROJAN_DOMAIN=%s\n' "${domain}"
  dns_line="$(vpskit_dns_health "${domain}" || true)"
  if [ -n "${dns_line}" ]; then
    printf '%s\n' "${dns_line}"
  fi

  if [ -n "${public_ipv4}" ]; then
    system_dns="$(vpskit_dns_health_field_value "${dns_line}" system 2>/dev/null || true)"
    cloudflare_dns="$(vpskit_dns_health_field_value "${dns_line}" cloudflare 2>/dev/null || true)"
    google_dns="$(vpskit_dns_health_field_value "${dns_line}" google 2>/dev/null || true)"

    if [ -z "${system_dns}" ] || [ -z "${cloudflare_dns}" ] || [ -z "${google_dns}" ]; then
      mismatch=1
    elif [ "${system_dns}" != "${public_ipv4}" ] || [ "${cloudflare_dns}" != "${public_ipv4}" ] || [ "${google_dns}" != "${public_ipv4}" ]; then
      mismatch=1
    fi

    printf 'TROJAN_PUBLIC_IPV4=%s\n' "${public_ipv4}"
    if [ "${mismatch}" -eq 1 ]; then
      printf 'TROJAN_DNS_PUBLIC_IPV4=warn reason=resolver_mismatch\n'
    else
      printf 'TROJAN_DNS_PUBLIC_IPV4=ok\n'
    fi
  fi
}
