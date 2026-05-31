#!/bin/bash

# ==========================================
# MASTER SETUP SCRIPT - TUIC v5 Cloudflare
# ==========================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TUIC_SCRIPT="${SCRIPT_DIR}/tuic.sh"

DEP_LOCK_FILE="/etc/os_deps_installed"

# ── [1] Dependencies ─────────────────────

if [! -f "$DEP_LOCK_FILE" ]; then
    echo "--- [1] First Time Setup: Updating & Installing Dependencies ---"
    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl wget sed python3-minimal tmate sudo ca-certificates openssl jq uuid-runtime
    touch "$DEP_LOCK_FILE"
    echo "Dependencies installed."
else
    echo "--- [1] System Setup: Dependencies already installed. Skipping. ---"
fi

# ==========================================
# GENERATOR: tuic.sh
# ==========================================

generate_tuic() {
    local TARGET="$1"
    cat << 'EOF' > "$TARGET"
#!/bin/bash

echo "---[TUIC v5 + Cloudflare Startup Script]---"

CONFIG_DIR="/usr/local/etc/tuic"
CONFIG_PATH="${CONFIG_DIR}/config.json"
CERT_PATH="${CONFIG_DIR}/cert.crt"
KEY_PATH="${CONFIG_DIR}/key.key"
BIN_PATH="/usr/local/bin/tuic-server"

mkdir -p "$CONFIG_DIR"

# --- TUIC Core Installation ---
echo "Checking/Installing TUIC v5..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    TUIC_ARCH="x86_64-unknown-linux-gnu"
elif [ "$ARCH" = "aarch64" ]; then
    TUIC_ARCH="aarch64-unknown-linux-gnu"
else
    echo "❌ Unsupported arch $ARCH"; exit 1
fi

if [! -f "$BIN_PATH" ]; then
    LATEST=$(curl -s https://api.github.com/repos/EAimTY/tuic/releases | grep -o 'tuic-server-v[0-9.]*' | head -1)
    URL="https://github.com/EAimTY/tuic/releases/download/${LATEST}/${LATEST}-${TUIC_ARCH}"
    echo "Downloading $LATEST..."
    curl -L -o "$BIN_PATH" "$URL"
    chmod +x "$BIN_PATH"
fi

# --- Port ---
if [ -z "${SERVER_PORT:-}" ]; then
    echo ""
    echo "⚠ SERVER_PORT is not set!"
    read -rp "SERVER_PORT: " SERVER_PORT
    while [ -z "$SERVER_PORT" ] ||! echo "$SERVER_PORT" | grep -qE '^[0-9]+$' \
          || [ "$SERVER_PORT" -lt 1 ] || [ "$SERVER_PORT" -gt 65535 ]; do
        echo "❌ Invalid port. Enter 1-65535:"
        read -rp "SERVER_PORT: " SERVER_PORT
    done
    echo "✅ Using port: $SERVER_PORT"
fi

# --- Hardcoded credentials (kept from your VLESS) ---
UUID="a4af6a92-4dba-4cd1-841d-8ac7b38f9d6e"
PASSWORD="oNDJxLaAiXojgAcdW5gzwuQB"
CONGESTION="bbr"

# --- Certificate with Cloudflare CN ---
if [! -f "$CERT_PATH" ]; then
    openssl ecparam -genkey -name prime256v1 -out "$KEY_PATH"
    openssl req -new -x509 -days 36500 -key "$KEY_PATH" -out "$CERT_PATH" -subj "/CN=www.cloudflare.com"
fi

cat > "$CONFIG_PATH" << JSON
{
  "server": "[::]:${SERVER_PORT}",
  "users": {
    "${UUID}": "${PASSWORD}"
  },
  "certificate": "${CERT_PATH}",
  "private_key": "${KEY_PATH}",
  "congestion_control": "${CONGESTION}",
  "alpn": ["h3"],
  "zero_rtt_handshake": false,
  "dual_stack": true,
  "auth_timeout": "3s",
  "task_negotiation_timeout": "3s",
  "max_idle_time": "10s",
  "max_external_packet_size": 1500,
  "send_window": 16777216,
  "receive_window": 8388608,
  "gc_interval": "3s",
  "gc_lifetime": "15s",
  "log_level": "warn"
}
JSON

server_ip=$(curl -s https://v4.ident.me || hostname -I | awk '{print $1}')

echo "=========================================================="
echo " TUIC v5 Link (Cloudflare):"
echo "tuic://${UUID}:${PASSWORD}@${server_ip}:${SERVER_PORT}?congestion_control=${CONGESTION}&alpn=h3&sni=www.cloudflare.com&allow_insecure=1#TUIC5-CF"
echo "=========================================================="

echo "Starting TUIC..."
exec "$BIN_PATH" -c "$CONFIG_PATH"
EOF
}

# ==========================================
# [2] Generate proxy scripts
# ==========================================

echo "--- [2] Generating proxy scripts ---"

generate_tuic "$TUIC_SCRIPT"
chmod +x "$TUIC_SCRIPT"

# ==========================================
# DONE
# ==========================================

printf "\e[1;36m"
echo " ╔══════════════════════════════════════════╗"
echo " ║ ✅ SETUP COMPLETE - TUIC v5 ║"
echo " ╠══════════════════════════════════════════╣"
echo " ║ Run: bash $TUIC_SCRIPT ║"
echo " ╚══════════════════════════════════════════╝"
printf "\e[0m"
