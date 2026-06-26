#!/usr/bin/env bash

VPSKIT_SUBSCRIPTION_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_SUBSCRIPTION_MODULE_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/trojan.sh
source "${VPSKIT_SUBSCRIPTION_MODULE_DIR}/../install/trojan.sh"

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

try:
    text = path.read_text(encoding="utf-8")
except FileNotFoundError:
    print(f"ERROR subscription file not found: {path}")
    raise SystemExit(1)
except UnicodeDecodeError:
    print(f"ERROR subscription file is not valid UTF-8: {path}")
    raise SystemExit(1)

for raw_line in text.splitlines():
    line = raw_line.strip()
    if line:
        print(line)
        raise SystemExit(0)

print(f"ERROR malformed VLESS Reality URI: empty subscription file: {path}")
raise SystemExit(1)
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

  parent_dir="$(dirname "${output_path}")"

  if [ -d "${output_path}" ]; then
    printf 'SUB_EXPORT=fail format=%s reason=output_path_is_directory output=%s\n' "${format}" "${output_path}"
    return 1
  fi

  if [ ! -d "${parent_dir}" ]; then
    printf 'SUB_EXPORT=fail format=%s reason=parent_directory_missing output=%s\n' "${format}" "${output_path}"
    return 1
  fi

  if ! printf '%s\n' "${content}" >"${output_path}"; then
    printf 'SUB_EXPORT=fail format=%s reason=write_failed output=%s\n' "${format}" "${output_path}"
    return 1
  fi

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

  subscription_file="$(vpskit_hysteria2_subscription_file)"
  if [ ! -f "${subscription_file}" ]; then
    printf 'SUB_EXPORT=fail format=hysteria2 reason=missing_subscription_file\n'
    return 1
  fi

  rendered="$(<"${subscription_file}")"
  printf '%s\n' "${rendered}"
}
