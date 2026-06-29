#!/usr/bin/env bats

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "system_check.sh"
}

@test "localhost dns is rejected" {
  run vpskit_validate_dns "localhost"

  [ "$status" -eq 1 ]
  [[ "$output" == *"forbidden dns target"* ]]
}

@test "loopback resolver ip is rejected" {
  run vpskit_validate_dns "127.0.0.1"

  [ "$status" -eq 1 ]
  [[ "$output" == *"forbidden dns target"* ]]
}

@test "system resolver stub is rejected" {
  run vpskit_validate_dns "127.0.0.53:53"

  [ "$status" -eq 1 ]
  [[ "$output" == *"forbidden dns target"* ]]
}

@test "explicit public dns target is accepted" {
  run vpskit_validate_dns "1.1.1.1"

  [ "$status" -eq 0 ]
  [ "$output" = "1.1.1.1" ]
}

@test "system inspection reports explicit dns target when set" {
  export VPSKIT_DNS_TARGET="1.1.1.1"
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_OS_VERSION_CODENAME=noble
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_TCP_PORT_IN_USE=8443
  export VPSKIT_TEST_UDP_PORT_IN_USE=8443

  run vpskit_system_inspection_summary

  [ "$status" -eq 0 ]
  [[ "$output" == *"DNS_TARGET=1.1.1.1"* ]]
}
