```bash
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
    apt-get install -y --no-install-recommends \
        curl wget sed python3-minimal tmate sudo ca-certificates openssl grep
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

echo "---[Xray Hysteria2 Startup Script] ---"

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_PATH="\${CONFIG_DIR}/config.json"
CERT_DIR="/usr/local/etc/xray/cert"

mkdir -p "\$CONFIG_DIR"
mkdir -p "\$CERT_DIR"

# --- Xray Core Installation ---
echo "Checking/Installing Xray..."
bash -c "\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# --- Port ---
if [ -z "\${SERVER_PORT:-}" ]; then
    echo ""
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "\$SERVER_PORT" ] || ! echo "\$SERVER_PORT" | grep -qE '^[0-9]+$' \\
          || [ "\$SERVER_PORT" -lt 1 ] || [ "\$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter a number between 1 and 65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: \$SERVER_PORT"
fi

# --- Generate Self-Signed TLS Certificate ---
CERT_FILE="\${CERT_DIR}/server.crt"
KEY_FILE="\${CERT_DIR}/server.key"

if [ ! -f "\$CERT_FILE" ] || [ ! -f "\$KEY_FILE" ]; then
    echo "Generating self-signed TLS certificate..."
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
        -x509 -sha256 -days 3650 -nodes \
        -out "\$CERT_FILE" -keyout "\$KEY_FILE" \
        -subj "/CN=google.com" 2>/dev/null
    echo "✅ Certificate generated."
else
    echo "✅ Certificate already exists. Skipping."
fi

# --- Hysteria2 Auth Password ---
HY2_PASSWORD="NourHysteria2"

# --- Bandwidth (server-side limit) ---
UP_BW="100 mbps"
DOWN_BW="100 mbps"

cat > "\$CONFIG_PATH" << JSON
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": \${SERVER_PORT},
      "listen": "0.0.0.0",
      "protocol": "hysteria2",
      "settings": {
        "password": "\${HY2_PASSWORD}"
      },
      "streamSettings": {
        "network": "hysteria2",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "\${CERT_FILE}",
              "keyFile": "\${KEY_FILE}"
            }
          ]
        },
        "hysteria2Settings": {
          "up": "\${UP_BW}",
          "down": "\${DOWN_BW}"
        },
        "sockopt": {
          "udpFastOpen": true
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy": "UseIPv4"
      }
    }
  ]
}
JSON

SERVER_IP=\$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

echo "=========================================================="
echo " Hysteria2 Link:"
echo "hysteria2://\${HY2_PASSWORD}@\${SERVER_IP}:\${SERVER_PORT}?insecure=1&sni=google.com#Nour"
echo "=========================================================="

echo "Starting Xray..."
xray run -c "\$CONFIG_PATH"
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

printf "\e[1;36m"
echo " ╔══════════════════════════════════════════╗"
echo " ║ ✅ SETUP COMPLETE                        ║"
echo " ╠══════════════════════════════════════════╣"
echo "bash $XRAY_SCRIPT"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
```
