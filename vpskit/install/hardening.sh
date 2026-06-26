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
  local detected_port

  if [ -n "${VPSKIT_SSH_PORT:-}" ]; then
    vpskit_validate_tcp_port "${VPSKIT_SSH_PORT}" || return 1
    printf '%s\n' "${VPSKIT_SSH_PORT}"
    return 0
  fi

  detected_port="$(vpskit_detect_ssh_port_from_sshd_t)"
  if [ -n "${detected_port}" ]; then
    printf '%s\n' "${detected_port}"
    return 0
  fi

  detected_port="$(vpskit_detect_ssh_port_from_config_files)"
  if [ -n "${detected_port}" ]; then
    printf '%s\n' "${detected_port}"
    return 0
  fi

  detected_port="$(vpskit_detect_ssh_port_from_listener)"
  if [ -n "${detected_port}" ]; then
    printf '%s\n' "${detected_port}"
    return 0
  fi

  vpskit_die "unable to confidently detect SSH port; set VPSKIT_SSH_PORT explicitly"
}

vpskit_validate_tcp_port() {
  local port="$1"

  case "${port}" in
    '' | *[!0-9]*)
      vpskit_die "invalid TCP port: ${port}"
      return 1
      ;;
  esac

  if [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
    vpskit_die "invalid TCP port: ${port}"
    return 1
  fi
}

vpskit_detect_ssh_port_from_sshd_t() {
  local output=""
  local port

  if [ -n "${VPSKIT_TEST_SSHD_T_OUTPUT+x}" ]; then
    output="${VPSKIT_TEST_SSHD_T_OUTPUT}"
  elif command -v sshd >/dev/null 2>&1; then
    output="$(sshd -T 2>/dev/null || true)"
  fi

  port="$(printf '%s\n' "${output}" | awk 'tolower($1) == "port" {print $2; exit}')"
  if [ -n "${port}" ]; then
    vpskit_validate_tcp_port "${port}" || return 1
    printf '%s\n' "${port}"
  fi
}

vpskit_detect_ssh_port_from_config_files() {
  local config_path
  local config_dir
  local port

  config_path="$(vpskit_sshd_config_path)"
  config_dir="${VPSKIT_TEST_SSHD_CONFIG_DIR:-/etc/ssh/sshd_config.d}"

  port="$(
    {
      [ -r "${config_path}" ] && printf '%s\n' "${config_path}"
      if [ -d "${config_dir}" ]; then
        find "${config_dir}" -maxdepth 1 -type f -name '*.conf' | sort
      fi
    } | while IFS= read -r file_path; do
      awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        tolower($1) == "port" { value = $2 }
        END { if (value != "") print value }
      ' "${file_path}"
    done | tail -n1
  )"

  if [ -n "${port}" ]; then
    vpskit_validate_tcp_port "${port}" || return 1
    printf '%s\n' "${port}"
  fi
}

vpskit_detect_ssh_port_from_listener() {
  local output=""
  local port

  if [ -n "${VPSKIT_TEST_SSHD_LISTENERS:-}" ]; then
    output="${VPSKIT_TEST_SSHD_LISTENERS}"
  elif command -v ss >/dev/null 2>&1; then
    output="$(ss -H -ltnp 2>/dev/null | grep -F 'sshd' || true)"
  fi

  port="$(printf '%s\n' "${output}" | awk '
    /sshd/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /:[0-9]+$/) {
          value = $i
          sub(/^.*:/, "", value)
          print value
          exit
        }
      }
    }
  ')"

  if [ -n "${port}" ]; then
    vpskit_validate_tcp_port "${port}" || return 1
    printf '%s\n' "${port}"
  fi
}

vpskit_authorized_keys_source() {
  printf '%s\n' "${VPSKIT_TEST_AUTHORIZED_KEYS_SOURCE:-/root/.ssh/authorized_keys}"
}

vpskit_validate_authorized_key_line() {
  local key_line="$1"

  case "${key_line}" in
    ssh-ed25519\ * | ssh-rsa\ * | ecdsa-sha2-*\ * | sk-ssh-*\ *)
      return 0
      ;;
    *)
      vpskit_die "invalid SSH public key format"
      return 1
      ;;
  esac
}

vpskit_read_explicit_authorized_key_content() {
  local key_line=""

  if [ -n "${VPSKIT_AUTHORIZED_KEY:-}" ]; then
    key_line="${VPSKIT_AUTHORIZED_KEY}"
  elif [ -n "${VPSKIT_AUTHORIZED_KEY_FILE:-}" ]; then
    if [ ! -r "${VPSKIT_AUTHORIZED_KEY_FILE}" ]; then
      vpskit_die "authorized key file is not readable: ${VPSKIT_AUTHORIZED_KEY_FILE}"
      return 1
    fi
    key_line="$(awk 'NF { print; exit }' "${VPSKIT_AUTHORIZED_KEY_FILE}")"
  else
    return 1
  fi

  printf '%s\n' "${key_line}"
}

vpskit_explicit_authorized_key_content() {
  local key_line

  key_line="$(vpskit_read_explicit_authorized_key_content)" || return 1
  vpskit_validate_authorized_key_line "${key_line}" || return 1
  printf '%s\n' "${key_line}"
}

vpskit_managed_authorized_keys_content() {
  local explicit_key

  explicit_key="$(vpskit_explicit_authorized_key_content 2>/dev/null || true)"
  if [ -n "${explicit_key}" ]; then
    printf '%s\n' "${explicit_key}"
    return 0
  fi

  cat "$(vpskit_authorized_keys_source)"
}

vpskit_require_root_ssh_key_source() {
  local authorized_keys
  local explicit_key

  if [ -n "${VPSKIT_AUTHORIZED_KEY:-}" ] || [ -n "${VPSKIT_AUTHORIZED_KEY_FILE:-}" ]; then
    explicit_key="$(vpskit_read_explicit_authorized_key_content)" || return 1
    vpskit_validate_authorized_key_line "${explicit_key}" || return 1
    return 0
  fi

  if [ "${VPSKIT_TEST_AUTHORIZED_KEYS_VALID:-}" = "yes" ]; then
    return 0
  fi

  authorized_keys="$(vpskit_authorized_keys_source)"
  if [ ! -s "${authorized_keys}" ]; then
    vpskit_die "root SSH authorized_keys is required before hardening SSH"
    return 1
  fi
}

vpskit_verify_managed_authorized_keys() {
  local managed_user="$1"
  local key_path
  local mode=""
  local owner=""

  case "${VPSKIT_TEST_AUTHORIZED_KEYS_VALID:-}" in
    yes)
      return 0
      ;;
    no)
      vpskit_die "managed user authorized_keys verification failed"
      return 1
      ;;
  esac

  key_path="/home/${managed_user}/.ssh/authorized_keys"
  if [ ! -s "${key_path}" ]; then
    vpskit_die "managed user authorized_keys verification failed: missing or empty ${key_path}"
    return 1
  fi

  mode="$(stat -c '%a' "${key_path}" 2>/dev/null || stat -f '%Lp' "${key_path}" 2>/dev/null || true)"
  owner="$(stat -c '%U:%G' "${key_path}" 2>/dev/null || true)"

  if [ "${mode}" != "600" ]; then
    vpskit_die "managed user authorized_keys verification failed: expected mode 600"
    return 1
  fi

  if [ -n "${owner}" ] && [ "${owner}" != "${managed_user}:${managed_user}" ]; then
    vpskit_die "managed user authorized_keys verification failed: expected owner ${managed_user}:${managed_user}"
    return 1
  fi
}

vpskit_authorized_keys_preflight() {
  local explicit_key

  if [ -n "${VPSKIT_AUTHORIZED_KEY:-}" ] || [ -n "${VPSKIT_AUTHORIZED_KEY_FILE:-}" ]; then
    explicit_key="$(vpskit_read_explicit_authorized_key_content)" || return 1
    vpskit_validate_authorized_key_line "${explicit_key}" || return 1
    return 0
  fi

  case "${VPSKIT_TEST_AUTHORIZED_KEYS_VALID:-}" in
    yes)
      return 0
      ;;
    no)
      vpskit_die "managed user authorized_keys verification failed"
      return 1
      ;;
  esac
}

vpskit_hardening_detect_server_ip() {
  if [ -n "${VPSKIT_SERVER_IP:-}" ]; then
    printf '%s\n' "${VPSKIT_SERVER_IP}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_PUBLIC_IP:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_PUBLIC_IP}"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null && return 0
  fi

  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}' && return 0
  fi

  printf '<server_ip>\n'
}

vpskit_test_list_contains_word() {
  local needle="$1"
  local item

  for item in ${VPSKIT_TEST_MISSING_COMMANDS:-}; do
    if [ "${item}" = "${needle}" ]; then
      return 0
    fi
  done

  return 1
}

vpskit_hardening_command_exists() {
  local command_name="$1"

  if vpskit_test_list_contains_word "${command_name}"; then
    return 1
  fi

  if vpskit_is_dry_run || [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
    return 0
  fi

  command -v "${command_name}" >/dev/null 2>&1
}

vpskit_hardening_missing_packages() {
  local packages=()

  vpskit_hardening_command_exists ufw || packages+=("ufw")
  vpskit_hardening_command_exists fail2ban-client || packages+=("fail2ban")
  vpskit_hardening_command_exists curl || packages+=("curl")
  vpskit_hardening_command_exists openssl || packages+=("openssl")
  vpskit_hardening_command_exists ss || packages+=("iproute2")

  printf '%s\n' "${packages[*]}"
}

vpskit_hardening_package_preflight() {
  local missing_packages

  vpskit_systemd_available || {
    vpskit_die "systemd/systemctl is required for Phase 1 hardening"
    return 1
  }

  missing_packages="$(vpskit_hardening_missing_packages)"
  if [ -z "${missing_packages}" ]; then
    return 0
  fi

  if ! vpskit_hardening_command_exists apt-get; then
    vpskit_die "missing required packages (${missing_packages}) and apt-get is unavailable"
    return 1
  fi

  vpskit_run_mutation apt-get update || return 1
  # shellcheck disable=SC2086
  vpskit_run_mutation apt-get install -y ${missing_packages}
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
  vpskit_write_managed_file "/home/${managed_user}/.ssh/authorized_keys" 0600 "$(vpskit_managed_authorized_keys_content)" || return 1
  vpskit_run_mutation chown -R "${managed_user}:${managed_user}" "/home/${managed_user}/.ssh" || return 1
  vpskit_run_mutation chmod 700 "/home/${managed_user}/.ssh" || return 1
  vpskit_run_mutation chmod 600 "/home/${managed_user}/.ssh/authorized_keys" || return 1
  vpskit_verify_managed_authorized_keys "${managed_user}" || return 1

  vpskit_write_managed_file "/etc/ssh/sshd_config.d/99-vpskit-hardening.conf" 0644 "${sshd_content}" || return 1
  vpskit_run_mutation sshd -t || return 1
  vpskit_run_mutation systemctl reload ssh.service || return 1

  vpskit_log_warn "UFW state changes cannot be fully rolled back automatically"
  vpskit_run_mutation ufw status verbose || true
  vpskit_run_mutation ufw allow "${ssh_port}/tcp" || return 1
  vpskit_run_mutation ufw default deny incoming || return 1
  vpskit_run_mutation ufw default allow outgoing || return 1
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
  vpskit_require_root_ssh_key_source || return 1
  vpskit_authorized_keys_preflight || return 1

  if ! vpskit_sshd_config_exists && ! vpskit_is_dry_run; then
    vpskit_die "sshd config is required before hardening"
    return 1
  fi

  ssh_port="$(vpskit_hardening_detect_ssh_port)" || return 1
  vpskit_hardening_package_preflight || return 1
  vpskit_transaction_init
  vpskit_hardening_apply "${managed_user}" "${ssh_port}" || status=$?

  if [ "${status}" -ne 0 ]; then
    vpskit_transaction_abort
    return "${status}"
  fi

  vpskit_transaction_commit
  printf 'HARDENING_USER=%s\n' "${managed_user}"
  printf 'SSH_PORT=%s\n' "${ssh_port}"
  printf 'Open a second terminal and verify: ssh -i <matching-private-key> -p %s %s@%s\n' "${ssh_port}" "${managed_user}" "$(vpskit_hardening_detect_server_ip)"
}
