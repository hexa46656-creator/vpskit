# Demo Packaging

## Purpose

Create a local customer handoff bundle with safe files only.

For the newer customer-facing handoff flow, prefer `vpskit sub bundle --redact --output ./vpskit-client-bundle`.

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

The bundle command adds protocol-specific import files and a manifest; this demo package stays available for broader QA/demo sharing.

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
