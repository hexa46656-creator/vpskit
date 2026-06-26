# Trojan 凭据轮换

当 Trojan URI 或密码可能已经不再私密时，使用这个流程。

## 为什么要轮换

- URI 已经出现在聊天、日志、截图或工单中。
- 客户端设备丢失或被盗。
- 需要撤销某个客户或同事的访问权限。
- 怀疑密码已经泄露。

## 命令

```bash
vpskit rotate trojan --dry-run
vpskit rotate trojan --yes
vpskit verify trojan
vpskit sub export trojan
vpskit sub export trojan --redact
vpskit sub bundle --redact --output ./vpskit-client-bundle
```

## 会发生什么

- 生成新的 Trojan 密码。
- 更新 TCP 8443 上的 Xray Trojan inbound。
- 重新写入 `/var/lib/vpskit/trojan.yaml`。
- 刷新 `/var/lib/vpskit/trojan.env` 以匹配新状态。
- 候选配置通过校验后再重启 Xray。

## 轮换后

- 旧客户端会失效，直到导入新的 URI。
- TCP 443 上的 VLESS Reality 应保持不变。
- UDP 443 上的 Hysteria2 应保持不变。

## 安全提示

- 真实轮换前先执行 `vpskit rotate trojan --dry-run`。
- 截图和支持工单使用 `vpskit sub export trojan --redact`。
- 轮换后重新生成客户端打包，保证交付内容是最新的。
- 不要公开分享 `/var/lib/vpskit/trojan.yaml`，其中包含当前可用密码。
- 不要公开分享完整 Trojan URI。
