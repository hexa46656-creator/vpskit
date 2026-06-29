#!/usr/bin/env bash
set -euo pipefail

VPSKIT_STATE_ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_STATE_ENGINE_DIR}/common.sh"

vpskit_state_file() {
  printf '%s\n' "${VPSKIT_STATE_FILE:-/etc/vpskit/state.env}"
}

vpskit_state_load() {
  local state_file tmp_file

  state_file="$(vpskit_state_file)"
  if ! vpskit_run_root test -f "${state_file}"; then
    return 1
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-state-read.XXXXXX")"
  vpskit_run_root cat "${state_file}" > "${tmp_file}"

  awk '
    /^[[:space:]]*$/ { next }
    /^[A-Za-z_][A-Za-z0-9_]*=.*/ { next }
    { exit 1 }
  ' "${tmp_file}" || {
    rm -f "${tmp_file}"
    vpskit_die "invalid state file format: ${state_file}"
    return 1
  }

  rm -f "${tmp_file}"
}

vpskit_state_get() {
  local key="$1"
  local state_file value tmp_file

  vpskit_state_load || return 1
  state_file="$(vpskit_state_file)"
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-state-read.XXXXXX")"
  vpskit_run_root cat "${state_file}" > "${tmp_file}"

  value="$(awk -F= -v key="${key}" '
    $1 == key {
      sub(/^[^=]*=/, "", $0)
      print $0
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "${tmp_file}")" || {
    rm -f "${tmp_file}"
    return 1
  }

  rm -f "${tmp_file}"

  printf '%s\n' "${value}"
}

vpskit_state_save() {
  local state_file working_file next_file target_tmp key value

  if [[ "$#" -eq 0 || $(( $# % 2 )) -ne 0 ]]; then
    vpskit_die "vpskit_state_save requires key/value pairs"
    return 1
  fi

  state_file="$(vpskit_state_file)"
  working_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-state.XXXXXX")"
  target_tmp="$(mktemp "${TMPDIR:-/tmp}/vpskit-state-final.XXXXXX")"

  if vpskit_run_root test -f "${state_file}"; then
    vpskit_run_root cat "${state_file}" > "${working_file}"
  else
    : > "${working_file}"
  fi

  while [[ "$#" -gt 0 ]]; do
    key="$1"
    value="$2"
    shift 2

    next_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-state-next.XXXXXX")"
    awk -F= -v key="${key}" '$1 != key { print }' "${working_file}" > "${next_file}"
    printf '%s=%s\n' "${key}" "${value}" >> "${next_file}"
    mv "${next_file}" "${working_file}"
    next_file=""
  done

  awk 'NF { print }' "${working_file}" > "${target_tmp}"
  vpskit_run_root install -d -m 0755 "$(dirname "${state_file}")"
  vpskit_run_root install -m 600 "${target_tmp}" "${state_file}"
  rm -f "${working_file}" "${target_tmp}"
}
