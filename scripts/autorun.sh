#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT (sing-box Reality)
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SINGBOX_SCRIPT="${SCRIPT_DIR}/singbox.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies & System Optimization ================

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y \
        curl wget sed python3 sudo grep nano
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
    cat << EOF > "$TARGET"
#!/bin/bash

echo "---[sing-box VLESS+Reality Startup Script] ---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="\${CONFIG_DIR}/config.json"

mkdir -p "\$CONFIG_DIR"

# --- sing-box Installation ---
echo "Checking/Installing sing-box..."
curl -fsSL https://sing-box.app/install.sh | sh

# --- Port ---
if [ -z "\${SERVER_PORT:-}" ]; then
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "\$SERVER_PORT" ] || ! echo "\$SERVER_PORT" | grep -qE '^[0-9]+$' \\
          || [ "\$SERVER_PORT" -lt 1 ] || [ "\$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: \$SERVER_PORT"
fi

# --- Hardcoded Reality keys ---

cat > "\$CONFIG_PATH" << JSON
{
  "log": { "disabled": true },
  "inbounds": [{
    "type": "vless",
    "tag": "vless-in",
    "listen": "0.0.0.0",
    "listen_port": ${SERVER_PORT},
    "users": [{ "uuid": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e", "flow": "xtls-rprx-vision" }],
    "tls": {
      "enabled": true,
      "server_name": ["ekb.eg", "c.whatsapp.net", "m.facebook.com", "www.messenger.com", "maps.google.com", "www.snapchat.com", "pubgmobile.com", "m.youtube.com", "m.tiktok.com", "playstation.net"],
      "reality": {
        "enabled": true,
        "handshake": { "server": "www.google.com", "server_port": 443 },
        "private_key": "oNDJxLaAiXojgAcdW5gzwuQB_gMYL0DXfRnqswUKvTE",
        "short_id": [""]
      }
    }
  }],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
JSON

echo "=========================================================="
echo " VLESS+Reality Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@\${SERVER_IP}:\${SERVER_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=playstation.net&fp=chrome&pbk=oVRY8h7Njgw25j3CNhaJVMUys378tTvecrSRbrB3gyo&type=tcp#Nour"
echo "=========================================================="

echo "Starting sing-box..."
systemctl enable --now sing-box

echo "Done"
echo "Checking that sing-box is started?..."
systemctl status sing-box
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
echo " ║ ✅  SETUP COMPLETE                        ║"
echo " ╠══════════════════════════════════════════╣"
echo "bash $SINGBOX_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
