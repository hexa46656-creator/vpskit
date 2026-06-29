from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class PayPalWebhookEvent(BaseModel):
    model_config = ConfigDict(extra="allow")

    id: str = Field(min_length=1)
    event_type: str = Field(min_length=1)
    resource: dict[str, Any] = Field(default_factory=dict)


class LoginRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=64)
    token: str = Field(min_length=16, max_length=128)


class MarkUsedRequest(BaseModel):
    token: str = Field(min_length=32, max_length=256)


class CheckoutRequest(BaseModel):
    plan: str = Field(pattern="^(basic|pro|elite)$")
    email: str | None = Field(default=None, max_length=320)
    region: str | None = Field(default=None, max_length=32)


class PayPalCreateOrderRequest(BaseModel):
    plan: str = Field(default="basic", pattern="^(basic|pro|elite)$")


class PayPalCaptureRequest(BaseModel):
    order_id: str = Field(min_length=1, max_length=128)
