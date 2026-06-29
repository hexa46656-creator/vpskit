# VPSKit Architecture Overview

## Scope

This document describes the public, safe architecture boundary for VPSKit.
It intentionally excludes commercial planning, pricing, and deployment
strategy.

## Public Layer

The open source layer is limited to:

- stable CLI and documentation surface
- read-only QA and inspection guidance
- installer safety concepts
- FastAPI endpoint descriptions
- test and validation strategy

## Boundary

The public layer must not describe:

- payment or subscription design
- SaaS roadmap details
- VPS deployment automation strategy
- monetization logic

## Core Principle

The repository should stay readable and safe for public review while keeping
commercial planning isolated in internal documentation.
