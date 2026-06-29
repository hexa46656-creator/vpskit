#!/usr/bin/env bash
set -euo pipefail

VPSKIT_FAIL2BAN_HARDENING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_FAIL2BAN_HARDENING_DIR}/../../core/common.sh"

vpskit_fail2ban_hardening_require_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "fail2ban hardening requires root or passwordless sudo"
}

vpskit_fail2ban_hardening_apply() {
  local jail_dir="/etc/fail2ban/jail.d"
  local target_file="${jail_dir}/vpskit.local"
  local tmp_file backup_file

  vpskit_fail2ban_hardening_require_root

  if ! command -v fail2ban-client >/dev/null 2>&1; then
    vpskit_die "fail2ban-client is not installed"
    return 1
  fi

  vpskit_run_root install -d -m 0755 "${jail_dir}"

  tmp_file="$(mktemp "${target_file}.XXXXXX")"
  backup_file="$(mktemp "${target_file}.backup.XXXXXX")"

  trap 'rm -f "${tmp_file}" "${backup_file}"' EXIT

  if [[ -f "${target_file}" ]]; then
    cp -p "${target_file}" "${backup_file}"
  fi

  cat > "${tmp_file}" <<'EOF'
# BEGIN VPSKIT HARDENING
[sshd]
enabled = true

[recidive]
enabled = true
bantime = 7d
findtime = 24h
maxretry = 5
# END VPSKIT HARDENING
EOF

  vpskit_run_root install -m 0644 "${tmp_file}" "${target_file}"

  if ! vpskit_run_root fail2ban-client -t >/dev/null 2>&1; then
    if [[ -f "${backup_file}" ]]; then
      vpskit_run_root install -m 0644 "${backup_file}" "${target_file}"
    else
      vpskit_run_root rm -f "${target_file}"
    fi
    vpskit_run_root fail2ban-client -t >/dev/null 2>&1 || true
    vpskit_die "fail2ban validation failed"
    return 1
  fi

  if ! vpskit_run_root systemctl restart fail2ban; then
    if [[ -f "${backup_file}" ]]; then
      vpskit_run_root install -m 0644 "${backup_file}" "${target_file}"
    else
      vpskit_run_root rm -f "${target_file}"
    fi
    vpskit_run_root systemctl restart fail2ban >/dev/null 2>&1 || true
    vpskit_die "fail2ban restart failed"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_fail2ban_hardening_apply "$@"
fi
