#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XRAY_SCRIPT="${SCRIPT_DIR}/xray.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# ── [1] Dependencies ─────────────────────

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl wget sed python3-minimal tmate sudo ca-certificates openssl
    touch "$DEP_LOCK_FILE"
    echo "Dependencies installed."
else
    echo "--- [1] System Setup: Dependencies already installed. Skipping. ---"
fi

# ==========================================
# GENERATOR: xray.sh
# ==========================================

generate_xray() {
    local TARGET="$1"
    cat << EOF > "$TARGET"
#!/bin/bash

echo "---[Xray VLESS+Reality Startup Script] ---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="\${CONFIG_DIR}/config.json"

mkdir -p "\$CONFIG_DIR"

# --- Xray Core Installation ---
echo "Checking/Installing Xray (without geodata)..."
bash -c "\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port ---
if [ -z "\${SERVER_PORT:-}" ]; then
    echo ""
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "\$SERVER_PORT" ] ||! echo "\$SERVER_PORT" | grep -qE '^[0-9]+$' \\
          || [ "\$SERVER_PORT" -lt 1 ] || [ "\$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: \$SERVER_PORT"
fi

# --- Hardcoded Reality keys ---

cat > "\$CONFIG_PATH" << JSON
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": "${SERVER_PORT}",
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "grpc",
        "security": "reality",
        "packetEncoding": "xudp",
        "grpcSettings": {
          "serviceName": "game",
          "multiMode": false
        },
        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true
        },
        "realitySettings": {
          "dest": "www.google.com:443",
          "serverNames": ["playstation.net"],
          "privateKey": "oNDJxLaAiXojgAcdW5gzwuQB_gMYL0DXfRnqswUKvTE",
          "shortIds": [""],
          "spiderX": "/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    }
  ]
}
JSON

echo "=========================================================="
echo " VLESS+Reality Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${server_ip}:${SERVER_PORT}?encryption=none&security=reality&sni=playstation.net&fp=chrome&pbk=oVRY8h7Njgw25j3CNhaJVMUys378tTvecrSRbrB3gyo&type=grpc&serviceName=game&mode=gun&packetEncoding"
echo "=========================================================="

echo "Starting Xray..."
xray run -c "\$CONFIG_PATH"
EOF
}

# ==========================================
# [2] Generate proxy scripts
# ==========================================

echo "--- [2] Generating proxy scripts ---"

generate_xray "$XRAY_SCRIPT"
chmod +x "$XRAY_SCRIPT"

# ==========================================
# DONE
# ==========================================

printf "\e[1;36m"
echo " ╔══════════════════════════════════════════╗"
echo " ║ ✅ SETUP COMPLETE ║"
echo " ╠══════════════════════════════════════════╣"
echo " ║ 🌍 Using IP → ${server_ip:-UNKNOWN_IP} "
echo "bash //xray.sh"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
