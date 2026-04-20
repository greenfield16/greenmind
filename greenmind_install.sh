#!/bin/bash
# 🌿 Greenmind v3.1 — Smart Building AI Platform
# Cài đặt: bash <(curl -fsSL https://raw.githubusercontent.com/greenfield16/greenmind/main/greenmind_install.sh)

set -uo pipefail

BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
SCRIPTS_DIR="/tmp/greenmind_scripts"

# ── Download tất cả scripts trước (fix stdin issue) ─────────
mkdir -p "$SCRIPTS_DIR/03_gateway" "$SCRIPTS_DIR/04_node"

_download() {
    curl -fsSL "$BASE_URL/installers/$1" -o "$SCRIPTS_DIR/$1" 2>/dev/null
}

_download "00_common.sh"
_download "01_env.sh"
_download "02_role.sh"
_download "03_gateway/01_packages.sh"
_download "03_gateway/02_mqtt.sh"
_download "03_gateway/03_venv.sh"
_download "03_gateway/04_ai.sh"
_download "03_gateway/05_config.sh"
_download "03_gateway/06_service.sh"
_download "03_gateway/07_openclaw.sh"
_download "04_node/01_packages.sh"
_download "04_node/02_modules.sh"
_download "04_node/03_config.sh"
_download "04_node/04_service.sh"

# Load common utils
source "$SCRIPTS_DIR/00_common.sh"
_load() { source "$SCRIPTS_DIR/$1"; }

_load "01_env.sh"
_load "02_role.sh"

if [ "$ROLE" = "gateway" ]; then
    for f in 03_gateway/01_packages.sh \
              03_gateway/02_mqtt.sh \
              03_gateway/03_venv.sh \
              03_gateway/04_ai.sh \
              03_gateway/05_config.sh \
              03_gateway/06_service.sh \
              03_gateway/07_openclaw.sh; do
        _load "$f"
    done
else
    for f in 04_node/01_packages.sh \
              04_node/02_modules.sh \
              04_node/03_config.sh \
              04_node/04_service.sh; do
        _load "$f"
    done
fi

# ── Summary box ──────────────────────────────────────────────
LOCAL_IP=$(hostname -I | awk '{print $1}')
PORT=$(grep GREENMIND_PORT "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo 8765)

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║     🌿 Greenmind cài đặt thành công!             ║${NC}"
echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════════╣${NC}"
if [ "${ROLE:-}" = "gateway" ]; then
echo -e "${GREEN}${BOLD}║${NC}  Dashboard : ${CYAN}http://${LOCAL_IP}:${PORT}${NC}"
echo -e "${GREEN}${BOLD}║${NC}  Config    : ${CYAN}${CONFIG_FILE}${NC}"
echo -e "${GREEN}${BOLD}║${NC}  Logs GW   : ${CYAN}journalctl -u greenmind-gateway -f${NC}"
echo -e "${GREEN}${BOLD}║${NC}  Logs AI   : ${CYAN}journalctl --user -u openclaw-gateway -f${NC}"
else
echo -e "${GREEN}${BOLD}║${NC}  Config    : ${CYAN}${CONFIG_FILE}${NC}"
echo -e "${GREEN}${BOLD}║${NC}  Logs      : ${CYAN}journalctl -u greenmind-node -f${NC}"
fi
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
