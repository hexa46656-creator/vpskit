# shellcheck disable=SC1091,SC2030,SC2031

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

@test "dns health reports unknown when resolver tool is missing" {
  VPSKIT_TEST_DNS_HEALTH_MISSING_TOOL=dig run vpskit_dns_health
  [ "$status" -eq 0 ]
  [ "$output" = 'DNS_HEALTH=unknown reason=missing_tool tool=dig host=www.cloudflare.com' ]
}

@test "doctor default DNS target is cloudflare and missing resolver is unknown" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_MISSING_TOOL=dig
  export VPSKIT_TEST_TCP_PROBE_RESULT=open

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"DNS_HEALTH=DNS_HEALTH=unknown reason=missing_tool tool=dig host=www.cloudflare.com"* ]]
}

@test "doctor reports generated default subscription file as present" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_SUBSCRIPTION_DIR="${BATS_TEST_TMPDIR}/vpskit"
  mkdir -p "${VPSKIT_SUBSCRIPTION_DIR}"
  printf 'vless://example\n' >"${VPSKIT_SUBSCRIPTION_DIR}/vless-reality.txt"

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"SUBSCRIPTION_FILE=present"* ]]
}

@test "sub show reads generated default subscription path" {
  export VPSKIT_SUBSCRIPTION_DIR="${BATS_TEST_TMPDIR}/vpskit"
  mkdir -p "${VPSKIT_SUBSCRIPTION_DIR}"
  printf 'vless://example\n' >"${VPSKIT_SUBSCRIPTION_DIR}/vless-reality.txt"

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" sub show

  [ "$status" -eq 0 ]
  [ "$output" = "vless://example" ]
}

@test "doctor reports tcp 443 in use by vpskit xray as expected" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_TCP_PORT_IN_USE=443
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_SUBSCRIPTION_DIR="${BATS_TEST_TMPDIR}/vpskit"
  export VPSKIT_XRAY_CONFIG_PATH="${BATS_TEST_TMPDIR}/xray/config.json"
  mkdir -p "${VPSKIT_SUBSCRIPTION_DIR}" "$(dirname "${VPSKIT_XRAY_CONFIG_PATH}")"
  printf 'vless://example\n' >"${VPSKIT_SUBSCRIPTION_DIR}/vless-reality.txt"
  printf '{"inbounds":[]}\n' >"${VPSKIT_XRAY_CONFIG_PATH}"

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"TCP_443_STATUS=in_use_expected service=xray"* ]]
}

@test "doctor reports installed hysteria2 state" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  printf 'listen: :443\nauth:\n  type: password\n  password: test-password\ntls:\n  cert: /etc/hysteria/server.crt\n  key: /etc/hysteria/server.key\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"
  printf 'server: 203.0.113.10:443\nauth: test-password\ntls:\n  sni: 203.0.113.10\n  pinSHA256: test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/udp ALLOW IN Anywhere'

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_INSTALLED=yes"* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=active"* ]]
  [[ "$output" == *"HYSTERIA2_UDP_443=bound"* ]]
  [[ "$output" == *"HYSTERIA2_SUBSCRIPTION_FILE=present"* ]]
  [[ "$output" == *"UFW_443_UDP=pass status=active rule=present"* ]]
}

@test "doctor reports hysteria2 udp listener owned by another process" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  printf 'listen: :443\nauth:\n  type: password\n  password: test-password\ntls:\n  cert: /etc/hysteria/server.crt\n  key: /etc/hysteria/server.key\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"
  printf 'server: 203.0.113.10:443\nauth: test-password\ntls:\n  sni: 203.0.113.10\n  pinSHA256: test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_UDP_443_LISTENERS=$'UNCONN 0 0 0.0.0.0:443 0.0.0.0:* users:(("nginx",pid=123,fd=7))'
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/udp ALLOW IN Anywhere'

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_UDP_443=owned_by_other"* ]]
}

@test "doctor reports inactive hysteria2 service state" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  printf 'listen: :443\nauth:\n  type: password\n  password: test-password\ntls:\n  cert: /etc/hysteria/server.crt\n  key: /etc/hysteria/server.key\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"
  printf 'server: 203.0.113.10:443\nauth: test-password\ntls:\n  sni: 203.0.113.10\n  pinSHA256: test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="other.service"
  export VPSKIT_TEST_UDP_443_LISTENERS=$'\n'
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_INSTALLED=yes"* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=inactive"* ]]
  [[ "$output" == *"HYSTERIA2_UDP_443=not_bound"* ]]
}

@test "doctor reports inactive ufw skip for hysteria2" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  printf 'listen: :443\nauth:\n  type: password\n  password: test-password\ntls:\n  cert: /etc/hysteria/server.crt\n  key: /etc/hysteria/server.key\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"
  printf 'server: 203.0.113.10:443\nauth: test-password\ntls:\n  sni: 203.0.113.10\n  pinSHA256: test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_443_UDP=skip status=inactive reason=not_enforced"* ]]
}

@test "doctor reports missing hysteria2 components clearly" {
  export VPSKIT_TEST_OS_ID=ubuntu
  export VPSKIT_TEST_OS_VERSION_ID=24.04
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_DNS_HEALTH_RESULT='DNS_HEALTH=ok host=www.cloudflare.com system=1.1.1.1 cloudflare=1.1.1.1 google=1.1.1.1'
  export VPSKIT_TEST_TCP_PROBE_RESULT=open
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  export VPSKIT_TEST_SERVICE_EXISTS=""
  export VPSKIT_TEST_SERVICE_ACTIVE=""
  export VPSKIT_TEST_UDP_443_OWNER=""
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${PROJECT_ROOT}/vpskit/cli/vpskit.sh" doctor

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_INSTALLED=no"* ]]
  [[ "$output" == *"HYSTERIA2_BINARY=missing"* ]]
  [[ "$output" == *"HYSTERIA2_CONFIG=missing"* ]]
  [[ "$output" == *"HYSTERIA2_SUBSCRIPTION_FILE=missing"* ]]
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
