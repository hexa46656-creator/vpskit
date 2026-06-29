# Common Issues

- Missing subscription file: run the installer or check `VPSKIT_SUBSCRIPTION_FILE`.
- Empty bundle: confirm the installation completed and the subscription files exist.
- Non-empty output directory: rerun with `--force` after checking the contents.
- Unsupported client format: use the matching import file from `subscriptions/`.
- Self-signed TLS and `allowInsecure`: enable insecure TLS only for the Trojan fallback when the client requires it.
- TCP 8443 blocked: confirm the provider firewall and UFW allow TCP 8443.
- Hysteria2 UDP blocked: confirm the provider firewall and UFW allow UDP 443.
