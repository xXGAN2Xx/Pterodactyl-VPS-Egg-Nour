#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NRNET_SCRIPT="${SCRIPT_DIR}/nrnet.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget sudo nano tmate python3-minimal tar ca-certificates procps unzip
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

# --- Auto-Update & Installation Check ---
install_or_update_xray() {
    echo "🔍 Checking for Xray-core updates..."

    # Get Local Version
    if [ -x "$XRAY_BIN" ]; then
        LOCAL_VER="v$("$XRAY_BIN" version 2>/dev/null | head -n 1 | awk '{print $2}')"
    else
        LOCAL_VER="Not Installed"
    fi

    # Get Latest Version via GitHub Redirect (Avoids GitHub API rate-limits)
    LATEST_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/XTLS/Xray-core/releases/latest 2>/dev/null)
    LATEST_VER="${LATEST_URL##*/}"

    if [ -z "$LATEST_VER" ] || [[ "$LATEST_VER" != v* ]]; then
        echo "⚠️ Could not fetch latest version from GitHub."
        if [ "$LOCAL_VER" != "Not Installed" ]; then
            echo "➡️ Proceeding with installed version ($LOCAL_VER)."
            return 0
        fi
        LATEST_Download_Path="latest/download"
    else
        echo "📌 Installed: $LOCAL_VER | Latest: $LATEST_VER"
        if [ "$LOCAL_VER" = "$LATEST_VER" ]; then
            echo "✅ Xray is already on the latest version ($LOCAL_VER)."
            return 0
        fi
        echo "⬆️ New version available! Updating Xray to $LATEST_VER..."
        LATEST_Download_Path="download/${LATEST_VER}"
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) XRAY_ARCH="64" ;;
        aarch64|arm64) XRAY_ARCH="arm64-v8a" ;;
        armv7*|armv8l) XRAY_ARCH="arm32-v7a" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    TMP_DIR=$(mktemp -d)
    if curl -fsSL "https://github.com/XTLS/Xray-core/releases/${LATEST_Download_Path}/Xray-linux-${XRAY_ARCH}.zip" -o "${TMP_DIR}/xray.zip"; then
        unzip -q "${TMP_DIR}/xray.zip" -d "$TMP_DIR"
        install -m 755 "${TMP_DIR}/xray" "$XRAY_BIN"
        install -m 644 "${TMP_DIR}/geoip.dat" "/usr/local/bin/geoip.dat" 2>/dev/null || true
        install -m 644 "${TMP_DIR}/geosite.dat" "/usr/local/bin/geosite.dat" 2>/dev/null || true
        rm -rf "$TMP_DIR"
        NEW_VER="v$("$XRAY_BIN" version 2>/dev/null | head -n 1 | awk '{print $2}')"
        echo "✅ Xray successfully updated/installed ($NEW_VER)."
    else
        rm -rf "$TMP_DIR"
        echo "❌ Failed to download Xray."
        [ -x "$XRAY_BIN" ] || exit 1
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

SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 api.ipify.org)

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
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "dl.google.com:443",
          "xver": 0,
          "serverNames": [
            "playstation.net",
            "www.snapchat.com",
            "ekb.eg",
            "netflix.com"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            ""
          ]
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
      "tag": "direct",
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

echo "Starting Xray with nohup..."
nohup "$XRAY_BIN" run -c "$CONFIG_PATH" > /dev/null 2>&1 &
sleep 1

if pgrep -f "$XRAY_BIN run" > /dev/null; then
    echo "✅ Xray is up and running in background."
else
    echo "⚠️ Process failed to stay alive. Test manually with: $XRAY_BIN run -c $CONFIG_PATH"
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
