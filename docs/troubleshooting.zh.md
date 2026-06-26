# VPSKit v2.0.0-beta 故障排查

## Shadowrocket 导入失败

- 重新运行 `bash vpskit/cli/vpskit.sh sub`。
- 如果订阅文本含有 CRLF 行尾，先在本地修复。
- 对本地文件使用 `vpskit/subscription/shadowrocket_repair.sh`。

## DNS 失败

- 运行 `bash vpskit/cli/vpskit.sh doctor`。
- 确认你的环境可以访问所配置的 DNS 目标。
- 使用 beta DNS health helper 的安全模式做验证。

## TCP 443 不可达

- 运行 `bash vpskit/cli/vpskit.sh doctor`。
- 检查目标主机是否真的开放 TCP 443。
- 在做任何改动前，先用 TCP probe helper 的安全模式检查。

## Reality 目标问题

- 确认发布说明里的服务器目标是否一致。
- 如果目标主机发生变化，重新生成订阅。

## 服务重启

- beta 版本不会自动重启服务。
- 外部服务变化后，重新运行 `status` 和 `doctor`。

## vpskit doctor

`doctor` 用于只读诊断。

## vpskit fix

`fix` 只用于安全的本地修复或报告生成。
