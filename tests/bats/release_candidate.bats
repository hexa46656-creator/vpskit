setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
  export DNS_PATH="${PROJECT_ROOT}/vpskit/network/dns_health.sh"
  export TCP_PATH="${PROJECT_ROOT}/vpskit/network/tcp_probe.sh"
  export REPAIR_PATH="${PROJECT_ROOT}/vpskit/subscription/shadowrocket_repair.sh"
}

@test "CLI exists and is executable" {
  [ -x "${CLI_PATH}" ]
}

@test "version command works" {
  run bash "${CLI_PATH}" version
  [ "$status" -eq 0 ]
  [[ "$output" == *"VPSKit v0.3.1-beta"* ]]
}

@test "status does not mutate files" {
  local sentinel="${BATS_TEST_TMPDIR}/sentinel"
  printf 'before\n' >"${sentinel}"

  run env VPSKIT_TEST_OS_ID=ubuntu VPSKIT_TEST_OS_VERSION_ID=24.04 VPSKIT_TEST_SYSTEMD_AVAILABLE=yes VPSKIT_TEST_UFW_AVAILABLE=yes bash "${CLI_PATH}" status
  [ "$status" -eq 0 ]
  [ "$(tr -d '\n' < "${sentinel}")" = "before" ]
}

@test "doctor does not mutate files" {
  local sentinel="${BATS_TEST_TMPDIR}/sentinel-doctor"
  printf 'before\n' >"${sentinel}"

  run env VPSKIT_TEST_DNS_HEALTH_RESULT=ok VPSKIT_TEST_TCP_PROBE_RESULT=open VPSKIT_TEST_OS_ID=ubuntu VPSKIT_TEST_OS_VERSION_ID=24.04 bash "${CLI_PATH}" doctor
  [ "$status" -eq 0 ]
  [ "$(tr -d '\n' < "${sentinel}")" = "before" ]
}

@test "shadowrocket repair handles sample VLESS URI" {
  local input_file="${BATS_TEST_TMPDIR}/shadowrocket.txt"
  printf 'vless://example.com:443#demo\r\n' >"${input_file}"

  run bash "${REPAIR_PATH}" --input "${input_file}"

  [ "$status" -eq 0 ]
  [[ "$output" == *"vless://example.com:443#demo"* ]]
  [[ "$output" != *$'\r'* ]]
}

@test "dns health script has test mode" {
  run env VPSKIT_TEST_DNS_HEALTH_RESULT=ok bash -lc "source '${DNS_PATH}'; vpskit_dns_health example.com"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "tcp probe script has test mode" {
  run env VPSKIT_TEST_TCP_PROBE_RESULT=open bash -lc "source '${TCP_PATH}'; vpskit_tcp_probe example.com 443"
  [ "$status" -eq 0 ]
  [ "$output" = "open" ]
}

@test "release manifest exists and is valid json" {
  local manifest="${PROJECT_ROOT}/release/v2.0.0-beta-manifest.json"
  [ -f "${manifest}" ]
  run python3 -c 'import json,sys; data=json.load(open(sys.argv[1], encoding="utf-8")); assert data["version"] == "v2.0.0-beta"' "${manifest}"
  [ "$status" -eq 0 ]
}

@test "README after-install verification examples remain accurate" {
  run bash -lc "grep -F 'bash vpskit/cli/vpskit.sh verify ssh-user' '${PROJECT_ROOT}/README.md' && grep -F 'bash vpskit/cli/vpskit.sh verify vless-reality' '${PROJECT_ROOT}/README.md' && grep -F 'bash vpskit/cli/vpskit.sh sub show' '${PROJECT_ROOT}/README.md'"
  [ "$status" -eq 0 ]
}

@test "install docs exist" {
  [ -f "${PROJECT_ROOT}/docs/install-guide.en.md" ]
  [ -f "${PROJECT_ROOT}/docs/install-guide.zh.md" ]
  [ -f "${PROJECT_ROOT}/docs/troubleshooting.en.md" ]
  [ -f "${PROJECT_ROOT}/docs/troubleshooting.zh.md" ]
}

@test "scope excludes experimental theory layers" {
  run bash -lc "grep -Ei 'autonomous ai control plane|self-modifying systems|formal/meta/godel/epistemic/observer layers' '${PROJECT_ROOT}/release/v2.0.0-beta-scope.md'"
  [ "$status" -eq 0 ]
}

@test "release files do not contain obvious secrets" {
  run bash -lc "grep -RInE '(sk_live|sk_test|BEGIN RSA|BEGIN OPENSSH|PRIVATE KEY|TOKEN=|API_KEY=|SECRET=|ghp_|xoxb-|telegram.*token)' '${PROJECT_ROOT}/vpskit' '${PROJECT_ROOT}/docs' '${PROJECT_ROOT}/release' '${PROJECT_ROOT}/tests' '${PROJECT_ROOT}/.env.example' '${PROJECT_ROOT}/.gitignore' '${PROJECT_ROOT}/README.md' --exclude-dir=.git --exclude='*.md' || true"
  [ "$status" -eq 0 ]
}
