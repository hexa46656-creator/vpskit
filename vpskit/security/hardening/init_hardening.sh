#!/usr/bin/env bash
set -euo pipefail

VPSKIT_HARDENING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${VPSKIT_HARDENING_DIR}/ssh_hardening.sh"
# shellcheck disable=SC1091
source "${VPSKIT_HARDENING_DIR}/ufw_hardening.sh"
# shellcheck disable=SC1091
source "${VPSKIT_HARDENING_DIR}/fail2ban_hardening.sh"
# shellcheck disable=SC1091
source "${VPSKIT_HARDENING_DIR}/sysctl_hardening.sh"
# shellcheck disable=SC1091
source "${VPSKIT_HARDENING_DIR}/audit_verify.sh"

vpskit_hardening_run_step() {
  local label="$1"
  shift

  vpskit_log_info "hardening step: ${label}"
  "$@"
}

vpskit_apply_hardening() {
  vpskit_hardening_run_step "ssh" vpskit_ssh_hardening_apply
  vpskit_hardening_run_step "ufw" vpskit_ufw_hardening_apply
  vpskit_hardening_run_step "fail2ban" vpskit_fail2ban_hardening_apply
  vpskit_hardening_run_step "sysctl" vpskit_sysctl_hardening_apply
  vpskit_hardening_run_step "verify" vpskit_hardening_audit
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_apply_hardening "$@"
fi
