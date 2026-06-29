#!/usr/bin/env bash

VPSKIT_INSTALLER_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_INSTALLER_RUNTIME_DIR}/public_surface.sh"

vpskit_installer_runtime_log() {
  vpskit_log_info "INSTALLER $*"
}

vpskit_installer_runtime_fetch() {
  local source_url="$1"
  local output_path="$2"

  if [ -z "${source_url}" ] || [ -z "${output_path}" ]; then
    vpskit_die "fetch source URL and output path are required"
    return 1
  fi

  vpskit_installer_runtime_log "fetch ${source_url}"
  vpskit_run_mutation curl -fsSL -o "${output_path}" "${source_url}"
}

vpskit_installer_runtime_verify_command() {
  local command_name="$1"

  if command -v "${command_name}" >/dev/null 2>&1; then
    return 0
  fi

  vpskit_die "required command not found: ${command_name}"
}

vpskit_installer_runtime_install() {
  local label="$1"
  shift || true

  if [ -z "${label}" ]; then
    vpskit_die "installer label is required"
    return 1
  fi

  vpskit_installer_runtime_log "install ${label}"
  if [ "$#" -eq 0 ]; then
    vpskit_die "installer command is required"
    return 1
  fi

  vpskit_run_mutation "$@"
}

vpskit_installer_runtime_rollback_hook() {
  local label="${1:-installer}"

  vpskit_installer_runtime_log "rollback ${label}"
  vpskit_transaction_abort
}

vpskit_installer_runtime_finalize() {
  local label="${1:-installer}"

  vpskit_installer_runtime_log "commit ${label}"
  vpskit_transaction_commit
}

vpskit_vless_command_exists() {
  local command_name="$1"

  if vpskit_is_dry_run || [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
    return 0
  fi

  command -v "${command_name}" >/dev/null 2>&1
}

vpskit_vless_missing_packages() {
  local packages=()

  vpskit_vless_command_exists curl || packages+=("curl")
  vpskit_vless_command_exists openssl || packages+=("openssl")
  vpskit_vless_command_exists ss || packages+=("iproute2")

  printf '%s\n' "${packages[*]}"
}

vpskit_vless_package_preflight() {
  local missing_packages

  vpskit_systemd_available || {
    vpskit_die "systemd/systemctl is required for VLESS Reality installation"
    return 1
  }

  missing_packages="$(vpskit_vless_missing_packages)"
  if [ -z "${missing_packages}" ]; then
    return 0
  fi

  if ! vpskit_vless_command_exists apt-get; then
    vpskit_die "missing required packages (${missing_packages}) and apt-get is unavailable"
    return 1
  fi

  vpskit_installer_runtime_install "vless-preflight" apt-get update || return 1
  # shellcheck disable=SC2086
  vpskit_installer_runtime_install "vless-preflight" apt-get install -y ${missing_packages}
}

vpskit_install_or_prepare_xray() {
  local installer_url="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
  local tmp_installer=""

  if vpskit_vless_xray_bin >/dev/null 2>&1; then
    return 0
  fi

  if vpskit_is_dry_run || [ -n "${VPSKIT_TEST_COMMAND_LOG:-}" ]; then
    vpskit_installer_runtime_install "xray-fetch" curl -fsSL -o /tmp/vpskit-xray-install.sh "${installer_url}" || return 1
    vpskit_installer_runtime_install "xray-install" bash /tmp/vpskit-xray-install.sh install || return 1
    return 0
  fi

  tmp_installer="$(mktemp)"
  if ! vpskit_installer_runtime_fetch "${installer_url}" "${tmp_installer}"; then
    rm -f "${tmp_installer}"
    return 1
  fi

  if ! vpskit_installer_runtime_install "xray-install" bash "${tmp_installer}" install; then
    rm -f "${tmp_installer}"
    return 1
  fi

  rm -f "${tmp_installer}"
  vpskit_vless_xray_bin >/dev/null 2>&1 || vpskit_die "xray binary is not available after install"
}

