#!/usr/bin/env bash

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
    printf '%s\n' "${repaired}" >"${output}"
  else
    printf '%s\n' "${repaired}"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  vpskit_shadowrocket_repair "$@"
fi
