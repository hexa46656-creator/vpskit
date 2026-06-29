# DNS Safety Layer

## Overview

The DNS safety layer rejects unsafe resolver targets before they can influence installer or system-check flows.

## Guarded Targets

- `127.0.0.1`
- `localhost`
- `127.0.0.53`

## Flow

```text
input target
  -> normalize host
  -> reject forbidden local targets
  -> allow explicit public targets
```

## Guarantees

- DNS targets must be explicit when validation is requested.
- Loopback resolver targets are blocked.
- No fallback target is introduced by the safety layer.

## Integration Points

- `vpskit/core/dns_safety.sh`
- `vpskit/core/system_check.sh`
- installer entrypoints that consume DNS-like values

## Forbidden Patterns

- Silent fallback to a resolver target
- Accepting `localhost` or loopback resolver addresses
- Deriving a resolver from an implicit default in new safety checks

## Migration Notes

Legacy code may still carry diagnostic defaults for read-only reporting. New safety checks should call `vpskit_assert_dns_safety()` with an explicit target.
