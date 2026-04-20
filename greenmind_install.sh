#!/bin/bash
# 🌿 Greenmind v3.0 — Smart Building AI Platform
# Cài đặt: bash <(curl -fsSL https://raw.githubusercontent.com/greenfield16/greenmind/main/greenmind_install.sh)

set -euo pipefail
BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"

# Load common utils
source <(curl -fsSL "$BASE_URL/installers/00_common.sh")

_load() { source <(curl -fsSL "$BASE_URL/installers/$1"); }

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

echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   🌿 Greenmind v3.0 cài đặt hoàn tất  ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${NC}"
echo ""
if [ "$ROLE" = "gateway" ]; then
    PORT=$(grep GREENMIND_PORT "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo 8765)
    echo -e "  Dashboard: ${CYAN}http://$(hostname -I | awk '{print $1}'):${PORT}${NC}"
fi
echo -e "  Config   : ${CYAN}${CONFIG_FILE}${NC}"
echo -e "  Logs     : ${CYAN}journalctl -u greenmind-${ROLE} -f${NC}"
echo ""
