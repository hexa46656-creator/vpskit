#!/usr/bin/env bash

set -euo pipefail

VPSKIT_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPSKIT_ROOT="$(cd "${VPSKIT_CLI_DIR}/.." && pwd)"

# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_ROOT}/core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${VPSKIT_ROOT}/core/system_check.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/install_lock.sh
source "${VPSKIT_ROOT}/core/install_lock.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/transaction.sh
source "${VPSKIT_ROOT}/core/transaction.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/safety.sh
source "${VPSKIT_ROOT}/core/safety.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/hardening.sh
source "${VPSKIT_ROOT}/install/hardening.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/vless_reality.sh
source "${VPSKIT_ROOT}/install/vless_reality.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/dns_health.sh
source "${VPSKIT_ROOT}/network/dns_health.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/tcp_probe.sh
source "${VPSKIT_ROOT}/network/tcp_probe.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/fallback_report.sh
source "${VPSKIT_ROOT}/network/fallback_report.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/reality_doctor.sh
source "${VPSKIT_ROOT}/network/reality_doctor.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/trojan_doctor.sh
source "${VPSKIT_ROOT}/network/trojan_doctor.sh"
# shellcheck disable=SC1091
# shellcheck source=../network/hysteria2_doctor.sh
source "${VPSKIT_ROOT}/network/hysteria2_doctor.sh"
# shellcheck disable=SC1091
# shellcheck source=../subscription/shadowrocket_repair.sh
source "${VPSKIT_ROOT}/subscription/shadowrocket_repair.sh"

vpskit_cli_version() {
  cat <<'EOF'
VPSKit v2.0.0-beta
Available commands: version, status, doctor, sub, fix, install
Available components: CLI, hardening installer, VLESS Reality installer, DNS health, TCP probe, fallback report, Shadowrocket repair
EOF
}

vpskit_cli_status() {
  printf 'VERSION=VPSKit v2.0.0-beta\n'
  vpskit_system_inspection_summary
  printf 'CLI=available\n'
  printf 'SUBSCRIPTION_REPAIR=available\n'
  printf 'DNS_HEALTH=available\n'
  printf 'TCP_PROBE=available\n'
  printf 'FALLBACK_REPORT=available\n'
  printf 'SAFETY=simulation-only\n'
}

vpskit_cli_doctor() {
  local dns_target="${VPSKIT_DOCTOR_DNS_TARGET:-localhost}"
  local tcp_host="${VPSKIT_DOCTOR_TCP_HOST:-127.0.0.1}"
  local tcp_port="${VPSKIT_DOCTOR_TCP_PORT:-443}"
  local subscription_file="${VPSKIT_SUBSCRIPTION_FILE:-}"
  local dns_state
  local tcp_state

  vpskit_system_inspection_summary
  dns_state="$(vpskit_dns_health "${dns_target}" || true)"
  tcp_state="$(vpskit_tcp_probe "${tcp_host}" "${tcp_port}" || true)"
  printf 'DNS_HEALTH=%s\n' "${dns_state}"
  printf 'TCP_PROBE=%s\n' "${tcp_state}"

  if [ -n "${subscription_file}" ] && [ -f "${subscription_file}" ]; then
    printf 'SUBSCRIPTION_FILE=present\n'
  else
    printf 'SUBSCRIPTION_FILE=missing\n'
  fi

  vpskit_reality_doctor
  vpskit_trojan_doctor
  vpskit_hysteria2_doctor
}

vpskit_cli_sub() {
  local subcommand="${1:-show}"
  local subscription_file="${VPSKIT_SUBSCRIPTION_FILE:-}"
  local managed_subscription="/var/lib/vpskit/vless-reality.txt"
  local output_dir="${VPSKIT_OUTPUT_DIR:-${VPSKIT_ROOT}/output}"
  local default_output="${output_dir}/final_links.txt"

  case "${subcommand}" in
    show)
      ;;
    "" | help | --help | -h)
      printf 'Usage: vpskit sub show\n'
      return 0
      ;;
    *)
      vpskit_die "unknown sub command: ${subcommand}"
      return 1
      ;;
  esac

  if [ -n "${subscription_file}" ] && [ -f "${subscription_file}" ]; then
    cat "${subscription_file}"
    return 0
  fi

  if [ -f "${managed_subscription}" ]; then
    cat "${managed_subscription}"
    return 0
  fi

  if [ -f "${default_output}" ]; then
    cat "${default_output}"
    return 0
  fi

  printf 'No subscription file is configured.\n'
  printf 'Next step: set VPSKIT_SUBSCRIPTION_FILE or generate one with the release docs.\n'
}

vpskit_cli_fix() {
  local input="${VPSKIT_FIX_INPUT:-}"
  local output="${VPSKIT_FIX_OUTPUT:-}"
  local dns_state
  local tcp_state

  if [ -n "${input}" ]; then
    if [ -n "${output}" ]; then
      vpskit_shadowrocket_repair --input "${input}" --output "${output}"
    else
      vpskit_shadowrocket_repair --input "${input}"
    fi
    return 0
  fi

  dns_state="$(vpskit_dns_health "${VPSKIT_DOCTOR_DNS_TARGET:-localhost}" || true)"
  tcp_state="$(vpskit_tcp_probe "${VPSKIT_DOCTOR_TCP_HOST:-127.0.0.1}" "${VPSKIT_DOCTOR_TCP_PORT:-443}" || true)"
  vpskit_fallback_report "${dns_state}" "${tcp_state}"
}

vpskit_cli_install() {
  local target="${1:-}"

  case "${target}" in
    hardening)
      vpskit_with_lock vpskit_install_hardening
      ;;
    vless-reality)
      vpskit_with_lock vpskit_install_vless_reality
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit install hardening
  vpskit install vless-reality
EOF
      ;;
    *)
      vpskit_die "unknown install target: ${target}"
      return 1
      ;;
  esac
}

vpskit_cli_usage() {
  cat <<'EOF'
Usage:
  vpskit version
  vpskit status
  vpskit doctor
  vpskit sub
  vpskit sub show
  vpskit fix
  vpskit install hardening
  vpskit install vless-reality
EOF
}

main() {
  local command="${1:-}"
  shift || true

  case "${command}" in
    version)
      vpskit_cli_version
      ;;
    status)
      vpskit_cli_status
      ;;
    doctor)
      vpskit_cli_doctor
      ;;
    sub)
      vpskit_cli_sub "$@"
      ;;
    fix)
      vpskit_cli_fix "$@"
      ;;
    install)
      vpskit_cli_install "$@"
      ;;
    "" | help | --help | -h)
      vpskit_cli_usage
      ;;
    *)
      vpskit_die "unknown command: ${command}"
      return 1
      ;;
  esac
}

main "$@"
