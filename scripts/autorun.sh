#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT - GAMING OPTIMIZED
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XRAY_SCRIPT="${SCRIPT_DIR}/xray.sh"
DEP_LOCK_FILE="/etc/os_deps_installed"

# ── [1] Dependencies ─────────────────────
if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl wget grep sed ca-certificates openssl
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
    cat << 'EOF' > "$TARGET"
#!/bin/bash
echo "---[Xray VLESS+Reality Startup Script]---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="${CONFIG_DIR}/config.json"
mkdir -p "$CONFIG_DIR"

# --- Kernel tuning for gaming ---
sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1

# --- Xray Core Installation ---
echo "Checking/Installing Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port ---
if [ -z "${SERVER_PORT:-}" ]; then
    echo ""
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "$SERVER_PORT" ] || ! echo "$SERVER_PORT" | grep -qE '^[0-9]+$' \
          || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: $SERVER_PORT"
fi

# --- Auto detect IP ---
SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 icanhazip.com || hostname -I | awk '{print $1}')

# --- Hardcoded Reality keys and UUID ---
UUID="9f2b4b10-6818-492e-a157-d5131d450c7b"
PRIVATE_KEY="M4cZLR81ErNfxnG1fAnNUIATs_UXqe6HR78wINhH7RA"
PUBLIC_KEY="ioE61VC3V30U7IdRmQ3bjhOq2ij9tPhVIgAD4JZ4YRY"
SHORT_ID=""

DEST="playstation.net:443"
SNI="playstation.net"

# --- Write VALID config.json with UseIP routing ---
cat > "$CONFIG_PATH" <<JSON
{
  "log": {
    "loglevel": "none"
  },
  "routing": {
    "domainStrategy": "UseIP"
  },
  "inbounds": [
    {
      "port": ${SERVER_PORT},
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "packetEncoding": "xudp"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "sockopt": {
          "tcpFastOpen": true,
          "tcpKeepAliveIdle": 30,
          "mark": 255
        },
        "realitySettings": {
          "show": false,
          "dest": "${DEST}",
          "xver": 0,
          "serverNames": [
            "${SNI}",
            "www.playstation.net",
            "ekb.eg"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ],
          "spiderX": "/"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "tag": "direct"
    }
  ]
}
JSON

echo "=========================================================="
echo " VLESS+Reality Link (CORRECT):"
echo "vless://${UUID}@${SERVER_IP}:${SERVER_PORT}?type=tcp&security=reality&encryption=none&flow=xtls-rprx-vision&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F&packetEncoding=xudp#Nour"
echo "=========================================================="
echo "IP: ${SERVER_IP} | Port: ${SERVER_PORT} | UUID: ${UUID}"
echo "Starting Xray..."
xray run -c "$CONFIG_PATH"
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
echo " ║ ✅ SETUP COMPLETE - GAMING MODE          ║"
echo " ╠══════════════════════════════════════════╣"
echo "bash $XRAY_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
