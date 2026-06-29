#!/usr/bin/env bash
set -euo pipefail

VPSKIT_HARDENING_AUDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_HARDENING_AUDIT_DIR}/../../core/common.sh"

vpskit_hardening_audit_check_ssh() {
  sshd -t >/dev/null 2>&1
}

vpskit_hardening_audit_check_ufw() {
  command -v ufw >/dev/null 2>&1 && vpskit_run_root ufw status 2>/dev/null | grep -q '^Status: active'
}

vpskit_hardening_audit_check_fail2ban() {
  command -v fail2ban-client >/dev/null 2>&1 \
    && vpskit_run_root fail2ban-client ping >/dev/null 2>&1 \
    && vpskit_run_root fail2ban-client status recidive >/dev/null 2>&1
}

vpskit_hardening_audit_check_sysctl() {
  local key expected actual

  while IFS='=' read -r key expected; do
    actual="$(sysctl -n "${key}" 2>/dev/null || true)"
    if [[ "${actual}" != "${expected}" ]]; then
      return 1
    fi
  done <<'EOF'
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
fs.suid_dumpable=0
EOF
}

vpskit_hardening_audit() {
  local ssh_status ufw_status fail2ban_status sysctl_status

  ssh_status="fail"
  ufw_status="fail"
  fail2ban_status="fail"
  sysctl_status="fail"

  if vpskit_hardening_audit_check_ssh; then
    ssh_status="ok"
  fi

  if vpskit_hardening_audit_check_ufw; then
    ufw_status="ok"
  fi

  if vpskit_hardening_audit_check_fail2ban; then
    fail2ban_status="ok"
  fi

  if vpskit_hardening_audit_check_sysctl; then
    sysctl_status="ok"
  fi

  printf '{\n'
  printf '  "ssh": "%s",\n' "${ssh_status}"
  printf '  "ufw": "%s",\n' "${ufw_status}"
  printf '  "fail2ban": "%s",\n' "${fail2ban_status}"
  printf '  "sysctl": "%s"\n' "${sysctl_status}"
  printf '}\n'

  if [[ "${ssh_status}" != "ok" || "${ufw_status}" != "ok" || "${fail2ban_status}" != "ok" || "${sysctl_status}" != "ok" ]]; then
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_hardening_audit "$@"
fi
