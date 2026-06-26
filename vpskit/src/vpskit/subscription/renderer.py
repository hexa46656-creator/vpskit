"""Render subscription profiles into a simple line-based format."""

from __future__ import annotations

from vpskit.subscription.models import SubscriptionProfile


def render_subscription(profile: SubscriptionProfile) -> str:
    lines = [f"# {profile.name}"]

    for node in profile.nodes:
        lines.append(f"{node.protocol}://{node.host}:{node.port}#{node.name}")

    return "\n".join(lines) + "\n"
