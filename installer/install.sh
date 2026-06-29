#!/usr/bin/env bash
set -euo pipefail

vpskit_install_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
vpskit_install_repo_root="$(cd "${vpskit_install_script_dir}/.." && pwd)"

vpskit_install_require_os() {
  local os_id os_version

  if [[ ! -r /etc/os-release ]]; then
    printf 'ERROR unsupported_os reason=missing_os_release\n' >&2
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  os_id="${ID:-}"
  os_version="${VERSION_ID:-}"

  case "${os_id}:${os_version}" in
    ubuntu:22.04 | ubuntu:24.04 | debian:11 | debian:12)
      return 0
      ;;
    *)
      printf 'ERROR unsupported_os id=%s version=%s\n' "${os_id:-unknown}" "${os_version:-unknown}" >&2
      exit 1
      ;;
  esac
}

vpskit_install_resolve_root() {
  local candidate_root bundle_path extract_dir

  if [[ -f "${vpskit_install_repo_root}/vpskit/core/installer_pipeline.sh" ]]; then
    printf '%s\n' "${vpskit_install_repo_root}"
    return 0
  fi

  if [[ -n "${VPSKIT_INSTALL_BUNDLE_DIR:-}" ]] && [[ -f "${VPSKIT_INSTALL_BUNDLE_DIR}/vpskit/core/installer_pipeline.sh" ]]; then
    printf '%s\n' "${VPSKIT_INSTALL_BUNDLE_DIR}"
    return 0
  fi

  if [[ -n "${VPSKIT_INSTALL_BUNDLE_TARBALL:-}" ]] && [[ -n "${VPSKIT_INSTALL_BUNDLE_SHA256:-}" ]]; then
    candidate_root="$(mktemp -d "${TMPDIR:-/tmp}/vpskit-install.XXXXXX")"
    tar -xzf "${VPSKIT_INSTALL_BUNDLE_TARBALL}" -C "${candidate_root}"
    printf '%s\n' "${candidate_root}"
    return 0
  fi

  if [[ -n "${VPSKIT_INSTALL_BUNDLE_URL:-}" ]] && [[ -n "${VPSKIT_INSTALL_BUNDLE_SHA256:-}" ]]; then
    extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/vpskit-install.XXXXXX")"
    bundle_path="${extract_dir}/vpskit-install.tar.gz"
    curl -fsSL -o "${bundle_path}" "${VPSKIT_INSTALL_BUNDLE_URL}"
    printf '%s  %s\n' "${VPSKIT_INSTALL_BUNDLE_SHA256}" "${bundle_path}" | sha256sum -c -
    tar -xzf "${bundle_path}" -C "${extract_dir}"
    printf '%s\n' "${extract_dir}"
    return 0
  fi

  printf 'ERROR missing_installer_bundle reason=local_modules_unavailable\n' >&2
  printf 'Provide the packaged installer bundle or run from the repository checkout.\n' >&2
  exit 1
}

vpskit_install_prepare_environment() {
  export DEBIAN_FRONTEND=noninteractive
  export UFW_FRONTEND=noninteractive
  export NEEDRESTART_MODE=a
}

main() {
  vpskit_install_require_os
  vpskit_install_prepare_environment

  VPSKIT_ROOT="$(vpskit_install_resolve_root)"
  export VPSKIT_ROOT

  # shellcheck disable=SC1091
  source "${VPSKIT_ROOT}/vpskit/core/installer_pipeline.sh"

  vpskit_install_pipeline "$@"
}

main "$@"
