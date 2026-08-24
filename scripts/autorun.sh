#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT (VLESS + REALITY + Vision)
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NRNET_SCRIPT="${SCRIPT_DIR}/nrnet.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies & System Optimization ================

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget sudo python3-minimal
    touch "$DEP_LOCK_FILE"
    echo "Dependencies installed."
else
    echo "--- [1] System Setup: Dependencies already installed. Skipping. ---"
fi

# ==========================================
# GENERATOR: nrnet.sh
# ==========================================

generate_nrnet() {
    local TARGET="$1"
    cat << 'EOF' > "$TARGET"
#!/bin/bash

echo "---[ Xray VLESS + REALITY + Vision Startup Script ]---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="${CONFIG_DIR}/config.json"

mkdir -p "$CONFIG_DIR"

# --- Xray Core Installation ---
echo "Installing/Updating Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port Configuration (Default: 443 for REALITY) ---
if [ -z "${SERVER_PORT:-}" ]; then
    read -rp "SERVER_PORT (Recommended 443) [443]: " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-443}
fi
while ! echo "$SERVER_PORT" | grep -qE '^[0-9]+$' \
      || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
    echo "❌ Invalid port. Enter a number between 1 and 65535:"
    read -rp "SERVER_PORT: " SERVER_PORT
done
echo "✅ Using Port: $SERVER_PORT"

# --- Fetch Server IP ---
SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 api.ipify.org)

# ==========================================
# STATIC CREDENTIALS & KEYS
# ==========================================
CLIENT_UUID="a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e"
PRIVATE_KEY="mIR3on3XwYQUqljzpQUbH1E3IDU0xVkUBplnGNljY2A"
PUBLIC_KEY="QUe0db2J_a4YZLnTpIqCG3MxjdmVcxkDYiJFs3dyRxo"

# --- Generate Xray Config ---
cat > "$CONFIG_PATH" << JSON
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${SERVER_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${CLIENT_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": [
          "ekb.eg",
          "c.whatsapp.net",
          "m.facebook.com",
          "www.messenger.com",
          "maps.google.com",
          "www.snapchat.com",
          "m.youtube.com",
          "m.tiktok.com",
          "playstation.net"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            ""
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
JSON

echo "Validating configuration..."
if ! xray -test -config "$CONFIG_PATH"; then
    echo "❌ Config validation failed, aborting."
    exit 1
fi

VLESS_LINK="vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?security=reality&encryption=none&pbk=${PUBLIC_KEY}&headerType=none&fp=chrome&spx=%2F&type=tcp&flow=xtls-rprx-vision&sni=playstation.net&sid=#Nour-REALITY"

echo "=========================================================="
echo " ✅ VLESS + REALITY + Vision Link:"
echo ""
echo "${VLESS_LINK}"
echo ""
echo "=========================================================="

echo "Starting Xray service..."
xray run -config "$CONFIG_PATH" > /dev/null 2>&1 &
echo "Xray is up and running."
EOF
}

# ==========================================
# [2] Generate proxy scripts
# ==========================================

echo "--- [2] Generating proxy scripts ---"

generate_nrnet "$NRNET_SCRIPT"
chmod +x "$NRNET_SCRIPT"

# ==========================================
# DONE
# ==========================================

echo " ╔══════════════════════════════════════════╗"
echo " ║            ✅ SETUP COMPLETE             ║"
echo " ╠══════════════════════════════════════════╣"
echo "Script By Nour Elden"
echo "Run:"
echo "bash $NRNET_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
