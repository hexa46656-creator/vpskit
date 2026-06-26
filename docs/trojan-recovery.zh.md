# Trojan 恢复

使用下面这些命令排查 VPSKit 的 Trojan 状态。

```bash
vpskit verify trojan
vpskit verify vless-reality
vpskit verify hysteria2
vpskit doctor
systemctl status xray.service --no-pager
journalctl -u xray.service -n 80 --no-pager -l
xray run -test -config /usr/local/etc/xray/config.json
ss -H -ltnp 'sport = :8443'
ss -H -ltnp 'sport = :443'
ufw status verbose
stat -c '%U:%G %a %n' /etc/vpskit/trojan /etc/vpskit/trojan/server.crt /etc/vpskit/trojan/server.key
cat /var/lib/vpskit/trojan.yaml
vpskit rotate trojan --dry-run
vpskit rotate trojan --yes
vpskit sub export trojan --redact
```

## 常见失败原因

- `server.key` 权限被拒绝：Xray 使用受限用户运行，无法读取私钥。
- 候选配置校验失败：临时 Xray 配置必须先通过验证，才能替换正式配置。
- TCP 8443 没有监听：Xray 没有成功绑定 Trojan 入口，或者服务重启失败。
- UFW 没有放行 `8443/tcp`：即使服务正常，端口仍可能被防火墙拦截。
- 改动后 VLESS 失效：Trojan 更新必须保留现有的 443 Reality 入口。
- 客户端拒绝自签名 TLS：开启 `allowInsecure`，或者手动信任证书。
- Xray 提示 Trojan deprecated：这是上游提示，VPSKit 会把 Trojan 保留为兼容性回退方案。
- 不要把 `/var/lib/vpskit/trojan.yaml` 贴到聊天、工单或截图里，其中包含当前可用的密码。
