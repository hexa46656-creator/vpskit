# 客户交付

## 交付给客户的内容

- 通过 `vpskit sub bundle --redact --output <dir>` 生成的脱敏客户端打包
- 通过 `vpskit demo package --redact --output <dir>` 生成的脱敏演示包
- `vpskit qa --redact` 的 QA 报告
- 客户实际会用到的一个私有客户端导出文件
- 协议布局说明

## 不要公开分享的内容

- 完整 Trojan URI
- `/var/lib/vpskit/trojan.yaml`
- 私钥
- SSH 凭据
- 未脱敏的日志或截图

## 推荐协议用途

- TCP 443 上的 VLESS Reality 是首选
- UDP 443 上的 Hysteria2 适合支持该协议的客户端
- TCP 8443 上的 Trojan 是兼容回退方案

## 如何运行 QA

```bash
vpskit qa
vpskit qa --redact
vpskit qa --redact --output ./qa-report.txt
```

## 如何生成客户端打包

```bash
vpskit sub bundle --redact --output ./vpskit-client-bundle
```

## 如何生成脱敏演示包

```bash
vpskit demo package --redact --output ./vpskit-demo-package
```

## 如何生成私有的真实导出

```bash
vpskit sub export trojan --output ./trojan-private.uri
vpskit sub export trojan --redact --output ./trojan-redacted.uri
```

## 交付后如何验证

```bash
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
vpskit doctor
ss -H -ltnp 'sport = :443'
ss -H -lunp 'sport = :443'
ss -H -ltnp 'sport = :8443'
ufw status verbose
```

## 基础排查

- 某个协议异常时，先检查对应服务状态
- 端口没有监听时，先看监听归属和服务日志
- 防火墙规则缺失时，先检查 UFW，再改协议配置
- 客户端拒绝 Trojan TLS 时，使用 `allowInsecure=1` 或手动信任证书

## 日志分享

- 日志里可能包含公网源 IP
- 分享前要先脱敏

另见：[docs/client-bundle.zh.md](docs/client-bundle.zh.md)
