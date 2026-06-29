#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_TOML="${PROJECT_TOML:-${REPO_ROOT}/vpskit/pyproject.toml}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/dist}"
VERSION="${RELEASE_VERSION:-}"

release_read_version() {
  if [[ -n "${VERSION}" ]]; then
    printf '%s\n' "${VERSION}"
    return 0
  fi

  awk -F'"' '/^version = / { print $2; exit }' "${PROJECT_TOML}"
}

release_make_tag() {
  local version="$1"
  printf 'vpskit-v%s\n' "${version}"
}

release_make_notes() {
  local tag="$1"
  local notes_path="$2"

  cat > "${notes_path}" <<EOF
# ${tag}

- Security hardening pipeline prepared.
- One-click installer bundle prepared.
- Subscription generator and validation modules included.
- Manual release approval required before publication.
EOF
}

release_package_artifact() {
  local tag="$1"
  local artifact_path="$2"

  tar -czf "${artifact_path}" \
    -C "${REPO_ROOT}" \
    installer/install.sh \
    vpskit/core/installer_pipeline.sh \
    vpskit/security/hardening \
    vpskit/install/vpn_stack.sh \
    vpskit/subscription/generator.sh \
    vpskit/verify/validate_install.sh \
    release/checklist.md
}

main() {
  local version tag release_dir notes_path artifact_path

  version="$(release_read_version)"
  tag="$(release_make_tag "${version}")"
  release_dir="${OUTPUT_DIR}/${tag}"
  notes_path="${release_dir}/release-notes.md"
  artifact_path="${release_dir}/vpskit-installer-${tag}.tar.gz"

  install -d -m 0755 "${release_dir}"
  release_make_notes "${tag}" "${notes_path}"
  release_package_artifact "${tag}" "${artifact_path}"

  printf 'RELEASE_TAG=%s\n' "${tag}"
  printf 'RELEASE_NOTES=%s\n' "${notes_path}"
  printf 'RELEASE_ARTIFACT=%s\n' "${artifact_path}"
  printf 'READY_FOR_MANUAL_RELEASE=true\n'
}

main "$@"
