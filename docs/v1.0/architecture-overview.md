# VPSKit v1.0 Architecture Overview

## Layer Model

- CORE: stable infra only
- SAAS: mock commercial layer only
- CLIENT: static marketing layer only

## Data Flow

CLIENT -> SAAS -> CORE

Core exports:

- release bundles
- QA reports
- protocol configs

SAAS consumes core artifacts and keeps its own state mock-only.

## Boundary Rule

Core must not import SAAS or CLIENT modules.

## Release Rule

The v1.0 release keeps business-facing surfaces separate from the stable
infra system so each layer can evolve without runtime coupling.
