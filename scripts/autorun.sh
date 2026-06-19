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
        curl wget sed python3 sudo grep
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

echo "---[Xray VLESS RAW HTTP Startup Script] ---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="${CONFIG_DIR}/config.json"

mkdir -p "$CONFIG_DIR"

# --- Xray Core Installation ---
echo "Checking/Installing Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

# --- Port ---
if [ -z "${SERVER_PORT:-}" ]; then
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "$SERVER_PORT" ] || ! echo "$SERVER_PORT" | grep -qE '^[0-9]+$' \
          || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: $SERVER_PORT"
fi

# --- Fetch Server IP for the link ---
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
        "network": "raw",
        "security": "none",
        "rawSettings": {
          "header": {
            "type": "http"
          }
        }
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
JSON

echo "=========================================================="
echo " VLESS RAW HTTP Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${SERVER_IP}:${SERVER_PORT}?encryption=none&security=none&type=raw&headerType=http#Nour"
echo "=========================================================="

echo "Starting Xray..."
systemctl enable --now xray
systemctl restart xray
systemctl status xray --no-pager
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
echo " ║ ✅  SETUP COMPLETE                        ║"
echo " ╠══════════════════════════════════════════╣"
echo "bash $XRAY_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
