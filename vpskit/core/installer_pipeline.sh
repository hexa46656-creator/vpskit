#!/usr/bin/env bash
set -euo pipefail

VPSKIT_INSTALL_PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${VPSKIT_INSTALL_PIPELINE_DIR}/common.sh"
# shellcheck disable=SC1091
source "${VPSKIT_INSTALL_PIPELINE_DIR}/public_surface.sh"
# shellcheck disable=SC1091
source "${VPSKIT_INSTALL_PIPELINE_DIR}/../security/hardening/init_hardening.sh"
# shellcheck disable=SC1091
source "${VPSKIT_INSTALL_PIPELINE_DIR}/../install/vpn_stack.sh"
# shellcheck disable=SC1091
source "${VPSKIT_INSTALL_PIPELINE_DIR}/../subscription/generator.sh"
# shellcheck disable=SC1091
source "${VPSKIT_INSTALL_PIPELINE_DIR}/../verify/validate_install.sh"

vpskit_install_require_privileges() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    return 0
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "root access or passwordless sudo is required"
}

vpskit_install_detect_os() {
  local os_id os_version

  if [[ ! -r /etc/os-release ]]; then
    vpskit_die "unsupported platform: missing /etc/os-release"
    return 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  os_id="${ID:-}"
  os_version="${VERSION_ID:-}"

  case "${os_id}:${os_version}" in
    ubuntu:22.04 | ubuntu:24.04 | debian:11 | debian:12)
      vpskit_log_info "supported OS detected: ${os_id} ${os_version}"
      return 0
      ;;
  esac

  vpskit_die "unsupported OS: ${os_id:-unknown} ${os_version:-unknown}"
}

vpskit_install_output_final_url() {
  local final_url

  if [[ -n "${VPSKIT_FINAL_URL:-}" ]]; then
    final_url="${VPSKIT_FINAL_URL}"
  elif [[ -n "${VPSKIT_PUBLIC_BASE_URL:-}" ]]; then
    final_url="${VPSKIT_PUBLIC_BASE_URL%/}/sub.txt"
  else
    final_url="file:///root/vpskit/sub.txt"
  fi

  printf 'FINAL_URL=%s\n' "${final_url}"
}

vpskit_install_pipeline() {
  vpskit_install_require_privileges
  vpskit_install_detect_os

  vpskit_log_info "starting security hardening"
  vpskit_apply_hardening

  vpskit_log_info "starting VPN stack installation"
  vpskit_install_vpn_stack

  vpskit_log_info "generating subscription artifacts"
  vpskit_generate_subscription

  vpskit_log_info "running install validation"
  vpskit_validate_install

  vpskit_install_output_final_url
}
