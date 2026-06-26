# shellcheck disable=SC2030,SC2031

setup() {
  load "helpers/test_helper.bash"
  reset_vpskit_test_env
  export PROJECT_ROOT
  export CLI_PATH="${PROJECT_ROOT}/vpskit/cli/vpskit.sh"
}

prepare_verify_rootfs() {
  export VPSKIT_TEST_ROOT_DIR="${BATS_TEST_TMPDIR}/rootfs"
  export VPSKIT_MANAGED_USER="alex"
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyExample alex@example\n' >"${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh/authorized_keys"
  chmod 700 "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh"
  chmod 600 "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh/authorized_keys"
  export VPSKIT_TEST_MANAGED_USER_EXISTS=yes
  export VPSKIT_TEST_MANAGED_USER_GROUPS="alex sudo"
  export VPSKIT_TEST_SSH_DIR_OWNER="alex:alex"
  export VPSKIT_TEST_AUTHORIZED_KEYS_OWNER="alex:alex"
}

prepare_verify_vless_rootfs() {
  prepare_verify_rootfs
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  printf 'vless://11111111-1111-4111-8111-111111111111@203.0.113.10:443#VPSKit-Reality\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/vless-reality.txt"
  export VPSKIT_TEST_XRAY_BIN="${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_ACTIVE="xray xray.service"
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/tcp ALLOW IN Anywhere'
}

prepare_verify_hysteria2_rootfs() {
  prepare_verify_rootfs
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"
  printf 'listen: :443\nauth:\n  type: password\n  password: test-password\ntls:\n  cert: /etc/hysteria/server.crt\n  key: /etc/hysteria/server.key\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"
  printf 'TEST-HYSTERIA2 PRIVATE\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/server.key"
  printf 'TEST-HYSTERIA2 CERT\n' >"${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/server.crt"
  printf 'server: 203.0.113.10:443\nauth: test-password\ntls:\n  sni: 203.0.113.10\n  pinSHA256: test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"
  printf 'VPSKIT_HYSTERIA2_SERVER_IP=203.0.113.10\nVPSKIT_HYSTERIA2_PASSWORD=test-password\nVPSKIT_HYSTERIA2_PIN_SHA256=test-pin\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.env"
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_EXISTS="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_SERVICE_ACTIVE="hysteria-server.service hysteria-server"
  export VPSKIT_TEST_UDP_443_OWNER=hysteria
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/udp ALLOW IN Anywhere'
}

prepare_verify_trojan_rootfs() {
  prepare_verify_rootfs
  mkdir -p "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin" "${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray" "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  chmod +x "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  cat >"${VPSKIT_TEST_ROOT_DIR}/usr/local/etc/xray/config.json" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-vision",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "11111111-1111-4111-8111-111111111111",
            "flow": "xtls-rprx-vision",
            "email": "default@vpskit"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.cloudflare.com:443",
          "xver": 0,
          "serverNames": [
            "www.cloudflare.com"
          ],
          "privateKey": "private-test-key",
          "shortIds": [
            "abcdef1234567890"
          ]
        }
      }
    },
    {
      "tag": "trojan-tcp-8443",
      "listen": "0.0.0.0",
      "port": 8443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "test-password",
            "email": "default@vpskit"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/vpskit/trojan/server.crt",
              "keyFile": "/etc/vpskit/trojan/server.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ]
}
EOF
  printf 'server: 203.0.113.10\nport: 8443\npassword: test-password\nsni: 203.0.113.10\nallowInsecure: 1\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml"
  printf 'VPSKIT_TROJAN_SERVER=203.0.113.10\nVPSKIT_TROJAN_PORT=8443\nVPSKIT_TROJAN_PASSWORD=test-password\nVPSKIT_TROJAN_SNI=203.0.113.10\nVPSKIT_TROJAN_ALLOW_INSECURE=1\n' >"${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.env"
  export VPSKIT_TEST_XRAY_BIN="${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/xray"
  export VPSKIT_TEST_SYSTEMD_AVAILABLE=yes
  export VPSKIT_TEST_SERVICE_EXISTS="xray xray.service"
  export VPSKIT_TEST_SERVICE_ACTIVE="xray xray.service"
  export VPSKIT_TEST_TCP_443_OWNER=xray
  export VPSKIT_TEST_TCP_8443_OWNER=xray
  export VPSKIT_TEST_UFW_AVAILABLE=yes
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n8443/tcp ALLOW IN Anywhere'
}

@test "verify help lists read-only verification targets" {
  run bash "${CLI_PATH}" verify help

  [ "$status" -eq 0 ]
  [[ "$output" == *"vpskit verify ssh-user"* ]]
  [[ "$output" == *"vpskit verify vless-reality"* ]]
  [[ "$output" == *"vpskit verify trojan"* ]]
}

@test "verify rejects unknown target" {
  run bash "${CLI_PATH}" verify unknown-target

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown verify target: unknown-target"* ]]
}

@test "verify ssh-user passes when managed user SSH state is correct" {
  prepare_verify_rootfs

  run bash "${CLI_PATH}" verify ssh-user

  [ "$status" -eq 0 ]
  [[ "$output" == *"SSH_USER_EXISTS=pass user=alex"* ]]
  [[ "$output" == *"SSH_USER_SUDO=pass user=alex group=sudo"* ]]
  [[ "$output" == *"SSH_DIR_MODE=pass expected=700 actual=700"* ]]
  [[ "$output" == *"AUTHORIZED_KEYS_MODE=pass expected=600 actual=600"* ]]
  [[ "$output" == *"VERIFY_SSH_USER=pass"* ]]
}

@test "verify ssh-user fails when authorized_keys is missing" {
  prepare_verify_rootfs
  rm "${VPSKIT_TEST_ROOT_DIR}/home/alex/.ssh/authorized_keys"

  run bash "${CLI_PATH}" verify ssh-user

  [ "$status" -eq 1 ]
  [[ "$output" == *"AUTHORIZED_KEYS=fail"* ]]
  [[ "$output" == *"VERIFY_SSH_USER=fail"* ]]
}

@test "verify vless-reality passes for active xray tcp 443 and subscription" {
  prepare_verify_vless_rootfs

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 0 ]
  [[ "$output" == *"XRAY_BINARY=pass"* ]]
  [[ "$output" == *"XRAY_SERVICE=pass state=active"* ]]
  [[ "$output" == *"TCP_443_LISTENER=pass service=xray"* ]]
  [[ "$output" == *"SUBSCRIPTION_FILE=pass"* ]]
  [[ "$output" == *"UFW_443_TCP=pass status=active rule=present"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=pass"* ]]
}

@test "verify vless-reality does not treat v6-only UFW 443 as IPv4 pass" {
  prepare_verify_vless_rootfs
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/tcp (v6) ALLOW IN Anywhere (v6)'

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 1 ]
  [[ "$output" == *"UFW_443_TCP=fail status=active rule=missing"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=fail"* ]]
}

@test "verify vless-reality fails when active UFW is missing tcp 443" {
  prepare_verify_vless_rootfs
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n22/tcp ALLOW IN Anywhere'

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 1 ]
  [[ "$output" == *"UFW_443_TCP=fail status=active rule=missing"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=fail"* ]]
}

@test "verify vless-reality skips inactive UFW without failing whole verify" {
  prepare_verify_vless_rootfs
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_443_TCP=skip status=inactive reason=not_enforced"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=pass"* ]]
}

@test "verify vless-reality fails when tcp 443 is not owned by xray" {
  prepare_verify_vless_rootfs
  export VPSKIT_TEST_TCP_443_OWNER=nginx

  run bash "${CLI_PATH}" verify vless-reality

  [ "$status" -eq 1 ]
  [[ "$output" == *"TCP_443_LISTENER=fail expected=xray actual=nginx"* ]]
  [[ "$output" == *"VERIFY_VLESS_REALITY=fail"* ]]
}

@test "verify hysteria2 passes for active service and allowed udp 443" {
  prepare_verify_hysteria2_rootfs

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"HYSTERIA2_BINARY=pass path="* ]]
  [[ "$output" == *"HYSTERIA2_CONFIG=pass path="* ]]
  [[ "$output" == *"HYSTERIA2_SERVICE=pass state=active"* ]]
  [[ "$output" == *"UDP_443_LISTENER=pass service=hysteria"* ]]
  [[ "$output" == *"HYSTERIA2_SUBSCRIPTION_FILE=pass path="* ]]
  [[ "$output" == *"UFW_443_UDP=pass status=active rule=present"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=pass"* ]]
}

@test "verify hysteria2 fails when binary is missing" {
  prepare_verify_hysteria2_rootfs
  rm "${VPSKIT_TEST_ROOT_DIR}/usr/local/bin/hysteria"

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_BINARY=fail path=missing"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 fails when config is missing" {
  prepare_verify_hysteria2_rootfs
  rm "${VPSKIT_TEST_ROOT_DIR}/etc/hysteria/config.yaml"

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_CONFIG=fail path="* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 fails when subscription file is missing" {
  prepare_verify_hysteria2_rootfs
  rm "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/hysteria2.yaml"

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_SUBSCRIPTION_FILE=fail path="* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 fails when service is inactive" {
  prepare_verify_hysteria2_rootfs
  export VPSKIT_TEST_SERVICE_ACTIVE=""

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"HYSTERIA2_SERVICE=fail state=inactive"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 fails when udp 443 is owned by another process" {
  prepare_verify_hysteria2_rootfs
  export VPSKIT_TEST_UDP_443_OWNER=nginx

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"UDP_443_LISTENER=fail expected=hysteria actual=nginx"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 reports unknown listener when ss is unavailable" {
  prepare_verify_hysteria2_rootfs
  export PATH="/usr/bin:/bin"
  export VPSKIT_TEST_UDP_443_OWNER=""
  export VPSKIT_TEST_UDP_443_LISTENERS=""

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"UDP_443_LISTENER=unknown reason=ss_unavailable"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 skips inactive ufw without failing" {
  prepare_verify_hysteria2_rootfs
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_443_UDP=skip status=inactive reason=not_enforced"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=pass"* ]]
}

@test "verify hysteria2 fails when active ufw is missing udp 443" {
  prepare_verify_hysteria2_rootfs
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n22/tcp ALLOW IN Anywhere'

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"UFW_443_UDP=fail status=active rule=missing"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify hysteria2 does not accept v6-only udp 443 ufw rules as an ipv4 pass" {
  prepare_verify_hysteria2_rootfs
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n443/udp (v6) ALLOW IN Anywhere (v6)'

  run bash "${CLI_PATH}" verify hysteria2

  [ "$status" -eq 1 ]
  [[ "$output" == *"UFW_443_UDP=fail status=active rule=missing"* ]]
  [[ "$output" == *"VERIFY_HYSTERIA2=fail"* ]]
}

@test "verify trojan passes for active xray tcp 8443 and subscription" {
  prepare_verify_trojan_rootfs

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"TROJAN_BINARY=pass path="* ]]
  [[ "$output" == *"TROJAN_CONFIG=pass"* ]]
  [[ "$output" == *"TROJAN_SUBSCRIPTION_FILE=pass path="* ]]
  [[ "$output" == *"TROJAN_SERVICE=pass state=active service=xray"* ]]
  [[ "$output" == *"TCP_8443_LISTENER=pass service=xray"* ]]
  [[ "$output" == *"UFW_8443_TCP=pass status=active rule=present"* ]]
  [[ "$output" == *"VLESS_REALITY_PRESERVED=pass tcp_443=bound service=xray"* ]]
  [[ "$output" == *"VERIFY_TROJAN=pass"* ]]
}

@test "verify trojan fails when subscription file is missing" {
  prepare_verify_trojan_rootfs
  rm "${VPSKIT_TEST_ROOT_DIR}/var/lib/vpskit/trojan.yaml"

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_SUBSCRIPTION_FILE=fail path="* ]]
  [[ "$output" == *"VERIFY_TROJAN=fail"* ]]
}

@test "verify trojan fails when xray service is inactive" {
  prepare_verify_trojan_rootfs
  export VPSKIT_TEST_SERVICE_ACTIVE="other.service"

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TROJAN_SERVICE=fail state=inactive"* ]]
  [[ "$output" == *"VERIFY_TROJAN=fail"* ]]
}

@test "verify trojan passes when tcp 8443 is owned by xray" {
  prepare_verify_trojan_rootfs

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"TCP_8443_LISTENER=pass service=xray"* ]]
}

@test "verify trojan fails when tcp 8443 is owned by another process" {
  prepare_verify_trojan_rootfs
  export VPSKIT_TEST_TCP_8443_OWNER=nginx

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"TCP_8443_LISTENER=fail expected=xray actual=nginx"* ]]
  [[ "$output" == *"VERIFY_TROJAN=fail"* ]]
}

@test "verify trojan passes with ipv4 ufw 8443 rule" {
  prepare_verify_trojan_rootfs

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_8443_TCP=pass status=active rule=present"* ]]
}

@test "verify trojan does not accept v6-only ufw 8443 as ipv4 pass" {
  prepare_verify_trojan_rootfs
  export VPSKIT_TEST_UFW_STATUS=$'Status: active\n8443/tcp (v6) ALLOW IN Anywhere (v6)'

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"UFW_8443_TCP=fail status=active rule=missing"* ]]
  [[ "$output" == *"VERIFY_TROJAN=fail"* ]]
}

@test "verify trojan skips inactive ufw without failing" {
  prepare_verify_trojan_rootfs
  export VPSKIT_TEST_UFW_STATUS="Status: inactive"

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 0 ]
  [[ "$output" == *"UFW_8443_TCP=skip status=inactive reason=not_enforced"* ]]
  [[ "$output" == *"VERIFY_TROJAN=pass"* ]]
}

@test "verify trojan fails when vless 443 is not bound by xray" {
  prepare_verify_trojan_rootfs
  export VPSKIT_TEST_TCP_443_OWNER=nginx

  run bash "${CLI_PATH}" verify trojan

  [ "$status" -eq 1 ]
  [[ "$output" == *"VLESS_REALITY_PRESERVED=fail tcp_443=nginx"* ]]
  [[ "$output" == *"VERIFY_TROJAN=fail"* ]]
}
