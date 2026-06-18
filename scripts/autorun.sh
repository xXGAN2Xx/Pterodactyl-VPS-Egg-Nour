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
    cat << EOF > "$TARGET"
#!/bin/bash

echo "---[Xray VLESS+Reality Startup Script] ---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="\${CONFIG_DIR}/config.json"

mkdir -p "\$CONFIG_DIR"

# --- Xray Core Installation ---
echo "Checking/Installing Xray..."
bash -c "\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --without-geodata

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
PRIVATE_KEY="oNDJxLaAiXojgAcdW5gzwuQB_gMYL0DXfRnqswUKvTE"
PUBLIC_KEY="oVRY8h7Njgw25j3CNhaJVMUys378tTvecrSRbrB3gyo"

cat > "\$CONFIG_PATH" << JSON
{
  "inbounds": [
    {
      "port": \${SERVER_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e", "flow": "xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "security": "reality",
        "realitySettings": {
          "dest": "www.google.com:443",
          "serverNames": ["ekb.eg", "c.whatsapp.net", "m.facebook.com", "www.messenger.com", "maps.google.com", "www.snapchat.com", "m.youtube.com", "m.tiktok.com", "playstation.net"],
          "privateKey": "\${PRIVATE_KEY}",
          "shortIds": [""]
        }
      }
    }
  ],
  "outbounds": [
    {"protocol": "freedom"}
  ]
}
JSON

echo "=========================================================="
echo " VLESS+Reality Link:"
echo "vless://a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e@${server_ip}:\${SERVER_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=playstation.net&fp=chrome&pbk=\${PUBLIC_KEY}&type=tcp&headerType=none#Nour"
echo "=========================================================="

echo "Starting Xray..."
systemctl enable --now xray
echo "DOne"
echo "Chacking that Xray is started?..."
systemctl status xray
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
