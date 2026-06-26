#!/usr/bin/env bash

VPSKIT_HYSTERIA2_DEFAULT_RELEASE_TAG="app/v2.9.2"

vpskit_hysteria2_bin_path() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_BIN_PATH:-/usr/local/bin/hysteria}"
}

vpskit_hysteria2_service_name() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_SERVICE_NAME:-hysteria-server.service}"
}

vpskit_hysteria2_service_unit_name() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_SERVICE_UNIT_NAME:-hysteria-server}"
}

vpskit_hysteria2_config_dir() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_CONFIG_DIR:-/etc/hysteria}"
}

vpskit_hysteria2_config_path() {
  printf '%s/config.yaml\n' "$(vpskit_hysteria2_config_dir)"
}

vpskit_hysteria2_cert_path() {
  printf '%s/server.crt\n' "$(vpskit_hysteria2_config_dir)"
}

vpskit_hysteria2_key_path() {
  printf '%s/server.key\n' "$(vpskit_hysteria2_config_dir)"
}

vpskit_hysteria2_metadata_file() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_METADATA_FILE:-/var/lib/vpskit/hysteria2.env}"
}

vpskit_hysteria2_subscription_file() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE:-/var/lib/vpskit/hysteria2.yaml}"
}

vpskit_hysteria2_port() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_PORT:-443}"
}

vpskit_hysteria2_release_tag() {
  printf '%s\n' "${VPSKIT_HYSTERIA2_RELEASE_TAG:-${VPSKIT_HYSTERIA2_DEFAULT_RELEASE_TAG}}"
}

vpskit_hysteria2_release_asset() {
  local arch

  case "${VPSKIT_HYSTERIA2_ARCH:-$(uname -m)}" in
    x86_64 | amd64)
      arch="amd64"
      ;;
    aarch64 | arm64)
      arch="arm64"
      ;;
    armv7l | armv7)
      arch="armv7"
      ;;
    *)
      arch="$(uname -m)"
      ;;
  esac

  printf '%s\n' "${VPSKIT_HYSTERIA2_RELEASE_ASSET:-hysteria-linux-${arch}}"
}

vpskit_hysteria2_release_url() {
  printf 'https://github.com/apernet/hysteria/releases/download/%s/%s\n' \
    "$(vpskit_hysteria2_release_tag)" "$(vpskit_hysteria2_release_asset)"
}

vpskit_hysteria2_password() {
  if [ -n "${VPSKIT_TEST_HYSTERIA2_PASSWORD:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_HYSTERIA2_PASSWORD}"
    return 0
  fi

  openssl rand -hex 32
}

vpskit_hysteria2_public_ip() {
  if [ -n "${VPSKIT_TEST_PUBLIC_IP:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_PUBLIC_IP}"
    return 0
  fi

  if [ -n "${VPSKIT_PUBLIC_IPV4:-}" ]; then
    printf '%s\n' "${VPSKIT_PUBLIC_IPV4}"
    return 0
  fi

  if vpskit_is_test_mode; then
    vpskit_die "unable to detect public IP in test mode"
    return 1
  fi

  curl -4 -fsS --max-time 10 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

vpskit_hysteria2_cert_pin_sha256() {
  local cert_path="$1"

  if [ -n "${VPSKIT_TEST_HYSTERIA2_PIN_SHA256:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_HYSTERIA2_PIN_SHA256}"
    return 0
  fi

  if vpskit_is_test_mode; then
    printf 'TEST-HYSTERIA2-PIN-SHA256\n'
    return 0
  fi

  openssl x509 -in "${cert_path}" -noout -pubkey \
    | openssl pkey -pubin -outform der \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A
}

vpskit_hysteria2_ufw_status() {
  if [ -n "${VPSKIT_TEST_UFW_STATUS:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_UFW_STATUS}"
    return 0
  fi

  vpskit_ufw_status
}

vpskit_hysteria2_ufw_allows_443_udp() {
  local ufw_status="$1"

  printf '%s\n' "${ufw_status}" | awk '
    {
      line = $0
      sub(/^[[:space:]]*\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]*/, "", line)
      if (line ~ /\(v6\)/) {
        next
      }

      field_count = split(line, fields, /[[:space:]]+/)
      if (fields[1] != "443/udp") {
        next
      }

      for (i = 2; i <= field_count; i++) {
        if (fields[i] == "ALLOW") {
          found = 1
        }
      }
    }
    END { exit !found }
  '
}

vpskit_hysteria2_udp_443_owner() {
  local output=""

  if [ -n "${VPSKIT_TEST_UDP_443_OWNER:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_UDP_443_OWNER}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_UDP_443_LISTENERS:-}" ]; then
    output="${VPSKIT_TEST_UDP_443_LISTENERS}"
  elif command -v ss >/dev/null 2>&1; then
    output="$(ss -H -lunp 'sport = :443' 2>/dev/null || true)"
  else
    printf 'unknown\n'
    return 0
  fi

  if [ -z "${output}" ]; then
    printf 'unknown\n'
    return 0
  fi

  printf '%s\n' "${output}" | awk '
    match($0, /"([^"]+)"/, match_result) {
      if (match_result[1] ~ /hysteria/) {
        print "hysteria"
      } else {
        print match_result[1]
      }
      found = 1
      exit
    }
    /hysteria/ { print "hysteria"; found = 1; exit }
    NF && !found { print "unknown"; found = 1; exit }
  '
}

vpskit_hysteria2_missing_packages() {
  local packages=()

  if vpskit_is_test_mode && [ -z "${VPSKIT_TEST_MISSING_COMMANDS:-}" ]; then
    printf '\n'
    return 0
  fi

  vpskit_command_exists curl || packages+=("curl")
  vpskit_command_exists openssl || packages+=("openssl")
  vpskit_command_exists update-ca-certificates || packages+=("ca-certificates")

  printf '%s\n' "${packages[*]}"
}

vpskit_hysteria2_package_preflight() {
  local missing_packages

  missing_packages="$(vpskit_hysteria2_missing_packages)"
  if [ -z "${missing_packages}" ]; then
    return 0
  fi

  if vpskit_is_test_mode; then
    if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
      printf 'RUN apt-get update\n' >>"${VPSKIT_TEST_COMMAND_LOG}"
      printf 'RUN apt-get install -y %s\n' "${missing_packages}" >>"${VPSKIT_TEST_COMMAND_LOG}"
    else
      vpskit_dry_run_log "RUN apt-get update"
      vpskit_dry_run_log "RUN apt-get install -y ${missing_packages}"
    fi
    return 0
  fi

  if ! vpskit_command_exists apt-get; then
    vpskit_die "missing required packages (${missing_packages}) and apt-get is unavailable"
    return 1
  fi

  vpskit_run_mutation apt-get update || return 1
  # shellcheck disable=SC2086
  vpskit_run_mutation apt-get install -y ${missing_packages}
}

vpskit_hysteria2_install_binary() {
  local bin_path
  local tmp_path=""
  local bin_dir
  local backup_path=""

  bin_path="$(vpskit_system_path "$(vpskit_hysteria2_bin_path)")"
  bin_dir="$(dirname "${bin_path}")"

  if vpskit_is_test_mode; then
    mkdir -p "${bin_dir}"
    if [ -e "${bin_path}" ]; then
      backup_path="$(mktemp)"
      cp -a "${bin_path}" "${backup_path}"
      vpskit_rollback_add "cp -a $(vpskit_shell_quote "${backup_path}") $(vpskit_shell_quote "${bin_path}")" || return 1
      vpskit_rollback_add "rm -f $(vpskit_shell_quote "${backup_path}")" || return 1
    else
      vpskit_rollback_add "rm -f $(vpskit_shell_quote "${bin_path}")" || return 1
    fi
    printf '#!/usr/bin/env bash\nexit 0\n' >"${bin_path}"
    chmod 0755 "${bin_path}"
    if [ -n "${VPSKIT_HYSTERIA2_INSTALL_COMMAND:-}" ]; then
      if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
        printf 'RUN %s\n' "${VPSKIT_HYSTERIA2_INSTALL_COMMAND}" >>"${VPSKIT_TEST_COMMAND_LOG}"
      else
        vpskit_dry_run_log "RUN ${VPSKIT_HYSTERIA2_INSTALL_COMMAND}"
      fi
    fi
    return 0
  fi

  if [ -n "${VPSKIT_HYSTERIA2_INSTALL_COMMAND:-}" ]; then
    bash -lc "${VPSKIT_HYSTERIA2_INSTALL_COMMAND}" || return 1
    [ -x "${bin_path}" ] || vpskit_die "hysteria binary is not available after installer command"
    return $?
  fi

  tmp_path="$(mktemp)"
  if ! curl -fsSL -o "${tmp_path}" "$(vpskit_hysteria2_release_url)"; then
    rm -f "${tmp_path}"
    return 1
  fi

  mkdir -p "${bin_dir}"
  if [ -e "${bin_path}" ]; then
    backup_path="$(mktemp)"
    cp -a "${bin_path}" "${backup_path}"
    vpskit_rollback_add "cp -a $(vpskit_shell_quote "${backup_path}") $(vpskit_shell_quote "${bin_path}")" || {
      rm -f "${tmp_path}" "${backup_path}"
      return 1
    }
    vpskit_rollback_add "rm -f $(vpskit_shell_quote "${backup_path}")" || {
      rm -f "${tmp_path}" "${backup_path}"
      return 1
    }
  else
    vpskit_rollback_add "rm -f $(vpskit_shell_quote "${bin_path}")" || {
      rm -f "${tmp_path}"
      return 1
    }
  fi
  install -m 0755 "${tmp_path}" "${bin_path}" || {
    rm -f "${tmp_path}"
    return 1
  }
  rm -f "${tmp_path}"
}

vpskit_hysteria2_generate_cert_bundle() {
  local server_ip="$1"
  local cert_path="$2"
  local key_path="$3"
  local tmp_config
  local pin_sha256=""

  if vpskit_is_test_mode; then
    vpskit_write_managed_file "${key_path}" 0600 "TEST-HYSTERIA2-PRIVATE-KEY ${server_ip}"
    vpskit_write_managed_file "${cert_path}" 0644 "TEST-HYSTERIA2-CERT ${server_ip}"
    pin_sha256="$(vpskit_hysteria2_cert_pin_sha256 "${cert_path}")"
    printf '%s\n' "${pin_sha256}"
    return 0
  fi

  mkdir -p "$(dirname "${cert_path}")"
  tmp_config="$(mktemp)"
  cat >"${tmp_config}" <<EOF
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
x509_extensions = req_ext
prompt = no

[ req_distinguished_name ]
CN = ${server_ip}

[ req_ext ]
subjectAltName = IP:${server_ip}
EOF

  if ! openssl req -x509 -newkey rsa:2048 -nodes -keyout "${key_path}" -out "${cert_path}" -days 3650 -sha256 -config "${tmp_config}" >/dev/null 2>&1; then
    rm -f "${tmp_config}"
    return 1
  fi

  chmod 0600 "${key_path}"
  chmod 0644 "${cert_path}"
  rm -f "${tmp_config}"
  vpskit_hysteria2_cert_pin_sha256 "${cert_path}"
}

vpskit_hysteria2_render_server_config() {
  local password="$1"
  local cert_path="$2"
  local key_path="$3"

  cat <<EOF
listen: :443
auth:
  type: password
  password: ${password}
tls:
  cert: ${cert_path}
  key: ${key_path}
# VPSKit keeps the server config minimal on purpose.
# Masquerade is intentionally omitted so the self-signed TLS setup stays simple.
EOF
}

vpskit_hysteria2_render_client_config() {
  local server_ip="$1"
  local password="$2"
  local pin_sha256="$3"

  cat <<EOF
server: ${server_ip}:443
auth: ${password}
tls:
  sni: ${server_ip}
  pinSHA256: ${pin_sha256}
EOF
}

vpskit_hysteria2_service_state() {
  if ! vpskit_systemd_available; then
    printf 'unknown\n'
    return 0
  fi

  if vpskit_service_active "$(vpskit_hysteria2_service_name)" || vpskit_service_active "$(vpskit_hysteria2_service_unit_name).service"; then
    printf 'active\n'
    return 0
  fi

  if vpskit_service_exists "$(vpskit_hysteria2_service_name)" || vpskit_service_exists "$(vpskit_hysteria2_service_unit_name).service"; then
    printf 'inactive\n'
    return 0
  fi

  printf 'missing\n'
}

vpskit_hysteria2_stop_service_on_failure() {
  local service_name

  service_name="$(vpskit_hysteria2_service_name)"

  if vpskit_is_test_mode; then
    if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
      printf 'RUN systemctl stop %s\n' "${service_name}" >>"${VPSKIT_TEST_COMMAND_LOG}"
    else
      vpskit_dry_run_log "RUN systemctl stop ${service_name}"
    fi
    return 0
  fi

  if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
    printf 'RUN systemctl stop %s\n' "${service_name}" >>"${VPSKIT_TEST_COMMAND_LOG}"
    return 0
  fi

  systemctl stop "${service_name}" || true
}

vpskit_hysteria2_udp_443_listener_owner() {
  local output=""

  if [ -n "${VPSKIT_TEST_UDP_443_OWNER:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_UDP_443_OWNER}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_UDP_443_LISTENERS:-}" ]; then
    output="${VPSKIT_TEST_UDP_443_LISTENERS}"
  elif vpskit_is_test_mode; then
    return 2
  elif command -v ss >/dev/null 2>&1; then
    output="$(ss -H -lunp 'sport = :443' 2>/dev/null || true)"
  else
    return 2
  fi

  if [ -z "${output}" ]; then
    printf 'unknown\n'
    return 1
  fi

  printf '%s\n' "${output}" | awk '
    match($0, /"([^"]+)"/, match_result) {
      if (match_result[1] ~ /hysteria/) {
        print "hysteria"
      } else {
        print match_result[1]
      }
      found = 1
      exit
    }
    /hysteria/ { print "hysteria"; found = 1; exit }
    NF && !found { print "unknown"; found = 1; exit }
  '
}

vpskit_hysteria2_validate_udp_443_listener() {
  local owner=""
  local owner_status=0

  if owner="$(vpskit_hysteria2_udp_443_listener_owner)"; then
    owner_status=0
  else
    owner_status=$?
  fi

  if [ "${owner_status}" -eq 2 ]; then
    return 2
  fi

  if [ "${owner}" = "hysteria" ]; then
    printf 'UDP_443_LISTENER=pass service=hysteria\n'
    return 0
  fi

  printf 'UDP_443_LISTENER=fail expected=hysteria actual=%s\n' "${owner}"
  return 1
}

vpskit_hysteria2_wait_for_service_active() {
  local attempts=0
  local max_attempts=5
  local state="unknown"

  if ! vpskit_is_test_mode; then
    sleep 1
  fi

  while [ "${attempts}" -lt "${max_attempts}" ]; do
    state="$(vpskit_hysteria2_service_state)"
    if [ "${state}" = "active" ]; then
      printf '%s\n' "${state}"
      return 0
    fi

    attempts=$((attempts + 1))
    if vpskit_is_test_mode || [ "${attempts}" -ge "${max_attempts}" ]; then
      break
    fi
    sleep 1
  done

  printf '%s\n' "${state}"
  return 1
}

vpskit_hysteria2_render_metadata() {
  local server_ip="$1"
  local password="$2"
  local pin_sha256="$3"

  cat <<EOF
VPSKIT_HYSTERIA2_SERVER_IP=${server_ip}
VPSKIT_HYSTERIA2_PORT=443
VPSKIT_HYSTERIA2_PASSWORD=${password}
VPSKIT_HYSTERIA2_PIN_SHA256=${pin_sha256}
VPSKIT_HYSTERIA2_SERVICE_NAME=$(vpskit_hysteria2_service_name)
VPSKIT_HYSTERIA2_CONFIG_PATH=$(vpskit_hysteria2_config_path)
VPSKIT_HYSTERIA2_SUBSCRIPTION_FILE=$(vpskit_hysteria2_subscription_file)
EOF
}

vpskit_hysteria2_render_service_unit() {
  local bin_path="$1"
  local config_path="$2"

  cat <<EOF
[Unit]
Description=Hysteria2 Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${bin_path} server -c ${config_path}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
}

vpskit_hysteria2_ensure_root_owns_system_paths() {
  mkdir -p "$(dirname "$(vpskit_hysteria2_config_path)")"
  mkdir -p "$(dirname "$(vpskit_hysteria2_subscription_file)")"
}

vpskit_install_hysteria2() {
  local port
  local server_ip
  local password
  local cert_path
  local key_path
  local config_path
  local subscription_file
  local metadata_file
  local service_unit_path
  local bin_path
  local pin_sha256
  local server_config
  local client_config
  local metadata
  local service_unit
  local service_state
  local listener_status=0
  local ufw_status=""
  local ufw_summary=""
  local status=0

  vpskit_require_root || return 1
  vpskit_require_supported_ubuntu || return 1
  vpskit_systemd_available || {
    printf 'HYSTERIA2_INSTALL=fail reason=systemd_unavailable\n'
    return 1
  }
  if vpskit_is_test_mode && [ -z "${VPSKIT_TEST_ROOT_DIR:-}" ]; then
    printf 'HYSTERIA2_INSTALL=fail reason=test_mode_requires_rootfs\n'
    return 1
  fi

  port="$(vpskit_hysteria2_port)"
  if [ "${port}" != "443" ]; then
    vpskit_die "Hysteria2 is currently locked to UDP 443"
    return 1
  fi

  if [ -n "${VPSKIT_TEST_UDP_PORT_IN_USE:-}" ] && [ "${VPSKIT_TEST_UDP_PORT_IN_USE}" = "${port}" ]; then
    printf 'HYSTERIA2_INSTALL=fail reason=udp_443_in_use\n'
    return 1
  fi

  if ! vpskit_is_test_mode; then
    if command -v ss >/dev/null 2>&1; then
      if ss -H -lun "sport = :${port}" 2>/dev/null | grep -q .; then
        printf 'HYSTERIA2_INSTALL=fail reason=udp_443_in_use\n'
        return 1
      fi
    elif command -v lsof >/dev/null 2>&1; then
      if lsof -nP -iUDP:"${port}" 2>/dev/null | grep -q .; then
        printf 'HYSTERIA2_INSTALL=fail reason=udp_443_in_use\n'
        return 1
      fi
    else
      printf 'HYSTERIA2_INSTALL=fail reason=udp_443_check_unavailable\n'
      return 1
    fi
  fi

  vpskit_hysteria2_package_preflight || return 1
  vpskit_transaction_init

  bin_path="$(vpskit_system_path "$(vpskit_hysteria2_bin_path)")"
  cert_path="$(vpskit_hysteria2_cert_path)"
  key_path="$(vpskit_hysteria2_key_path)"
  config_path="$(vpskit_hysteria2_config_path)"
  subscription_file="$(vpskit_hysteria2_subscription_file)"
  metadata_file="$(vpskit_hysteria2_metadata_file)"
  service_unit_path="/etc/systemd/system/$(vpskit_hysteria2_service_name)"

  if [ "${status}" -eq 0 ]; then
    server_ip="$(vpskit_hysteria2_public_ip)" || status=$?
    password="$(vpskit_hysteria2_password)" || status=$?
  fi

  if [ "${status}" -eq 0 ] && { [ -z "${server_ip}" ] || [ -z "${password}" ]; }; then
    vpskit_die "failed to generate Hysteria2 values"
    status=1
  fi

  if [ "${status}" -eq 0 ]; then
    if vpskit_hysteria2_install_binary; then
      vpskit_rollback_add "rm -f $(vpskit_shell_quote "${bin_path}")" || status=$?
    else
      status=$?
    fi
  fi

  if [ "${status}" -eq 0 ]; then
    pin_sha256="$(vpskit_hysteria2_generate_cert_bundle "${server_ip}" "${cert_path}" "${key_path}")" || status=$?
  fi

  if [ "${status}" -eq 0 ] && [ -z "${pin_sha256}" ]; then
    vpskit_die "failed to generate Hysteria2 certificate pin"
    status=1
  fi

  if [ "${status}" -eq 0 ]; then
    server_config="$(vpskit_hysteria2_render_server_config "${password}" "${cert_path}" "${key_path}")"
    client_config="$(vpskit_hysteria2_render_client_config "${server_ip}" "${password}" "${pin_sha256}")"
    metadata="$(vpskit_hysteria2_render_metadata "${server_ip}" "${password}" "${pin_sha256}")"
    service_unit="$(vpskit_hysteria2_render_service_unit "${bin_path}" "${config_path}")"
  fi

  if [ "${status}" -eq 0 ]; then
    vpskit_write_managed_file "${config_path}" 0644 "${server_config}" || status=$?
    vpskit_write_managed_file "${subscription_file}" 0600 "${client_config}" || status=$?
    vpskit_write_managed_file "${metadata_file}" 0600 "${metadata}" || status=$?
    vpskit_write_managed_file "${service_unit_path}" 0644 "${service_unit}" || status=$?
  fi

  if [ "${status}" -eq 0 ]; then
    if vpskit_is_test_mode; then
      if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
        {
          printf 'RUN systemctl daemon-reload\n'
          printf 'RUN systemctl enable %s\n' "$(vpskit_hysteria2_service_name)"
          printf 'RUN systemctl restart %s\n' "$(vpskit_hysteria2_service_name)"
        } >>"${VPSKIT_TEST_COMMAND_LOG}"
      else
        vpskit_dry_run_log "RUN systemctl daemon-reload"
        vpskit_dry_run_log "RUN systemctl enable $(vpskit_hysteria2_service_name)"
        vpskit_dry_run_log "RUN systemctl restart $(vpskit_hysteria2_service_name)"
      fi
    elif [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
      {
        printf 'RUN systemctl daemon-reload\n'
        printf 'RUN systemctl enable %s\n' "$(vpskit_hysteria2_service_name)"
        printf 'RUN systemctl restart %s\n' "$(vpskit_hysteria2_service_name)"
      } >>"${VPSKIT_TEST_COMMAND_LOG}"
    else
      vpskit_run_mutation systemctl daemon-reload || status=$?
      vpskit_run_mutation systemctl enable "$(vpskit_hysteria2_service_name)" || status=$?
      vpskit_run_mutation systemctl restart "$(vpskit_hysteria2_service_name)" || status=$?
    fi
  fi

  if [ "${status}" -eq 0 ]; then
    service_state="$(vpskit_hysteria2_wait_for_service_active)" || status=$?
    if [ "${status}" -ne 0 ]; then
      vpskit_hysteria2_stop_service_on_failure
      vpskit_transaction_abort
      printf 'HYSTERIA2_INSTALL=fail reason=service_inactive\n'
      printf 'HYSTERIA2_SERVICE=fail state=%s\n' "${service_state}"
      return 1
    fi
  fi

  if [ "${status}" -eq 0 ]; then
    if vpskit_hysteria2_validate_udp_443_listener; then
      listener_status=0
    else
      listener_status=$?
    fi
    case "${listener_status}" in
      0)
        :
        ;;
      2)
        :
        ;;
      *)
        vpskit_hysteria2_stop_service_on_failure
        vpskit_transaction_abort
        printf 'HYSTERIA2_INSTALL=fail reason=udp_443_not_bound\n'
        return 1
        ;;
    esac
  fi

  if [ "${status}" -eq 0 ]; then
    ufw_status="$(vpskit_hysteria2_ufw_status 2>/dev/null || true)"
    if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
      ufw_summary="UFW_443_UDP=skip reason=ufw_unavailable"
    elif printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
      ufw_summary="UFW_443_UDP=skip status=inactive reason=not_enforced"
    elif printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
      if vpskit_is_test_mode; then
        if [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
          {
            printf 'RUN ufw allow 443/udp\n'
            printf 'RUN ufw reload\n'
          } >>"${VPSKIT_TEST_COMMAND_LOG}"
        else
          vpskit_dry_run_log "RUN ufw allow 443/udp"
          vpskit_dry_run_log "RUN ufw reload"
        fi
      elif [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
        {
          printf 'RUN ufw allow 443/udp\n'
          printf 'RUN ufw reload\n'
        } >>"${VPSKIT_TEST_COMMAND_LOG}"
      else
        vpskit_run_mutation ufw allow 443/udp || status=$?
        vpskit_run_mutation ufw reload || status=$?
      fi

      if [ "${status}" -eq 0 ]; then
        ufw_summary="UFW_443_UDP=pass status=active rule=present"
      fi
    else
      ufw_summary="UFW_443_UDP=skip status=unknown"
    fi
  fi

  if [ "${status}" -ne 0 ]; then
    vpskit_transaction_abort
    printf 'HYSTERIA2_INSTALL=fail\n'
    return "${status}"
  fi

  vpskit_transaction_commit
  printf 'HYSTERIA2_INSTALL=pass\n'
  printf 'HYSTERIA2_PORT=%s/udp\n' "${port}"
  printf 'HYSTERIA2_SERVICE=active\n'
  printf 'HYSTERIA2_CONFIG=%s\n' "${config_path}"
  printf 'HYSTERIA2_SUBSCRIPTION_FILE=%s\n' "${subscription_file}"
  if [ -n "${ufw_summary}" ]; then
    printf '%s\n' "${ufw_summary}"
  fi
}
