# Trojan Credential Rotation

Use this workflow when a Trojan URI or password may no longer be private.

## Why Rotate

- The URI was exposed in chat, logs, screenshots, or issue trackers.
- A client device was lost or stolen.
- Access needs to be revoked for a customer or teammate.
- You suspect the password has leaked.

## Commands

```bash
vpskit rotate trojan --dry-run
vpskit rotate trojan --yes
vpskit verify trojan
vpskit sub export trojan
vpskit sub export trojan --redact
vpskit sub bundle --redact --output ./vpskit-client-bundle
```

## What Changes

- A new Trojan password is generated.
- The Xray Trojan inbound at TCP 8443 is updated.
- `/var/lib/vpskit/trojan.yaml` is rewritten with the new password.
- `/var/lib/vpskit/trojan.env` is refreshed to match the new state.
- Xray is restarted after the candidate config validates.

## After Rotation

- Old clients stop working until they import the new URI.
- VLESS Reality on TCP 443 should remain unchanged.
- Hysteria2 on UDP 443 should remain unchanged.

## Safety Notes

- Use `vpskit rotate trojan --dry-run` before a real rotation.
- Use `vpskit sub export trojan --redact` for screenshots and support requests.
- Rebuild the client bundle after rotation so the handoff files stay current.
- Do not share `/var/lib/vpskit/trojan.yaml` publicly; it contains the live password.
- Do not share the full Trojan URI publicly.
