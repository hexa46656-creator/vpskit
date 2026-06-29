#!/usr/bin/env bash

VPSKIT_TROJAN_ROTATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_TROJAN_ROTATE_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/system_check.sh
source "${VPSKIT_TROJAN_ROTATE_DIR}/../core/system_check.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/install_lock.sh
source "${VPSKIT_TROJAN_ROTATE_DIR}/../core/install_lock.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/transaction.sh
source "${VPSKIT_TROJAN_ROTATE_DIR}/../core/transaction.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_TROJAN_ROTATE_DIR}/../core/public_surface.sh"

vpskit_trojan_rotate_new_password() {
  if [ -n "${VPSKIT_TEST_TROJAN_ROTATE_PASSWORD:-}" ]; then
    printf '%s\n' "${VPSKIT_TEST_TROJAN_ROTATE_PASSWORD}"
    return 0
  fi

  openssl rand -hex 32
}

vpskit_trojan_rotate_state_ready() {
  local xray_bin
  local config_path
  local subscription_file
  local config_state

  if ! xray_bin="$(vpskit_vless_xray_bin 2>/dev/null)"; then
    printf 'TROJAN_ROTATE_DRY_RUN=fail reason=xray_binary_missing\n'
    return 1
  fi

  if [ ! -x "${xray_bin}" ]; then
    printf 'TROJAN_ROTATE_DRY_RUN=fail reason=xray_binary_missing\n'
    return 1
  fi

  config_path="$(vpskit_system_path "$(vpskit_trojan_config_path)")"
  if [ ! -f "${config_path}" ]; then
    printf 'TROJAN_ROTATE_DRY_RUN=fail reason=xray_config_missing\n'
    return 1
  fi

  config_state="$(vpskit_trojan_xray_config_state)"
  if [ "${config_state}" != "present" ]; then
    printf 'TROJAN_ROTATE_DRY_RUN=fail reason=trojan_config_missing\n'
    return 1
  fi

  subscription_file="$(vpskit_system_path "$(vpskit_trojan_subscription_file)")"
  if [ ! -f "${subscription_file}" ]; then
    printf 'TROJAN_ROTATE_DRY_RUN=fail reason=subscription_file_missing\n'
    return 1
  fi

  printf 'TROJAN_ROTATE_DRY_RUN=pass\n'
  return 0
}

vpskit_trojan_rotate_rollback_failure() {
  local xray_service_state=""
  local tcp_443_owner=""
  local tcp_8443_owner=""
  local rollback_status=0

  vpskit_transaction_abort || rollback_status=$?

  if [ "${rollback_status}" -eq 0 ]; then
    vpskit_run_mutation systemctl restart xray || rollback_status=$?
  fi

  if [ "${rollback_status}" -eq 0 ]; then
    if ! vpskit_is_test_mode; then
      sleep 1
    fi

    xray_service_state="$(vpskit_vless_xray_service_summary)"
    tcp_443_owner="$(vpskit_trojan_tcp_443_owner)"
    export VPSKIT_TROJAN_POST_RESTART=1
    if [ -n "${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART:-}" ]; then
      tcp_8443_owner="${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART}"
    else
      tcp_8443_owner="$(vpskit_trojan_tcp_8443_owner)"
    fi
    unset VPSKIT_TROJAN_POST_RESTART

    if [ "${xray_service_state}" != "active" ] || [ "${tcp_443_owner}" != "xray" ] || [ "${tcp_8443_owner}" != "xray" ]; then
      rollback_status=1
    fi
  fi

  if [ "${rollback_status}" -eq 0 ]; then
    printf 'XRAY_ROLLBACK=pass reason=trojan_rotate_failed\n'
  else
    printf 'XRAY_ROLLBACK=fail reason=restore_failed\n'
  fi

  return "${rollback_status}"
}

vpskit_trojan_rotate_post_validation() {
  local xray_service_state
  local tcp_443_owner
  local tcp_8443_owner

  xray_service_state="$(vpskit_vless_xray_service_summary)"
  tcp_443_owner="$(vpskit_trojan_tcp_443_owner)"
  export VPSKIT_TROJAN_POST_RESTART=1
  if [ -n "${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART:-}" ]; then
    tcp_8443_owner="${VPSKIT_TEST_TCP_8443_OWNER_AFTER_RESTART}"
  else
    tcp_8443_owner="$(vpskit_trojan_tcp_8443_owner)"
  fi
  unset VPSKIT_TROJAN_POST_RESTART

  if [ "${xray_service_state}" != "active" ]; then
    printf 'TROJAN_ROTATE=fail reason=xray_service_inactive\n'
    return 1
  fi

  if [ "${tcp_443_owner}" != "xray" ]; then
    printf 'TROJAN_ROTATE=fail reason=vless_reality_not_preserved tcp_443=%s\n' "${tcp_443_owner:-none}"
    return 1
  fi

  if [ "${tcp_8443_owner}" != "xray" ]; then
    printf 'TROJAN_ROTATE=fail reason=tcp_8443_not_bound actual=%s\n' "${tcp_8443_owner:-none}"
    return 1
  fi

  if [ "$(vpskit_trojan_xray_config_state)" != "present" ]; then
    printf 'TROJAN_ROTATE=fail reason=trojan_config_missing\n'
    return 1
  fi

  if [ ! -s "$(vpskit_system_path "$(vpskit_trojan_subscription_file)")" ]; then
    printf 'TROJAN_ROTATE=fail reason=subscription_file_missing\n'
    return 1
  fi

  return 0
}

vpskit_trojan_rotate_confirm() {
  if [ "${VPSKIT_TROJAN_ROTATE_YES:-0}" = "1" ]; then
    return 0
  fi

  if vpskit_is_test_mode || [ ! -t 0 ]; then
    printf 'TROJAN_ROTATE=fail reason=confirmation_required\n'
    return 1
  fi

  printf 'Rotate Trojan password now? [y/N] '
  if ! read -r response; then
    printf 'TROJAN_ROTATE=fail reason=confirmation_required\n'
    return 1
  fi

  case "${response}" in
    y | Y | yes | YES)
      return 0
      ;;
  esac

  printf 'TROJAN_ROTATE=fail reason=confirmation_declined\n'
  return 1
}

vpskit_rotate_trojan() {
  local status=0
  local xray_bin=""
  local server_address=""
  local old_password=""
  local new_password=""
  local sni=""
  local allow_insecure="1"
  local rendered_config=""
  local rendered_yaml=""
  local rendered_env=""
  local candidate_config_path=""

  if vpskit_is_dry_run; then
    vpskit_trojan_rotate_state_ready
    return $?
  fi

  vpskit_require_root || return 1
  vpskit_trojan_rotate_confirm || return 1
  vpskit_transaction_init

  if ! xray_bin="$(vpskit_vless_xray_bin)"; then
    printf 'TROJAN_ROTATE=fail reason=xray_binary_missing\n'
    vpskit_transaction_abort
    return 1
  fi

  if [ ! -x "${xray_bin}" ]; then
    printf 'TROJAN_ROTATE=fail reason=xray_binary_missing\n'
    vpskit_transaction_abort
    return 1
  fi

  if [ "$(vpskit_trojan_xray_config_state)" != "present" ]; then
    printf 'TROJAN_ROTATE=fail reason=trojan_config_missing\n'
    vpskit_transaction_abort
    return 1
  fi

  if [ ! -s "$(vpskit_system_path "$(vpskit_trojan_subscription_file)")" ]; then
    printf 'TROJAN_ROTATE=fail reason=subscription_file_missing\n'
    vpskit_transaction_abort
    return 1
  fi

  server_address="$(vpskit_trojan_server_state_value server 2>/dev/null || true)"
  old_password="$(vpskit_trojan_server_state_value password 2>/dev/null || true)"
  sni="$(vpskit_trojan_server_state_value sni 2>/dev/null || true)"
  allow_insecure="$(vpskit_trojan_server_state_value allowInsecure 2>/dev/null || true)"
  new_password="$(vpskit_trojan_rotate_new_password)"

  if [ -z "${server_address}" ] || [ -z "${old_password}" ] || [ -z "${sni}" ]; then
    printf 'TROJAN_ROTATE=fail reason=trojan_state_unavailable\n'
    vpskit_transaction_abort
    return 1
  fi

  if [ -z "${allow_insecure}" ]; then
    allow_insecure="1"
  fi

  rendered_config="$(
    vpskit_trojan_xray_config_merge "${new_password}"
  )" || {
    printf 'TROJAN_ROTATE=fail reason=xray_config_update_failed\n'
    vpskit_transaction_abort
    return 1
  }

  candidate_config_path="$(vpskit_trojan_candidate_xray_config_path)"
  vpskit_write_managed_file "${candidate_config_path}" 0644 "${rendered_config}" || {
    printf 'TROJAN_ROTATE=fail reason=xray_config_write_failed\n'
    vpskit_transaction_abort
    return 1
  }
  if ! vpskit_trojan_validate_candidate_xray_config "${xray_bin}" "${candidate_config_path}"; then
    rm -f "${candidate_config_path}"
    printf 'TROJAN_ROTATE=fail reason=xray_config_invalid\n'
    vpskit_transaction_abort
    return 1
  fi
  rm -f "${candidate_config_path}"
  candidate_config_path=""

  rendered_yaml="$(vpskit_trojan_render_subscription_yaml "${server_address}" "${new_password}" "${sni}" "${allow_insecure}")"
  rendered_env="$(vpskit_trojan_render_env_file "${server_address}" "${new_password}" "${sni}" "${allow_insecure}")"

  vpskit_write_managed_file "$(vpskit_trojan_config_path)" 0644 "${rendered_config}" || {
    printf 'TROJAN_ROTATE=fail reason=xray_config_write_failed\n'
    vpskit_transaction_abort
    return 1
  }
  vpskit_write_managed_file "$(vpskit_trojan_subscription_file)" 0600 "${rendered_yaml}" || {
    printf 'TROJAN_ROTATE=fail reason=subscription_write_failed\n'
    vpskit_transaction_abort
    return 1
  }
  vpskit_write_managed_file "$(vpskit_trojan_env_file)" 0600 "${rendered_env}" || {
    printf 'TROJAN_ROTATE=fail reason=env_write_failed\n'
    vpskit_transaction_abort
    return 1
  }

  vpskit_run_mutation systemctl daemon-reload || status=$?
  vpskit_run_mutation systemctl restart xray || status=$?
  if [ "${status}" -ne 0 ]; then
    printf 'TROJAN_ROTATE=fail reason=xray_restart_failed\n'
    if ! vpskit_trojan_rotate_rollback_failure; then
      :
    fi
    return 1
  fi

  if ! vpskit_is_test_mode; then
    sleep 1
  fi

  export VPSKIT_TROJAN_POST_RESTART=1
  if ! vpskit_trojan_rotate_post_validation; then
    unset VPSKIT_TROJAN_POST_RESTART
    printf 'TROJAN_ROTATE=fail reason=post_validation_failed\n'
    if ! vpskit_trojan_rotate_rollback_failure; then
      :
    fi
    return 1
  fi
  unset VPSKIT_TROJAN_POST_RESTART

  vpskit_transaction_commit
  printf 'TROJAN_ROTATE=pass\n'
  printf 'TROJAN_PASSWORD_OLD=redacted\n'
  printf 'TROJAN_PASSWORD_NEW=redacted\n'
  printf 'TROJAN_SUBSCRIPTION_FILE=%s\n' "$(vpskit_trojan_subscription_file)"
  printf 'VLESS_REALITY_PRESERVED=pass tcp_443=bound service=xray\n'
  printf 'TCP_8443_LISTENER=pass service=xray\n'
  return 0
}
