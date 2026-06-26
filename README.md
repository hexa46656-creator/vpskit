# VPSKit v2.0.0-beta

VPSKit is a commercial VPS VPN deployment and repair toolkit.

Supported protocols:

- VLESS Reality
- Hysteria2
- Trojan

Quick start:

```bash
git clone https://github.com/hexa46656-creator/vpskit.git
cd vpskit
bash vpskit/cli/vpskit.sh version
```

CLI commands:

- `version`
- `status`
- `doctor`
- `sub`
- `fix`

Shadowrocket usage:

- Run `bash vpskit/cli/vpskit.sh sub`
- Repair local subscription text with `bash vpskit/subscription/shadowrocket_repair.sh --input <file>`
- Import the repaired output into Shadowrocket using the app's standard import flow

Troubleshooting:

- Read [docs/troubleshooting.en.md](docs/troubleshooting.en.md) or [docs/troubleshooting.zh.md](docs/troubleshooting.zh.md)
- Run `bash vpskit/cli/vpskit.sh doctor`
- Run `bash vpskit/cli/vpskit.sh fix` for a safe local repair report

Install guides:

- [English](docs/install-guide.en.md)
- [中文](docs/install-guide.zh.md)

Safety and recovery:

- This release is read-only or local-file-only unless you explicitly provide an output path to a repair helper.
- It does not modify SSH, UFW, Fail2ban, systemd, firewall, or other VPS system configuration.
- If a repair produces unexpected output, keep the original input file and re-run the repair helper on a copy.

Uninstall:

- Remove the cloned repository directory when you are done with the toolkit.

Commercial delivery:

- See [release/commercial-delivery.md](release/commercial-delivery.md)

Release notes:

- See [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- See [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)

## 中文

VPSKit 是一个面向商业交付的 VPS VPN 部署与修复工具包。

支持协议：

- VLESS Reality
- Hysteria2
- Trojan

快速开始：

```bash
git clone https://github.com/hexa46656-creator/vpskit.git
cd vpskit
bash vpskit/cli/vpskit.sh version
```

CLI 命令：

- `version`
- `status`
- `doctor`
- `sub`
- `fix`

Shadowrocket 使用：

- 运行 `bash vpskit/cli/vpskit.sh sub`
- 使用 `bash vpskit/subscription/shadowrocket_repair.sh --input <file>` 修复本地订阅文本
- 通过 Shadowrocket 的标准导入流程导入修复后的输出

故障排查：

- 阅读 [docs/troubleshooting.zh.md](docs/troubleshooting.zh.md) 或 [docs/troubleshooting.en.md](docs/troubleshooting.en.md)
- 运行 `bash vpskit/cli/vpskit.sh doctor`
- 运行 `bash vpskit/cli/vpskit.sh fix` 获取安全的本地修复报告

安装指南：

- [English](docs/install-guide.en.md)
- [中文](docs/install-guide.zh.md)

安全与恢复：

- 除非你显式为修复 helper 提供输出路径，否则本版本只读或仅处理本地文件。
- 它不会修改 SSH、UFW、Fail2ban、systemd、防火墙或其他 VPS 系统配置。
- 如果修复后的输出不符合预期，请保留原始输入文件，并在副本上重新运行修复 helper。

卸载：

- 直接删除克隆出来的仓库目录即可。

商业交付：

- 参见 [release/commercial-delivery.md](release/commercial-delivery.md)

发布说明：

- 参见 [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- 参见 [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)
