#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
}

@test "installers source only the installer runtime layer" {
  run rg -n "source .*install/" "${PROJECT_ROOT}/vpskit/install"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "installers source the shared runtime layer" {
  run rg -n "source .*installer_runtime.sh" "${PROJECT_ROOT}/vpskit/install"

  [ "$status" -eq 0 ]
  [[ "$output" == *"installer_runtime.sh"* ]]
}

@test "installer scripts and runtime parse cleanly" {
  run bash -n \
    "${PROJECT_ROOT}/vpskit/core/installer_runtime.sh" \
    "${PROJECT_ROOT}/vpskit/install/hardening.sh" \
    "${PROJECT_ROOT}/vpskit/install/hysteria2.sh" \
    "${PROJECT_ROOT}/vpskit/install/trojan.sh" \
    "${PROJECT_ROOT}/vpskit/install/vless_reality.sh"

  [ "$status" -eq 0 ]
}

