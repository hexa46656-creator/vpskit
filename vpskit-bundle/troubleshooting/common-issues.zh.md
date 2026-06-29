# 常见问题

- 缺少订阅文件：先运行安装流程，或检查 `VPSKIT_SUBSCRIPTION_FILE`。
- 打包内容为空：确认安装已完成，并且订阅文件确实存在。
- 输出目录非空：确认目录内容后，再使用 `--force` 重新生成。
- 客户端格式不支持：改用 `subscriptions/` 里的对应导入文件。
- 自签名 TLS 和 `allowInsecure`：只有在 Trojan 回退方案需要时才开启不安全 TLS。
- TCP 8443 被拦截：检查云厂商防火墙和 UFW 是否允许 TCP 8443。
- Hysteria2 UDP 被拦截：检查云厂商防火墙和 UFW 是否允许 UDP 443。
