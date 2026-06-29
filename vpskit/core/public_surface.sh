#!/usr/bin/env bash

VPSKIT_PUBLIC_SURFACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${VPSKIT_ROOT:-}" ]; then
  VPSKIT_ROOT="$(cd "${VPSKIT_PUBLIC_SURFACE_DIR}/.." && pwd)"
fi

# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_PUBLIC_SURFACE_DIR}/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${VPSKIT_PUBLIC_SURFACE_DIR}/system_check.sh"

vpskit_vless_xray_port() {
  printf '%s\n' "${VPSKIT_XRAY_PORT:-443}"
}

vpskit_vless_server_name() {
  printf '%s\n' "${VPSKIT_REALITY_SERVER_NAME:-www.cloudflare.com}"
}

vpskit_vless_dest() {
  printf '%s\n' "${VPSKIT_REALITY_DEST:-www.cloudflare.com:443}"
}

vpskit_vless_config_path() {
  printf '%s\n' "${VPSKIT_XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}"
}

vpskit_vless_subscription_file() {
  vpskit_default_subscription_file
}

vpskit_vless_xray_bin() {
  if [ -n "${VPSKIT_TEST_XRAY_BIN:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_XRAY_BIN}"
    return 0
  fi

  if command -v xray >/dev/null 2>&1; then
    command -v xray
    return 0
  fi

  if [ -x /usr/local/bin/xray ]; then
    printf '%s\n' "/usr/local/bin/xray"
    return 0
  fi

  return 1
}

vpskit_vless_xray_service_summary() {
  if ! vpskit_systemd_available; then
    printf 'systemd_unavailable\n'
    return 0
  fi

  if vpskit_service_active xray || vpskit_service_active xray.service; then
    printf 'active\n'
    return 0
  fi

  printf 'inactive\n'
}

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
  local parsed_owner=""

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
    return 2
  fi

  if [ -z "$(printf '%s' "${output}" | tr -d '[:space:]')" ]; then
    printf 'not_bound\n'
    return 0
  fi

  parsed_owner="$(printf '%s\n' "${output}" | awk '
    /hysteria/ { print "hysteria"; found = 1; exit }
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

vpskit_trojan_port() {
  printf '%s\n' "${VPSKIT_TROJAN_PORT:-8443}"
}

vpskit_trojan_config_dir() {
  printf '%s\n' "${VPSKIT_TROJAN_CONFIG_DIR:-/etc/vpskit/trojan}"
}

vpskit_trojan_config_path() {
  printf '%s\n' "${VPSKIT_TROJAN_CONFIG_PATH:-$(vpskit_vless_config_path)}"
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

vpskit_trojan_candidate_xray_config_path() {
  mktemp "${TMPDIR:-/tmp}/vpskit-xray-candidate.XXXXXX.json"
}

vpskit_trojan_validate_candidate_xray_config() {
  local xray_bin="$1"
  local candidate_config_path="$2"

  if [ -z "${xray_bin}" ] || [ ! -x "${xray_bin}" ]; then
    return 1
  fi

  "${xray_bin}" run -test -config "${candidate_config_path}"
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

vpskit_subscription_supported_formats() {
  printf 'SUPPORTED_SUB_FORMATS=raw,base64,shadowrocket,v2rayng,clash-meta,sing-box,hysteria2,trojan\n'
}

vpskit_subscription_resolve_file() {
  local subscription_file

  subscription_file="$(vpskit_default_subscription_file)"
  if [ -f "${subscription_file}" ]; then
    printf '%s\n' "${subscription_file}"
    return 0
  fi

  vpskit_die "subscription file not found: ${subscription_file}"
}

vpskit_subscription_first_uri() {
  local subscription_file="$1"

  python3 - "${subscription_file}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
allowed_prefixes = ("vless://", "trojan://", "hysteria://")

try:
    text = path.read_text(encoding="utf-8")
except FileNotFoundError:
    print(f"ERROR subscription file not found: {path}")
    raise SystemExit(1)
except UnicodeDecodeError:
    print(f"ERROR subscription file is not valid UTF-8: {path}")
    raise SystemExit(1)

first_non_empty_line = ""

for raw_line in text.splitlines():
    line = raw_line.strip()
    if line:
        first_non_empty_line = line
        break

if not first_non_empty_line:
    print(f"ERROR malformed subscription URI: empty subscription file: {path}")
    raise SystemExit(1)

if not first_non_empty_line.startswith(allowed_prefixes):
    print(
        "ERROR malformed subscription URI: expected vless://, trojan://, or hysteria://"
    )
    raise SystemExit(1)

print(first_non_empty_line)
raise SystemExit(0)
PY
}

vpskit_subscription_print_file() {
  local subscription_file="$1"
  local content

  content="$(<"${subscription_file}")"
  printf '%s\n' "${content}"
}

vpskit_subscription_uri_tool() {
  python3 "${VPSKIT_ROOT}/subscription/uri_tool.py" "$@"
}

vpskit_subscription_render_export() {
  local format="$1"
  local uri="$2"
  local rendered

  if rendered="$(vpskit_subscription_uri_tool render "${format}" "${uri}")"; then
    printf '%s\n' "${rendered}"
    return 0
  fi

  printf '%s\n' "${rendered}"
  return 1
}

vpskit_subscription_validate() {
  local uri="$1"

  vpskit_subscription_uri_tool validate "${uri}"
}

vpskit_subscription_write_output_file() {
  local format="$1"
  local output_path="$2"
  local content="$3"
  local status_extra="${4:-}"
  local parent_dir
  local payload_path
  local payload_path_quoted
  local output_path_quoted
  local parent_dir_quoted

  parent_dir="$(dirname "${output_path}")"
  output_path_quoted="$(vpskit_shell_quote "${output_path}")"
  parent_dir_quoted="$(vpskit_shell_quote "${parent_dir}")"

  if [ -d "${output_path}" ]; then
    printf 'SUB_EXPORT=fail format=%s reason=output_path_is_directory output=%s\n' "${format}" "${output_path}"
    return 1
  fi

  if [ ! -d "${parent_dir}" ]; then
    printf 'SUB_EXPORT=fail format=%s reason=parent_directory_missing output=%s\n' "${format}" "${output_path}"
    return 1
  fi

  payload_path="$(mktemp "${TMPDIR:-/tmp}/vpskit-sub-export.XXXXXX")" || return 1
  printf '%s\n' "${content}" >"${payload_path}" || {
    rm -f "${payload_path}"
    return 1
  }
  payload_path_quoted="$(vpskit_shell_quote "${payload_path}")"

  if ! vpskit_safe_run_script "mkdir -p ${parent_dir_quoted}; cp ${payload_path_quoted} ${output_path_quoted}"; then
    rm -f "${payload_path}"
    printf 'SUB_EXPORT=fail format=%s reason=write_failed output=%s\n' "${format}" "${output_path}"
    return 1
  fi
  rm -f "${payload_path}"

  if [ -n "${status_extra}" ]; then
    printf 'SUB_EXPORT=pass format=%s output=%s %s\n' "${format}" "${output_path}" "${status_extra}"
  else
    printf 'SUB_EXPORT=pass format=%s output=%s\n' "${format}" "${output_path}"
  fi
  return 0
}

vpskit_hysteria2_subscription_export() {
  local subscription_file
  local rendered

  subscription_file="$(vpskit_system_path "$(vpskit_hysteria2_subscription_file)")"
  if [ ! -f "${subscription_file}" ]; then
    printf 'SUB_EXPORT=fail format=hysteria2 reason=missing_subscription_file\n'
    return 1
  fi

  rendered="$(<"${subscription_file}")"
  printf '%s\n' "${rendered}"
}

vpskit_trojan_subscription_export() {
  local subscription_file
  local output_path=""
  local redact_mode=0
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

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --output | -o)
        shift
        if [ -z "${1:-}" ]; then
          printf 'SUB_EXPORT=fail reason=missing_output_path\n'
          return 1
        fi
        output_path="${1}"
        ;;
      --redact)
        redact_mode=1
        ;;
      "" | help | --help | -h)
        cat <<'EOF'
Usage:
  vpskit sub export trojan
  vpskit sub export trojan --redact
  vpskit sub export trojan --output <path>
  vpskit sub export trojan -o <path>
  vpskit sub export trojan --redact --output <path>
  vpskit sub export trojan --redact -o <path>
EOF
        return 0
        ;;
      *)
        printf 'SUB_EXPORT=fail reason=unexpected_argument value=%s\n' "${1}"
        return 1
        ;;
    esac

    shift || true
  done

  if [ -n "${output_path}" ] && [ -d "${output_path}" ]; then
    printf 'SUB_EXPORT=fail format=trojan reason=output_path_is_directory output=%s\n' "${output_path}"
    return 1
  fi

  if [ -n "${output_path}" ] && [ ! -d "$(dirname "${output_path}")" ]; then
    printf 'SUB_EXPORT=fail format=trojan reason=parent_directory_missing output=%s\n' "${output_path}"
    return 1
  fi

  rendered="$(
    python3 - "${subscription_file}" "${redact_mode}" <<'PY'
from pathlib import Path
from urllib.parse import quote
import sys

path = Path(sys.argv[1])
data = {}
redact = len(sys.argv) > 2 and sys.argv[2] == "1"

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

server = quote(server, safe="[]:.")
password = "REDACTED" if redact else quote(password, safe="")
sni = quote(sni, safe="")
fragment = quote("VPSKit-Trojan", safe="")

print(
    f"trojan://{password}@{server}:8443?sni={sni}&allowInsecure={allow_insecure}#{fragment}"
)
PY
  )" || {
    printf 'SUB_EXPORT=fail format=trojan reason=malformed_subscription_file\n'
    return 1
  }

  if [ -n "${output_path}" ]; then
    if [ "${redact_mode}" -eq 1 ]; then
      if vpskit_subscription_write_output_file trojan "${output_path}" "${rendered}" "redacted=yes"; then
        return 0
      fi
      return 1
    fi

    if vpskit_subscription_write_output_file trojan "${output_path}" "${rendered}"; then
      return 0
    fi
    return 1
  fi

  printf '%s\n' "${rendered}"
}

vpskit_shadowrocket_repair_read_input() {
  local input="${1:-}"

  if [ -z "${input}" ]; then
    cat
    return 0
  fi

  if [ -f "${input}" ]; then
    cat "${input}"
    return 0
  fi

  printf '%s\n' "${input}"
}

vpskit_shadowrocket_repair_decode_bundle() {
  local data
  data="$(cat)"

  if printf '%s' "${data}" | grep -Eq '^[A-Za-z0-9+/=[:space:]]+$' && ! printf '%s' "${data}" | grep -q '://'; then
    if command -v python3 >/dev/null 2>&1; then
      python3 - "$data" <<'PY'
import base64
import re
import sys

payload = re.sub(r"\s+", "", sys.argv[1])
try:
    decoded = base64.b64decode(payload).decode("utf-8")
except Exception:
    raise SystemExit(1)
sys.stdout.write(decoded)
PY
      return $?
    fi

    if command -v base64 >/dev/null 2>&1; then
      if printf '%s' "${data}" | tr -d '[:space:]' | base64 --decode 2>/dev/null; then
        return 0
      fi
      if printf '%s' "${data}" | tr -d '[:space:]' | base64 -D 2>/dev/null; then
        return 0
      fi
    fi
  fi

  printf '%s' "${data}"
}

vpskit_shadowrocket_repair_normalize_lines() {
  tr -d '\r' | awk '
    BEGIN { first = 1 }
    /^#/ { print; next }
    /^(vless|hysteria2|trojan):\/\// { print; next }
    /^[[:space:]]*$/ { next }
    {
      if (first) {
        first = 0
      }
    }
  '
}

vpskit_shadowrocket_repair() {
  local input=""
  local output=""
  local repaired
  local payload_path
  local output_path_quoted
  local payload_path_quoted

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --input)
        input="$2"
        shift 2
        ;;
      --output)
        output="$2"
        shift 2
        ;;
      --help|-h)
        cat <<'EOF'
Usage: vpskit_shadowrocket_repair [--input PATH|TEXT] [--output PATH]
EOF
        return 0
        ;;
      *)
        input="$1"
        shift
        ;;
    esac
  done

  repaired="$(
    vpskit_shadowrocket_repair_read_input "${input}" \
      | vpskit_shadowrocket_repair_decode_bundle \
      | vpskit_shadowrocket_repair_normalize_lines
  )"

  if [ -n "${output}" ]; then
    payload_path="$(mktemp "${TMPDIR:-/tmp}/vpskit-shadowrocket.XXXXXX")" || return 1
    printf '%s\n' "${repaired}" >"${payload_path}" || {
      rm -f "${payload_path}"
      return 1
    }
    payload_path_quoted="$(vpskit_shell_quote "${payload_path}")"
    output_path_quoted="$(vpskit_shell_quote "${output}")"
    if ! vpskit_safe_run_script "cp ${payload_path_quoted} ${output_path_quoted}"; then
      rm -f "${payload_path}"
      return 1
    fi
    rm -f "${payload_path}"
  else
    printf '%s\n' "${repaired}"
  fi
}
