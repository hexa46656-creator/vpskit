# VPSKit API Description

## Scope

This document lists the public FastAPI surface at a high level.

## Endpoints

- `POST /register`
- `POST /upload-config`
- `GET /sub/{id}`
- `GET /status/{id}`

## Notes

- Requests should be authenticated.
- Responses should be structured JSON.
- Sensitive subscription or deployment design should stay out of the public
  documentation layer.
- This file documents the API shape only, not any commercial workflow around it.
