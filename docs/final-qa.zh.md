# 最终 QA

## 目的

对已安装的 VPSKit 系统运行一个安全、只读的汇总检查。

## 命令

```bash
vpskit qa
vpskit qa --redact
vpskit qa --redact --output ./qa-report.txt
```

## 检查内容

- VLESS Reality 验证
- Hysteria2 验证
- Trojan 验证
- doctor 汇总
- 脱敏 Trojan 导出
- 如果系统里有 Xray，则运行配置测试
- 检查 TCP 443、UDP 443、TCP 8443 的本地监听归属
- UFW 状态汇总
- 服务状态汇总

## 输出规则

- 输出是适合 grep 的 `key=value` 文本
- 命令是只读的
- 敏感信息默认脱敏
- 最后一行是 `VPSKIT_QA=pass` 或 `VPSKIT_QA=fail`

## 常见后续命令

```bash
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
vpskit doctor
vpskit sub export trojan --redact
vpskit sub bundle --redact --output ./vpskit-client-bundle
```
