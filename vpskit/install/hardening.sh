#!/usr/bin/env bash

vpskit_hardening_managed_user() {
  printf '%s\n' "${VPSKIT_MANAGED_USER:-alex}"
}

vpskit_validate_managed_user() {
  local managed_user="$1"

  if [[ "${managed_user}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
    return 0
  fi

  vpskit_die "invalid managed user: ${managed_user}"
}

vpskit_hardening_detect_ssh_port() {
  local configured_port

  if [ -n "${VPSKIT_SSH_PORT:-}" ]; then
    printf '%s\n' "${VPSKIT_SSH_PORT}"
    return 0
  fi

  configured_port="$(vpskit_sshd_effective_value Port 2>/dev/null || true)"
  printf '%s\n' "${configured_port:-22}"
}

vpskit_require_root_ssh_key_safety() {
  local authorized_keys

  if vpskit_is_dry_run || [ -n "${VPSKIT_TEST_ROOT_DIR:-}" ]; then
    return 0
  fi

  authorized_keys="/root/.ssh/authorized_keys"
  if [ ! -s "${authorized_keys}" ]; then
    vpskit_die "root SSH authorized_keys is required before hardening SSH"
    return 1
  fi
}

vpskit_managed_user_exists() {
  local managed_user="$1"

  if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ] || vpskit_is_dry_run; then
    return 1
  fi

  id "${managed_user}" >/dev/null 2>&1
}

vpskit_hardening_fail2ban_content() {
  local ssh_port="$1"

  cat <<EOF
[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
}

vpskit_hardening_sshd_dropin_content() {
  local ssh_port="$1"

  cat <<EOF
# Managed by VPSKit Phase 1 hardening.
Port ${ssh_port}
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
X11Forwarding no
EOF
}

vpskit_hardening_apply() {
  local managed_user="$1"
  local ssh_port="$2"
  local fail2ban_content
  local sshd_content

  fail2ban_content="$(vpskit_hardening_fail2ban_content "${ssh_port}")"
  sshd_content="$(vpskit_hardening_sshd_dropin_content "${ssh_port}")"

  if ! vpskit_managed_user_exists "${managed_user}"; then
    vpskit_run_mutation useradd --create-home --shell /bin/bash "${managed_user}" || return 1
  fi
  vpskit_run_mutation usermod -aG sudo "${managed_user}" || return 1
  vpskit_write_managed_file "/etc/sudoers.d/90-${managed_user}" 0440 "${managed_user} ALL=(ALL) NOPASSWD:ALL" || return 1
  vpskit_run_mutation mkdir -p "/home/${managed_user}/.ssh" || return 1
  vpskit_run_mutation cp /root/.ssh/authorized_keys "/home/${managed_user}/.ssh/authorized_keys" || return 1
  vpskit_run_mutation chown -R "${managed_user}:${managed_user}" "/home/${managed_user}/.ssh" || return 1
  vpskit_run_mutation chmod 700 "/home/${managed_user}/.ssh" || return 1
  vpskit_run_mutation chmod 600 "/home/${managed_user}/.ssh/authorized_keys" || return 1

  vpskit_write_managed_file "/etc/ssh/sshd_config.d/99-vpskit-hardening.conf" 0644 "${sshd_content}" || return 1
  vpskit_run_mutation sshd -t || return 1
  vpskit_run_mutation systemctl reload ssh.service || return 1

  vpskit_run_mutation ufw --force reset || return 1
  vpskit_run_mutation ufw default deny incoming || return 1
  vpskit_run_mutation ufw default allow outgoing || return 1
  vpskit_run_mutation ufw allow "${ssh_port}/tcp" || return 1
  vpskit_run_mutation ufw --force enable || return 1

  vpskit_write_managed_file "/etc/fail2ban/jail.d/sshd.local" 0644 "${fail2ban_content}" || return 1
  vpskit_run_mutation systemctl enable fail2ban || return 1
  vpskit_run_mutation systemctl restart fail2ban || return 1
}

vpskit_install_hardening() {
  local managed_user
  local ssh_port
  local status=0

  managed_user="$(vpskit_hardening_managed_user)"
  vpskit_validate_managed_user "${managed_user}" || return 1
  vpskit_require_root || return 1
  vpskit_require_ubuntu_2404 || return 1
  vpskit_require_root_ssh_key_safety || return 1

  if ! vpskit_sshd_config_exists && ! vpskit_is_dry_run; then
    vpskit_die "sshd config is required before hardening"
    return 1
  fi

  ssh_port="$(vpskit_hardening_detect_ssh_port)" || return 1
  vpskit_transaction_init
  vpskit_hardening_apply "${managed_user}" "${ssh_port}" || status=$?

  if [ "${status}" -ne 0 ]; then
    vpskit_transaction_abort
    return "${status}"
  fi

  vpskit_transaction_commit
  printf 'HARDENING_USER=%s\n' "${managed_user}"
  printf 'SSH_PORT=%s\n' "${ssh_port}"
}
