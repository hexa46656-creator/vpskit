# VPSKit v2.0.0-beta 安装指南

## 安装

```bash
git clone https://github.com/hexa46656-creator/vpskit.git
cd vpskit
bash vpskit/cli/vpskit.sh version
```

## 首次使用

```bash
bash vpskit/cli/vpskit.sh status
bash vpskit/cli/vpskit.sh doctor
```

## Phase 1 安装

在干净的 Ubuntu 24.04 VPS 上，先运行安全加固。建议为受管理用户 `alex` 显式提供公钥：

```bash
sudo VPSKIT_AUTHORIZED_KEY_FILE="$HOME/.ssh/id_ed25519.pub" bash vpskit/cli/vpskit.sh install hardening
```

如果没有显式提供公钥，VPSKit 会复制 root 的 `authorized_keys`。这并不保证默认的 `ssh alex@IP` 会使用匹配的私钥。请打开第二个终端，按安装器打印的 SSH 命令验证登录成功，再关闭 root 会话。

然后安装 VLESS Reality：

```bash
sudo bash vpskit/cli/vpskit.sh install vless-reality
bash vpskit/cli/vpskit.sh sub show
```

如果 UFW 已启用，VLESS 安装器会允许配置的 Reality TCP 端口，默认 `443/tcp`。如果 UFW 未启用，它不会主动启用 UFW。

## 导入 Shadowrocket

打开修复后的订阅文本或导出的订阅文件，使用 Shadowrocket 的原生导入流程导入。

## 说明

- Phase 1 会修改 SSH、UFW、Fail2ban、sudoers、Xray 配置和 systemd 服务状态。
- 官方 Xray 安装器可能输出关于特殊用户 `nobody` 的 systemd 警告；这是 Phase 1 已知限制。
