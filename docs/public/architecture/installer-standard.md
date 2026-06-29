# Installer Standard

## Lifecycle

All installers must follow this sequence:

1. fetch stage
2. verify stage
3. parse stage
4. install stage
5. systemd stage
6. validate stage

## Required Safety Rules

- never use `curl | bash`
- always use `vpskit_safe_run`
- always include rollback hooks
- always integrate `install_lock` and `transaction`

## Stage Intent

- fetch stage: acquire the artifact or package source
- verify stage: validate checksum and trust boundary before execution
- parse stage: read configuration or metadata without mutation
- install stage: perform controlled host changes
- systemd stage: register or update service units
- validate stage: confirm service and state correctness after install

## Enforcement

Installer entrypoints must route execution through the shared core safety
framework so that unsafe remote pipe execution and missing checksum checks are
blocked before mutation.
