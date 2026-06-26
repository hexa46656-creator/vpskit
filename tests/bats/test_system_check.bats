setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "system_check.sh"
}

@test "root check uses VPSKIT_TEST_EUID override" {
  VPSKIT_TEST_EUID=0 run vpskit_require_root
  [ "$status" -eq 0 ]

  VPSKIT_TEST_EUID=501 run vpskit_require_root
  [ "$status" -eq 1 ]
  [[ "$output" == *"root privileges required"* ]]
}

@test "Ubuntu detection uses injected OS values" {
  VPSKIT_TEST_OS_ID=ubuntu VPSKIT_TEST_OS_VERSION_ID=22.04 run vpskit_detect_os_release

  [ "$status" -eq 0 ]
  [ "$output" = "ubuntu 22.04" ]
}

@test "Ubuntu requirement rejects non-Ubuntu OS" {
  VPSKIT_TEST_OS_ID=debian VPSKIT_TEST_OS_VERSION_ID=12 run vpskit_require_ubuntu

  [ "$status" -eq 1 ]
  [[ "$output" == *"Ubuntu is required"* ]]
}

@test "supported Ubuntu requirement accepts supported version" {
  VPSKIT_TEST_OS_ID=ubuntu VPSKIT_TEST_OS_VERSION_ID=22.04 run vpskit_require_supported_ubuntu

  [ "$status" -eq 0 ]
}

@test "supported Ubuntu requirement rejects unsupported version" {
  VPSKIT_TEST_OS_ID=ubuntu VPSKIT_TEST_OS_VERSION_ID=18.04 run vpskit_require_supported_ubuntu

  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported Ubuntu version"* ]]
}

@test "port availability check uses simulated port state" {
  VPSKIT_TEST_PORT_IN_USE=443 run vpskit_check_port_available 443
  [ "$status" -eq 1 ]
  [[ "$output" == *"port 443 is already in use"* ]]

  VPSKIT_TEST_PORT_IN_USE=8443 run vpskit_check_port_available 443
  [ "$status" -eq 0 ]
}
