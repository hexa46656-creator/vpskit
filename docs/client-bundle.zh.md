# 客户端打包

## 这是什么

`vpskit sub bundle` 会生成一个面向客户交付的目录，里面包含脱敏后的客户端导出、导入说明、QA 输出和排障说明。

## 什么时候用

- VPSKit 安装成功之后
- 需要交付一个干净的客户包时
- 做教程、截图或支持回复时

## 如何生成

```bash
vpskit sub bundle
vpskit sub bundle --redact --output ./vpskit-client-bundle
vpskit sub bundle --redact --force --output ./vpskit-client-bundle
```

## 包含内容

- `README.en.md`
- `README.zh.md`
- `manifest.txt`
- `protocol-layout.txt`
- `security-notes.en.md`
- `security-notes.zh.md`
- `import-shadowrocket.en.md`
- `import-shadowrocket.zh.md`
- `import-v2rayng.en.md`
- `import-v2rayng.zh.md`
- `import-clash-meta.en.md`
- `import-clash-meta.zh.md`
- `import-sing-box.en.md`
- `import-sing-box.zh.md`
- `qa-summary.txt`
- `command-checklist.txt`
- `subscriptions/`
- `troubleshooting/`

## 故意不包含

- `.env` 文件
- 私钥
- `server.key`
- 原始日志
- 脱敏模式下的完整 Trojan URI

## 导入说明

- Shadowrocket：先导入 `subscriptions/vless-reality.txt`，只有在需要回退兼容时才用脱敏 Trojan URI。
- v2rayNG：优先导入 VLESS Reality URI。
- Clash Meta：导入 `subscriptions/clash-meta.yaml`。
- sing-box：导入 `subscriptions/sing-box.json`。

## 安全提示

- 不要公开完整订阅 URI。
- 截图和支持沟通请使用 `--redact`。
- 如果 Trojan 泄露，先轮换再重新打包。
- 日志里可能包含源 IP 地址。

## 排障

- 缺少订阅文件：确认安装完成并且源文件存在。
- 打包内容为空：先确认订阅文件不是空的。
- 输出目录非空：改用 `--force`。
- 客户端格式不支持：使用 `subscriptions/` 里的对应文件。
- 自签名 TLS 和 `allowInsecure`：只在 Trojan 回退方案需要时开启。
- TCP 8443 被拦截：确认防火墙和云厂商网络允许 TCP 8443。
- Hysteria2 UDP 被拦截：确认防火墙和云厂商网络允许 UDP 443。
