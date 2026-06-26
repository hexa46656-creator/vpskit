"""Typed subscription data models."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class SubscriptionNode:
    name: str
    host: str
    port: int
    protocol: str = "vmess"


@dataclass(frozen=True)
class SubscriptionProfile:
    name: str
    nodes: list[SubscriptionNode] = field(default_factory=list)
