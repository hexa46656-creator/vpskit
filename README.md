# VPSKit Phase 1

VPSKit is a practical VPS deployment and repair toolkit.

Current beta capability: `v0.6.1-beta` keeps the existing services and stabilizes Trojan compatibility:

- VPS hardening for Ubuntu 24.04 LTS
- Xray VLESS Reality over TCP 443 with `xtls-rprx-vision`
- Hysteria2 over UDP 443 with self-signed TLS and no domain requirement
- subscription export for Shadowrocket, v2rayNG, Clash Meta, sing-box, and base64 subscription bundles
- client export to file for existing VLESS Reality subscriptions
- post-install verification commands for managed SSH user, VLESS Reality state, Hysteria2 state, and Trojan state

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
- `sub formats`
- `sub export <format>`
- `sub export <format> --output <path>`
- `sub export <format> -o <path>`
- `sub export hysteria2`
- `sub export trojan`
- `sub validate`
- `fix`
- `install hardening`
- `install vless-reality`
- `install hysteria2`
- `install trojan`
- `verify ssh-user`
- `verify vless-reality`
- `verify hysteria2`
- `verify trojan`

Phase 1 install examples:

```bash
sudo VPSKIT_AUTHORIZED_KEY_FILE="$HOME/.ssh/id_ed25519.pub" bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install vless-reality
sudo bash vpskit/cli/vpskit.sh install hysteria2
sudo bash vpskit/cli/vpskit.sh install trojan
bash vpskit/cli/vpskit.sh sub show
```

After install verification:

```bash
bash vpskit/cli/vpskit.sh verify ssh-user
bash vpskit/cli/vpskit.sh verify vless-reality
bash vpskit/cli/vpskit.sh verify hysteria2
bash vpskit/cli/vpskit.sh verify trojan
bash vpskit/cli/vpskit.sh sub show
```

Managed user SSH key:

- `install hardening` creates or updates the managed Linux user `alex`.
- Prefer `VPSKIT_AUTHORIZED_KEY` or `VPSKIT_AUTHORIZED_KEY_FILE` so `alex` receives the public key that matches the private key you plan to use.
- If no explicit key is provided, VPSKit copies root `authorized_keys`; this does not guarantee your default `ssh alex@IP` command uses the matching private key.
- After hardening, open a second terminal and verify the exact SSH command printed by the installer before closing the root session.

Not included yet:

- SaaS control plane
- Telegram Bot
- PayPal or billing automation
- Web UI

Shadowrocket usage:

- Run `bash vpskit/cli/vpskit.sh sub show`
- Repair local subscription text with `bash vpskit/subscription/shadowrocket_repair.sh --input <file>`
- Import the repaired output into Shadowrocket using the app's standard import flow

Client export:

- Shadowrocket: `bash vpskit/cli/vpskit.sh sub export shadowrocket`
- v2rayNG: `bash vpskit/cli/vpskit.sh sub export v2rayng`
- Clash Meta: `bash vpskit/cli/vpskit.sh sub export clash-meta`
- sing-box: `bash vpskit/cli/vpskit.sh sub export sing-box`
- Base64 generic subscription: `bash vpskit/cli/vpskit.sh sub export base64`
- Hysteria2: `bash vpskit/cli/vpskit.sh sub export hysteria2`
- Trojan: `bash vpskit/cli/vpskit.sh sub export trojan`

Client export to file:

- Shadowrocket and v2rayNG keep the existing URI text export format.
- Clash Meta writes YAML files that can be imported directly by Clash Meta-compatible clients.
- sing-box writes JSON files that can be imported directly by sing-box.
- Base64 writes a generic subscription bundle for clients that expect encoded subscription text.
- Trojan writes a trojan URI using the VPSKit-managed password and server address.
- Validate the current VLESS Reality subscription before exporting with `bash vpskit/cli/vpskit.sh sub validate`.

Examples:

```bash
bash vpskit/cli/vpskit.sh sub export clash-meta --output /tmp/vpskit-clash.yaml
bash vpskit/cli/vpskit.sh sub export sing-box --output /tmp/vpskit-sing-box.json
bash vpskit/cli/vpskit.sh sub export hysteria2 --output /tmp/vpskit-hysteria2.yaml
bash vpskit/cli/vpskit.sh sub export trojan --output /tmp/vpskit-trojan.txt
bash vpskit/cli/vpskit.sh sub validate
```

Hysteria2:

- Uses UDP 443 and can coexist with VLESS Reality on TCP 443.
- The installer writes the server config to `/etc/hysteria/config.yaml`.
- The installer stores the client subscription YAML at `/var/lib/vpskit/hysteria2.yaml`.
- `sub export hysteria2` prints the client YAML, and `--output` saves it to a file.
- Re-running `vpskit install hysteria2` is expected to be safe when Hysteria2 is already installed.
- After install, run `vpskit verify hysteria2` and `vpskit doctor`.
- Recovery docs: [docs/hysteria2-recovery.en.md](docs/hysteria2-recovery.en.md) and [docs/hysteria2-recovery.zh.md](docs/hysteria2-recovery.zh.md).
- UDP 443 must be reachable externally for the service to work.

Trojan:

- Uses TCP 8443 and runs inside Xray, so process-level checks show `xray` on 8443 while the inbound protocol remains Trojan.
- Trojan is a compatibility fallback. VLESS Reality remains the primary recommendation.
- The installer writes the Trojan TLS cert and key to `/etc/vpskit/trojan/server.crt` and `/etc/vpskit/trojan/server.key`.
- The installer stores Trojan state at `/var/lib/vpskit/trojan.yaml` and `/var/lib/vpskit/trojan.env`.
- v0.6.1-beta uses self-signed TLS by default and does not require a domain name, certbot, or Let's Encrypt.
- Clients may need `allowInsecure=1` or a trusted cert if they enforce TLS validation.
- TCP 8443 must be reachable externally for the service to work.
- See [docs/trojan-client-compatibility.en.md](docs/trojan-client-compatibility.en.md) and [docs/trojan-recovery.en.md](docs/trojan-recovery.en.md).
- After install, run `vpskit verify trojan` and `vpskit doctor`.

`v0.6.0-beta` adds Trojan TCP 8443 support alongside Hysteria2.
It does not add QR code generation, SaaS, Telegram Bot, PayPal, or Web UI.

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
- `install trojan` updates the Xray config to add a Trojan inbound on TCP 8443, writes the self-signed cert/key under `/etc/vpskit/trojan/`, and saves the Trojan subscription output under `/var/lib/vpskit/trojan.yaml`.
- When UFW is active, `install vless-reality` allows the configured Reality TCP port, default `443/tcp`; when UFW is inactive it does not enable UFW.
- When UFW is active, `install trojan` allows `8443/tcp`; when UFW is inactive it does not enable UFW.
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
- See [release/v0.4.0-beta-notes.md](release/v0.4.0-beta-notes.md)
- See [release/v0.4.1-beta-notes.md](release/v0.4.1-beta-notes.md)
- See [release/v0.5.0-beta-notes.md](release/v0.5.0-beta-notes.md)
- See [release/v0.5.0-beta-test-report.md](release/v0.5.0-beta-test-report.md)
- See [release/v0.5.1-beta-notes.md](release/v0.5.1-beta-notes.md)
- See [release/v0.6.0-beta-notes.md](release/v0.6.0-beta-notes.md)
- See [release/v0.6.0-beta-test-report.md](release/v0.6.0-beta-test-report.md)
- See [release/v0.6.1-beta-notes.md](release/v0.6.1-beta-notes.md)
- See [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- See [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)

## 中文

VPSKit 是一个实用的 VPS 部署与修复工具包。

当前 beta 能力：`v0.6.1-beta` 继续支持现有能力，并加强 Trojan 兼容性：

- Ubuntu 24.04 LTS VPS 安全加固
- 基于 TCP 443 和 `xtls-rprx-vision` 的 Xray VLESS Reality
- 基于 UDP 443、使用自签名 TLS 且无需域名的 Hysteria2
- Shadowrocket、v2rayNG、Clash Meta、sing-box 和 base64 订阅导出
- 现有 VLESS Reality 订阅的文件导出体验优化
- 用于受管理 SSH 用户、VLESS Reality 状态、Hysteria2 状态和 Trojan 状态的安装后验证命令

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
- `sub formats`
- `sub export <format>`
- `sub export <format> --output <path>`
- `sub export <format> -o <path>`
- `sub export hysteria2`
- `sub export trojan`
- `sub validate`
- `fix`
- `install hardening`
- `install vless-reality`
- `install hysteria2`
- `install trojan`
- `verify ssh-user`
- `verify vless-reality`
- `verify hysteria2`
- `verify trojan`

Phase 1 安装示例：

```bash
sudo VPSKIT_AUTHORIZED_KEY_FILE="$HOME/.ssh/id_ed25519.pub" bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install hardening
sudo bash vpskit/cli/vpskit.sh install vless-reality
sudo bash vpskit/cli/vpskit.sh install hysteria2
sudo bash vpskit/cli/vpskit.sh install trojan
bash vpskit/cli/vpskit.sh sub show
```

安装后验证：

```bash
bash vpskit/cli/vpskit.sh verify ssh-user
bash vpskit/cli/vpskit.sh verify vless-reality
bash vpskit/cli/vpskit.sh verify hysteria2
bash vpskit/cli/vpskit.sh verify trojan
bash vpskit/cli/vpskit.sh sub show
```

受管理用户 SSH 密钥：

- `install hardening` 会创建或更新受管理的 Linux 用户 `alex`。
- 建议使用 `VPSKIT_AUTHORIZED_KEY` 或 `VPSKIT_AUTHORIZED_KEY_FILE`，确保 `alex` 收到与你计划使用的私钥匹配的公钥。
- 如果没有显式提供公钥，VPSKit 会复制 root 的 `authorized_keys`；这并不保证默认的 `ssh alex@IP` 会使用匹配的私钥。
- 加固完成后，请打开第二个终端，按安装器打印的 SSH 命令验证登录成功，再关闭 root 会话。

尚未包含：

- SaaS 控制台
- Telegram Bot
- PayPal 或计费自动化
- Web UI

Shadowrocket 使用：

- 运行 `bash vpskit/cli/vpskit.sh sub show`
- 使用 `bash vpskit/subscription/shadowrocket_repair.sh --input <file>` 修复本地订阅文本
- 通过 Shadowrocket 的标准导入流程导入修复后的输出

客户端导出：

- Shadowrocket：`bash vpskit/cli/vpskit.sh sub export shadowrocket`
- v2rayNG：`bash vpskit/cli/vpskit.sh sub export v2rayng`
- Clash Meta：`bash vpskit/cli/vpskit.sh sub export clash-meta`
- sing-box：`bash vpskit/cli/vpskit.sh sub export sing-box`
- 通用 base64 订阅：`bash vpskit/cli/vpskit.sh sub export base64`
- Hysteria2：`bash vpskit/cli/vpskit.sh sub export hysteria2`
- Trojan：`bash vpskit/cli/vpskit.sh sub export trojan`

文件导出体验：

- Shadowrocket 和 v2rayNG 继续使用现有的 URI 文本导出格式。
- Clash Meta 可直接导出可导入的 YAML 文件。
- sing-box 可直接导出可导入的 JSON 文件。
- Base64 可导出通用的编码订阅文本。
- Trojan 会导出使用 VPSKit 管理的密码和服务器地址生成的 trojan URI。
- 导出前可先运行 `bash vpskit/cli/vpskit.sh sub validate` 检查当前 VLESS Reality 订阅。

示例：

```bash
bash vpskit/cli/vpskit.sh sub export clash-meta --output /tmp/vpskit-clash.yaml
bash vpskit/cli/vpskit.sh sub export sing-box --output /tmp/vpskit-sing-box.json
bash vpskit/cli/vpskit.sh sub export hysteria2 --output /tmp/vpskit-hysteria2.yaml
bash vpskit/cli/vpskit.sh sub export trojan --output /tmp/vpskit-trojan.txt
bash vpskit/cli/vpskit.sh sub validate
```

Hysteria2：

- 使用 UDP 443，并且可以与 TCP 443 上的 VLESS Reality 共存。
- 安装器会把服务端配置写到 `/etc/hysteria/config.yaml`。
- 安装器会把客户端订阅 YAML 保存到 `/var/lib/vpskit/hysteria2.yaml`。
- `sub export hysteria2` 会输出客户端 YAML，`--output` 会写入文件。
- `vpskit install hysteria2` 在已安装时重复运行应该是安全的。
- 安装后请运行 `vpskit verify hysteria2` 和 `vpskit doctor`。
- 恢复文档：[docs/hysteria2-recovery.en.md](docs/hysteria2-recovery.en.md) 和 [docs/hysteria2-recovery.zh.md](docs/hysteria2-recovery.zh.md)。
- UDP 443 必须能从 VPS 外部访问，服务才会正常工作。

Trojan：

- 使用 TCP 8443，并且运行在 Xray 内部，所以进程级检查会显示 `xray` 占用 8443，但入口协议仍然是 Trojan。
- Trojan 是兼容性回退方案，VLESS Reality 仍然是首选。
- 安装器会把 Trojan TLS 证书和私钥写到 `/etc/vpskit/trojan/server.crt` 和 `/etc/vpskit/trojan/server.key`。
- 安装器会把 Trojan 状态保存到 `/var/lib/vpskit/trojan.yaml` 和 `/var/lib/vpskit/trojan.env`。
- `v0.6.1-beta` 默认使用自签名 TLS，不需要域名、certbot 或 Let’s Encrypt。
- 客户端如强制校验证书，可能需要 `allowInsecure=1` 或信任证书。
- TCP 8443 必须能从 VPS 外部访问，服务才会正常工作。
- 参见 [docs/trojan-client-compatibility.zh.md](docs/trojan-client-compatibility.zh.md) 和 [docs/trojan-recovery.zh.md](docs/trojan-recovery.zh.md)。
- 安装后请运行 `vpskit verify trojan` 和 `vpskit doctor`。

`v0.6.0-beta` 新增 Trojan TCP 8443 支持，并继续包含 Hysteria2。
它不会新增二维码生成、SaaS、Telegram Bot、PayPal 或 Web UI。

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
- `install trojan` 会在 Xray 配置中添加 Trojan inbound，写入自签名证书和私钥到 `/etc/vpskit/trojan/`，并把 Trojan 订阅输出保存到 `/var/lib/vpskit/trojan.yaml`。
- 如果 UFW 已启用，`install vless-reality` 会允许配置的 Reality TCP 端口，默认 `443/tcp`；如果 UFW 未启用，它不会主动启用 UFW。
- 如果 UFW 已启用，`install trojan` 会允许 `8443/tcp`；如果 UFW 未启用，它不会主动启用 UFW。
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
- 参见 [release/v0.4.0-beta-notes.md](release/v0.4.0-beta-notes.md)
- 参见 [release/v0.4.1-beta-notes.md](release/v0.4.1-beta-notes.md)
- 参见 [release/v0.5.0-beta-notes.md](release/v0.5.0-beta-notes.md)
- 参见 [release/v0.5.0-beta-test-report.md](release/v0.5.0-beta-test-report.md)
- 参见 [release/v0.5.1-beta-notes.md](release/v0.5.1-beta-notes.md)
- 参见 [release/v0.6.0-beta-notes.md](release/v0.6.0-beta-notes.md)
- 参见 [release/v0.6.0-beta-test-report.md](release/v0.6.0-beta-test-report.md)
- 参见 [release/v0.6.1-beta-notes.md](release/v0.6.1-beta-notes.md)
- 参见 [release/v2.0.0-beta-scope.md](release/v2.0.0-beta-scope.md)
- 参见 [release/v2.0.0-beta-inventory.md](release/v2.0.0-beta-inventory.md)
