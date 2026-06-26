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

## Generate Subscription

Use the existing subscription renderer or the beta CLI `sub` command when a subscription file is configured:

```bash
bash vpskit/cli/vpskit.sh sub
```

## Import to Shadowrocket

Open the repaired or exported subscription text and import it into Shadowrocket through the app's native import flow.

## Notes

- VPSKit v2.0.0-beta is read-only unless you explicitly provide a local repair output path.
- Do not use it to modify SSH, firewall, or systemd settings.
