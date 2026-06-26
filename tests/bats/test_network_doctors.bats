setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  load_core "common.sh"
  load_core "system_check.sh"
  source "${PROJECT_ROOT}/vpskit/network/dns_health.sh"
  source "${PROJECT_ROOT}/vpskit/network/reality_doctor.sh"
  source "${PROJECT_ROOT}/vpskit/network/trojan_doctor.sh"
  source "${PROJECT_ROOT}/vpskit/network/hysteria2_doctor.sh"
}

@test "dns health reports ok with matching resolver outputs" {
  local line='DNS_HEALTH=ok host=example.com system=1.2.3.4 cloudflare=1.2.3.4 google=1.2.3.4'

  VPSKIT_TEST_DNS_HEALTH_RESULT="${line}" run vpskit_dns_health example.com
  [ "$status" -eq 0 ]
  [ "$output" = "${line}" ]
}

@test "dns health reports drift when resolver outputs differ" {
  local line='DNS_HEALTH=drift host=example.com system=1.2.3.4 cloudflare=5.6.7.8 google=1.2.3.4'

  VPSKIT_TEST_DNS_HEALTH_RESULT="${line}" run vpskit_dns_health example.com
  [ "$status" -eq 1 ]
  [ "$output" = "${line}" ]
}

@test "dns health reports fail when override requests failure" {
  VPSKIT_TEST_DNS_HEALTH_FAIL=1 run vpskit_dns_health example.com
  [ "$status" -eq 1 ]
  [ "$output" = 'DNS_HEALTH=fail host=example.com system=empty cloudflare=empty google=empty' ]
}

@test "reality doctor marks risky cdn targets" {
  local dns_line='DNS_HEALTH=ok host=www.microsoft.com system=13.107.246.45 cloudflare=13.107.246.45 google=13.107.246.45'

  export VPSKIT_TEST_DNS_HEALTH_RESULT="${dns_line}"
  export VPSKIT_REALITY_SERVER_NAME=www.microsoft.com
  export VPSKIT_REALITY_DEST=www.microsoft.com:443
  run vpskit_reality_doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"REALITY_SERVER_NAME=www.microsoft.com"* ]]
  [[ "$output" == *"REALITY_CONFIG=ok reason=serverName_dest_host_match"* ]]
  [[ "$output" == *"REALITY_TARGET_RISK=high reason=cdn_edge_drift_likely"* ]]
}

@test "reality doctor marks safe target" {
  local dns_line='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'

  export VPSKIT_TEST_DNS_HEALTH_RESULT="${dns_line}"
  export VPSKIT_REALITY_SERVER_NAME=www.cloudflare.com
  export VPSKIT_REALITY_DEST=www.cloudflare.com:443
  run vpskit_reality_doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"REALITY_CONFIG=ok reason=serverName_dest_host_match"* ]]
  [[ "$output" == *"REALITY_TARGET_RISK=normal"* ]]
}

@test "doctor command still runs without modifying system state" {
  local sentinel="${BATS_TEST_TMPDIR}/sentinel"
  printf 'before
' >"${sentinel}"

  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=example.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_REALITY_SERVER_NAME=www.cloudflare.com
  export VPSKIT_REALITY_DEST=www.cloudflare.com:443
  export VPSKIT_TROJAN_DOMAIN=trojan.example.com
  export VPSKIT_PUBLIC_IPV4=1.1.1.1
  export VPSKIT_HYSTERIA2_PORT=443
  export VPSKIT_HYSTERIA2_MASQUERADE_HOST=www.bing.com

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [ "$(tr -d '
' < "${sentinel}")" = "before" ]
}
