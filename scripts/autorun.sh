#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XRAY_SCRIPT="${SCRIPT_DIR}/xray.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies & System Optimization ================

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y \
        curl wget tmate grep sudo python3-minimal
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

echo "---[Xray VLESS Multi-Inbound Startup Script] ---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="${CONFIG_DIR}/config.json"
PORTS_FILE="${CONFIG_DIR}/ports.env"

mkdir -p "$CONFIG_DIR"

# --- Load Saved Reality Port ---
if [ -f "$PORTS_FILE" ]; then
    [ -z "${REALITY_PORT:-}" ] && REALITY_PORT=$(grep -m1 '^REALITY_PORT=' "$PORTS_FILE" | cut -d= -f2)
fi

# --- Xray Core Installation ---
echo "Checking/Installing Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port for HTTP ---
if [ -z "${SERVER_PORT:-}" ]; then
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT (for VLESS HTTP): " SERVER_PORT
    while [ -z "$SERVER_PORT" ] ||! echo "$SERVER_PORT" | grep -qE '^[0-9]+$' \
          || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using HTTP port: $SERVER_PORT"
fi

# --- Port for REALITY ---
if [ -z "${REALITY_PORT:-}" ]; then
    echo "⚠ REALITY_PORT is not set!"
    read -rp "REALITY_PORT (for VLESS Reality TCP): " REALITY_PORT
fi
while [ -z "$REALITY_PORT" ] ||! echo "$REALITY_PORT" | grep -qE '^[0-9]+$' \
      || [ "$REALITY_PORT" -lt 1 ] || [ "$REALITY_PORT" -gt 65535 ] || [ "$REALITY_PORT" -eq "$SERVER_PORT" ]; do
    echo "❌ Invalid port, or same as SERVER_PORT ($SERVER_PORT). Enter a different one:"
    read -rp "REALITY_PORT: " REALITY_PORT
done
echo "✅ Using Reality port: $REALITY_PORT"

# --- Save Reality Port for Next Run ---
cat > "$PORTS_FILE" << PORTSEOF
REALITY_PORT=${REALITY_PORT}
PORTSEOF

# --- Fetch Server IP ---
SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 api.ipify.org)

# --- Generate Xray Config ---
cat > "$CONFIG_PATH" << JSON
{
  "log": {"loglevel": "none"},
  "inbounds": [
    {
      "port": ${SERVER_PORT},
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
        "network": "tcp",
        "security": "none",
        "tcpSettings": {
          "header": {
            "type": "http"
          }
        }
      }
    },
    {
      "port": ${REALITY_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e",
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
          "serverNames": ["ekb.eg", "c.whatsapp.net", "m.facebook.com", "www.messenger.com", "maps.google.com", "www.snapchat.com", "playstation.net"],
          "privateKey": "KJnLYyUW_AMYhoKdCwH4ZS8bq5XlcfoIpwSOlanWD0c",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
JSON

echo "=========================================================="
echo " 1) VLESS RAW HTTP Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${SERVER_IP}:${SERVER_PORT}?encryption=none&security=none&type=tcp&headerType=http&host=playstation.net#Nour-HTTP"
echo ""
echo " 2) VLESS REALITY TCP Link (no shortId):"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${SERVER_IP}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=playstation.net&fp=chrome&pbk=7ZSGpEACOsc5XXADnkNH4KUgLJxG4JTFHi1pXBkHt2c&type=tcp#Nour-Reality"
echo "=========================================================="

echo "Starting Xray..."
xray run -c "$CONFIG_PATH" > /dev/null 2>&1 &
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

echo " ╔══════════════════════════════════════════╗"
echo " ║ ✅ SETUP COMPLETE ║"
echo " ╠══════════════════════════════════════════╣"
echo "bash $XRAY_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
echo '[::] [/]: Done (.s)! For help, type "help"'
