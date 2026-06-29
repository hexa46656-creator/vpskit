# VPSKit Testing Strategy

## Scope

This document describes the public testing approach for the stable toolkit.

## Checks

- shell syntax validation
- Bats coverage for installer and CLI behavior
- pytest coverage for Python helpers
- diff and repository hygiene checks

## Strategy

- prefer read-only validation where possible
- keep tests deterministic
- avoid host mutation in test runs
- validate public docs and safe installer concepts only

## Outcome

The goal is to prove the public surface is stable, readable, and safe to review
without exposing internal planning or commercialization details.
