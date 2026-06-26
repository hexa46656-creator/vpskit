# VPSKit v2.0.0-beta Troubleshooting

## Shadowrocket Import Failure

- Run `bash vpskit/cli/vpskit.sh sub` again.
- If the subscription text contains CRLF line endings, repair it locally first.
- Use `vpskit/subscription/shadowrocket_repair.sh` on a local file.

## DNS Failure

- Run `bash vpskit/cli/vpskit.sh doctor`.
- Confirm the DNS target is reachable in your environment.
- Use the beta DNS health helper in test-safe mode for validation.

## TCP 443 Unreachable

- Run `bash vpskit/cli/vpskit.sh doctor`.
- Check whether the target host actually exposes TCP 443.
- Use the TCP probe helper in safe mode before making changes.

## Reality Destination Issue

- Confirm the server destination reported by the release notes.
- Rebuild the subscription if the target host changed.

## Service Restart

- The beta does not restart services automatically.
- Re-run `status` and `doctor` after any external service change.


## Reality, Trojan, and Hysteria2 Diagnostics

- If Reality times out while Trojan and Hysteria2 still work, check DNS/CDN edge consistency first.
- Reality depends on SNI, dest, TLS fingerprint, and resolver consistency.
- Compare resolver answers with:
  - `dig www.microsoft.com @1.1.1.1`
  - `dig www.microsoft.com @8.8.8.8`
  - `dig www.microsoft.com`
- If the answers differ, avoid highly dynamic CDN targets and prefer a more stable Reality destination.
- Trojan requires the real domain to resolve consistently to the VPS public IP before certificate issuance.
- Hysteria2 UDP issues should check cloud firewall, security group, provider UDP filtering, MTU, and `insecure=true` when using a self-signed certificate.


## Reality, Trojan, and Hysteria2 Diagnostics

- If Reality times out while Trojan and Hysteria2 still work, check DNS/CDN edge consistency first.
- Reality depends on SNI, dest, TLS fingerprint, and resolver consistency.
- Compare resolver answers with:
  - `dig www.microsoft.com @1.1.1.1`
  - `dig www.microsoft.com @8.8.8.8`
  - `dig www.microsoft.com`
- If the answers differ, avoid highly dynamic CDN targets and prefer a more stable Reality destination.
- Trojan requires the real domain to resolve consistently to the VPS public IP before certificate issuance.
- Hysteria2 UDP issues should check cloud firewall, security group, provider UDP filtering, MTU, and `insecure=true` when using a self-signed certificate.

## vpskit doctor

Use `doctor` for read-only diagnostics.

## vpskit fix

Use `fix` only for safe local repair or report generation.
