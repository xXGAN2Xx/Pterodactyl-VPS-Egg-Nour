#!/bin/bash

# ==========================================
#        MASTER SETUP SCRIPT
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SINGBOX_SCRIPT="${SCRIPT_DIR}/sing-box.sh"

# Detect Public IP
SERVER_IP=$(curl -s https://api.ipify.org || echo "YOUR_IP")

DEP_LOCK_FILE="/etc/os_deps_installed"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Run as root." >&2
    exit 1
fi

# ── [1] Dependencies ─────────────────────

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl wget sed python3-minimal tmate sudo ca-certificates
    touch "$DEP_LOCK_FILE"
    echo "Dependencies installed."
else
    echo "--- [1] System Setup: Dependencies already installed. Skipping. ---"
fi

# ==========================================
#   GENERATOR: sing-box.sh
# ==========================================

generate_singbox() {
    local TARGET="$1"
    cat << EOF > "$TARGET"
#!/bin/bash

echo "--- [Sing-box VLESS+HTTP (Empty Host) Startup Script] ---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="\${CONFIG_DIR}/config.json"

mkdir -p "\$CONFIG_DIR"

# --- Sing-box Core Installation ---
echo "Checking/Installing Sing-box..."
if ! command -v sing-box &> /dev/null; then
    bash -c "\$(curl -fsSL https://sing-box.app/install.sh)" install
fi

# --- Port ---
if [ -z "\${SERVER_PORT:-}" ]; then
    echo ""
    echo "⚠️  SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "\$SERVER_PORT" ] || ! echo "\$SERVER_PORT" | grep -qE '^[0-9]+$' \
          || [ "\$SERVER_PORT" -lt 1 ] || [ "\$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: \$SERVER_PORT"
fi

UUID="a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e"

cat > "\$CONFIG_PATH" << JSON
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": \${SERVER_PORT},
      "users": [
        {
          "name": "user",
          "uuid": "\${UUID}"
        }
      ],
      "transport": {
        "type": "http",
        "host": [],
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

echo ""
echo "=========================================================="
echo "  VLESS+HTTP (Empty Host) Link:"
echo "  vless://\${UUID}@${SERVER_IP}:\${SERVER_PORT}?encryption=none&security=none&type=http&host=&path=/#Nour"
echo "=========================================================="
echo ""

echo "Starting Sing-box..."
sing-box run -c "\$CONFIG_PATH"
EOF
}

# ==========================================
#   [2] Generate proxy scripts
# ==========================================

echo "--- [2] Generating proxy scripts ---"

generate_singbox "$SINGBOX_SCRIPT"
chmod +x "$SINGBOX_SCRIPT"

# ==========================================
#        DONE
# ==========================================

echo ""
printf "\e[1;36m"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║         ✅  SETUP COMPLETE               ║"
echo "  ╠══════════════════════════════════════════╣"
echo "  ║                                          ║"
echo "  ║  🌍  Using IP         →  $SERVER_IP"
echo "  ║  ⚙️  Sing-box Config  →  Ready (HTTP/Empty)║"
echo "  ║                                          ║"
echo "  ╠══════════════════════════════════════════╣"
echo "  ║  ▶  To start Sing-box:                   ║"
echo "  ║  bash $SINGBOX_SCRIPT                    ║"
echo "  ╚══════════════════════════════════════════╝"
printf "\e[0m\n"
