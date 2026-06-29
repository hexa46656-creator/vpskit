#!/usr/bin/env bash
set -euo pipefail

VPSKIT_SYSCTL_HARDENING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_SYSCTL_HARDENING_DIR}/../../core/common.sh"

vpskit_sysctl_hardening_require_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "sysctl hardening requires root or passwordless sudo"
}

vpskit_sysctl_hardening_validate_file() {
  local file_path="$1"

  awk '
    /^[[:space:]]*($|#)/ { next }
    /^[[:alnum:]_.-]+[[:space:]]*=[[:space:]]*[^[:space:]].*$/ { next }
    { exit 1 }
  ' "${file_path}"
}

vpskit_sysctl_hardening_verify_value() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$(sysctl -n "${key}" 2>/dev/null || true)"
  [[ "${actual}" == "${expected}" ]]
}

vpskit_sysctl_hardening_apply() {
  local target_file="/etc/sysctl.d/99-vpskit.conf"
  local tmp_file backup_file

  vpskit_sysctl_hardening_require_root

  vpskit_run_root install -d -m 0755 /etc/sysctl.d

  tmp_file="$(mktemp "${target_file}.XXXXXX")"
  backup_file="$(mktemp "${target_file}.backup.XXXXXX")"

  trap 'rm -f "${tmp_file}" "${backup_file}"' EXIT

  if [[ -f "${target_file}" ]]; then
  vpskit_run_root cp -p "${target_file}" "${backup_file}"
  fi

  cat > "${tmp_file}" <<'EOF'
# BEGIN VPSKIT HARDENING
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
# END VPSKIT HARDENING
EOF

  vpskit_sysctl_hardening_validate_file "${tmp_file}"
  vpskit_run_root install -m 0644 "${tmp_file}" "${target_file}"

  if ! vpskit_run_root sysctl --system >/dev/null 2>&1; then
    if [[ -f "${backup_file}" ]]; then
      vpskit_run_root install -m 0644 "${backup_file}" "${target_file}"
    else
      vpskit_run_root rm -f "${target_file}"
    fi
    vpskit_run_root sysctl --system >/dev/null 2>&1 || true
    vpskit_die "sysctl apply failed"
    return 1
  fi

  if ! vpskit_sysctl_hardening_verify_value net.ipv4.ip_forward 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv6.conf.all.forwarding 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.tcp_syncookies 1 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.all.accept_source_route 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.default.accept_source_route 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.all.send_redirects 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.default.send_redirects 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.all.accept_redirects 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.default.accept_redirects 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv6.conf.all.accept_redirects 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv6.conf.default.accept_redirects 0 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.all.rp_filter 1 \
    || ! vpskit_sysctl_hardening_verify_value net.ipv4.conf.default.rp_filter 1 \
    || ! vpskit_sysctl_hardening_verify_value kernel.dmesg_restrict 1 \
    || ! vpskit_sysctl_hardening_verify_value kernel.kptr_restrict 2 \
    || ! vpskit_sysctl_hardening_verify_value kernel.yama.ptrace_scope 1 \
    || ! vpskit_sysctl_hardening_verify_value fs.suid_dumpable 0; then
    if [[ -f "${backup_file}" ]]; then
      vpskit_run_root install -m 0644 "${backup_file}" "${target_file}"
    else
      vpskit_run_root rm -f "${target_file}"
    fi
    vpskit_run_root sysctl --system >/dev/null 2>&1 || true
    vpskit_die "sysctl verification failed"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_sysctl_hardening_apply "$@"
fi
