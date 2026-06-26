#!/usr/bin/env python3
"""Parse and render VPSKit VLESS Reality subscription URIs."""

from __future__ import annotations

from base64 import b64encode
from dataclasses import dataclass
import json
import re
import sys
from urllib.parse import parse_qs, unquote, urlparse


EXPECTED_FLOW = "xtls-rprx-vision"
EXPECTED_SECURITY = "reality"
EXPECTED_TYPE = "tcp"
DEFAULT_TAG = "VPSKit-Reality"


@dataclass(frozen=True)
class ParsedUri:
    scheme: str
    uuid: str
    server: str
    port: int | None
    port_raw: str
    security: str
    sni: str
    fp: str
    pbk: str
    sid: str
    type: str
    flow: str
    tag: str


def yaml_scalar(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9._:-]+", value):
        return value
    return json.dumps(value)


def extract_raw_port(netloc: str) -> str:
    host_part = netloc.rsplit("@", 1)[-1]

    if host_part.startswith("[") and "]:" in host_part:
        return host_part.rsplit("]:", 1)[1]

    if ":" in host_part:
        return host_part.rsplit(":", 1)[1]

    return ""


def parse_uri(uri: str) -> ParsedUri:
    parsed = urlparse(uri)

    try:
        port = parsed.port
        port_raw = "" if port is not None else extract_raw_port(parsed.netloc)
    except ValueError:
        port = None
        port_raw = extract_raw_port(parsed.netloc)

    params = parse_qs(parsed.query, keep_blank_values=True)

    def first(key: str) -> str:
        values = params.get(key)
        if not values:
            return ""
        return unquote(values[0])

    return ParsedUri(
        scheme=parsed.scheme.lower(),
        uuid=unquote(parsed.username or ""),
        server=parsed.hostname or "",
        port=port,
        port_raw=port_raw,
        security=first("security"),
        sni=first("sni"),
        fp=first("fp"),
        pbk=first("pbk"),
        sid=first("sid"),
        type=first("type"),
        flow=first("flow"),
        tag=unquote(parsed.fragment) if parsed.fragment else DEFAULT_TAG,
    )


def require(parsed: ParsedUri, condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def render_export(format_name: str, uri: str) -> str:
    parsed = parse_uri(uri)
    require(parsed, parsed.scheme == "vless", "malformed VLESS Reality URI: expected vless scheme")
    require(parsed, bool(parsed.uuid), "malformed VLESS Reality URI: missing uuid")
    require(parsed, bool(parsed.server), "malformed VLESS Reality URI: missing server")
    require(parsed, parsed.port is not None, "malformed VLESS Reality URI: invalid port")
    require(parsed, parsed.security == EXPECTED_SECURITY, "malformed VLESS Reality URI: security must be reality")
    require(parsed, bool(parsed.sni), "malformed VLESS Reality URI: missing required parameter: sni")
    require(parsed, bool(parsed.fp), "malformed VLESS Reality URI: missing required parameter: fp")
    require(parsed, bool(parsed.pbk), "malformed VLESS Reality URI: missing required parameter: pbk")
    require(parsed, bool(parsed.sid), "malformed VLESS Reality URI: missing required parameter: sid")
    require(parsed, parsed.type == EXPECTED_TYPE, "malformed VLESS Reality URI: type must be tcp")
    require(parsed, parsed.flow == EXPECTED_FLOW, "malformed VLESS Reality URI: flow must be xtls-rprx-vision")

    if format_name == "base64":
        return b64encode(uri.encode("utf-8")).decode("ascii")

    if format_name == "clash-meta":
        lines = [
            "proxies:",
            f"  - name: {yaml_scalar(parsed.tag)}",
            "    type: vless",
            f"    server: {parsed.server}",
            f"    port: {parsed.port}",
            f"    uuid: {parsed.uuid}",
            "    network: tcp",
            "    tls: true",
            "    udp: true",
            f"    flow: {yaml_scalar(parsed.flow)}",
            f"    servername: {yaml_scalar(parsed.sni)}",
            f"    client-fingerprint: {yaml_scalar(parsed.fp)}",
            "    reality-opts:",
            f"      public-key: {yaml_scalar(parsed.pbk)}",
            f"      short-id: {yaml_scalar(parsed.sid)}",
            "proxy-groups:",
            "  - name: PROXY",
            "    type: select",
            "    proxies:",
            f"      - {yaml_scalar(parsed.tag)}",
            "rules:",
            "  - MATCH,PROXY",
        ]
        return "\n".join(lines)

    if format_name == "sing-box":
        payload = {
            "outbounds": [
                {
                    "type": "vless",
                    "tag": parsed.tag,
                    "server": parsed.server,
                    "server_port": parsed.port,
                    "uuid": parsed.uuid,
                    "flow": parsed.flow,
                    "tls": {
                        "enabled": True,
                        "server_name": parsed.sni,
                        "utls": {
                            "enabled": True,
                            "fingerprint": parsed.fp,
                        },
                        "reality": {
                            "enabled": True,
                            "public_key": parsed.pbk,
                            "short_id": parsed.sid,
                        },
                    },
                }
            ]
        }
        return json.dumps(payload, indent=2)

    raise ValueError(f"unsupported sub export format: {format_name}")


def validate_uri(uri: str) -> list[str]:
    parsed = parse_uri(uri)
    status = True
    lines: list[str] = []

    if parsed.scheme == "vless":
        lines.append("SUB_URI=pass scheme=vless")
    else:
        lines.append(f"SUB_URI=fail reason=unsupported_scheme value={parsed.scheme or 'missing'}")
        status = False

    if parsed.uuid:
        lines.append("SUB_UUID=pass")
    else:
        lines.append("SUB_UUID=fail reason=missing")
        status = False

    if parsed.server:
        lines.append(f"SUB_SERVER=pass value={parsed.server}")
    else:
        lines.append("SUB_SERVER=fail reason=missing")
        status = False

    if parsed.port is not None:
        lines.append(f"SUB_PORT=pass value={parsed.port}")
    elif parsed.port_raw:
        lines.append(f"SUB_PORT=fail reason=non_numeric value={parsed.port_raw}")
        status = False
    else:
        lines.append("SUB_PORT=fail reason=missing")
        status = False

    if parsed.security == EXPECTED_SECURITY:
        lines.append(f"SUB_SECURITY=pass value={parsed.security}")
    else:
        lines.append(
            f"SUB_SECURITY=fail value={parsed.security or 'missing'} expected={EXPECTED_SECURITY}"
        )
        status = False

    if parsed.sni:
        lines.append(f"SUB_SNI=pass value={parsed.sni}")
    else:
        lines.append("SUB_SNI=fail reason=missing")
        status = False

    if parsed.fp:
        lines.append(f"SUB_FP=pass value={parsed.fp}")
    else:
        lines.append("SUB_FP=fail reason=missing")
        status = False

    if parsed.pbk:
        lines.append("SUB_PBK=pass")
    else:
        lines.append("SUB_PBK=fail reason=missing")
        status = False

    if parsed.sid:
        lines.append("SUB_SID=pass")
    else:
        lines.append("SUB_SID=fail reason=missing")
        status = False

    if parsed.type == EXPECTED_TYPE:
        lines.append(f"SUB_TYPE=pass value={parsed.type}")
    else:
        lines.append(f"SUB_TYPE=fail value={parsed.type or 'missing'} expected={EXPECTED_TYPE}")
        status = False

    if parsed.flow == EXPECTED_FLOW:
        lines.append(f"SUB_FLOW=pass value={parsed.flow}")
    else:
        lines.append(
            f"SUB_FLOW=fail value={parsed.flow or 'missing'} expected={EXPECTED_FLOW}"
        )
        status = False

    lines.append(f"SUB_VALIDATE={'pass' if status else 'fail'}")
    return lines


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print("ERROR usage: uri_tool.py <render|validate> <format?> <uri>")
        return 1

    mode = argv[1]

    try:
        if mode == "render":
            if len(argv) != 4:
                raise ValueError("usage: uri_tool.py render <format> <uri>")
            print(render_export(argv[2], argv[3]))
            return 0

        if mode == "validate":
            if len(argv) != 3:
                raise ValueError("usage: uri_tool.py validate <uri>")
            lines = validate_uri(argv[2])
            print("\n".join(lines))
            return 0 if lines[-1] == "SUB_VALIDATE=pass" else 1

        raise ValueError(f"unknown mode: {mode}")
    except ValueError as exc:
        print(f"ERROR {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
