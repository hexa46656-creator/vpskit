# VPSKit v2.0.0-beta Install Guide

## Install

```bash
git clone https://github.com/hexa46656-creator/vpskit.git
cd vpskit
bash vpskit/cli/vpskit.sh version
```

## First Use

```bash
bash vpskit/cli/vpskit.sh status
bash vpskit/cli/vpskit.sh doctor
```

## Phase 1 Install

For a clean Ubuntu 24.04 VPS, run hardening first. Prefer an explicit public key for the managed user `alex`:

```bash
sudo VPSKIT_AUTHORIZED_KEY_FILE="$HOME/.ssh/id_ed25519.pub" bash vpskit/cli/vpskit.sh install hardening
```

If no explicit key is provided, VPSKit copies root `authorized_keys`. That does not guarantee default `ssh alex@IP` uses the matching private key. Open a second terminal and verify the SSH command printed by the installer before closing the root session.

Then install VLESS Reality:

```bash
sudo bash vpskit/cli/vpskit.sh install vless-reality
bash vpskit/cli/vpskit.sh sub show
```

When UFW is active, the VLESS installer allows the configured Reality TCP port, default `443/tcp`. When UFW is inactive, it does not enable UFW.

## Import to Shadowrocket

Open the repaired or exported subscription text and import it into Shadowrocket through the app's native import flow.

## Notes

- Phase 1 modifies SSH, UFW, Fail2ban, sudoers, Xray config, and systemd service state.
- The official Xray installer may emit a systemd warning about the special user `nobody`; this is a known Phase 1 limitation.
