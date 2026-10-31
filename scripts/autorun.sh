#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT (VLESS + Minimal TCP HTTP)
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

echo "---[ Xray VLESS + Minimal HTTP Startup Script ]---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="${CONFIG_DIR}/config.json"

mkdir -p "$CONFIG_DIR"

# --- Xray Core Installation ---
echo "Installing/Updating Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port Configuration (Kept as 443) ---
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
# STATIC CREDENTIALS
# ==========================================
CLIENT_UUID="00000000-0000-0000-0000-000000000000"
BUG_HOST="www.snapchat.com"

# --- Generate Stripped Xray Config ---
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
            "id": "${CLIENT_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "header": {
            "type": "http",
            "request": {
              "headers": {
                "Host": [
                  "${BUG_HOST}"
                ]
              }
            }
          }
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

echo "=========================================================="
echo " ✅ VLESS + TCP HTTP Link:"
echo ""
echo "vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?path=%2F&security=none&encryption=none&host=${BUG_HOST}&type=tcp&headerType=http#Nour-Snapchat-${SERVER_PORT}"
echo ""
echo "=========================================================="

echo "Starting Xray service..."
nohup xray run -c "$CONFIG_PATH" > /dev/null 2>&1 &
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
