#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT (sing-box VLESS + HTTP)
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NRNET_SCRIPT="${SCRIPT_DIR}/nrnet.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies & System Optimization ================

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget sudo nano tmate tar procps
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

echo "---[ sing-box VLESS + HTTP Startup Script ]---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="${CONFIG_DIR}/config.json"

mkdir -p "$CONFIG_DIR"

# --- Stop conflicting instances and free ports (Safe for PRoot) ---
pkill -f xray 2>/dev/null || true
pkill -f sing-box 2>/dev/null || true

# --- sing-box Core Installation ---
echo "Installing/Updating sing-box..."
curl -fsSL https://sing-box.app/install.sh | sh

# --- Port Configuration (Preserved, Default: 443) ---
if [ -z "${SERVER_PORT:-}" ]; then
    read -rp "SERVER_PORT [443]: " SERVER_PORT
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
# CREDENTIALS & SNI/HOST SETTINGS
# ==========================================
CLIENT_UUID="00000000-0000-0000-0000-000000000000"
SNI_HOST="www.snapchat.com"

# --- Generate sing-box Config ---
cat > "$CONFIG_PATH" << JSON
{
  "log": {
    "level": "warn"
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "0.0.0.0",
      "listen_port": ${SERVER_PORT},
      "users": [
        {
          "name": "Nour",
          "uuid": "${CLIENT_UUID}"
        }
      ],
      "transport": {
        "type": "http",
        "host": [
          "${SNI_HOST}"
        ],
        "path": "/"
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
echo " ✅ VLESS + HTTP Link:"
echo ""
echo "vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?path=%2F&security=none&encryption=none&host=${SNI_HOST}&type=http&sni=${SNI_HOST}#Nour-${SERVER_PORT}"
echo ""
echo "=========================================================="

echo "Starting sing-box service..."
nohup sing-box run -c "$CONFIG_PATH" > /dev/null 2>&1 &
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
