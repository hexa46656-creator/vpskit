# VPSKit v1.1.0 Immutable Snapshot

This release snapshot is frozen.

- No overwrite allowed
- No regeneration allowed
- Validation is commit-bound through `.vpskit.lock`
- The release surface is limited to `manifest.json` and `README.md`

## Snapshot Rule

Treat `releases/v1.1.0/` as a read-only artifact. Any change requires a new snapshot path and a new lock commit.
