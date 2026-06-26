# VPSKit Phase 1

VPSKit is a practical VPS deployment and repair toolkit.

Current beta capability: `v0.3.0-beta` supports:

- VPS hardening for Ubuntu 24.04 LTS
- Xray VLESS Reality over TCP 443 with `xtls-rprx-vision`
- subscription output for Shadowrocket/v2rayNG
- post-install verification commands for managed SSH user and VLESS Reality state

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
- `verify ssh-user`
- `verify vless-reality`

Phase 1 install examples:

```bash
sudo VPSKIT_AUTHORIZED_KEY_FILE="$HOME/.ssh/id_ed25519.pub" bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install vless-reality
bash vpskit/cli/vpskit.sh sub show
```

After install verification:

```bash
bash vpskit/cli/vpskit.sh verify ssh-user
bash vpskit/cli/vpskit.sh verify vless-reality
bash vpskit/cli/vpskit.sh sub show
```

Managed user SSH key:

- `install hardening` creates or updates the managed Linux user `alex`.
- Prefer `VPSKIT_AUTHORIZED_KEY` or `VPSKIT_AUTHORIZED_KEY_FILE` so `alex` receives the public key that matches the private key you plan to use.
- If no explicit key is provided, VPSKit copies root `authorized_keys`; this does not guarantee your default `ssh alex@IP` command uses the matching private key.
- After hardening, open a second terminal and verify the exact SSH command printed by the installer before closing the root session.

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
- When UFW is active, `install vless-reality` allows the configured Reality TCP port, default `443/tcp`; when UFW is inactive it does not enable UFW.
- Default managed Linux user is `alex`.
- File writes are transaction-backed where practical.
- Package installation, Linux user creation, sudo group changes, UFW state changes, and service restarts are not fully reversible automatically.
- The installer refuses to overwrite an existing Xray config unless `VPSKIT_XRAY_FORCE_OVERWRITE=1` is set.
- The official Xray installer may emit a systemd warning about the special user `nobody`; this is a known upstream service-unit limitation for Phase 1 and is not rewritten by VPSKit yet.
- If a repair produces unexpected output, keep the original input file and re-run the repair helper on a copy.

Uninstall:

- Remove the cloned repository directory when you are done with the toolkit.

Commercial delivery:

- See [release/commercial-delivery.md](release/commercial-delivery.md)

Release notes:

- See [release/v0.3.0-beta-notes.md](release/v0.3.0-beta-notes.md)
- See [release/v0.3.0-beta-test-report.md](release/v0.3.0-beta-test-report.md)
- See [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- See [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)

## 中文

VPSKit 是一个实用的 VPS 部署与修复工具包。

当前 beta 能力：`v0.3.0-beta` 支持：

- Ubuntu 24.04 LTS VPS 安全加固
- 基于 TCP 443 和 `xtls-rprx-vision` 的 Xray VLESS Reality
- Shadowrocket/v2rayNG 订阅输出
- 用于受管理 SSH 用户和 VLESS Reality 状态的安装后验证命令

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
- `verify ssh-user`
- `verify vless-reality`

Phase 1 安装示例：

```bash
sudo VPSKIT_AUTHORIZED_KEY_FILE="$HOME/.ssh/id_ed25519.pub" bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install vless-reality
bash vpskit/cli/vpskit.sh sub show
```

安装后验证：

```bash
bash vpskit/cli/vpskit.sh verify ssh-user
bash vpskit/cli/vpskit.sh verify vless-reality
bash vpskit/cli/vpskit.sh sub show
```

受管理用户 SSH 密钥：

- `install hardening` 会创建或更新受管理的 Linux 用户 `alex`。
- 建议使用 `VPSKIT_AUTHORIZED_KEY` 或 `VPSKIT_AUTHORIZED_KEY_FILE`，确保 `alex` 收到与你计划使用的私钥匹配的公钥。
- 如果没有显式提供公钥，VPSKit 会复制 root 的 `authorized_keys`；这并不保证默认的 `ssh alex@IP` 会使用匹配的私钥。
- 加固完成后，请打开第二个终端，按安装器打印的 SSH 命令验证登录成功，再关闭 root 会话。

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
- 如果 UFW 已启用，`install vless-reality` 会允许配置的 Reality TCP 端口，默认 `443/tcp`；如果 UFW 未启用，它不会主动启用 UFW。
- 默认受管理的 Linux 用户是 `alex`。
- 文件写入会尽量使用事务回滚。
- 软件包安装、Linux 用户创建、sudo 组变更、UFW 状态变更和服务重启无法完全自动回滚。
- 如果已有 Xray 配置，除非设置 `VPSKIT_XRAY_FORCE_OVERWRITE=1`，安装器会拒绝覆盖。
- 官方 Xray 安装器可能输出关于特殊用户 `nobody` 的 systemd 警告；这是 Phase 1 已知的上游 service unit 限制，VPSKit 暂不重写该 service。
- 如果修复后的输出不符合预期，请保留原始输入文件，并在副本上重新运行修复 helper。

卸载：

- 直接删除克隆出来的仓库目录即可。

商业交付：

- 参见 [release/commercial-delivery.md](release/commercial-delivery.md)

发布说明：

- 参见 [release/v0.3.0-beta-notes.md](release/v0.3.0-beta-notes.md)
- 参见 [release/v0.3.0-beta-test-report.md](release/v0.3.0-beta-test-report.md)
- 参见 [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- 参见 [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)
