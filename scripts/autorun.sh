#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SINGBOX_SCRIPT="${SCRIPT_DIR}/singbox.sh"

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
# GENERATOR: singbox.sh
# ==========================================

generate_singbox() {
    local TARGET="$1"
    cat << 'EOF' > "$TARGET"
#!/bin/bash

echo "---[Sing-box VLESS HTTP Startup Script]---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="${CONFIG_DIR}/config.json"

mkdir -p "$CONFIG_DIR"

# --- sing-box Core Installation ---
echo "Checking/Installing sing-box..."
curl -fsSL https://sing-box.app/install.sh | sh

# --- Port for VLESS ---
if [ -z "${SERVER_PORT:-}" ]; then
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT (for VLESS HTTP): " SERVER_PORT
fi
while [ -z "$SERVER_PORT" ] || ! echo "$SERVER_PORT" | grep -qE '^[0-9]+$' \
      || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
    echo "❌ Invalid port. Enter a number between 1 and 65535:"
    read -rp "SERVER_PORT: " SERVER_PORT
done
echo "✅ Using VLESS port: $SERVER_PORT"

# --- Fetch Server IP ---
SERVER_IP=$(curl -s4 ifconfig.me || curl -s4 api.ipify.org)

# --- Generate sing-box Config ---
cat > "$CONFIG_PATH" << JSON
{
  "log": {
    "disabled": true,
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${SERVER_PORT},
      "users": [
        {
          "uuid": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e",
          "flow": ""
        }
      ],
      "transport": {
        "type": "http",
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
echo " VLESS RAW+HTTP Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${SERVER_IP}:${SERVER_PORT}?encryption=none&security=none&type=http&host=playstation.net#Nour-VLESS-HTTP"
echo "=========================================================="

echo "Starting sing-box..."
sing-box run -c "$CONFIG_PATH" > /dev/null 2>&1 &
EOF
}

# ==========================================
# [2] Generate proxy scripts
# ==========================================

echo "--- [2] Generating proxy scripts ---"

generate_singbox "$SINGBOX_SCRIPT"
chmod +x "$SINGBOX_SCRIPT"

# ==========================================
# DONE
# ==========================================

echo " ╔══════════════════════════════════════════╗"
echo " ║            ✅ SETUP COMPLETE             ║"
echo " ╠══════════════════════════════════════════╣"
echo "bash $SINGBOX_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
echo '[::] [/]: Done (.s)! For help, type "help"'
