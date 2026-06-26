#!/usr/bin/env bash

VPSKIT_NETWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_NETWORK_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=dns_health.sh
source "${VPSKIT_NETWORK_DIR}/dns_health.sh"

vpskit_reality_extract_dest_host() {
  local dest="${1:-}"

  if [[ "${dest}" =~ ^\[([^]]+)\]:(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "${dest}" == *:* ]]; then
    printf '%s\n' "${dest%:*}"
    return 0
  fi

  printf '%s\n' "${dest}"
}

vpskit_reality_target_is_risky() {
  local target="${1:-}"
  local lowered

  lowered="$(printf '%s' "${target}" | tr '[:upper:]' '[:lower:]')"

  case "${lowered}" in
    *edgekey*|*akamaiedge*|*akamai*|*microsoft*|*google*|*apple*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

vpskit_reality_doctor() {
  local server_name="${VPSKIT_REALITY_SERVER_NAME:-www.cloudflare.com}"
  local dest="${VPSKIT_REALITY_DEST:-${server_name}:443}"
  local dest_host
  local dns_line

  dest_host="$(vpskit_reality_extract_dest_host "${dest}")"

  printf 'REALITY_SERVER_NAME=%s\n' "${server_name}"
  printf 'REALITY_DEST=%s\n' "${dest}"
  printf 'REALITY_DEST_HOST=%s\n' "${dest_host}"

  if [ "${dest_host}" != "${server_name}" ]; then
    printf 'REALITY_CONFIG=warn reason=serverName_dest_host_mismatch\n'
  else
    printf 'REALITY_CONFIG=ok reason=serverName_dest_host_match\n'
  fi

  dns_line="$(vpskit_dns_health "${dest_host}" || true)"
  if [ -n "${dns_line}" ]; then
    printf '%s\n' "${dns_line}"
  fi

  if vpskit_reality_target_is_risky "${server_name}" || vpskit_reality_target_is_risky "${dest_host}"; then
    printf 'REALITY_TARGET_RISK=high reason=cdn_edge_drift_likely\n'
  else
    printf 'REALITY_TARGET_RISK=normal\n'
  fi
}
