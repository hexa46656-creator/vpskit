#!/usr/bin/env bash

vpskit_fallback_report() {
  local dns_state="${1:-unknown}"
  local tcp_state="${2:-unknown}"

  cat <<EOF
FALLBACK_REPORT=available
DNS=${dns_state}
TCP=${tcp_state}
RECOMMENDATION=$(
  if [ "${dns_state}" = "ok" ] && [ "${tcp_state}" = "open" ]; then
    printf '%s' 'keep-primary'
  else
    printf '%s' 'check-fallback'
  fi
)
EOF
}
