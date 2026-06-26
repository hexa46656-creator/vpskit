#!/usr/bin/env bash

vpskit_dns_health() {
  local host="${1:-${VPSKIT_DNS_HEALTH_HOST:-localhost}}"

  if [ -n "${VPSKIT_TEST_DNS_HEALTH_RESULT:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_DNS_HEALTH_RESULT}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_DNS_HEALTH_FAIL:-}" ]; then
    printf 'fail\n'
    return 1
  fi

  if command -v getent >/dev/null 2>&1; then
    if getent ahosts "${host}" >/dev/null 2>&1; then
      printf 'ok\n'
      return 0
    fi
  fi

  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$host" <<'PY'
import socket
import sys

host = sys.argv[1]
try:
    socket.getaddrinfo(host, None)
except socket.gaierror:
    raise SystemExit(1)
PY
    then
      printf 'ok\n'
      return 0
    fi
  fi

  printf 'unknown\n'
  return 1
}
