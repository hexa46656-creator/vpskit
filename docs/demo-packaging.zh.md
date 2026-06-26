# 演示打包

## 目的

生成一个本地交付包，只包含安全文件。

## 命令

```bash
vpskit demo package --redact --output ./vpskit-demo-package
```

## 输出文件

- `README.en.md`
- `README.zh.md`
- `qa-report.txt`
- `protocol-layout.txt`
- `client-import-notes.en.md`
- `client-import-notes.zh.md`
- `security-notes.en.md`
- `security-notes.zh.md`
- `trojan-redacted.uri`
- `command-checklist.txt`

## 行为

- 如果输出目录不存在，会自动创建
- 如果输出目录已存在且非空，默认拒绝，除非加 `--force`
- 文件名是固定的
- 默认就是脱敏包

## 安全分享规则

- 只分享脱敏包
- 不要公开真实 Trojan 密码
- 不要公开私钥或原始日志

## 验证命令

```bash
vpskit qa --redact
vpskit demo package --redact --output ./vpskit-demo-package
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
```
