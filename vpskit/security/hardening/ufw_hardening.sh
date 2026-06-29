#!/usr/bin/env bash
set -euo pipefail

VPSKIT_UFW_HARDENING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_UFW_HARDENING_DIR}/../../core/common.sh"

vpskit_ufw_hardening_require_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "ufw hardening requires root or passwordless sudo"
}

vpskit_ufw_hardening_rule_exists() {
  local rule="$1"

  ufw status numbered 2>/dev/null | awk -v rule="${rule}" '
    {
      line = $0
      sub(/^[[:space:]]*\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]*/, "", line)
      if (line ~ ("^" rule "[[:space:]]+ALLOW")) {
        found = 1
      }
    }
    END { exit(found ? 0 : 1) }
  '
}

vpskit_ufw_hardening_ensure_rule() {
  local rule="$1"

  if ! vpskit_ufw_hardening_rule_exists "${rule}"; then
    vpskit_run_root ufw allow "${rule}"
  fi
}

vpskit_ufw_hardening_apply() {
  vpskit_ufw_hardening_require_root

  if ! command -v ufw >/dev/null 2>&1; then
    vpskit_die "ufw is not installed"
    return 1
  fi

  vpskit_run_root ufw default deny incoming
  vpskit_run_root ufw default allow outgoing

  vpskit_ufw_hardening_ensure_rule 22/tcp
  vpskit_ufw_hardening_ensure_rule 443/tcp

  if ufw status 2>/dev/null | grep -q '^Status: active'; then
    vpskit_run_root ufw reload
  else
    vpskit_run_root ufw --force enable
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_ufw_hardening_apply "$@"
fi
