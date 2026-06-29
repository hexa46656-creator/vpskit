#!/usr/bin/env bash
set -euo pipefail

VPSKIT_SECRET_ENGINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_SECRET_ENGINE_DIR}/common.sh"

vpskit_secret_get() {
  local name="$1"
  local secret_path
  local tmp_file

  for secret_path in "/run/secrets/${name}" "/etc/vpskit/secrets/${name}"; do
    if vpskit_run_root test -r "${secret_path}"; then
      tmp_file="$(mktemp "${TMPDIR:-/tmp}/vpskit-secret.XXXXXX")"
      vpskit_run_root cat "${secret_path}" > "${tmp_file}"
      awk '
        NR == 1 { printf "%s", $0; next }
        { printf "\n%s", $0 }
      ' "${tmp_file}"
      rm -f "${tmp_file}"
      return 0
    fi
  done

  return 1
}
