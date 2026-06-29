#!/usr/bin/env bash
set -euo pipefail

cat <<'JSON'
{
  "manifest_version": 2,
  "deterministic": true,
  "freeze_tag": "vpskit-pre-split-freeze",
  "repos": {
    "vpskit-core": {
      "include": [
        "vpskit/core/",
        "vpskit/cli/vpskit.sh",
        "vpskit/network/",
        "vpskit/qa/",
        "vpskit/verify/",
        "vpskit/subscription/",
        "vpskit/rotate/",
        "vpskit/demo/",
        "vpskit/templates/",
        "vpskit/README.md",
        "vpskit/pyproject.toml",
        "vpskit/ARCHITECTURE_POLICY.json",
        "vpskit/tests/",
        "docs/public/"
      ],
      "exclude": [".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "vpskit-ui/dist/", "vpskit-ui/node_modules/", "releases/", "vpskit-bundle/", ".vpskit.lock"]
    },
    "vpskit-installers": {
      "include": ["vpskit/install/", "tests/bats/test_install_commands.bats", "tests/bats/test_install_hardening.bats", "tests/bats/test_install_hysteria2.bats", "tests/bats/test_install_lock.bats", "tests/bats/test_install_vless_reality.bats", "tests/bats/test_installer_boundary.bats", "docs/install-guide.en.md", "docs/install-guide.zh.md", "docs/troubleshooting.en.md", "docs/troubleshooting.zh.md"],
      "exclude": [".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "vpskit-ui/dist/", "vpskit-ui/node_modules/", "releases/", "vpskit-bundle/", ".vpskit.lock"]
    },
    "vpskit-contracts": {
      "include": ["vpskit-contracts/"],
      "exclude": [".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "vpskit-ui/dist/", "vpskit-ui/node_modules/", "releases/", "vpskit-bundle/", ".vpskit.lock"]
    },
    "vpskit-ui": {
      "include": ["vpskit-ui/"],
      "exclude": ["vpskit-ui/dist/", "vpskit-ui/node_modules/", ".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "releases/", "vpskit-bundle/", ".vpskit.lock"]
    },
    "vpskit-landing": {
      "include": ["landing-v2/", "landing-youtube/", "vpskit-client/"],
      "exclude": [".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "vpskit-ui/dist/", "vpskit-ui/node_modules/", "releases/", "vpskit-bundle/", ".vpskit.lock"]
    },
    "vpskit-saas": {
      "include": ["vpskit-saas/", "docs/architecture/v0.9-saas-boundary.md"],
      "exclude": [".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "vpskit-ui/dist/", "vpskit-ui/node_modules/", "releases/", "vpskit-bundle/", ".vpskit.lock"]
    },
    "vpskit-tools": {
      "include": ["scripts/", "release/", "tests/bats/release_candidate.bats"],
      "exclude": ["releases/", "vpskit-bundle/", ".vpskit.lock", ".pytest_cache/", ".mypy_cache/", ".ruff_cache/", "vpskit/.venv/", "vpskit-ui/dist/", "vpskit-ui/node_modules/"]
    }
  }
}
JSON
