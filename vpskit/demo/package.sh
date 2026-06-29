#!/usr/bin/env bash

VPSKIT_DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_DEMO_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../core/public_surface.sh
source "${VPSKIT_DEMO_DIR}/../core/public_surface.sh"
# shellcheck disable=SC1091
# shellcheck source=../qa/run.sh
source "${VPSKIT_DEMO_DIR}/../qa/run.sh"

vpskit_demo_package_write_file() {
  local output_path="$1"
  local content="$2"

  if ! printf '%s\n' "${content}" >"${output_path}"; then
    return 1
  fi

  return 0
}

vpskit_demo_package_nonempty_dir() {
  local output_dir="$1"

  find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
}

vpskit_demo_package_protocol_layout() {
  cat <<'EOF'
TCP 443  -> Xray -> VLESS Reality
UDP 443  -> Hysteria2
TCP 8443 -> Xray -> Trojan TLS
EOF
}

vpskit_demo_package_qa_report() {
  local report=""

  set +e
  report="$(vpskit_qa_render_report redacted)"
  set -e

  printf '%s\n' "${report}"
}

vpskit_demo_package_readme_en() {
  local output_dir="$1"

  cat <<EOF
# VPSKit Demo Package

This package is a redacted handoff bundle for the VPSKit deployment in \`${output_dir}\`.

Contents:

- \`qa-report.txt\`
- \`protocol-layout.txt\`
- \`client-import-notes.en.md\`
- \`client-import-notes.zh.md\`
- \`security-notes.en.md\`
- \`security-notes.zh.md\`
- \`trojan-redacted.uri\`

Recommended use:

1. Share the redacted files with the customer.
2. Keep the live Trojan credentials private.
3. Re-run \`vpskit qa --redact\` after any delivery change.
EOF
}

vpskit_demo_package_readme_zh() {
  local output_dir="$1"

  cat <<EOF
# VPSKit 演示包

这是用于交付客户的脱敏打包文件，生成于 \`${output_dir}\`。

包含内容：

- \`qa-report.txt\`
- \`protocol-layout.txt\`
- \`client-import-notes.en.md\`
- \`client-import-notes.zh.md\`
- \`security-notes.en.md\`
- \`security-notes.zh.md\`
- \`trojan-redacted.uri\`

建议用途：

1. 只把脱敏文件交给客户。
2. 保留真实 Trojan 凭据在私下。
3. 交付后重新运行 \`vpskit qa --redact\`。
EOF
}

vpskit_demo_package_client_notes_en() {
  cat <<'EOF'
# Client Import Notes

- VLESS Reality is the primary recommendation.
- Hysteria2 is the UDP 443 option for clients that support it.
- Trojan is the compatibility fallback on TCP 8443.
- Trojan uses self-signed TLS by default, so clients may need `allowInsecure=1` or a manually trusted certificate.

Import guidance:

- Shadowrocket: import the VLESS Reality or Trojan URI directly, then confirm the chosen profile is active.
- v2rayNG: import the VLESS Reality URI for the primary route; use the Trojan URI only when compatibility is required.
- Clash Meta: use the Clash Meta export or the redacted URI as a reference for manual profile creation.
- Generic clients: prefer the VLESS Reality profile first; keep Trojan for fallback compatibility only.
EOF
}

vpskit_demo_package_client_notes_zh() {
  cat <<'EOF'
# 客户端导入说明

- VLESS Reality 是首选方案。
- Hysteria2 是支持 UDP 443 客户端的可选方案。
- Trojan 是 TCP 8443 上的兼容回退方案。
- Trojan 默认使用自签名 TLS，客户端可能需要 `allowInsecure=1` 或手动信任证书。

导入建议：

- Shadowrocket：直接导入 VLESS Reality 或 Trojan URI，然后确认当前启用的配置。
- v2rayNG：优先导入 VLESS Reality；仅在需要兼容性时再使用 Trojan。
- Clash Meta：可根据 Clash Meta 导出或脱敏 URI 手动创建配置。
- 通用客户端：优先使用 VLESS Reality，Trojan 仅作为回退方案。
EOF
}

vpskit_demo_package_security_notes_en() {
  cat <<'EOF'
# Security Notes

- Do not share the full Trojan URI publicly.
- Do not share `/var/lib/vpskit/trojan.yaml` publicly because it contains the live password.
- Use the redacted export for screenshots, tickets, and demos.
- Logs may contain public source IP addresses; redact them before sharing.
- The package is intentionally redacted and does not contain private keys.
EOF
}

vpskit_demo_package_security_notes_zh() {
  cat <<'EOF'
# 安全说明

- 不要公开分享完整 Trojan URI。
- 不要公开分享 `/var/lib/vpskit/trojan.yaml`，其中包含真实密码。
- 截图、工单和演示请使用脱敏导出。
- 日志里可能包含公网源 IP，分享前要先脱敏。
- 该打包内容已默认脱敏，不包含私钥。
EOF
}

vpskit_demo_package_command_checklist() {
  cat <<'EOF'
# Command Checklist

```bash
vpskit qa --redact
vpskit qa --redact --output ./qa-report.txt
vpskit sub export trojan --redact
vpskit sub export trojan --redact --output ./trojan-redacted.uri
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
vpskit doctor
```
EOF
}

vpskit_demo_package_main() {
  local output_dir="./vpskit-demo-package"
  local redact_mode="yes"
  local force_mode=0
  local report=""
  local qa_report_status=0
  local trojan_export_status=0

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --redact)
        redact_mode="yes"
        ;;
      --force)
        force_mode=1
        ;;
      --output | -o)
        shift || true
        if [ -z "${1:-}" ]; then
          printf 'DEMO_PACKAGE=fail reason=missing_output_path\n'
          return 1
        fi
        output_dir="${1}"
        ;;
      "" | help | --help | -h)
        cat <<'EOF'
Usage:
  vpskit demo package
  vpskit demo package --redact
  vpskit demo package --output <dir>
  vpskit demo package --redact --output <dir>
  vpskit demo package --force --output <dir>
EOF
        return 0
        ;;
      *)
        vpskit_die "unknown demo option: ${1}"
        return 1
        ;;
    esac

    shift || true
  done

  if [ -e "${output_dir}" ] && [ ! -d "${output_dir}" ]; then
    printf 'DEMO_PACKAGE=fail reason=output_path_not_directory output=%s\n' "${output_dir}"
    return 1
  fi

  if [ -d "${output_dir}" ] && [ "${force_mode}" -ne 1 ] && vpskit_demo_package_nonempty_dir "${output_dir}"; then
    printf 'DEMO_PACKAGE=fail reason=output_directory_not_empty output=%s\n' "${output_dir}"
    return 1
  fi

  mkdir -p "${output_dir}" || {
    printf 'DEMO_PACKAGE=fail reason=mkdir_failed output=%s\n' "${output_dir}"
    return 1
  }

  set +e
  report="$(vpskit_demo_package_qa_report)"
  qa_report_status=$?
  set -e

  if [ "${qa_report_status}" -ne 0 ]; then
    :
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/README.en.md" "$(vpskit_demo_package_readme_en "${output_dir}")"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/README.en.md"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/README.zh.md" "$(vpskit_demo_package_readme_zh "${output_dir}")"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/README.zh.md"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/qa-report.txt" "${report}"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/qa-report.txt"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/protocol-layout.txt" "$(vpskit_demo_package_protocol_layout)"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/protocol-layout.txt"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/client-import-notes.en.md" "$(vpskit_demo_package_client_notes_en)"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/client-import-notes.en.md"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/client-import-notes.zh.md" "$(vpskit_demo_package_client_notes_zh)"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/client-import-notes.zh.md"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/security-notes.en.md" "$(vpskit_demo_package_security_notes_en)"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/security-notes.en.md"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/security-notes.zh.md" "$(vpskit_demo_package_security_notes_zh)"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/security-notes.zh.md"
    return 1
  fi

  if ! vpskit_demo_package_write_file "${output_dir}/command-checklist.txt" "$(vpskit_demo_package_command_checklist)"; then
    printf 'DEMO_PACKAGE=fail reason=write_failed path=%s\n' "${output_dir}/command-checklist.txt"
    return 1
  fi

  set +e
  vpskit_trojan_subscription_export --redact --output "${output_dir}/trojan-redacted.uri" >/dev/null 2>&1
  trojan_export_status=$?
  set -e

  if [ "${trojan_export_status}" -ne 0 ]; then
    printf 'DEMO_PACKAGE=fail reason=trojan_redacted_export_failed output=%s\n' "${output_dir}"
    return 1
  fi

  printf 'DEMO_PACKAGE=pass output=%s redacted=%s\n' "${output_dir}" "${redact_mode}"
  return 0
}

vpskit_demo_dispatch() {
  local subcommand="${1:-}"

  shift || true

  case "${subcommand}" in
    package)
      vpskit_demo_package_main "$@"
      ;;
    "" | help | --help | -h)
      cat <<'EOF'
Usage:
  vpskit demo package
  vpskit demo package --redact
  vpskit demo package --output <dir>
  vpskit demo package --redact --output <dir>
  vpskit demo package --force --output <dir>
EOF
      return 0
      ;;
    *)
      vpskit_die "unknown demo command: ${subcommand}"
      return 1
      ;;
  esac
}
