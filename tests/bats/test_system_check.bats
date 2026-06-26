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

@test "OS inspection exposes ID version and codename from injected values" {
  VPSKIT_TEST_OS_ID=ubuntu run vpskit_detect_os_id
  [ "$status" -eq 0 ]
  [ "$output" = "ubuntu" ]

  VPSKIT_TEST_OS_VERSION_ID=24.04 run vpskit_detect_os_version_id
  [ "$status" -eq 0 ]
  [ "$output" = "24.04" ]

  VPSKIT_TEST_OS_VERSION_CODENAME=noble run vpskit_detect_os_version_codename
  [ "$status" -eq 0 ]
  [ "$output" = "noble" ]
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

@test "supported Ubuntu requirement accepts 24.04" {
  VPSKIT_TEST_OS_ID=ubuntu VPSKIT_TEST_OS_VERSION_ID=24.04 run vpskit_require_supported_ubuntu

  [ "$status" -eq 0 ]
}

@test "port availability check uses simulated port state" {
  VPSKIT_TEST_PORT_IN_USE=443 run vpskit_check_port_available 443
  [ "$status" -eq 1 ]
  [[ "$output" == *"port 443 is already in use"* ]]

  VPSKIT_TEST_PORT_IN_USE=8443 run vpskit_check_port_available 443
  [ "$status" -eq 0 ]
}

@test "required command report is deterministic for present and missing commands" {
  run vpskit_required_commands_report bash vpskit-missing-command-for-test

  [ "$status" -eq 0 ]
  [ "$output" = $'COMMAND bash=present\nCOMMAND vpskit-missing-command-for-test=missing' ]
}

@test "TCP and UDP port checks use injected port state" {
  VPSKIT_TEST_TCP_PORT_IN_USE=443 run vpskit_check_tcp_port_available 443
  [ "$status" -eq 1 ]
  [[ "$output" == *"tcp port 443 is already in use"* ]]

  VPSKIT_TEST_TCP_PORT_IN_USE=8443 run vpskit_check_tcp_port_available 443
  [ "$status" -eq 0 ]

  VPSKIT_TEST_UDP_PORT_IN_USE=443 run vpskit_check_udp_port_available 443
  [ "$status" -eq 1 ]
  [[ "$output" == *"udp port 443 is already in use"* ]]

  VPSKIT_TEST_UDP_PORT_IN_USE=8443 run vpskit_check_udp_port_available 443
  [ "$status" -eq 0 ]
}

@test "systemd and service inspection use injected state" {
  VPSKIT_TEST_SYSTEMD_AVAILABLE=yes run vpskit_systemd_available
  [ "$status" -eq 0 ]

  VPSKIT_TEST_SYSTEMD_AVAILABLE=no run vpskit_systemd_available
  [ "$status" -eq 1 ]

  VPSKIT_TEST_SERVICE_EXISTS=ssh.service run vpskit_service_exists ssh.service
  [ "$status" -eq 0 ]

  VPSKIT_TEST_SERVICE_EXISTS=nginx.service run vpskit_service_exists ssh.service
  [ "$status" -eq 1 ]

  VPSKIT_TEST_SERVICE_ACTIVE=ssh.service run vpskit_service_active ssh.service
  [ "$status" -eq 0 ]

  VPSKIT_TEST_SERVICE_ACTIVE=nginx.service run vpskit_service_active ssh.service
  [ "$status" -eq 1 ]
}

@test "ufw inspection uses injected availability and status" {
  VPSKIT_TEST_UFW_AVAILABLE=yes run vpskit_ufw_available
  [ "$status" -eq 0 ]

  VPSKIT_TEST_UFW_AVAILABLE=no run vpskit_ufw_available
  [ "$status" -eq 1 ]

  VPSKIT_TEST_UFW_STATUS=inactive run vpskit_ufw_status
  [ "$status" -eq 0 ]
  [ "$output" = "inactive" ]
}

@test "sshd config helpers use temporary config files" {
  local sshd_config="${BATS_TEST_TMPDIR}/sshd_config"
  printf '%s\n' \
    '# PasswordAuthentication yes' \
    'Port 2222' \
    'PasswordAuthentication no' >"${sshd_config}"

  VPSKIT_TEST_SSHD_CONFIG_PATH="${sshd_config}" run vpskit_sshd_config_path
  [ "$status" -eq 0 ]
  [ "$output" = "${sshd_config}" ]

  VPSKIT_TEST_SSHD_CONFIG_PATH="${sshd_config}" run vpskit_sshd_config_exists
  [ "$status" -eq 0 ]

  VPSKIT_TEST_SSHD_CONFIG_PATH="${sshd_config}" run vpskit_sshd_effective_value PasswordAuthentication
  [ "$status" -eq 0 ]
  [ "$output" = "no" ]
}

@test "inspection summary output is deterministic with injected values" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_OS_VERSION_CODENAME=noble
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_TCP_PORT_IN_USE=8443
  export VPSKIT_TEST_UDP_PORT_IN_USE=8443

  run vpskit_system_inspection_summary

  [ "$status" -eq 0 ]
  [ "$output" = $'OS_ID=ubuntu\nOS_VERSION_ID=24.04\nOS_VERSION_CODENAME=noble\nSUPPORTED_OS=yes\nSYSTEMD_AVAILABLE=yes\nUFW_AVAILABLE=yes\nTCP_443_AVAILABLE=yes\nUDP_443_AVAILABLE=yes' ]
}
