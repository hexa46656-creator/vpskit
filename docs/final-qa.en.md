# Final QA

## Purpose

Run a safe, read-only summary of the installed VPSKit system.

## Command

```bash
vpskit qa
vpskit qa --redact
vpskit qa --redact --output ./qa-report.txt
```

## What It Checks

- VLESS Reality verification
- Hysteria2 verification
- Trojan verification
- Doctor summary
- Redacted Trojan export
- Xray config test if Xray is available
- Local listener ownership on TCP 443, UDP 443, and TCP 8443
- UFW status summary
- Service status summary

## Output Rules

- Output is grep-friendly key=value text
- The command is read-only
- Sensitive output stays redacted by default
- Final status line is `VPSKIT_QA=pass` or `VPSKIT_QA=fail`

## Typical Follow-Up

```bash
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
vpskit doctor
vpskit sub export trojan --redact
```
