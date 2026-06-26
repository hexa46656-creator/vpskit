# Trojan Recovery

Use these commands to diagnose Trojan on VPSKit.

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

## Common Failure Causes

- `server.key` permission denied: Xray runs as a restricted user and cannot read the key.
- Candidate config validation failure: the temporary Xray config must validate before replacement.
- TCP 8443 not listening: Xray did not bind the Trojan inbound or the service failed to restart.
- UFW missing `8443/tcp`: the port is blocked even if the service is healthy.
- VLESS broken after config change: the Trojan update must preserve the existing 443 Reality inbound.
- Self-signed TLS rejected by client: enable `allowInsecure` or trust the certificate manually.
- Xray Trojan deprecated warning: expected upstream behavior; VPSKit keeps Trojan as a compatibility fallback.
- Do not paste `/var/lib/vpskit/trojan.yaml` into chat, issue trackers, or screenshots; it contains the live password.
