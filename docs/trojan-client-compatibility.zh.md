# Trojan 客户端兼容性

VPSKit 提供 Trojan 作为兼容性回退方案。VLESS Reality 仍然是推荐的主协议。

协议布局：

```text
TCP 8443 -> Xray Trojan TLS inbound
```

Trojan 运行在 Xray 进程内部，所以进程级检查会显示 `xray` 占用 TCP 8443。这是正常现象。协议级入口仍然是 Trojan。

## 客户端设置

- 协议：`Trojan`
- 端口：`8443`
- 密码：导出的 Trojan 密码
- SNI：导出的 `sni`，或者在手动配置时使用服务器 IP
- `allowInsecure`：客户端如果校验证书，设置为 `true` 或 `1`

## 凭据轮换

- 如果 URI 已泄露，运行 `vpskit rotate trojan --yes`，然后把新的 URI 重新导入到每个客户端。
- 真实轮换前可先运行 `vpskit rotate trojan --dry-run`，确认本地状态已经准备好。
- 需要截图、提工单或支持沟通时，使用 `vpskit sub export trojan --redact`。

VPSKit v0.6.0-beta 和 v0.6.1-beta 的 Trojan 默认使用自签名 TLS。客户端如果不信任证书，需要开启 `allowInsecure`，或者手动导入证书信任链。

## 导入说明

- Shadowrocket：直接导入导出的 `trojan://` URI，或者在解析严格时手动填写。
- v2rayNG：使用 Trojan 导入流程，若支持直接粘贴 URI 就使用导出的链接。
- Clash Meta 兼容客户端：导入 URI，或者手动创建启用 TLS 的 Trojan 配置。
- 通用 Trojan 客户端：按导出内容填写 host、port、password、SNI 和 insecure-TLS 选项。

## 排查

- 无法导入 URI：重新复制一次，确认剪贴板工具没有去掉特殊字符。
- TLS 证书错误：开启 `allowInsecure`，或者信任自签名证书。
- 8443 被拦截：确认 UFW 已放行 TCP 8443，并且外部网络可达。
- SNI 错误：优先使用导出的 `sni`，或者在手动配置时填服务器 IP。
- `allowInsecure` 关闭：自签名 beta 环境通常需要打开它。
- 复制后的 URI 丢失特殊字符：重新导出，不要经过会改写链接的应用。
- 服务器端显示 `xray`：这是正常的。Xray 是进程，Trojan 是入口协议。
