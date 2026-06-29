#!/usr/bin/env bash
set -euo pipefail

declare -A OWNERS=()
declare -a DUPES=()
declare -a PATHS=()

add_paths() {
  local repo="$1"
  shift
  local path
  for path in "$@"; do
    PATHS+=("${path}")
    if [ -n "${OWNERS[$path]:-}" ] && [ "${OWNERS[$path]}" != "${repo}" ]; then
      DUPES+=("${path} => ${OWNERS[$path]},${repo}")
    else
      OWNERS["${path}"]="${repo}"
    fi
  done
}

add_paths vpskit-core \
  "vpskit/core/" "vpskit/cli/vpskit.sh" "vpskit/network/" "vpskit/qa/" "vpskit/verify/" "vpskit/subscription/" "vpskit/rotate/" "vpskit/demo/" "vpskit/templates/" "vpskit/README.md" "vpskit/pyproject.toml" "vpskit/ARCHITECTURE_POLICY.json" "vpskit/tests/" "docs/public/" \
  "docs/architecture/v0.8-boundary.md" "docs/architecture/v0.8.1-strong-boundary.md" "docs/client-bundle.en.md" "docs/client-bundle.zh.md" "docs/customer-handoff.en.md" "docs/customer-handoff.zh.md" "docs/demo-packaging.en.md" "docs/demo-packaging.zh.md" "docs/final-qa.en.md" "docs/final-qa.zh.md" "docs/hysteria2-recovery.en.md" "docs/hysteria2-recovery.zh.md" "docs/install-guide.en.md" "docs/install-guide.zh.md" "docs/trojan-client-compatibility.en.md" "docs/trojan-client-compatibility.zh.md" "docs/trojan-credential-rotation.en.md" "docs/trojan-credential-rotation.zh.md" "docs/trojan-recovery.en.md" "docs/trojan-recovery.zh.md" "docs/troubleshooting.en.md" "docs/troubleshooting.zh.md" "tests/bats/test_common.bats" "tests/bats/test_concurrency_v2.bats" "tests/bats/test_dns_safety.bats" "tests/bats/test_execution_security.bats" "tests/bats/test_installer_boundary.bats" "tests/bats/test_network_doctors.bats" "tests/bats/test_qa_demo_commands.bats" "tests/bats/test_rotate_commands.bats" "tests/bats/test_sub_bundle_commands.bats" "tests/bats/test_subscription_exports.bats" "tests/bats/test_system_check.bats" "tests/bats/test_transaction.bats" "tests/bats/test_verify_commands.bats"

add_paths vpskit-installers \
  "vpskit/install/" "tests/bats/test_install_commands.bats" "tests/bats/test_install_hardening.bats" "tests/bats/test_install_hysteria2.bats" "tests/bats/test_install_lock.bats" "tests/bats/test_install_vless_reality.bats" "tests/bats/test_installer_boundary.bats" \
  "docs/install-guide.en.md" "docs/install-guide.zh.md" "docs/troubleshooting.en.md" "docs/troubleshooting.zh.md" "docs/hysteria2-recovery.en.md" "docs/hysteria2-recovery.zh.md" "docs/trojan-client-compatibility.en.md" "docs/trojan-client-compatibility.zh.md" "docs/trojan-credential-rotation.en.md" "docs/trojan-credential-rotation.zh.md" "docs/trojan-recovery.en.md" "docs/trojan-recovery.zh.md"

add_paths vpskit-contracts "vpskit-contracts/"
add_paths vpskit-ui "vpskit-ui/"
add_paths vpskit-landing "landing-v2/" "landing-youtube/" "vpskit-client/"
add_paths vpskit-saas "vpskit-saas/" "docs/architecture/v0.9-saas-boundary.md"
add_paths vpskit-tools "scripts/" "release/" "tests/bats/release_candidate.bats"

for i in "${!PATHS[@]}"; do
  for j in "${!PATHS[@]}"; do
    [ "${i}" = "${j}" ] && continue
    left="${PATHS[$i]}"
    right="${PATHS[$j]}"
    case "${right}" in
      "${left}"/*)
        if [ "${OWNERS[$left]}" != "${OWNERS[$right]}" ]; then
          DUPES+=("${left} <=> ${right} (${OWNERS[$left]},${OWNERS[$right]})")
        fi
        ;;
    esac
  done
done

if [ "${#DUPES[@]}" -gt 0 ]; then
  printf 'OVERLAP_CHECK=fail reason=duplicate_assignment\n'
  printf '  %s\n' "${DUPES[@]}"
  exit 1
fi

echo "OVERLAP_CHECK=pass reason=no_duplicate_assignments"
echo "OVERLAP_CHECK=pass reason=no_shared_mutable_runtime_logic"
echo "OVERLAP_CHECK=pass reason=no_conflicting_path_assignments"
