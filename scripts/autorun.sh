generate_singbox() {
    local TARGET="$1"
    # Using evaluated heredoc to bake the existing SERVER_IP into the script
    cat << EOF > "$TARGET"
#!/bin/bash

echo "---[Sing-box VLESS+TCP (Plain HTTP Obfuscation) Startup Script] ---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="\${CONFIG_DIR}/config.json"

mkdir -p "\$CONFIG_DIR"

# --- Sing-box Core Installation ---
echo "Checking/Installing Sing-box..."
curl -fsSL https://sing-box.app/install.sh | sh

# --- Port ---
if [ -z "\${SERVER_PORT:-}" ]; then
    echo ""
    echo "⚠️  SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "\$SERVER_PORT" ] || ! echo "\$SERVER_PORT" | grep -qE '^[0-9]+$' \\
          ||[ "\$SERVER_PORT" -lt 1 ] || [ "\$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: \$SERVER_PORT"
fi

cat > "\$CONFIG_PATH" << JSON
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds":[
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": \${SERVER_PORT},
      "users":[
        {
          "name": "user",
          "uuid": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e"
        }
      ],
      "transport": {
        "type": "http",
        "path": "/nour"
      }
    }
  ],
  "outbounds":[
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
JSON

echo ""
echo "=========================================================="
echo "  VLESS+TCP (Plain HTTP Obfuscation) Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${server_ip}:\${SERVER_PORT}?encryption=none&security=none&type=tcp&headerType=http&host=playstation.net&path=/nour#Nour"
echo "=========================================================="
echo ""

echo "Starting Sing-box..."
sing-box run -c "\$CONFIG_PATH"
EOF
}
