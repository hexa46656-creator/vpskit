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


## Reality、Trojan 和 Hysteria2 诊断

- 如果 Reality 超时，而 Trojan 和 Hysteria2 仍然正常，优先检查 DNS / CDN 边缘结果是否一致。
- Reality 对 SNI、dest、TLS 指纹和解析器一致性都很敏感。
- 可以用下面命令对比不同解析器的结果：
  - `dig www.microsoft.com @1.1.1.1`
  - `dig www.microsoft.com @8.8.8.8`
  - `dig www.microsoft.com`
- 如果结果不同，不要选择变化很大的 CDN 目标，优先使用更稳定的 Reality 目标。
- Trojan 在申请证书前，真实域名必须稳定解析到 VPS 公网 IP。
- Hysteria2 UDP 问题需要检查云防火墙、安全组、VPS 提供商 UDP 过滤、MTU，以及自签证书场景下的 `insecure=true`。


## Reality、Trojan 和 Hysteria2 诊断

- 如果 Reality 超时，而 Trojan 和 Hysteria2 仍然正常，优先检查 DNS / CDN 边缘结果是否一致。
- Reality 对 SNI、dest、TLS 指纹和解析器一致性都很敏感。
- 可以用下面命令对比不同解析器的结果：
  - `dig www.microsoft.com @1.1.1.1`
  - `dig www.microsoft.com @8.8.8.8`
  - `dig www.microsoft.com`
- 如果结果不同，不要选择变化很大的 CDN 目标，优先使用更稳定的 Reality 目标。
- Trojan 在申请证书前，真实域名必须稳定解析到 VPS 公网 IP。
- Hysteria2 UDP 问题需要检查云防火墙、安全组、VPS 提供商 UDP 过滤、MTU，以及自签证书场景下的 `insecure=true`。

## vpskit doctor

`doctor` 用于只读诊断。

## vpskit fix

`fix` 只用于安全的本地修复或报告生成。
