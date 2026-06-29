# Concurrency Control System v2

## Overview

Concurrency v2 splits the mutation path into a deterministic lock chain:

```text
global lock
  -> operation lock
  -> transaction lock
  -> execution
  -> release in reverse order
```

## Components

- `vpskit_global_lock_acquire()`
- `vpskit_op_lock()`
- `vpskit_bind_transaction_lock()`
- `vpskit_deadlock_guard()`

## Guarantees

- Mutation work is serialized.
- Lock acquisition is atomic.
- Locks release automatically when the owning process exits.
- Read-only operations do not require the global lock.

## Migration From v1

- Remove PID-file lock assumptions.
- Use the global lock as the canonical entry point for mutation work.
- Bind the transaction stage only after the operation lock is held.

## Forbidden Patterns

- PID file lock files
- Parallel mutation execution
- Nested lock acquisition without guard checks
- Using lock state as a proxy for DNS validation

## Notes

This layer is scoped to locking and concurrency only. It does not change installer semantics or add deployment behavior.
