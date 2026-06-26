#!/usr/bin/env bash

VPSKIT_NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_NETWORK_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=dns_health.sh
source "${VPSKIT_NETWORK_DIR}/dns_health.sh"

vpskit_hysteria2_doctor() {
  local port="${VPSKIT_HYSTERIA2_PORT:-443}"
  local masquerade_host="${VPSKIT_HYSTERIA2_MASQUERADE_HOST:-www.bing.com}"
  local dns_line
  local congestion_control
  local default_qdisc
  local mtu

  printf 'HYSTERIA2_PORT=%s/udp\n' "${port}"
  printf 'HYSTERIA2_MASQUERADE_HOST=%s\n' "${masquerade_host}"
  printf 'HYSTERIA2_UDP_NOTE=local_listening_only_external_reachability_differs\n'

  dns_line="$(vpskit_dns_health "${masquerade_host}" || true)"
  if [ -n "${dns_line}" ]; then
    printf '%s\n' "${dns_line}"
  fi

  congestion_control="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
  default_qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || true)"
  printf 'BBR_TCP_CONGESTION_CONTROL=%s\n' "${congestion_control:-empty}"
  printf 'BBR_DEFAULT_QDISC=%s\n' "${default_qdisc:-empty}"
  if [ "${congestion_control}" != "bbr" ]; then
    printf 'BBR_STATUS=warn reason=not_bbr\n'
  else
    printf 'BBR_STATUS=ok\n'
  fi

  if command -v ip >/dev/null 2>&1; then
    mtu="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "mtu") { print $(i + 1); exit }}')"
  else
    mtu=""
  fi
  if [ -n "${mtu}" ]; then
    printf 'PATH_MTU_HINT=%s\n' "${mtu}"
  else
    printf 'PATH_MTU_HINT=unavailable reason=check_route_or_provider_path\n'
  fi
}
