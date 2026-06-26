# Demo Packaging

## Purpose

Create a local customer handoff bundle with safe files only.

## Command

```bash
vpskit demo package --redact --output ./vpskit-demo-package
```

## Output Files

- `README.en.md`
- `README.zh.md`
- `qa-report.txt`
- `protocol-layout.txt`
- `client-import-notes.en.md`
- `client-import-notes.zh.md`
- `security-notes.en.md`
- `security-notes.zh.md`
- `trojan-redacted.uri`
- `command-checklist.txt`

## Behavior

- The output directory is created if it does not exist
- Existing non-empty output directories are refused unless `--force` is supplied
- File names are deterministic
- The package is redacted by default

## Safe Sharing Rules

- Share the redacted package only
- Do not share the live Trojan password publicly
- Do not share private keys or raw logs

## Verification Commands

```bash
vpskit qa --redact
vpskit demo package --redact --output ./vpskit-demo-package
vpskit verify vless-reality
vpskit verify hysteria2
vpskit verify trojan
```
