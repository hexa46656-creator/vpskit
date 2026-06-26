# VPSKit Phase 1

VPSKit is a practical VPS deployment and repair toolkit.

Phase 1 includes:

- VPS hardening for Ubuntu 24.04 LTS
- Xray VLESS Reality over TCP 443 with `xtls-rprx-vision`
- subscription output for Shadowrocket/v2rayNG

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
- `sub show`
- `fix`
- `install hardening`
- `install vless-reality`

Phase 1 install examples:

```bash
sudo bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install vless-reality
bash vpskit/cli/vpskit.sh sub show
```

Not included yet:

- Hysteria2 installer
- Trojan installer
- SaaS control plane
- Telegram Bot
- PayPal or billing automation
- Web UI

Shadowrocket usage:

- Run `bash vpskit/cli/vpskit.sh sub show`
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

- `install hardening` changes SSH, UFW, Fail2ban, sudoers, and the managed Linux user.
- `install vless-reality` writes Xray config, starts `xray.service`, and saves subscription output under `/var/lib/vpskit/`.
- Default managed Linux user is `alex`.
- File writes are transaction-backed where practical.
- Package installation, Linux user creation, sudo group changes, UFW state changes, and service restarts are not fully reversible automatically.
- The installer refuses to overwrite an existing Xray config unless `VPSKIT_XRAY_FORCE_OVERWRITE=1` is set.
- If a repair produces unexpected output, keep the original input file and re-run the repair helper on a copy.

Uninstall:

- Remove the cloned repository directory when you are done with the toolkit.

Commercial delivery:

- See [release/commercial-delivery.md](release/commercial-delivery.md)

Release notes:

- See [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- See [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)

## 中文

VPSKit 是一个实用的 VPS 部署与修复工具包。

Phase 1 包含：

- Ubuntu 24.04 LTS VPS 安全加固
- 基于 TCP 443 和 `xtls-rprx-vision` 的 Xray VLESS Reality
- Shadowrocket/v2rayNG 订阅输出

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
- `sub show`
- `fix`
- `install hardening`
- `install vless-reality`

Phase 1 安装示例：

```bash
sudo bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install vless-reality
bash vpskit/cli/vpskit.sh sub show
```

尚未包含：

- Hysteria2 安装器
- Trojan 安装器
- SaaS 控制台
- Telegram Bot
- PayPal 或计费自动化
- Web UI

Shadowrocket 使用：

- 运行 `bash vpskit/cli/vpskit.sh sub show`
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

- `install hardening` 会修改 SSH、UFW、Fail2ban、sudoers 和受管理的 Linux 用户。
- `install vless-reality` 会写入 Xray 配置、启动 `xray.service`，并把订阅输出保存到 `/var/lib/vpskit/`。
- 默认受管理的 Linux 用户是 `alex`。
- 文件写入会尽量使用事务回滚。
- 软件包安装、Linux 用户创建、sudo 组变更、UFW 状态变更和服务重启无法完全自动回滚。
- 如果已有 Xray 配置，除非设置 `VPSKIT_XRAY_FORCE_OVERWRITE=1`，安装器会拒绝覆盖。
- 如果修复后的输出不符合预期，请保留原始输入文件，并在副本上重新运行修复 helper。

卸载：

- 直接删除克隆出来的仓库目录即可。

商业交付：

- 参见 [release/commercial-delivery.md](release/commercial-delivery.md)

发布说明：

- 参见 [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- 参见 [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)
