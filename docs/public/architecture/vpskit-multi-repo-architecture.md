# VPSKit Multi-Repo Architecture

## Purpose

This document defines the intended repository boundaries for the VPSKit
architecture without executing any repo split.

## 1. Core Repository: `vpskit-core`

The open source safe layer belongs here.

Includes:

- `install_lock.sh`
- `transaction.sh`
- `system_check.sh`
- `permission_model.sh`
- safety framework modules
- CLI entrypoints
- tests

This repository is the stable public base for safe installer coordination,
read-only inspection, validation, and controlled mutation primitives.

## 2. Installer Repository: `vpskit-installers`

Not implemented yet.

Contains:

- Xray installer
- Hysteria2 installer
- Trojan installer

This repository must depend on the `vpskit-core` safety layer instead of
reimplementing it.

## 3. SaaS Repository: `vpskit-saas`

Not implemented yet.

Contains:

- subscription API
- Telegram bot
- payment system

## 4. Landing Repository: `vpskit-landing`

Not implemented yet.

Contains:

- public marketing and product landing assets
- static presentation content

## 5. Contracts Repository: `vpskit-contracts`

Not implemented yet.

Contains:

- API schema
- subscription schema

## Boundary Rules

- Core stays safe and public.
- Installers depend on core safety primitives.
- SaaS stays separate from installer runtime.
- Landing assets stay presentation-only.
- Contracts stay schema-only.

## Status

This is a documentation-only target architecture. No repository split is
performed by this document.
