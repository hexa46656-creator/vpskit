#!/usr/bin/env bash

vpskit_subscription_supported_formats() {
  printf 'SUPPORTED_SUB_FORMATS=raw,base64,shadowrocket,v2rayng,clash-meta,sing-box\n'
}

vpskit_subscription_resolve_file() {
  local subscription_file

  subscription_file="$(vpskit_default_subscription_file)"
  if [ -f "${subscription_file}" ]; then
    printf '%s\n' "${subscription_file}"
    return 0
  fi

  vpskit_die "subscription file not found: ${subscription_file}"
}

vpskit_subscription_first_uri() {
  local subscription_file="$1"

  python3 - "${subscription_file}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])

try:
    text = path.read_text(encoding="utf-8")
except FileNotFoundError:
    print(f"ERROR subscription file not found: {path}")
    raise SystemExit(1)
except UnicodeDecodeError:
    print(f"ERROR subscription file is not valid UTF-8: {path}")
    raise SystemExit(1)

for raw_line in text.splitlines():
    line = raw_line.strip()
    if line:
        print(line)
        raise SystemExit(0)

print(f"ERROR malformed VLESS Reality URI: empty subscription file: {path}")
raise SystemExit(1)
PY
}

vpskit_subscription_render_export() {
  local format="$1"
  local uri="$2"

  python3 - "${format}" "${uri}" <<'PY'
from base64 import b64encode
from urllib.parse import parse_qs, unquote, urlparse
import json
import re
import sys

format_name = sys.argv[1]
uri = sys.argv[2]


def fail(message: str) -> None:
    print(f"ERROR {message}")
    raise SystemExit(1)


def yaml_scalar(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9._:-]+", value):
        return value
    return json.dumps(value)


parsed = urlparse(uri)
if parsed.scheme.lower() != "vless":
    fail("malformed VLESS Reality URI: expected vless scheme")

try:
    port = parsed.port
except ValueError:
    fail("malformed VLESS Reality URI: invalid port")

if not parsed.username:
    fail("malformed VLESS Reality URI: missing uuid")
if not parsed.hostname:
    fail("malformed VLESS Reality URI: missing server")
if port is None:
    fail("malformed VLESS Reality URI: missing port")

params = parse_qs(parsed.query, keep_blank_values=True)

if params.get("security", [""])[0] != "reality":
    fail("malformed VLESS Reality URI: security must be reality")

required_params = {}
for key in ("sni", "fp", "pbk", "sid", "flow"):
    values = params.get(key)
    if not values or values[0] == "":
        fail(f"malformed VLESS Reality URI: missing required parameter: {key}")
    required_params[key] = unquote(values[0])

tag = unquote(parsed.fragment) if parsed.fragment else "VPSKit-Reality"
uuid = unquote(parsed.username)
server = parsed.hostname

if format_name == "base64":
    print(b64encode(uri.encode("utf-8")).decode("ascii"))
    raise SystemExit(0)

if format_name == "clash-meta":
    print("proxies:")
    print(f"  - name: {yaml_scalar(tag)}")
    print("    type: vless")
    print(f"    server: {server}")
    print(f"    port: {port}")
    print(f"    uuid: {uuid}")
    print("    network: tcp")
    print("    tls: true")
    print("    udp: true")
    print(f"    flow: {yaml_scalar(required_params['flow'])}")
    print(f"    servername: {yaml_scalar(required_params['sni'])}")
    print(f"    client-fingerprint: {yaml_scalar(required_params['fp'])}")
    print("    reality-opts:")
    print(f"      public-key: {yaml_scalar(required_params['pbk'])}")
    print(f"      short-id: {yaml_scalar(required_params['sid'])}")
    print("proxy-groups:")
    print("  - name: PROXY")
    print("    type: select")
    print("    proxies:")
    print(f"      - {yaml_scalar(tag)}")
    print("rules:")
    print("  - MATCH,PROXY")
    raise SystemExit(0)

if format_name == "sing-box":
    payload = {
        "outbounds": [
            {
                "type": "vless",
                "tag": tag,
                "server": server,
                "server_port": port,
                "uuid": uuid,
                "flow": required_params["flow"],
                "tls": {
                    "enabled": True,
                    "server_name": required_params["sni"],
                    "utls": {
                        "enabled": True,
                        "fingerprint": required_params["fp"],
                    },
                    "reality": {
                        "enabled": True,
                        "public_key": required_params["pbk"],
                        "short_id": required_params["sid"],
                    },
                },
            }
        ]
    }
    print(json.dumps(payload, indent=2))
    raise SystemExit(0)

fail(f"unsupported sub export format: {format_name}")
PY
}
