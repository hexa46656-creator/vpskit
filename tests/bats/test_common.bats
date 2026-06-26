setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
}

@test "logging helpers write deterministic level-prefixed output" {
  run vpskit_log_info "ready"
  [ "$status" -eq 0 ]
  [ "$output" = "INFO ready" ]

  run vpskit_log_warn "careful"
  [ "$status" -eq 0 ]
  [ "$output" = "WARN careful" ]

  run vpskit_log_error "failed"
  [ "$status" -eq 0 ]
  [ "$output" = "ERROR failed" ]
}

@test "vpskit_die exits non-zero and writes error output" {
  run vpskit_die "stop now"

  [ "$status" -eq 1 ]
  [ "$output" = "ERROR stop now" ]
}

@test "vpskit_require_command succeeds for available command" {
  run vpskit_require_command "bash"

  [ "$status" -eq 0 ]
}

@test "vpskit_require_command fails for missing command" {
  run vpskit_require_command "vpskit-missing-command-for-test"

  [ "$status" -eq 1 ]
  [[ "$output" == *"required command not found"* ]]
}

@test "vpskit_is_dry_run detects truthy dry-run values" {
  VPSKIT_DRY_RUN=1 run vpskit_is_dry_run
  [ "$status" -eq 0 ]

  VPSKIT_DRY_RUN=true run vpskit_is_dry_run
  [ "$status" -eq 0 ]

  VPSKIT_DRY_RUN=0 run vpskit_is_dry_run
  [ "$status" -eq 1 ]
}
