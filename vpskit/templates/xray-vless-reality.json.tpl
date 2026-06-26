{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-vision",
      "listen": "0.0.0.0",
      "port": __XRAY_PORT__,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "__UUID__",
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
          "dest": "__REALITY_DEST__",
          "xver": 0,
          "serverNames": [
            "__REALITY_SERVER_NAME__"
          ],
          "privateKey": "__PRIVATE_KEY__",
          "shortIds": [
            "__SHORT_ID__"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "blocked",
      "protocol": "blackhole"
    }
  ]
}
