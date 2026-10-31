#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT (VLESS + TLS + Vision + SAN Fix)
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NRNET_SCRIPT="${SCRIPT_DIR}/nrnet.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# == [1] Dependencies & System Optimization ================

if [ ! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y curl wget sudo nano tmate tar procps openssl
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

echo "---[ sing-box VLESS + TLS + XTLS-Vision Startup Script ]---"

CONFIG_DIR="/etc/sing-box"
CONFIG_PATH="${CONFIG_DIR}/config.json"
CERT_PATH="${CONFIG_DIR}/cert.pem"
KEY_PATH="${CONFIG_DIR}/key.pem"

mkdir -p "$CONFIG_DIR"

# --- Stop conflicting instances and free ports (Safe for PRoot) ---
pkill -f xray 2>/dev/null || true
pkill -f sing-box 2>/dev/null || true

# --- sing-box Core Installation ---
echo "Installing/Updating sing-box..."
curl -fsSL https://sing-box.app/install.sh | sh

# --- Port Configuration (Default: 25633) ---
if [ -z "${SERVER_PORT:-}" ]; then
    read -rp "SERVER_PORT [25633]: " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-25633}
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
# CREDENTIALS & TLS CERTIFICATE (WITH SAN FIX)
# ==========================================
CLIENT_UUID="00000000-0000-0000-0000-000000000000"
SNI_HOST="www.snapchat.com"

echo "Generating TLS certificate with proper SAN for ${SNI_HOST}..."
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
  -keyout "$KEY_PATH" -out "$CERT_PATH" -days 3650 \
  -subj "/CN=${SNI_HOST}" \
  -addext "subjectAltName=DNS:${SNI_HOST},DNS:snapchat.com" > /dev/null 2>&1

# --- Generate sing-box VLESS TLS + Vision Config ---
cat > "$CONFIG_PATH" << JSON
{
  "log": {
    "disabled": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-tls-in",
      "listen": "0.0.0.0",
      "listen_port": ${SERVER_PORT},
      "users": [
        {
          "name": "Nour",
          "uuid": "${CLIENT_UUID}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "certificate_path": "${CERT_PATH}",
        "key_path": "${KEY_PATH}"
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
echo " ✅ VLESS + TLS + Vision Link:"
echo ""
echo "vless://${CLIENT_UUID}@${SERVER_IP}:${SERVER_PORT}?security=tls&encryption=none&flow=xtls-rprx-vision&sni=${SNI_HOST}&allowInsecure=1&type=tcp#Nour-${SERVER_PORT}"
echo ""
echo "=========================================================="

echo "Starting sing-box service..."
nohup sing-box run -c "$CONFIG_PATH" > /dev/null 2>&1 &
sleep 1

if ps aux | grep -v grep | grep -q "sing-box"; then
    echo "✅ sing-box VLESS TLS + Vision is up and running."
else
    echo "❌ Failed to start. Try running 'sing-box run -c $CONFIG_PATH' to see the issue."
fi
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
