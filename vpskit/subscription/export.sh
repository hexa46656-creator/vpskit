#!/usr/bin/env bash

VPSKIT_SUBSCRIPTION_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_SUBSCRIPTION_MODULE_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_SUBSCRIPTION_MODULE_DIR}/../core/public_surface.sh"

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
