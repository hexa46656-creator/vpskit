# Client Bundle

## What It Is

`vpskit sub bundle` creates a customer-ready handoff directory with redacted client exports, import notes, QA output, and troubleshooting notes.

## When To Use It

- After a successful VPSKit install
- Before sending a customer a clean handoff package
- For tutorials, screenshots, and support replies

## How To Generate It

```bash
vpskit sub bundle
vpskit sub bundle --redact --output ./vpskit-client-bundle
vpskit sub bundle --redact --force --output ./vpskit-client-bundle
```

## Included Files

- `README.en.md`
- `README.zh.md`
- `manifest.txt`
- `protocol-layout.txt`
- `security-notes.en.md`
- `security-notes.zh.md`
- `import-shadowrocket.en.md`
- `import-shadowrocket.zh.md`
- `import-v2rayng.en.md`
- `import-v2rayng.zh.md`
- `import-clash-meta.en.md`
- `import-clash-meta.zh.md`
- `import-sing-box.en.md`
- `import-sing-box.zh.md`
- `qa-summary.txt`
- `command-checklist.txt`
- `subscriptions/`
- `troubleshooting/`

## Intentionally Excluded

- `.env` files
- Private keys
- `server.key`
- Raw logs
- Full Trojan URI in redacted mode

## Import Notes

- Shadowrocket: import `subscriptions/vless-reality.txt` first; use the redacted Trojan URI only for fallback testing.
- v2rayNG: import the VLESS Reality URI as the primary profile.
- Clash Meta: import `subscriptions/clash-meta.yaml`.
- sing-box: import `subscriptions/sing-box.json`.

## Security Warnings

- Never publish the full subscription URI.
- Use `--redact` for screenshots and support.
- Rotate Trojan after leaks.
- Logs may contain source IP addresses.

## Troubleshooting

- Missing subscription file: confirm the install completed and the expected files exist.
- Empty bundle: verify the source subscription files are present before bundling.
- Non-empty output dir: rerun with `--force`.
- Unsupported client format: use the matching file from `subscriptions/`.
- Self-signed TLS and `allowInsecure`: enable it only for the Trojan fallback when required.
- TCP 8443 blocked: confirm the firewall and provider network allow TCP 8443.
- Hysteria2 UDP blocked: confirm the firewall and provider network allow UDP 443.
