#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NRNET_SCRIPT="${SCRIPT_DIR}/nrnet.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget sudo nano tmate python3-minimal tar ca-certificates procps openssl unzip
    touch "$DEP_LOCK_FILE"
    echo "Dependencies installed."
else
    echo "--- System Setup: Dependencies already installed. Skipping. ---"
    if ! command -v unzip >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y unzip
    fi
fi

generate_nrnet() {
    local TARGET="$1"
    cat << 'EOF' > "$TARGET"
#!/bin/bash

echo "---[ Xray VLESS + REALITY + Vision Startup Script (PRoot) ]---"

SNI="playstation.net"
echo "✅ Active SNI: $SNI"

CONFIG_DIR="/etc/xray"
CONFIG_PATH="${CONFIG_DIR}/config.json"
XRAY_BIN="/usr/local/bin/xray"

mkdir -p "$CONFIG_DIR"

# --- Official Installation & Auto-Update (Without Geodata) ---
install_or_update_xray() {
    echo "🔍 Installing/Updating Xray-core using official script (without geodata)..."

    # Run official Xray install script without geoip.dat and geosite.dat
    # '|| true' prevents exit in PRoot environments where systemd is not running
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata || true

    # Remove any leftover geodata files just in case
    rm -f /usr/local/share/xray/geoip.dat /usr/local/share/xray/geosite.dat \
          /usr/local/bin/geoip.dat /usr/local/bin/geosite.dat 2>/dev/null || true

    if [ -x "$XRAY_BIN" ]; then
        NEW_VER="v$("$XRAY_BIN" version 2>/dev/null | head -n 1 | awk '{print $2}')"
        echo "✅ Xray successfully installed/updated ($NEW_VER)."
    else
        echo "❌ Failed to install Xray."
        exit 1
    fi
}

install_or_update_xray

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

SERVER_IP=$(curl -fsSL4 --max-time 5 api.ipify.org || curl -fsSL4 --max-time 5 ifconfig.me || curl -fsSL4 --max-time 5 icanhazip.com)

CLIENT_UUID="00000000-0000-0000-0000-000000000000"
PRIVATE_KEY="mIR3on3XwYQUqljzpQUbH1E3IDU0xVkUBplnGNljY2A"
PUBLIC_KEY="QUe0db2J_a4YZLnTpIqCG3MxjdmVcxkDYiJFs3dyRxo"

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
        "network": "raw",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "target": "dl.google.com:443",
          "xver": 0,
          "serverNames": [
            "playstation.net",
            "www.snapchat.com",
            "netflix.com",
            "ekb.eg"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [""]
        },
        "sockopt": {
          "tcpNoDelay": true
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "streamSettings": {
        "sockopt": {
          "tcpNoDelay": true
        }
      }
    }
  ]
}
JSON

echo "Validating configuration..."
if ! "$XRAY_BIN" run -test -c "$CONFIG_PATH" > /dev/null 2>&1; then
    echo "❌ Config validation failed, aborting."
    "$XRAY_BIN" run -test -c "$CONFIG_PATH"
    exit 1
fi

echo "=========================================================="
echo " ✅ Xray VLESS + REALITY + Vision Link (${SNI}):"
echo ""
echo "vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&type=tcp&headerType=none#Nour-${SERVER_PORT}"
echo ""
echo "=========================================================="

echo "Stopping any existing Xray process..."
pkill -f "$XRAY_BIN run" 2>/dev/null || true
sleep 1

echo "Starting Xray with nohup..."
nohup "$XRAY_BIN" run -c "$CONFIG_PATH" > /dev/null 2>&1 &
sleep 1

if pgrep -f "$XRAY_BIN run" > /dev/null; then
    echo "✅ Xray is up and running in background."
else
    echo "⚠️ Process failed to stay alive. Log output:"
    cat "$XRAY_LOG" 2>/dev/null || true
    echo "Test manually with: $XRAY_BIN run -c $CONFIG_PATH"
fi
EOF
}

echo "Generating proxy script..."
generate_nrnet "$NRNET_SCRIPT"
chmod +x "$NRNET_SCRIPT"

echo " ╔══════════════════════════════════════════╗"
echo " ║            ✅ SETUP COMPLETE             ║"
echo " ╠══════════════════════════════════════════╣"
echo "Script By Nour Elden (Xray Auto-Update Edition)"
echo "Usage:"
echo "bash $NRNET_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
