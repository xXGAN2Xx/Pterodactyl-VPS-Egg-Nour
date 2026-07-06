#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XRAY_SCRIPT="${SCRIPT_DIR}/xray.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies ================

if [! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget tmate python3-minimal
    touch "$DEP_LOCK_FILE"
else
    echo "--- [1] Dependencies already installed. Skipping. ---"
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
REALITY_PORT_FILE="${CONFIG_DIR}/.reality_port"

mkdir -p "$CONFIG_DIR"

# --- Xray Core Installation ---
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port for HTTP (always ask) ---
unset SERVER_PORT
read -rp "SERVER_PORT (for VLESS HTTP): " SERVER_PORT
while! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
    echo "❌ Invalid port. Enter 1-65535:"
    read -rp "SERVER_PORT: " SERVER_PORT
done
echo "✅ Using HTTP port: $SERVER_PORT"

# --- Load saved REALITY_PORT if exists ---
if [ -f "$REALITY_PORT_FILE" ]; then
    source "$REALITY_PORT_FILE"
    echo "✓ Found saved REALITY_PORT=$REALITY_PORT"
fi

# --- Port for REALITY (save once) ---
if [ -z "${REALITY_PORT:-}" ] || [ "$REALITY_PORT" -eq "$SERVER_PORT" ] 2>/dev/null; then
    [ "$REALITY_PORT" -eq "$SERVER_PORT" ] 2>/dev/null && echo "⚠ Saved REALITY_PORT conflicts with HTTP port, asking again..."
    unset REALITY_PORT
    read -rp "REALITY_PORT (for VLESS Reality TCP): " REALITY_PORT
    while! [[ "$REALITY_PORT" =~ ^[0-9]+$ ]] || [ "$REALITY_PORT" -lt 1 ] || [ "$REALITY_PORT" -gt 65535 ] || [ "$REALITY_PORT" -eq "$SERVER_PORT" ]; do
        echo "❌ Invalid. Enter 1-65535 and different from $SERVER_PORT:"
        read -rp "REALITY_PORT: " REALITY_PORT
    done
    echo "REALITY_PORT=${REALITY_PORT}" > "$REALITY_PORT_FILE"
    chmod 600 "$REALITY_PORT_FILE"
    echo "💾 Saved REALITY_PORT for future runs"
else
    echo "✅ Using saved Reality port: $REALITY_PORT"
fi

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
      "settings": {"clients": [{"id": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e"}], "decryption": "none"},
      "streamSettings": {"network": "tcp", "security": "none", "tcpSettings": {"header": {"type": "http"}}}
    },
    {
      "port": ${REALITY_PORT},
      "protocol": "vless",
      "settings": {"clients": [{"id": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e", "flow": "xtls-rprx-vision"}], "decryption": "none"},
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": [
            "playstation.net",
            "ekb.eg"
          ],
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
echo " 1) VLESS HTTP:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${SERVER_IP}:${SERVER_PORT}?encryption=none&security=none&type=tcp&headerType=http&host=playstation.net#Nour-HTTP"
echo ""
echo " 2) VLESS REALITY:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${SERVER_IP}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=playstation.net&fp=chrome&pbk=7ZSGpEACOsc5XXADnkNH4KUgLJxG4JTFHi1pXBkHt2c&type=tcp#Nour-Reality"
echo "=========================================================="

systemctl enable --now xray
systemctl restart xray
systemctl status xray --no-pager
EOF
}

echo "--- [2] Generating xray.sh ---"
generate_xray "$XRAY_SCRIPT"
chmod +x "$XRAY_SCRIPT"

echo "✅ DONE - run: bash $XRAY_SCRIPT"
