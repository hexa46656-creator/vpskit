# VPSKit Client Bundle

This bundle is the customer-ready handoff package for a VPSKit installation at `./vpskit-bundle`.

It includes:

- protocol exports
- import guides for supported clients
- a QA summary
- a protocol layout summary
- security notes

Use it when you need to hand a customer a clean, redacted client bundle after install.

Primary protocol recommendation:

- VLESS Reality on TCP 443
- Hysteria2 on UDP 443
- Trojan on TCP 8443 as the compatibility fallback
