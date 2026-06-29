#!/usr/bin/env bash

VPSKIT_QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_QA_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${VPSKIT_QA_DIR}/../core/system_check.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_QA_DIR}/../core/public_surface.sh"
# shellcheck disable=SC1091
# shellcheck source=../verify/checks.sh
source "${VPSKIT_QA_DIR}/../verify/checks.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/reality_doctor.sh
source "${VPSKIT_QA_DIR}/../network/reality_doctor.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/trojan_doctor.sh
source "${VPSKIT_QA_DIR}/../network/trojan_doctor.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/hysteria2_doctor.sh
source "${VPSKIT_QA_DIR}/../network/hysteria2_doctor.sh"

VPSKIT_QA_VERSION="v0.7.0-beta"

vpskit_qa_capture_output() {
  local __output_var="$1"
  shift

  local output
  local status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  printf -v "${__output_var}" '%s' "${output}"
  return "${status}"
}

vpskit_qa_first_line_for_label() {
  local label="$1"
  local content="$2"

  printf '%s\n' "${content}" | awk -v label="${label}" '
    $0 ~ "^" label "=" {
      line = $0
    }
    END {
      if (line != "") {
        print line
      }
    }
  '
}

vpskit_qa_extract_value() {
  local label="$1"
  local content="$2"
  local default_value="${3:-}"
  local line
  local value

  line="$(vpskit_qa_first_line_for_label "${label}" "${content}")"
  if [ -z "${line}" ]; then
    printf '%s\n' "${default_value}"
    return 0
  fi

  value="${line#*=}"
  value="${value%% *}"
  printf '%s\n' "${value}"
}

vpskit_qa_detect_service_state() {
  local service_name="$1"

  if ! vpskit_systemd_available; then
    printf 'unknown\n'
    return 0
  fi

  if vpskit_service_active "${service_name}" || vpskit_service_active "${service_name}.service"; then
    printf 'active\n'
    return 0
  fi

  if vpskit_service_exists "${service_name}" || vpskit_service_exists "${service_name}.service"; then
    printf 'inactive\n'
    return 0
  fi

  printf 'missing\n'
}

vpskit_qa_detect_doctor_state() {
  local content="$1"

  if printf '%s\n' "${content}" | grep -Eq '=(fail|error)'; then
    printf 'fail\n'
    return 0
  fi

  if printf '%s\n' "${content}" | grep -Eq '=(warn|unknown|skip)'; then
    printf 'partial\n'
    return 0
  fi

  printf 'pass\n'
}

vpskit_qa_xray_config_test() {
  local xray_bin
  local config_path

  if ! xray_bin="$(vpskit_vless_xray_bin 2>/dev/null)"; then
    printf 'XRAY_CONFIG_TEST=skip reason=xray_binary_missing\n'
    return 0
  fi

  if [ ! -x "${xray_bin}" ]; then
    printf 'XRAY_CONFIG_TEST=skip reason=xray_binary_missing\n'
    return 0
  fi

  config_path="$(vpskit_system_path "$(vpskit_vless_config_path)")"
  if [ ! -f "${config_path}" ]; then
    printf 'XRAY_CONFIG_TEST=skip reason=config_missing path=%s\n' "${config_path}"
    return 0
  fi

  if "${xray_bin}" run -test -config "${config_path}" >/dev/null 2>&1; then
    printf 'XRAY_CONFIG_TEST=pass path=%s\n' "${config_path}"
    return 0
  fi

  printf 'XRAY_CONFIG_TEST=fail path=%s\n' "${config_path}"
  return 1
}

vpskit_qa_render_report() {
  local mode="${1:-redacted}"
  local report_status=0
  local vless_output=""
  local hysteria_output=""
  local trojan_output=""
  local doctor_output=""
  local export_output=""
  local xray_service_state
  local hysteria_service_state
  local trojan_service_state
  local tcp_443_owner
  local udp_443_owner
  local tcp_8443_owner
  local qa_doctor_state
  local ufw_state

  printf 'VPSKIT_QA_VERSION=%s\n' "${VPSKIT_QA_VERSION}"
  printf 'QA_MODE=%s\n' "${mode}"
  printf 'QA_READ_ONLY=yes\n'
  printf 'SENSITIVE_OUTPUT=redacted\n'

  if vpskit_qa_capture_output vless_output vpskit_verify_vless_reality; then
    :
  else
    report_status=1
  fi
  printf '%s\n' "${vless_output}"

  if vpskit_qa_capture_output hysteria_output vpskit_verify_hysteria2; then
    :
  else
    report_status=1
  fi
  printf '%s\n' "${hysteria_output}"

  if vpskit_qa_capture_output trojan_output vpskit_verify_trojan; then
    :
  else
    report_status=1
  fi
  printf '%s\n' "${trojan_output}"

  if vpskit_qa_capture_output doctor_output vpskit_cli_doctor; then
    :
  else
    report_status=1
  fi
  printf '%s\n' "${doctor_output}"

  if vpskit_trojan_subscription_export --redact >/dev/null 2>&1; then
    export_output="pass"
  else
    export_output="fail"
    report_status=1
  fi
  printf 'TROJAN_EXPORT_REDACTED=%s\n' "${export_output}"

  if vpskit_qa_xray_config_test; then
    :
  else
    report_status=1
  fi

  xray_service_state="$(vpskit_qa_detect_service_state xray)"
  hysteria_service_state="$(vpskit_qa_detect_service_state "$(vpskit_hysteria2_service_name)")"
  trojan_service_state="$(vpskit_qa_detect_service_state "$(vpskit_trojan_service_name)")"
  printf 'XRAY_SERVICE_STATUS=%s\n' "${xray_service_state}"
  printf 'HYSTERIA2_SERVICE_STATUS=%s\n' "${hysteria_service_state}"
  printf 'TROJAN_SERVICE_STATUS=%s\n' "${trojan_service_state}"

  tcp_443_owner="$(vpskit_verify_tcp_443_owner)"
  udp_443_owner="$(vpskit_hysteria2_udp_443_owner)"
  tcp_8443_owner="$(vpskit_trojan_tcp_8443_owner)"
  if [ "${tcp_443_owner}" = "xray" ]; then
    printf 'TCP_443=xray\n'
  else
    printf 'TCP_443=fail actual=%s expected=xray\n' "${tcp_443_owner:-none}"
    report_status=1
  fi

  if [ "${udp_443_owner}" = "hysteria" ]; then
    printf 'UDP_443=hysteria\n'
  else
    printf 'UDP_443=fail actual=%s expected=hysteria\n' "${udp_443_owner:-none}"
    report_status=1
  fi

  if [ "${tcp_8443_owner}" = "xray" ]; then
    printf 'TCP_8443=xray\n'
  else
    printf 'TCP_8443=fail actual=%s expected=xray\n' "${tcp_8443_owner:-none}"
    report_status=1
  fi

  ufw_state="$(vpskit_ufw_status 2>/dev/null || true)"
  if [ -z "${ufw_state}" ]; then
    printf 'UFW_STATUS=unknown\n'
  elif printf '%s\n' "${ufw_state}" | grep -qi 'inactive'; then
    printf 'UFW_STATUS=inactive\n'
  elif printf '%s\n' "${ufw_state}" | grep -qi 'active'; then
    printf 'UFW_STATUS=active\n'
  else
    printf 'UFW_STATUS=unknown\n'
  fi

  qa_doctor_state="$(vpskit_qa_detect_doctor_state "${doctor_output}")"
  printf 'DOCTOR=%s\n' "${qa_doctor_state}"

  if printf '%s\n' "${vless_output}" | grep -q '^VERIFY_VLESS_REALITY=fail$'; then
    report_status=1
  fi

  if printf '%s\n' "${hysteria_output}" | grep -q '^VERIFY_HYSTERIA2=fail$'; then
    report_status=1
  fi

  if printf '%s\n' "${trojan_output}" | grep -q '^VERIFY_TROJAN=fail$'; then
    report_status=1
  fi

  if [ "${qa_doctor_state}" = "fail" ]; then
    report_status=1
  fi

  if [ "${report_status}" -eq 0 ]; then
    printf 'VPSKIT_QA=pass\n'
  else
    printf 'VPSKIT_QA=fail\n'
  fi

  return "${report_status}"
}

vpskit_cli_qa() {
  local mode="redacted"
  local output_path=""
  local report=""
  local status=0
  local qa_exit=0

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --redact)
        mode="redacted"
        ;;
      --output | -o)
        shift || true
        if [ -z "${1:-}" ]; then
          printf 'QA=fail reason=missing_output_path\n'
          return 1
        fi
        output_path="${1}"
        ;;
      "" | help | --help | -h)
        cat <<'EOF'
Usage:
  vpskit qa
  vpskit qa --redact
  vpskit qa --output <path>
  vpskit qa --redact --output <path>
  vpskit qa --redact -o <path>
EOF
        return 0
        ;;
      *)
        vpskit_die "unknown qa option: ${1}"
        return 1
        ;;
    esac

    shift || true
  done

  set +e
  report="$(vpskit_qa_render_report "${mode}")"
  qa_exit=$?
  set -e

  printf '%s\n' "${report}"

  if [ -n "${output_path}" ]; then
    if [ -d "${output_path}" ]; then
      printf 'QA=fail reason=output_path_is_directory path=%s\n' "${output_path}"
      return 1
    fi

    if [ ! -d "$(dirname "${output_path}")" ]; then
      printf 'QA=fail reason=parent_directory_missing path=%s\n' "${output_path}"
      return 1
    fi

    printf '%s\n' "${report}" >"${output_path}" || {
      printf 'QA=fail reason=write_failed path=%s\n' "${output_path}"
      return 1
    }
  fi

  if [ "${qa_exit}" -eq 0 ]; then
    status=0
  else
    status=1
  fi

  return "${status}"
}
