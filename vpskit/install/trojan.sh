#!/usr/bin/env bash

VPSKIT_TROJAN_DEFAULT_PORT="8443"

# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${BASH_SOURCE[0]%/*}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${BASH_SOURCE[0]%/*}/../core/system_check.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/vless_reality.sh
source "${BASH_SOURCE[0]%/*}/vless_reality.sh"

vpskit_trojan_port() {
  printf '%s\n' "${VPSKIT_TROJAN_PORT:-${VPSKIT_TROJAN_DEFAULT_PORT}}"
}

vpskit_trojan_config_path() {
  vpskit_vless_config_path
}

vpskit_trojan_config_dir() {
  printf '%s\n' "${VPSKIT_TROJAN_CONFIG_DIR:-/etc/vpskit/trojan}"
}

vpskit_trojan_cert_path() {
  printf '%s/server.crt\n' "$(vpskit_trojan_config_dir)"
}

vpskit_trojan_key_path() {
  printf '%s/server.key\n' "$(vpskit_trojan_config_dir)"
}

vpskit_trojan_subscription_file() {
  printf '%s\n' "${VPSKIT_TROJAN_SUBSCRIPTION_FILE:-/var/lib/vpskit/trojan.yaml}"
}

vpskit_trojan_env_file() {
  printf '%s\n' "${VPSKIT_TROJAN_ENV_FILE:-/var/lib/vpskit/trojan.env}"
}

vpskit_trojan_service_name() {
  printf '%s\n' "xray"
}

vpskit_trojan_xray_runtime_user() {
  local user=""

  if [ -n "${VPSKIT_TEST_XRAY_USER:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_XRAY_USER}"
    return 0
  fi

  user="$(systemctl show xray.service -p User --value 2>/dev/null || true)"
  if [ -z "${user}" ]; then
    user="root"
  fi

  printf '%s\n' "${user}"
}

vpskit_trojan_xray_runtime_group() {
  local user="$1"
  local group=""

  if [ -n "${VPSKIT_TEST_XRAY_GROUP:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_XRAY_GROUP}"
    return 0
  fi

  group="$(systemctl show xray.service -p Group --value 2>/dev/null || true)"
  if [ -z "${group}" ]; then
    if [ "${user}" = "nobody" ] && getent group nogroup >/dev/null 2>&1; then
      group="nogroup"
    else
      group="$(id -gn "${user}" 2>/dev/null || true)"
    fi
  fi

  if [ -z "${group}" ]; then
    group="root"
  fi

  printf '%s\n' "${group}"
}

vpskit_trojan_apply_tls_permissions() {
  local config_dir
  local xray_user="${1:-}"
  local xray_group="${2:-}"

  config_dir="$(vpskit_trojan_config_dir)"

  if [ -z "${xray_user}" ]; then
    xray_user="$(vpskit_trojan_xray_runtime_user)"
  fi

  if [ -z "${xray_group}" ]; then
    xray_group="$(vpskit_trojan_xray_runtime_group "${xray_user}")"
  fi

  vpskit_run_mutation chown -R "${xray_user}:${xray_group}" "${config_dir}" || return 1
  vpskit_run_mutation chmod 750 "${config_dir}" || return 1
  vpskit_run_mutation chmod 644 "$(vpskit_trojan_cert_path)" || return 1
  vpskit_run_mutation chmod 600 "$(vpskit_trojan_key_path)" || return 1
}

vpskit_trojan_validate_candidate_xray_config() {
  local xray_bin="$1"
  local candidate_config_path="$2"

  if [ -z "${xray_bin}" ] || [ ! -x "${xray_bin}" ]; then
    return 1
  fi

  "${xray_bin}" run -test -config "${candidate_config_path}"
}

vpskit_trojan_candidate_xray_config_path() {
  mktemp "${TMPDIR:-/tmp}/vpskit-xray-candidate.XXXXXX.json"
}

vpskit_trojan_rollback_install_failure() {
  local xray_service_state=""
  local tcp_443_owner=""
  local rollback_status=0

  vpskit_transaction_abort || rollback_status=$?

  if [ "${rollback_status}" -eq 0 ]; then
    vpskit_run_mutation systemctl restart xray || rollback_status=$?
  fi

  if [ "${rollback_status}" -eq 0 ]; then
    if ! vpskit_is_test_mode; then
      sleep 1
    fi

    xray_service_state="$(vpskit_vless_xray_service_summary)"
    tcp_443_owner="$(vpskit_trojan_tcp_443_owner)"
    if [ "${xray_service_state}" != "active" ] || [ "${tcp_443_owner}" != "xray" ]; then
      rollback_status=1
    fi
  fi

  if [ "${rollback_status}" -eq 0 ]; then
    printf 'XRAY_ROLLBACK=pass reason=trojan_install_failed\n'
  else
    printf 'XRAY_ROLLBACK=fail reason=restore_failed\n'
  fi

  return "${rollback_status}"
}

vpskit_trojan_server_state_value() {
  local key="$1"
  local subscription_file

  subscription_file="$(vpskit_system_path "$(vpskit_trojan_subscription_file)")"
  if [ ! -f "${subscription_file}" ]; then
    return 1
  fi

  python3 - "${subscription_file}" "${key}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
needle = sys.argv[2]
values = {}

for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or ":" not in line:
        continue
    key, value = line.split(":", 1)
    values[key.strip()] = value.strip().strip("'\"")

print(values.get(needle, ""))
PY
}

vpskit_trojan_server_address() {
  local existing=""

  existing="$(vpskit_trojan_server_state_value server 2>/dev/null || true)"
  if [ -n "${existing}" ]; then
    printf '%s\n' "${existing}"
    return 0
  fi

  if [ -n "${VPSKIT_TROJAN_SERVER:-}" ]; then
    printf '%s\n' "${VPSKIT_TROJAN_SERVER}"
    return 0
  fi

  if [ -n "${VPSKIT_SERVER_IP:-}" ]; then
    printf '%s\n' "${VPSKIT_SERVER_IP}"
    return 0
  fi

  if [ -n "${VPSKIT_PUBLIC_IPV4:-}" ]; then
    printf '%s\n' "${VPSKIT_PUBLIC_IPV4}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_PUBLIC_IP:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_PUBLIC_IP}"
    return 0
  fi

  vpskit_detect_public_ip
}

vpskit_trojan_sni() {
  local existing=""
  local server_address

  existing="$(vpskit_trojan_server_state_value sni 2>/dev/null || true)"
  if [ -n "${existing}" ]; then
    printf '%s\n' "${existing}"
    return 0
  fi

  if [ -n "${VPSKIT_TROJAN_SNI:-}" ]; then
    printf '%s\n' "${VPSKIT_TROJAN_SNI}"
    return 0
  fi

  server_address="$(vpskit_trojan_server_address)"
  printf '%s\n' "${server_address}"
}

vpskit_trojan_password() {
  local existing=""

  existing="$(vpskit_trojan_server_state_value password 2>/dev/null || true)"
  if [ -n "${existing}" ]; then
    printf '%s\n' "${existing}"
    return 0
  fi

  if [ -n "${VPSKIT_TROJAN_PASSWORD:-}" ]; then
    printf '%s\n' "${VPSKIT_TROJAN_PASSWORD}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_TROJAN_PASSWORD:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TROJAN_PASSWORD}"
    return 0
  fi

  openssl rand -hex 32
}

vpskit_trojan_allow_insecure() {
  local existing=""

  existing="$(vpskit_trojan_server_state_value allowInsecure 2>/dev/null || true)"
  if [ -n "${existing}" ]; then
    printf '%s\n' "${existing}"
    return 0
  fi

  printf '1\n'
}

vpskit_trojan_read_existing_config_json() {
  local config_path

  config_path="$(vpskit_system_path "$(vpskit_trojan_config_path)")"
  if [ ! -f "${config_path}" ]; then
    return 1
  fi

  cat "${config_path}"
}

vpskit_trojan_xray_config_state() {
  local config_path
  local state

  config_path="$(vpskit_system_path "$(vpskit_trojan_config_path)")"
  if [ ! -f "${config_path}" ]; then
    printf 'missing\n'
    return 0
  fi

  state="$(
    python3 - "${config_path}" <<'PY'
from pathlib import Path
import json
import sys

config_path = Path(sys.argv[1])

try:
    payload = json.loads(config_path.read_text(encoding="utf-8"))
except Exception:
    print("missing")
    raise SystemExit(0)

for inbound in payload.get("inbounds", []):
    if inbound.get("port") == 8443 and inbound.get("protocol") == "trojan":
        print("present")
        raise SystemExit(0)

print("missing")
PY
  )"

  printf '%s\n' "${state}"
}

vpskit_trojan_xray_config_conflict_protocol() {
  local config_path

  config_path="$(vpskit_system_path "$(vpskit_trojan_config_path)")"
  if [ ! -f "${config_path}" ]; then
    return 0
  fi

  python3 - "${config_path}" <<'PY'
from pathlib import Path
import json
import sys

config_path = Path(sys.argv[1])

try:
    payload = json.loads(config_path.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

for inbound in payload.get("inbounds", []):
    if inbound.get("port") == 8443 and inbound.get("protocol") not in (None, "", "trojan"):
        print(inbound.get("protocol", "unknown"))
        raise SystemExit(0)

raise SystemExit(0)
PY
}

vpskit_trojan_xray_config_merge() {
  local config_path
  local cert_path
  local key_path
  local password

  config_path="$(vpskit_system_path "$(vpskit_trojan_config_path)")"
  cert_path="$(vpskit_trojan_cert_path)"
  key_path="$(vpskit_trojan_key_path)"
  password="$1"

  python3 - "${config_path}" "${cert_path}" "${key_path}" "${password}" <<'PY'
from pathlib import Path
import json
import sys

config_path = Path(sys.argv[1])
cert_path = sys.argv[2]
key_path = sys.argv[3]
password = sys.argv[4]

payload = json.loads(config_path.read_text(encoding="utf-8"))
inbounds = list(payload.get("inbounds", []))

trojan_inbound = {
    "tag": "trojan-tcp-8443",
    "listen": "0.0.0.0",
    "port": 8443,
    "protocol": "trojan",
    "settings": {
        "clients": [
            {
                "password": password,
                "email": "default@vpskit",
            }
        ]
    },
    "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
            "certificates": [
                {
                    "certificateFile": cert_path,
                    "keyFile": key_path,
                }
            ]
        },
    },
    "sniffing": {
        "enabled": True,
        "destOverride": ["http", "tls", "quic"],
    },
}

updated = False
for index, inbound in enumerate(inbounds):
    if inbound.get("port") == 8443 and inbound.get("protocol") == "trojan":
        inbounds[index] = trojan_inbound
        updated = True
        break

if not updated:
    for inbound in inbounds:
        if inbound.get("port") == 8443 and inbound.get("protocol") not in (None, "", "trojan"):
            raise SystemExit(3)
    inbounds.append(trojan_inbound)

payload["inbounds"] = inbounds
print(json.dumps(payload, indent=2))
PY
}

vpskit_trojan_generate_cert_bundle() {
  local server_address="$1"
  local cert_path
  local key_path
  local tmp_config
  local san_entry

  cert_path="$(vpskit_trojan_cert_path)"
  key_path="$(vpskit_trojan_key_path)"

  if [[ "${server_address}" =~ : ]]; then
    san_entry="IP:${server_address}"
  elif [[ "${server_address}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    san_entry="IP:${server_address}"
  else
    san_entry="DNS:${server_address}"
  fi

  if vpskit_is_test_mode; then
    vpskit_write_managed_file "${key_path}" 0600 "TEST-TROJAN-PRIVATE-KEY ${server_address}"
    vpskit_write_managed_file "${cert_path}" 0644 "TEST-TROJAN-CERT ${server_address}"
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
CN = ${server_address}

[ req_ext ]
subjectAltName = ${san_entry}
EOF

  if ! openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${key_path}" \
    -out "${cert_path}" \
    -days 3650 \
    -sha256 \
    -config "${tmp_config}" >/dev/null 2>&1; then
    rm -f "${tmp_config}"
    return 1
  fi

  chmod 0600 "${key_path}"
  chmod 0644 "${cert_path}"
  rm -f "${tmp_config}"
}

vpskit_trojan_render_subscription_yaml() {
  local server_address="$1"
  local password="$2"
  local sni="$3"
  local allow_insecure="$4"

  cat <<EOF
server: ${server_address}
port: $(vpskit_trojan_port)
password: ${password}
sni: ${sni}
allowInsecure: ${allow_insecure}
EOF
}

vpskit_trojan_render_env_file() {
  local server_address="$1"
  local password="$2"
  local sni="$3"
  local allow_insecure="$4"

  cat <<EOF
VPSKIT_TROJAN_SERVER=${server_address}
VPSKIT_TROJAN_PORT=$(vpskit_trojan_port)
VPSKIT_TROJAN_PASSWORD=${password}
VPSKIT_TROJAN_SNI=${sni}
VPSKIT_TROJAN_ALLOW_INSECURE=${allow_insecure}
EOF
}

vpskit_trojan_tcp_8443_owner() {
  local output=""
  local parsed_owner=""

  if [ "${VPSKIT_TROJAN_POST_RESTART:-0}" = "1" ] && [ -n "${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_TCP_8443_OWNER:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TCP_8443_OWNER}"
    return 0
  fi

  if [ -n "${VPSKIT_TEST_TCP_8443_LISTENERS:-}" ]; then
    output="${VPSKIT_TEST_TCP_8443_LISTENERS}"
  elif command -v ss >/dev/null 2>&1; then
    output="$(ss -H -ltnp 'sport = :8443' 2>/dev/null || true)"
  else
    printf 'unknown\n'
    return 2
  fi

  if [ -z "$(printf '%s' "${output}" | tr -d '[:space:]')" ]; then
    printf 'not_bound\n'
    return 0
  fi

  parsed_owner="$(printf '%s\n' "${output}" | awk '
    /xray/ { print "xray"; found = 1; exit }
    {
      count = split($0, parts, "\"")
      if (count >= 3 && parts[2] != "") {
        print parts[2]
        found = 1
        exit
      }
    }
    NF && !found { print "unknown"; found = 1; exit }
  ')"

  if [ -z "${parsed_owner}" ]; then
    printf 'unknown\n'
    return 2
  fi

  printf '%s\n' "${parsed_owner}"
}

vpskit_trojan_tcp_443_owner() {
  if [ -n "${VPSKIT_TEST_TCP_443_OWNER:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TCP_443_OWNER}"
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    ss -H -ltnp 'sport = :443' 2>/dev/null | awk '
      /xray/ { print "xray"; found = 1; exit }
      NF && !found { print "unknown"; found = 1; exit }
    '
    return 0
  fi

  printf 'unknown\n'
}

vpskit_trojan_ufw_status() {
  vpskit_ufw_status 2>/dev/null || true
}

vpskit_trojan_ufw_allows_8443_tcp() {
  local ufw_status="$1"

  printf '%s\n' "${ufw_status}" | awk '
    {
      line = $0
      sub(/^[[:space:]]*\[[[:space:]]*[0-9]+[[:space:]]*\][[:space:]]*/, "", line)
      if (line ~ /\(v6\)/) {
        next
      }

      field_count = split(line, fields, /[[:space:]]+/)
      if (fields[1] != "8443/tcp") {
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

vpskit_trojan_subscription_export() {
  local subscription_file
  local output_path=""
  local server_address=""
  local password=""
  local sni=""
  local allow_insecure="1"
  local rendered=""

  subscription_file="$(vpskit_system_path "$(vpskit_trojan_subscription_file)")"
  if [ ! -f "${subscription_file}" ]; then
    printf 'SUB_EXPORT=fail format=trojan reason=missing_subscription_file\n'
    return 1
  fi

  if [ "$#" -gt 0 ]; then
    case "${1:-}" in
      --output | -o)
        shift
        if [ -z "${1:-}" ]; then
          printf 'SUB_EXPORT=fail reason=missing_output_path\n'
          return 1
        fi
        output_path="${1}"
        ;;
      "")
        ;;
      *)
        printf 'SUB_EXPORT=fail reason=unexpected_argument value=%s\n' "${1}"
        return 1
        ;;
    esac
  fi

  if [ -n "${output_path}" ] && [ -d "${output_path}" ]; then
    printf 'SUB_EXPORT=fail format=trojan reason=output_path_is_directory output=%s\n' "${output_path}"
    return 1
  fi

  if [ -n "${output_path}" ] && [ ! -d "$(dirname "${output_path}")" ]; then
    printf 'SUB_EXPORT=fail format=trojan reason=parent_directory_missing output=%s\n' "${output_path}"
    return 1
  fi

  rendered="$(
    python3 - "${subscription_file}" <<'PY'
from pathlib import Path
from urllib.parse import quote
import sys

path = Path(sys.argv[1])
data = {}

for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or ":" not in line:
        continue
    key, value = line.split(":", 1)
    data[key.strip()] = value.strip().strip("'\"")

server = data.get("server", "").strip()
password = data.get("password", "").strip()
sni = data.get("sni", "").strip() or server
allow_insecure = data.get("allowInsecure", "").strip() or "1"

if not server or not password:
    raise SystemExit(1)

if ":" in server and not server.startswith("["):
    server = f"[{server}]"

print(
    f"trojan://{quote(password, safe='')}@{server}:8443?sni={quote(sni, safe='')}&allowInsecure={allow_insecure}#VPSKit-Trojan"
)
PY
  )" || {
    printf 'SUB_EXPORT=fail format=trojan reason=malformed_subscription_file\n'
    return 1
  }

  if [ -n "${output_path}" ]; then
    if vpskit_subscription_write_output_file trojan "${output_path}" "${rendered}"; then
      return 0
    fi
    return 1
  fi

  printf '%s\n' "${rendered}"
}

vpskit_install_trojan() {
  local status=0
  local xray_bin=""
  local server_address=""
  local password=""
  local sni=""
  local allow_insecure="1"
  local subscription_file
  local system_subscription_file
  local env_file
  local cert_path
  local key_path
  local config_path
  local system_config_path
  local config_conflict=""
  local tcp_owner=""
  local xray_service_state=""
  local tcp_443_owner=""
  local ufw_status=""
  local rendered_config=""
  local rendered_yaml=""
  local rendered_env=""
  local candidate_config_path=""
  local xray_user=""
  local xray_group=""

  vpskit_require_root || return 1
  vpskit_require_ubuntu_2404 || return 1
  vpskit_vless_package_preflight || {
    return 1
  }
  vpskit_transaction_init

  if ! vpskit_install_or_prepare_xray; then
    printf 'TROJAN_INSTALL=fail reason=xray_missing\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  if ! xray_bin="$(vpskit_vless_xray_bin)"; then
    printf 'TROJAN_INSTALL=fail reason=xray_missing\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  config_path="$(vpskit_trojan_config_path)"
  system_config_path="$(vpskit_system_path "${config_path}")"
  cert_path="$(vpskit_trojan_cert_path)"
  key_path="$(vpskit_trojan_key_path)"
  subscription_file="$(vpskit_trojan_subscription_file)"
  system_subscription_file="$(vpskit_system_path "${subscription_file}")"
  env_file="$(vpskit_trojan_env_file)"

  if [ ! -f "${system_config_path}" ]; then
    printf 'TROJAN_INSTALL=fail reason=xray_config_missing\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  config_conflict="$(vpskit_trojan_xray_config_conflict_protocol 2>/dev/null || true)"
  if [ -n "${config_conflict}" ]; then
    printf 'TROJAN_INSTALL=fail reason=tcp_8443_conflict owner=%s\n' "${config_conflict}"
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  tcp_owner="$(vpskit_trojan_tcp_8443_owner)"
  case "${tcp_owner}" in
    not_bound | xray)
      ;;
    unknown)
      printf 'TROJAN_INSTALL=fail reason=tcp_8443_in_use owner=unknown\n'
      vpskit_transaction_abort
      vpskit_release_lock
      return 1
      ;;
    *)
      printf 'TROJAN_INSTALL=fail reason=tcp_8443_in_use owner=%s\n' "${tcp_owner}"
      vpskit_transaction_abort
      vpskit_release_lock
      return 1
      ;;
  esac

  server_address="$(vpskit_trojan_server_address)" || status=$?
  password="$(vpskit_trojan_password)" || status=$?
  sni="$(vpskit_trojan_sni)" || status=$?
  allow_insecure="$(vpskit_trojan_allow_insecure)"

  if [ "${status}" -ne 0 ] || [ -z "${server_address}" ] || [ -z "${password}" ] || [ -z "${sni}" ]; then
    printf 'TROJAN_INSTALL=fail reason=trojan_state_unavailable\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  if ! vpskit_trojan_generate_cert_bundle "${server_address}"; then
    printf 'TROJAN_INSTALL=fail reason=certificate_generation_failed\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  if ! xray_user="$(vpskit_trojan_xray_runtime_user)"; then
    printf 'TROJAN_INSTALL=fail reason=xray_runtime_user_unavailable\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  if ! xray_group="$(vpskit_trojan_xray_runtime_group "${xray_user}")"; then
    printf 'TROJAN_INSTALL=fail reason=xray_runtime_group_unavailable\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  if ! vpskit_trojan_apply_tls_permissions "${xray_user}" "${xray_group}"; then
    printf 'TROJAN_INSTALL=fail reason=trojan_tls_permission_update_failed\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi

  rendered_config="$(
    vpskit_trojan_xray_config_merge "${password}"
  )" || {
    printf 'TROJAN_INSTALL=fail reason=xray_config_update_failed\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  }

  candidate_config_path="$(vpskit_trojan_candidate_xray_config_path)"
  printf '%s\n' "${rendered_config}" >"${candidate_config_path}"
  if ! vpskit_trojan_validate_candidate_xray_config "${xray_bin}" "${candidate_config_path}"; then
    rm -f "${candidate_config_path}"
    printf 'TROJAN_INSTALL=fail reason=xray_config_invalid\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  fi
  rm -f "${candidate_config_path}"
  candidate_config_path=""

  rendered_yaml="$(vpskit_trojan_render_subscription_yaml "${server_address}" "${password}" "${sni}" "${allow_insecure}")"
  rendered_env="$(vpskit_trojan_render_env_file "${server_address}" "${password}" "${sni}" "${allow_insecure}")"

  vpskit_write_managed_file "${config_path}" 0644 "${rendered_config}" || {
    printf 'TROJAN_INSTALL=fail reason=xray_config_write_failed\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  }
  vpskit_write_managed_file "${subscription_file}" 0600 "${rendered_yaml}" || {
    printf 'TROJAN_INSTALL=fail reason=subscription_write_failed\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  }
  vpskit_write_managed_file "${env_file}" 0600 "${rendered_env}" || {
    printf 'TROJAN_INSTALL=fail reason=env_write_failed\n'
    vpskit_transaction_abort
    vpskit_release_lock
    return 1
  }

  vpskit_run_mutation systemctl daemon-reload || status=$?
  vpskit_run_mutation systemctl enable xray || status=$?
  vpskit_run_mutation systemctl restart xray || status=$?
  if [ "${status}" -ne 0 ]; then
    printf 'TROJAN_INSTALL=fail reason=xray_restart_failed\n'
    if ! vpskit_trojan_rollback_install_failure; then
      :
    fi
    vpskit_release_lock
    return 1
  fi

  if ! vpskit_is_test_mode; then
    sleep 1
  fi

  export VPSKIT_TROJAN_POST_RESTART=1
  xray_service_state="$(vpskit_vless_xray_service_summary)"
  tcp_443_owner="$(vpskit_trojan_tcp_443_owner)"
  if [ -n "${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART:-}" ]; then
    tcp_owner="${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART}"
  else
    tcp_owner="$(vpskit_trojan_tcp_8443_owner)"
  fi
  unset VPSKIT_TROJAN_POST_RESTART

  if [ "${xray_service_state}" != "active" ]; then
    printf 'TROJAN_INSTALL=fail reason=service_inactive\n'
    printf 'TROJAN_SERVICE=fail state=%s\n' "${xray_service_state}"
    if ! vpskit_trojan_rollback_install_failure; then
      :
    fi
    vpskit_release_lock
    return 1
  fi

  if [ "${tcp_443_owner}" != "xray" ]; then
    printf 'TROJAN_INSTALL=fail reason=tcp_443_not_preserved\n'
    printf 'TCP_443_LISTENER=fail expected=xray actual=%s\n' "${tcp_443_owner:-none}"
    if ! vpskit_trojan_rollback_install_failure; then
      :
    fi
    vpskit_release_lock
    return 1
  fi

  if [ "${tcp_owner}" != "xray" ]; then
    printf 'TROJAN_INSTALL=fail reason=tcp_8443_not_bound\n'
    printf 'TCP_8443_LISTENER=fail expected=xray actual=%s\n' "${tcp_owner:-none}"
    if ! vpskit_trojan_rollback_install_failure; then
      :
    fi
    vpskit_release_lock
    return 1
  fi

  ufw_status="$(vpskit_trojan_ufw_status)"
  if ! vpskit_ufw_available && [ -z "${ufw_status}" ]; then
    printf 'UFW_8443_TCP=skip status=inactive reason=not_enforced\n'
  elif printf '%s\n' "${ufw_status}" | grep -qi 'inactive'; then
    printf 'UFW_8443_TCP=skip status=inactive reason=not_enforced\n'
  elif printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    if vpskit_trojan_ufw_allows_8443_tcp "${ufw_status}"; then
      :
    else
      vpskit_run_mutation ufw allow 8443/tcp || status=$?
      vpskit_run_mutation ufw reload || status=$?
      if [ "${status}" -ne 0 ]; then
        printf 'TROJAN_INSTALL=fail reason=ufw_update_failed\n'
        if ! vpskit_trojan_rollback_install_failure; then
          :
        fi
        vpskit_release_lock
        return 1
      fi
    fi
  fi

  xray_service_state="$(vpskit_vless_xray_service_summary)"
  tcp_443_owner="$(vpskit_trojan_tcp_443_owner)"

  if [ "${xray_service_state}" != "active" ] || [ "${tcp_443_owner}" != "xray" ] || [ "${tcp_owner}" != "xray" ] || [ ! -s "${system_subscription_file}" ]; then
    printf 'TROJAN_INSTALL=fail reason=post_validation_failed\n'
    if ! vpskit_trojan_rollback_install_failure; then
      :
    fi
    vpskit_release_lock
    return 1
  fi

  if [ -n "${candidate_config_path}" ]; then
    rm -f "${candidate_config_path}"
  fi

  vpskit_transaction_commit
  vpskit_release_lock
  printf 'VLESS_REALITY_PRESERVED=pass tcp_443=bound service=xray\n'
  printf 'TROJAN_INSTALL=pass\n'
  printf 'TROJAN_PORT=%s/tcp\n' "$(vpskit_trojan_port)"
  printf 'TROJAN_SERVICE=%s service=xray\n' "${xray_service_state}"
  printf 'TROJAN_CONFIG=present\n'
  printf 'TROJAN_SUBSCRIPTION_FILE=%s\n' "$(vpskit_trojan_subscription_file)"
  printf 'TCP_8443_LISTENER=pass service=xray\n'
  if printf '%s\n' "${ufw_status}" | grep -qi 'active'; then
    printf 'UFW_8443_TCP=pass status=active rule=present\n'
  elif printf '%s\n' "${ufw_status}" | grep -qi 'inactive' || [ -z "${ufw_status}" ]; then
    printf 'UFW_8443_TCP=skip status=inactive reason=not_enforced\n'
  else
    printf 'UFW_8443_TCP=skip status=unknown\n'
  fi
}
