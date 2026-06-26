# Customer Handoff

## What To Give A Customer

- The redacted client bundle from `vpskit sub bundle --redact --output <dir>`
- The redacted demo package from `vpskit demo package --redact --output <dir>`
- The QA report from `vpskit qa --redact`
- One private client export for the protocol they will actually use
- The protocol layout summary

## What Not To Share Publicly

- The full Trojan URI
- `/var/lib/vpskit/trojan.yaml`
- Private keys
- SSH credentials
- Unredacted logs or screenshots

## Recommended Protocol Use

- VLESS Reality on TCP 443 is the primary recommendation
- Hysteria2 on UDP 443 is the UDP option for supported clients
- Trojan on TCP 8443 is the compatibility fallback

## How To Run QA

```bash
vpskit qa
vpskit qa --redact
vpskit qa --redact --output ./qa-report.txt
```

## How To Generate A Client Bundle

```bash
vpskit sub bundle --redact --output ./vpskit-client-bundle
```

## How To Generate A Redacted Demo Package

```bash
vpskit demo package --redact --output ./vpskit-demo-package
```

## How To Generate A Private Real Export

```bash
vpskit sub export trojan --output ./trojan-private.uri
vpskit sub export trojan --redact --output ./trojan-redacted.uri
```

## Verify After Delivery

```bash
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
vpskit doctor
ss -H -ltnp 'sport = :443'
ss -H -lunp 'sport = :443'
ss -H -ltnp 'sport = :8443'
ufw status verbose
```

## Basic Troubleshooting

- If a protocol fails, check the matching service status first
- If a port is not listening, check the listener owner and service logs
- If firewall rules are missing, check UFW before changing protocol settings
- If the client rejects Trojan TLS, use `allowInsecure=1` or trust the certificate manually

## Log Sharing

- Logs may contain public source IP addresses
- Redact logs before sharing them with customers or in support tickets

See also: [docs/client-bundle.en.md](docs/client-bundle.en.md)
