#!/usr/bin/env bash

vpskit_tcp_probe() {
  local host="${1:-${VPSKIT_TCP_PROBE_HOST:-127.0.0.1}}"
  local port="${2:-${VPSKIT_TCP_PROBE_PORT:-443}}"

  if [ -n "${VPSKIT_TEST_TCP_PROBE_RESULT:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TCP_PROBE_RESULT}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_TCP_PROBE_OPEN:-}" ] && [ "${VPSKIT_TEST_TCP_PROBE_OPEN}" = "${host}:${port}" ]; then
    printf 'open\n'
    return 0
  fi

  if [ -n "${VPSKIT_TEST_TCP_PROBE_CLOSED:-}" ] && [ "${VPSKIT_TEST_TCP_PROBE_CLOSED}" = "${host}:${port}" ]; then
    printf 'closed\n'
    return 1
  fi

  if command -v timeout >/dev/null 2>&1; then
    if timeout 3 bash -c ":</dev/tcp/${host}/${port}" >/dev/null 2>&1; then
      printf 'open\n'
      return 0
    fi
    printf 'closed\n'
    return 1
  fi

  printf 'unknown\n'
  return 1
}
