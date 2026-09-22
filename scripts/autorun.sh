#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT (sing-box VLESS + REALITY + Vision)
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NRNET_SCRIPT="${SCRIPT_DIR}/nrnet.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies & System Optimization ================

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget sudo nano tmate python3-minimal
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

echo "---[ sing-box VLESS + REALITY + Vision Startup Script ]---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="${CONFIG_DIR}/config.json"

mkdir -p "$CONFIG_DIR"

# --- Official sing-box Installation ---
echo "Installing/Updating sing-box via official script..."
curl -fsSL https://sing-box.app/install.sh | bash

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

# --- Generate sing-box Config ---
cat > "$CONFIG_PATH" << JSON
{
  "log": {
    "disabled": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": ${SERVER_PORT},
      "users": [
        {
          "uuid": "${CLIENT_UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "playstation.net",
        "insecure": true,
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.google.com",
            "server_port": 443
          },
          "private_key": "${PRIVATE_KEY}",
          "short_id": [
            ""
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
JSON

echo "Validating configuration..."
if ! sing-box check -c "$CONFIG_PATH"; then
    echo "❌ Config validation failed, aborting."
    exit 1
fi

echo "=========================================================="
echo " ✅ VLESS + REALITY + Vision Link:"
echo ""
echo "vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=playstation.net&fp=chrome&pbk=${PUBLIC_KEY}&allowInsecure=1&type=tcp&headerType=none#Nour-${SERVER_PORT}"
echo ""
echo "=========================================================="

echo "Starting sing-box service..."
# Stop any existing sing-box instance
pkill -f "sing-box run" 2>/dev/null || true

# Run sing-box in background
sing-box run -c "$CONFIG_PATH" > /dev/null 2>&1 &
echo "sing-box is up and running."
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
