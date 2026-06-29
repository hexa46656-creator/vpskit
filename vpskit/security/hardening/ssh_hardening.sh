#!/usr/bin/env bash
set -euo pipefail

VPSKIT_SSH_HARDENING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${VPSKIT_SSH_HARDENING_DIR}/../../core/common.sh"

vpskit_ssh_hardening_require_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "ssh hardening requires root or passwordless sudo"
}

vpskit_ssh_hardening_has_keys() {
  find /root /home -path '*/.ssh/authorized_keys' -type f -size +0c 2>/dev/null | grep -q .
}

vpskit_ssh_hardening_service_restart() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl cat ssh >/dev/null 2>&1; then
      vpskit_run_root systemctl reload ssh 2>/dev/null || vpskit_run_root systemctl restart ssh
      return 0
    fi

    if systemctl cat sshd >/dev/null 2>&1; then
      vpskit_run_root systemctl reload sshd 2>/dev/null || vpskit_run_root systemctl restart sshd
      return 0
    fi
  fi

  vpskit_die "unable to restart SSH service"
}

vpskit_ssh_hardening_apply() {
  local ssh_config="/etc/ssh/sshd_config"
  local tmp_dir tmp_config backup_config password_auth root_login

  vpskit_ssh_hardening_require_root

  if [[ ! -f "${ssh_config}" ]]; then
    vpskit_die "missing SSH config: ${ssh_config}"
    return 1
  fi

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/vpskit-ssh.XXXXXX")"
  tmp_config="${tmp_dir}/sshd_config"
  backup_config="${tmp_dir}/sshd_config.backup"
  password_auth="no"
  root_login="${VPSKIT_SSH_PERMIT_ROOT_LOGIN:-prohibit-password}"

  trap 'rm -rf "${tmp_dir}"' EXIT

  if ! vpskit_ssh_hardening_has_keys; then
    password_auth=""
  fi

  vpskit_run_root cp -p "${ssh_config}" "${backup_config}"

  awk '
    BEGIN { skip = 0 }
    /^# BEGIN VPSKIT HARDENING$/ { skip = 1; next }
    /^# END VPSKIT HARDENING$/ { skip = 0; next }
    skip == 0 { print }
  ' "${ssh_config}" > "${tmp_config}"

  {
    printf '%s\n' '# BEGIN VPSKIT HARDENING'
    printf 'PermitRootLogin %s\n' "${root_login}"
    if [[ -n "${password_auth}" ]]; then
      printf 'PasswordAuthentication no\n'
    fi
    printf 'MaxAuthTries 3\n'
    printf 'PermitEmptyPasswords no\n'
    printf '%s\n' '# END VPSKIT HARDENING'
  } >> "${tmp_config}"

  if ! sshd -t -f "${tmp_config}" >/dev/null 2>&1; then
    vpskit_die "SSH config validation failed before install"
    return 1
  fi

  vpskit_run_root install -m 0644 "${tmp_config}" "${ssh_config}"

  if ! sshd -t >/dev/null 2>&1; then
    vpskit_run_root install -m 0644 "${backup_config}" "${ssh_config}"
    sshd -t >/dev/null 2>&1 || true
    vpskit_die "SSH config validation failed after install"
    return 1
  fi

  if ! vpskit_ssh_hardening_service_restart; then
    vpskit_run_root install -m 0644 "${backup_config}" "${ssh_config}"
    vpskit_ssh_hardening_service_restart >/dev/null 2>&1 || true
    vpskit_die "SSH service restart failed"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  vpskit_ssh_hardening_apply "$@"
fi
