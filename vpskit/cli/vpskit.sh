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
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_ROOT}/core/public_surface.sh"
# shellcheck disable=SC1091
# shellcheck source=../rotate/trojan.sh
source "${VPSKIT_ROOT}/rotate/trojan.sh"
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
# shellcheck source=../qa/run.sh
source "${VPSKIT_ROOT}/qa/run.sh"
# shellcheck disable=SC1091
# shellcheck source=../verify/checks.sh
source "${VPSKIT_ROOT}/verify/checks.sh"

vpskit_cli_version() {
  cat <<'EOF'
VPSKit v0.7.0-beta
Available commands: version, status, doctor, qa, sub, demo, fix, install, verify, rotate
Available components: CLI, read-only QA, static release packaging, DNS health, TCP probe, fallback report, Shadowrocket repair, subscription export, rotate compatibility
EOF
}

vpskit_cli_status() {
  printf 'VERSION=VPSKit v0.7.0-beta\n'
  vpskit_system_inspection_summary
  printf 'CLI=available\n'
  printf 'QA=available\n'
  printf 'SUB_BUNDLE=available\n'
  printf 'SUBSCRIPTION_REPAIR=available\n'
  printf 'SUBSCRIPTION_EXPORT=available\n'
  printf 'DNS_HEALTH=available\n'
  printf 'TCP_PROBE=available\n'
  printf 'FALLBACK_REPORT=available\n'
  printf 'TROJAN=available\n'
  printf 'HYSTERIA2=available\n'
  printf 'SAFETY=simulation-only\n'
}

vpskit_cli_doctor() {
  local dns_target="${VPSKIT_DNS_TARGET:-www.cloudflare.com}"
  local tcp_host="${VPSKIT_DOCTOR_TCP_HOST:-127.0.0.1}"
  local tcp_port="${VPSKIT_DOCTOR_TCP_PORT:-443}"
  local subscription_file
  local dns_state
  local tcp_state

  vpskit_system_inspection_summary
  vpskit_cli_tcp_443_status
  dns_state="$(vpskit_dns_health "${dns_target}" || true)"
  tcp_state="$(vpskit_tcp_probe "${tcp_host}" "${tcp_port}" || true)"
  printf 'DNS_HEALTH=%s\n' "${dns_state}"
  printf 'TCP_PROBE=%s\n' "${tcp_state}"

  subscription_file="$(vpskit_default_subscription_file)"
  if [ -f "${subscription_file}" ]; then
    printf 'SUBSCRIPTION_FILE=present\n'
  else
    printf 'SUBSCRIPTION_FILE=missing\n'
  fi

  vpskit_reality_doctor
  vpskit_trojan_doctor
  vpskit_hysteria2_doctor
}

vpskit_cli_tcp_443_status() {
  local config_path

  config_path="$(vpskit_system_path "${VPSKIT_XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}")"

  if [ "${VPSKIT_TEST_TCP_443_OWNER:-}" = "xray" ] && [ -f "${config_path}" ] && [ -f "$(vpskit_default_subscription_file)" ]; then
    printf 'TCP_443_STATUS=in_use_expected service=xray\n'
    return 0
  fi

  if command -v ss >/dev/null 2>&1 && [ -f "${config_path}" ] && [ -f "$(vpskit_default_subscription_file)" ]; then
    if ss -H -ltnp 'sport = :443' 2>/dev/null | grep -q 'xray'; then
      printf 'TCP_443_STATUS=in_use_expected service=xray\n'
      return 0
    fi
  fi

  printf 'TCP_443_STATUS=unverified\n'
}

vpskit_cli_sub() {
  local subcommand="${1:-show}"

  shift || true

  case "${subcommand}" in
    show)
      local subscription_file
      local output_dir="${VPSKIT_OUTPUT_DIR:-${VPSKIT_ROOT}/output}"
      local default_output="${output_dir}/final_links.txt"

      subscription_file="$(vpskit_default_subscription_file)"
      if [ -f "${subscription_file}" ]; then
        cat "${subscription_file}"
        return 0
      fi

      if [ -f "${default_output}" ]; then
        cat "${default_output}"
        return 0
      fi

      printf 'No subscription file is configured.\n'
      printf 'Next step: set VPSKIT_SUBSCRIPTION_FILE or generate one with the release docs.\n'
      return 0
      ;;
    formats)
      vpskit_subscription_supported_formats
      return 0
      ;;
    export)
      if vpskit_cli_sub_export "$@"; then
        return 0
      fi
      return 1
      ;;
    bundle)
      if vpskit_cli_sub_bundle "$@"; then
        return 0
      fi
      return 1
      ;;
    validate)
      if vpskit_cli_sub_validate; then
        return 0
      fi
      return 1
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit sub show
  vpskit sub formats
  vpskit sub export <format>
  vpskit sub export <format> --output <path>
  vpskit sub export <format> -o <path>
  vpskit sub export hysteria2
  vpskit sub export trojan
  vpskit sub export trojan --redact
  vpskit sub export trojan --redact --output <path>
  vpskit sub export trojan --redact -o <path>
  vpskit sub bundle
  vpskit sub bundle --redact
  vpskit sub bundle --output <dir>
  vpskit sub bundle --redact --output <dir>
  vpskit sub bundle --force --output <dir>
  vpskit sub validate
EOF
      return 0
      ;;
    *)
      vpskit_die "unknown sub command: ${subcommand}"
      return 1
      ;;
  esac
}

vpskit_cli_sub_export() {
  local format="${1:-}"
  local subscription_file
  local uri
  local rendered
  local output_path=""

  shift || true

  case "${format}" in
    raw | shadowrocket | v2rayng | base64 | clash-meta | sing-box | hysteria2 | trojan)
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit sub export raw
  vpskit sub export base64
  vpskit sub export shadowrocket
  vpskit sub export v2rayng
  vpskit sub export clash-meta
  vpskit sub export sing-box
  vpskit sub export hysteria2
  vpskit sub export trojan
  vpskit sub export trojan --redact
  vpskit sub export trojan --redact --output <path>
  vpskit sub export trojan --redact -o <path>
  vpskit sub export <format> --output <path>
  vpskit sub export <format> -o <path>
EOF
      return 0
      ;;
    *)
      printf 'SUB_EXPORT=fail reason=unsupported_format format=%s\n' "${format}"
      return 1
      ;;
  esac

  if [ "${format}" = "trojan" ]; then
    if vpskit_trojan_subscription_export "$@"; then
      return 0
    fi
    return 1
  fi

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --output | -o)
        shift || true
        if [ -z "${1:-}" ]; then
          printf 'SUB_EXPORT=fail reason=missing_output_path\n'
          return 1
        fi
        output_path="${1}"
        ;;
      *)
        printf 'SUB_EXPORT=fail reason=unexpected_argument value=%s\n' "${1}"
        return 1
        ;;
    esac

    shift || true
  done

  if [ "${format}" = "hysteria2" ]; then
    if rendered="$(vpskit_hysteria2_subscription_export)"; then
      :
    else
      printf '%s\n' "${rendered}"
      return 1
    fi

    if [ -n "${output_path}" ]; then
      if vpskit_subscription_write_output_file "${format}" "${output_path}" "${rendered}"; then
        return 0
      fi
      return 1
    fi

    printf '%s\n' "${rendered}"
    return 0
  fi

  if subscription_file="$(vpskit_subscription_resolve_file)"; then
    :
  else
    printf '%s\n' "${subscription_file}"
    return 1
  fi

  case "${format}" in
    raw | shadowrocket | v2rayng)
      if [ -n "${output_path}" ]; then
        if vpskit_subscription_write_output_file "${format}" "${output_path}" "$(<"${subscription_file}")"; then
          return 0
        fi
        return 1
      fi

      vpskit_subscription_print_file "${subscription_file}"
      return 0
      ;;
  esac

  if uri="$(vpskit_subscription_first_uri "${subscription_file}")"; then
    :
  else
    printf '%s\n' "${uri}"
    return 1
  fi

  if rendered="$(vpskit_subscription_render_export "${format}" "${uri}")"; then
    :
  else
    printf '%s\n' "${rendered}"
    return 1
  fi

  if [ -n "${output_path}" ]; then
    if vpskit_subscription_write_output_file "${format}" "${output_path}" "${rendered}"; then
      return 0
    fi
    return 1
  fi

  printf '%s\n' "${rendered}"
}

vpskit_cli_sub_validate() {
  local subscription_file
  local uri

  if subscription_file="$(vpskit_subscription_resolve_file)"; then
    :
  else
    printf '%s\n' "${subscription_file}"
    return 1
  fi

  if uri="$(vpskit_subscription_first_uri "${subscription_file}")"; then
    :
  else
    printf '%s\n' "${uri}"
    return 1
  fi

  if vpskit_subscription_validate "${uri}"; then
    return 0
  fi

  return 1
}

vpskit_cli_sub_bundle() {
  bash "${VPSKIT_ROOT}/subscription/bundle.sh" "$@"
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

  dns_state="$(vpskit_dns_health "${VPSKIT_DNS_TARGET:-www.cloudflare.com}" || true)"
  tcp_state="$(vpskit_tcp_probe "${VPSKIT_DOCTOR_TCP_HOST:-127.0.0.1}" "${VPSKIT_DOCTOR_TCP_PORT:-443}" || true)"
  vpskit_fallback_report "${dns_state}" "${tcp_state}"
}

vpskit_cli_install() {
  local target="${1:-}"

  case "${target}" in
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit install <target>
EOF
      ;;
    *)
      printf 'INSTALL=fail reason=installer_layer_separated target=%s\n' "${target}"
      return 1
      ;;
  esac
}

vpskit_cli_demo() {
  bash "${VPSKIT_ROOT}/demo/package.sh" "$@"
}

vpskit_cli_verify() {
  local target="${1:-}"

  case "${target}" in
    ssh-user)
      vpskit_verify_ssh_user
      ;;
    vless-reality)
      vpskit_verify_vless_reality
      ;;
    hysteria2)
      vpskit_verify_hysteria2
      ;;
    trojan)
      vpskit_verify_trojan
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit verify ssh-user
  vpskit verify vless-reality
  vpskit verify hysteria2
  vpskit verify trojan
EOF
      ;;
    *)
      vpskit_die "unknown verify target: ${target}"
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
  vpskit qa
  vpskit qa --redact
  vpskit qa --output <path>
  vpskit qa --redact --output <path>
  vpskit sub
  vpskit sub show
  vpskit sub formats
  vpskit sub export <format>
  vpskit sub export <format> --output <path>
  vpskit sub export <format> -o <path>
  vpskit sub export hysteria2
  vpskit sub export trojan
  vpskit sub export trojan --redact
  vpskit sub export trojan --redact --output <path>
  vpskit sub export trojan --redact -o <path>
  vpskit sub bundle
  vpskit sub bundle --redact
  vpskit sub bundle --output <dir>
  vpskit sub bundle --redact --output <dir>
  vpskit sub bundle --force --output <dir>
  vpskit sub validate
  vpskit release bundle
  vpskit demo package
  vpskit demo package --redact
  vpskit demo package --output <dir>
  vpskit demo package --redact --output <dir>
  vpskit demo package --force --output <dir>
  vpskit fix
  vpskit install <target>
  vpskit verify ssh-user
  vpskit verify vless-reality
  vpskit verify hysteria2
  vpskit verify trojan
  vpskit rotate trojan
  vpskit rotate trojan --yes
  vpskit rotate trojan --dry-run
EOF
}

vpskit_cli_release() {
  local subcommand="${1:-bundle}"

  shift || true

  case "${subcommand}" in
    bundle)
      local project_root
      local release_script

      project_root="$(cd "${VPSKIT_ROOT}/.." && pwd)"
      release_script="${project_root}/scripts/release_packager.sh"

      if [ ! -f "${release_script}" ]; then
        vpskit_die "release bundle script not found: ${release_script}"
        return 1
      fi

      bash "${release_script}" "$@"
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit release bundle
EOF
      return 0
      ;;
    *)
      vpskit_die "unknown release command: ${subcommand}"
      return 1
      ;;
  esac
}

vpskit_cli_rotate() {
  local target="${1:-}"
  local yes_flag=0
  local dry_run_flag=0

  shift || true

  case "${target}" in
    trojan)
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit rotate trojan
  vpskit rotate trojan --yes
  vpskit rotate trojan --dry-run
EOF
      return 0
      ;;
    *)
      vpskit_die "unknown rotate target: ${target}"
      return 1
      ;;
  esac

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --yes)
        yes_flag=1
        ;;
      --dry-run)
        dry_run_flag=1
        ;;
      "" | help | --help | -h)
        cat <<'EOF'
Usage:
  vpskit rotate trojan
  vpskit rotate trojan --yes
  vpskit rotate trojan --dry-run
EOF
        return 0
        ;;
      *)
        vpskit_die "unknown rotate option: ${1}"
        return 1
        ;;
    esac

    shift || true
  done

  if [ "${dry_run_flag}" -eq 1 ]; then
    VPSKIT_DRY_RUN=1 vpskit_rotate_trojan
    return $?
  fi

  if [ "${yes_flag}" -eq 1 ]; then
    VPSKIT_TROJAN_ROTATE_YES=1 vpskit_with_lock vpskit_rotate_trojan
    return $?
  fi

  vpskit_with_lock vpskit_rotate_trojan
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
    qa)
      vpskit_cli_qa "$@"
      ;;
    sub)
      vpskit_cli_sub "$@"
      ;;
    release)
      vpskit_cli_release "$@"
      ;;
    demo)
      vpskit_cli_demo "$@"
      ;;
    fix)
      vpskit_cli_fix "$@"
      ;;
    install)
      vpskit_cli_install "$@"
      ;;
    verify)
      vpskit_cli_verify "$@"
      ;;
    rotate)
      vpskit_cli_rotate "$@"
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
