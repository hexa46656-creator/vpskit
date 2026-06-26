# Trojan Client Compatibility

VPSKit provides Trojan as a compatibility fallback. VLESS Reality remains the recommended primary protocol.

Protocol layout:

```text
TCP 8443 -> Xray Trojan TLS inbound
```

Trojan runs inside Xray, so process-level checks show `xray` owning TCP 8443. That is expected. The protocol-level inbound is still Trojan.

## Client Settings

- Protocol: `Trojan`
- Port: `8443`
- Password: the exported Trojan password
- SNI: the exported `sni` value, or the server IP if your client needs a manual override
- `allowInsecure`: `true` or `1` when the client enforces certificate validation

VPSKit v0.6.0-beta and v0.6.1-beta use self-signed TLS for Trojan. Clients that do not trust the certificate must enable `allowInsecure` or install the certificate trust chain manually.

## Import Notes

- Shadowrocket: import the exported `trojan://` URI directly, or enter the values manually if import parsing is strict.
- v2rayNG: use the Trojan import flow and paste the exported URI if direct import is supported.
- Clash Meta-compatible clients: import the URI or enter a manual Trojan profile with TLS enabled.
- Generic Trojan clients: set the host, port, password, SNI, and insecure-TLS flag to match the export.

## Troubleshooting

- Cannot import URI: copy the URI again and make sure special characters were not stripped by the clipboard app.
- TLS certificate error: enable `allowInsecure`, or trust the self-signed certificate.
- 8443 blocked: confirm TCP 8443 is open in UFW and reachable from the provider network.
- Wrong SNI: use the exported `sni` value, or the server IP if the client expects a manual host.
- `allowInsecure` disabled: turn it on for self-signed beta installs.
- Copied URI lost special characters: re-export the URI and avoid apps that reformat links.
- Server shows `xray`: that is normal. Xray is the process; Trojan is the inbound protocol.

