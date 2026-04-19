#!/bin/bash
# =================================================================
# 🌿 GREENMIND — AI-Powered Home Surveillance
#    "Ngôi nhà biết nhìn, biết nghĩ, biết bảo vệ"
# 🛠  Greenfield Tech  |  🤖 AI-crafted by Mary
# =================================================================

BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
INSTALLER_URL="$BASE_URL/installers"

# --- Load từng module qua source ---
_load() {
    local name=$1
    # Nếu đang chạy từ repo local thì source trực tiếp
    local local_path="$(dirname "$0")/installers/${name}.sh"
    if [ -f "$local_path" ]; then
        source "$local_path"
    else
        source <(curl -fsSL "$INSTALLER_URL/${name}.sh")
    fi
}

_load 00_common
_load 01_env
_load 02_role
_load 03_core
_load 04_venv
_load 05_ai
_load 06_config
_load 07_frigate
_load 08_auth
_load 09_telegram
_load 10_service
_load 11_dashboard

# =================================================================
# 🚀 CHẠY CÀI ĐẶT
# =================================================================
check_env
show_intro
select_node_role
setup_core
setup_venv
setup_ai_engines
setup_config
setup_frigate
setup_auth
setup_telegram
setup_service
setup_dashboard

# --- Kết nối Node về Gateway ---
if [[ "$NODE_ROLE" == "node" ]]; then
    echo -e "\n${BOLD}${CYAN}🔗 KẾT NỐI NODE VỀ GATEWAY${NC}"
    openclaw connect --gateway "$GATEWAY_ADDR" --token "$GATEWAY_TOKEN" 2>/dev/null && \
        echo -e "${GREEN} [✓] Đã kết nối: $GATEWAY_ADDR${NC}" || \
        echo -e "${YELLOW} [!] Chạy thủ công: openclaw connect --gateway $GATEWAY_ADDR --token $GATEWAY_TOKEN${NC}"
fi

# --- Tổng kết ---
echo -e "\n${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   🎉 CÀI ĐẶT GREENMIND HOÀN TẤT!        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

if [[ "$NODE_ROLE" == "gateway" ]]; then
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "${CYAN}  📊 Dashboard : http://localhost:${GREENMIND_PORT}${NC}"
    [[ -n "$LAN_IP" ]] && \
    echo -e "${CYAN}  🌐 LAN       : http://$LAN_IP:${GREENMIND_PORT}${NC}"
    echo -e "${CYAN}  ⚙️  Config    : /etc/greenmind/config.env${NC}"
    echo -e "${CYAN}  🔑 Node token: openclaw gateway token${NC}"
else
    echo -e "${CYAN}  📡 Node đã kết nối về Gateway: $GATEWAY_ADDR${NC}"
fi
echo ""
