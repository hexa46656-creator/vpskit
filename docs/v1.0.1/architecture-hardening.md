# VPSKit v1.0.1 Architecture Hardening

This release enforces a strict static boundary:

- core stays infra-only
- SaaS stays interface-only and non-executable
- client stays static-only

No monetization, automation, or financial processing logic is allowed anywhere
in the runtime path.
