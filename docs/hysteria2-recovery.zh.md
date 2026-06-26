# Hysteria2 恢复

当 `vpskit install hysteria2`、`vpskit verify hysteria2` 或 Hysteria2 服务看起来不稳定时，使用这里的步骤。

## 快速检查

```bash
systemctl stop hysteria-server.service
systemctl reset-failed hysteria-server.service
systemctl status hysteria-server.service --no-pager
journalctl -u hysteria-server.service -n 80 --no-pager
cat /etc/hysteria/config.yaml
ss -H -lunp 'sport = :443'
ufw status verbose
vpskit verify hysteria2
vpskit doctor
```

## 常见故障原因

- `/etc/hysteria/config.yaml` 里的服务器认证配置无效
- UDP 443 被其他进程占用
- UFW 已启用，但缺少 IPv4 的 `443/udp` 放行规则
- 配置错误或进程崩溃导致服务反复重启
- 客户端不接受自签名证书，或者 `pinSHA256` 不匹配

## 说明

- Hysteria2 预期使用 UDP 443。
- VLESS Reality 继续使用 TCP 443。
- 如果服务连续崩溃，先停止服务，避免重启风暴，再检查配置和日志。
