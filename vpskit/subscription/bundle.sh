#!/usr/bin/env bash

VPSKIT_BUNDLE_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../core/common.sh
source "${VPSKIT_BUNDLE_MODULE_DIR}/../core/common.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/hysteria2.sh
source "${VPSKIT_BUNDLE_MODULE_DIR}/../install/hysteria2.sh"
# shellcheck disable=SC1091
# shellcheck source=../install/trojan.sh
source "${VPSKIT_BUNDLE_MODULE_DIR}/../install/trojan.sh"
# shellcheck disable=SC1091
# shellcheck source=../subscription/export.sh
source "${VPSKIT_BUNDLE_MODULE_DIR}/../subscription/export.sh"
# shellcheck disable=SC1091
# shellcheck source=../qa/run.sh
source "${VPSKIT_BUNDLE_MODULE_DIR}/../qa/run.sh"

VPSKIT_BUNDLE_VERSION="v0.7.0-beta"

vpskit_bundle_default_output_dir() {
  printf '%s\n' "./vpskit-client-bundle"
}

vpskit_bundle_nonempty_dir() {
  local output_dir="$1"

  find "${output_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
}

vpskit_bundle_write_file() {
  local output_path="$1"
  local content="$2"

  mkdir -p "$(dirname "${output_path}")"
  printf '%s\n' "${content}" >"${output_path}"
}

vpskit_bundle_timestamp() {
  if [ -n "${VPSKIT_BUNDLE_GENERATED_AT:-}" ]; then
    printf '%s\n' "${VPSKIT_BUNDLE_GENERATED_AT}"
    return 0
  fi

  date -u +%Y-%m-%dT%H:%M:%SZ
}

vpskit_bundle_protocol_layout() {
  cat <<'EOF'
TCP 443  -> Xray -> VLESS Reality
UDP 443  -> Hysteria2
TCP 8443 -> Xray -> Trojan TLS
EOF
}

vpskit_bundle_security_notes_en() {
  cat <<'EOF'
# Security Notes

- Do not share the full subscription URI publicly.
- Use the redacted bundle for screenshots, tickets, and support.
- Rotate Trojan if the URI or password leaks.
- Logs may contain source IP addresses.
- Trojan is a compatibility fallback; VLESS Reality is the primary recommendation.
- The bundle is redacted and does not include private keys or `.env` files.
EOF
}

vpskit_bundle_security_notes_zh() {
  cat <<'EOF'
# 安全说明

- 不要公开分享完整订阅 URI。
- 截图、工单和支持沟通请使用脱敏包。
- 如果 Trojan URI 或密码泄露，请立即轮换。
- 日志里可能包含源 IP 地址。
- Trojan 只是兼容回退方案，VLESS Reality 才是首选。
- 该打包内容已脱敏，不包含私钥或 `.env` 文件。
EOF
}

vpskit_bundle_import_shadowrocket_en() {
  cat <<'EOF'
# Shadowrocket Import

Use the VLESS Reality URI first. Keep Trojan only as a fallback.

Steps:

1. Open Shadowrocket.
2. Import the `subscriptions/vless-reality.txt` URI or the redacted Trojan URI if needed.
3. Confirm the profile connects on TCP 443.

Notes:

- If the import parser is strict, paste the URI manually.
- For screenshots or support, use the redacted bundle only.
EOF
}

vpskit_bundle_import_shadowrocket_zh() {
  cat <<'EOF'
# Shadowrocket 导入

优先使用 VLESS Reality。Trojan 只作为回退方案。

步骤：

1. 打开 Shadowrocket。
2. 导入 `subscriptions/vless-reality.txt` 对应的 URI，必要时再使用脱敏 Trojan URI。
3. 确认配置能在 TCP 443 上连接。

说明：

- 如果导入解析很严格，可以手动粘贴 URI。
- 截图和支持沟通只使用脱敏包。
EOF
}

vpskit_bundle_import_v2rayng_en() {
  cat <<'EOF'
# v2rayNG Import

Use the VLESS Reality profile as the primary import.

Steps:

1. Open v2rayNG.
2. Import the `subscriptions/vless-reality.txt` URI.
3. Keep the Trojan URI only for compatibility fallback testing.

Notes:

- If direct import fails, paste the URI manually.
- Prefer the redacted bundle for customer handoff.
EOF
}

vpskit_bundle_import_v2rayng_zh() {
  cat <<'EOF'
# v2rayNG 导入

优先导入 VLESS Reality 配置。

步骤：

1. 打开 v2rayNG。
2. 导入 `subscriptions/vless-reality.txt` 对应的 URI。
3. 仅在兼容性回退测试时再使用 Trojan URI。

说明：

- 如果直接导入失败，可以手动粘贴 URI。
- 客户交付优先使用脱敏包。
EOF
}

vpskit_bundle_import_clash_meta_en() {
  cat <<'EOF'
# Clash Meta Import

Import the generated `subscriptions/clash-meta.yaml` file into Clash Meta-compatible clients.

Notes:

- Use the VLESS Reality YAML first.
- Trojan is not the primary Clash route in the bundle.
- If a client needs manual setup, copy the server, port, UUID, and Reality fields from the YAML.
EOF
}

vpskit_bundle_import_clash_meta_zh() {
  cat <<'EOF'
# Clash Meta 导入

将生成的 `subscriptions/clash-meta.yaml` 导入 Clash Meta 兼容客户端。

说明：

- 优先使用 VLESS Reality 的 YAML。
- Trojan 不是这个包里的首选 Clash 路由。
- 如果需要手动配置，可从 YAML 里复制服务器、端口、UUID 和 Reality 字段。
EOF
}

vpskit_bundle_import_sing_box_en() {
  cat <<'EOF'
# sing-box Import

Import the generated `subscriptions/sing-box.json` file into sing-box-compatible clients.

Notes:

- The JSON is built from the VLESS Reality subscription.
- Keep Trojan only for compatibility fallback.
- If your client expects manual values, copy the server, port, UUID, flow, and Reality fields.
EOF
}

vpskit_bundle_import_sing_box_zh() {
  cat <<'EOF'
# sing-box 导入

将生成的 `subscriptions/sing-box.json` 导入 sing-box 兼容客户端。

说明：

- 该 JSON 由 VLESS Reality 订阅生成。
- Trojan 只作为兼容回退方案。
- 如果客户端需要手动填写，可复制服务器、端口、UUID、flow 和 Reality 字段。
EOF
}

vpskit_bundle_troubleshooting_en() {
  cat <<'EOF'
# Common Issues

- Missing subscription file: run the installer or check `VPSKIT_SUBSCRIPTION_FILE`.
- Empty bundle: confirm the installation completed and the subscription files exist.
- Non-empty output directory: rerun with `--force` after checking the contents.
- Unsupported client format: use the matching import file from `subscriptions/`.
- Self-signed TLS and `allowInsecure`: enable insecure TLS only for the Trojan fallback when the client requires it.
- TCP 8443 blocked: confirm the provider firewall and UFW allow TCP 8443.
- Hysteria2 UDP blocked: confirm the provider firewall and UFW allow UDP 443.
EOF
}

vpskit_bundle_troubleshooting_zh() {
  cat <<'EOF'
# 常见问题

- 缺少订阅文件：先运行安装流程，或检查 `VPSKIT_SUBSCRIPTION_FILE`。
- 打包内容为空：确认安装已完成，并且订阅文件确实存在。
- 输出目录非空：确认目录内容后，再使用 `--force` 重新生成。
- 客户端格式不支持：改用 `subscriptions/` 里的对应导入文件。
- 自签名 TLS 和 `allowInsecure`：只有在 Trojan 回退方案需要时才开启不安全 TLS。
- TCP 8443 被拦截：检查云厂商防火墙和 UFW 是否允许 TCP 8443。
- Hysteria2 UDP 被拦截：检查云厂商防火墙和 UFW 是否允许 UDP 443。
EOF
}

vpskit_bundle_readme_en() {
  local output_dir="$1"

  cat <<EOF
# VPSKit Client Bundle

This bundle is the customer-ready handoff package for a VPSKit installation at \`${output_dir}\`.

It includes:

- protocol exports
- import guides for supported clients
- a QA summary
- a protocol layout summary
- security notes

Use it when you need to hand a customer a clean, redacted client bundle after install.

Primary protocol recommendation:

- VLESS Reality on TCP 443
- Hysteria2 on UDP 443
- Trojan on TCP 8443 as the compatibility fallback
EOF
}

vpskit_bundle_readme_zh() {
  local output_dir="$1"

  cat <<EOF
# VPSKit 客户端打包

这个打包目录是面向客户交付的 VPSKit 成品，输出位置是 \`${output_dir}\`。

它包含：

- 协议导出文件
- 支持客户端的导入说明
- QA 汇总
- 协议布局说明
- 安全说明

在安装完成后，需要把一个干净、脱敏的客户端包交给客户时使用。

首选协议：

- TCP 443 上的 VLESS Reality
- UDP 443 上的 Hysteria2
- TCP 8443 上的 Trojan，作为兼容回退方案
EOF
}

vpskit_bundle_command_checklist() {
  cat <<'EOF'
# Command Checklist

```bash
vpskit qa --redact
vpskit sub bundle --redact --output ./vpskit-client-bundle
vpskit sub bundle --redact --force --output ./vpskit-client-bundle
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
vpskit doctor
```
EOF
}

vpskit_bundle_manifest() {
  local generated_at="$1"
  local vless_state="$2"
  local hysteria_state="$3"
  local trojan_state="$4"
  local clash_state="$5"
  local sing_box_state="$6"

  cat <<EOF
VPSKIT_BUNDLE_VERSION=${VPSKIT_BUNDLE_VERSION}
BUNDLE_MODE=redacted
GENERATED_AT=${generated_at}
VLESS_REALITY=${vless_state}
HYSTERIA2=${hysteria_state}
TROJAN=${trojan_state}
CLASH_META=${clash_state}
SING_BOX=${sing_box_state}
SENSITIVE_OUTPUT=redacted
EOF
}

vpskit_bundle_export_main() {
  local output_dir=""
  local redact_mode="yes"
  local force_mode=0
  local generated_at=""
  local qa_summary=""
  local vless_state="missing"
  local hysteria_state="missing"
  local trojan_state="missing"
  local clash_state="skipped"
  local sing_box_state="skipped"
  local bundle_files=0
  local subscription_file=""
  local hysteria2_file=""
  local trojan_file=""
  local uri=""
  local rendered=""

  output_dir="$(vpskit_bundle_default_output_dir)"

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
          printf 'SUB_BUNDLE=fail reason=missing_output_path\n'
          return 1
        fi
        output_dir="${1}"
        ;;
      "" | help | --help | -h)
        cat <<'EOF'
Usage:
  vpskit sub bundle
  vpskit sub bundle --redact
  vpskit sub bundle --output <dir>
  vpskit sub bundle --redact --output <dir>
  vpskit sub bundle --force --output <dir>
EOF
        return 0
        ;;
      *)
        printf 'SUB_BUNDLE=fail reason=unexpected_argument value=%s\n' "${1}"
        return 1
        ;;
    esac

    shift || true
  done

  if [ -e "${output_dir}" ] && [ ! -d "${output_dir}" ]; then
    printf 'SUB_BUNDLE=fail reason=output_path_not_directory output=%s\n' "${output_dir}"
    return 1
  fi

  if [ -d "${output_dir}" ] && [ "${force_mode}" -ne 1 ] && vpskit_bundle_nonempty_dir "${output_dir}"; then
    printf 'SUB_BUNDLE=fail reason=output_directory_not_empty output=%s\n' "${output_dir}"
    return 1
  fi

  if [ -d "${output_dir}" ] && [ "${force_mode}" -eq 1 ]; then
    find "${output_dir}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  fi

  if ! mkdir -p "${output_dir}/subscriptions" "${output_dir}/troubleshooting"; then
    printf 'SUB_BUNDLE=fail reason=mkdir_failed output=%s\n' "${output_dir}"
    return 1
  fi

  generated_at="$(vpskit_bundle_timestamp)"

  set +e
  qa_summary="$(vpskit_qa_render_report redacted)"
  set -e

  if ! vpskit_bundle_write_file "${output_dir}/README.en.md" "$(vpskit_bundle_readme_en "${output_dir}")"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/README.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/README.zh.md" "$(vpskit_bundle_readme_zh "${output_dir}")"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/README.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/protocol-layout.txt" "$(vpskit_bundle_protocol_layout)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/protocol-layout.txt"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/security-notes.en.md" "$(vpskit_bundle_security_notes_en)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/security-notes.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/security-notes.zh.md" "$(vpskit_bundle_security_notes_zh)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/security-notes.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-shadowrocket.en.md" "$(vpskit_bundle_import_shadowrocket_en)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-shadowrocket.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-shadowrocket.zh.md" "$(vpskit_bundle_import_shadowrocket_zh)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-shadowrocket.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-v2rayng.en.md" "$(vpskit_bundle_import_v2rayng_en)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-v2rayng.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-v2rayng.zh.md" "$(vpskit_bundle_import_v2rayng_zh)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-v2rayng.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-clash-meta.en.md" "$(vpskit_bundle_import_clash_meta_en)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-clash-meta.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-clash-meta.zh.md" "$(vpskit_bundle_import_clash_meta_zh)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-clash-meta.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-sing-box.en.md" "$(vpskit_bundle_import_sing_box_en)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-sing-box.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/import-sing-box.zh.md" "$(vpskit_bundle_import_sing_box_zh)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/import-sing-box.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/troubleshooting/common-issues.en.md" "$(vpskit_bundle_troubleshooting_en)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/troubleshooting/common-issues.en.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/troubleshooting/common-issues.zh.md" "$(vpskit_bundle_troubleshooting_zh)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/troubleshooting/common-issues.zh.md"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/command-checklist.txt" "$(vpskit_bundle_command_checklist)"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/command-checklist.txt"
    return 1
  fi

  if ! vpskit_bundle_write_file "${output_dir}/qa-summary.txt" "${qa_summary}"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/qa-summary.txt"
    return 1
  fi

  subscription_file="$(vpskit_system_path "$(vpskit_default_subscription_file)")"
  if [ -f "${subscription_file}" ]; then
    vless_state="present"

    if ! vpskit_bundle_write_file "${output_dir}/subscriptions/vless-reality.txt" "$(<"${subscription_file}")"; then
      printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/subscriptions/vless-reality.txt"
      return 1
    fi

    if uri="$(vpskit_subscription_first_uri "${subscription_file}")"; then
      :
    else
      printf 'SUB_BUNDLE=fail reason=invalid_vless_subscription\n'
      return 1
    fi

    if rendered="$(vpskit_subscription_render_export clash-meta "${uri}")"; then
      if ! vpskit_bundle_write_file "${output_dir}/subscriptions/clash-meta.yaml" "${rendered}"; then
        printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/subscriptions/clash-meta.yaml"
        return 1
      fi
      clash_state="present"
    else
      printf 'SUB_BUNDLE=fail reason=invalid_vless_subscription\n'
      return 1
    fi

    if rendered="$(vpskit_subscription_render_export sing-box "${uri}")"; then
      if ! vpskit_bundle_write_file "${output_dir}/subscriptions/sing-box.json" "${rendered}"; then
        printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/subscriptions/sing-box.json"
        return 1
      fi
      sing_box_state="present"
    else
      printf 'SUB_BUNDLE=fail reason=invalid_vless_subscription\n'
      return 1
    fi
  fi

  hysteria2_file="$(vpskit_system_path "$(vpskit_hysteria2_subscription_file)")"
  if [ -f "${hysteria2_file}" ]; then
    hysteria_state="present"

    if rendered="$(vpskit_hysteria2_subscription_export)"; then
      if ! vpskit_bundle_write_file "${output_dir}/subscriptions/hysteria2.yaml" "${rendered}"; then
        printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/subscriptions/hysteria2.yaml"
        return 1
      fi
    else
      printf 'SUB_BUNDLE=fail reason=invalid_hysteria2_subscription\n'
      return 1
    fi
  fi

  trojan_file="$(vpskit_system_path "$(vpskit_trojan_subscription_file)")"
  if [ -f "${trojan_file}" ]; then
    trojan_state="present"

    if rendered="$(vpskit_trojan_subscription_export --redact)"; then
      if ! vpskit_bundle_write_file "${output_dir}/subscriptions/trojan-redacted.uri" "${rendered}"; then
        printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/subscriptions/trojan-redacted.uri"
        return 1
      fi
    else
      printf 'SUB_BUNDLE=fail reason=invalid_trojan_subscription\n'
      return 1
    fi
  fi

  if ! vpskit_bundle_write_file "${output_dir}/manifest.txt" "$(vpskit_bundle_manifest "${generated_at}" "${vless_state}" "${hysteria_state}" "${trojan_state}" "${clash_state}" "${sing_box_state}")"; then
    printf 'SUB_BUNDLE=fail reason=write_failed path=%s\n' "${output_dir}/manifest.txt"
    return 1
  fi

  bundle_files="$(find "${output_dir}" -type f 2>/dev/null | wc -l | tr -d '[:space:]')"

  printf 'SUB_BUNDLE=pass output=%s redacted=%s\n' "${output_dir}" "${redact_mode}"
  printf 'SUB_BUNDLE_FILES=%s\n' "${bundle_files}"
  printf 'SENSITIVE_OUTPUT=redacted\n'
  return 0
}
