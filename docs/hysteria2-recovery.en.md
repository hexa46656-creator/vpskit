# Hysteria2 Recovery

Use this when `vpskit install hysteria2`, `vpskit verify hysteria2`, or the Hysteria2 service looks unstable.

## Quick Checks

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

## Common Failure Causes

- Invalid server auth config in `/etc/hysteria/config.yaml`
- UDP 443 occupied by another process
- UFW active but missing an IPv4 `443/udp` allow rule
- Service restart loop after a bad config or crash
- Client TLS rejection because the self-signed certificate is not accepted or `pinSHA256` does not match

## Notes

- Hysteria2 is expected to use UDP 443.
- VLESS Reality remains on TCP 443.
- If the service crashed repeatedly, stop it first to prevent a restart storm, then inspect the config and journal.
