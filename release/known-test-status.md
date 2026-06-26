# Known Test Status

## Current Status

- `rtk bats tests/bats`: passing
- `bash -n` on core shell scripts: passing
- Backend pytest: passing with one Starlette deprecation warning
- Frontend build: passing
- `git diff --check`: passing

## Notes

- The backend warning is from FastAPI/Starlette test client usage.
- No release candidate-specific failures are currently known.
