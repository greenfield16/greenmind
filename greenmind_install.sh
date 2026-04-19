#!/bin/bash
# =================================================================
# 🌿 GREENMIND — AI-Powered Home Surveillance
#    "Ngôi nhà biết nhìn, biết nghĩ, biết bảo vệ"
# 🛠  Greenfield Tech  |  🤖 AI-crafted by Mary
# =================================================================

BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
INSTALLER_URL="$BASE_URL/installers"

# --- Load từng module qua source ---
_TMPDIR=$(mktemp -d)
trap "rm -rf $_TMPDIR" EXIT

_load() {
    local name=$1
    local local_path="$(dirname "$0")/installers/${name}.sh"
    if [ -f "$local_path" ]; then
        source "$local_path"
    else
        local tmp="$_TMPDIR/${name}.sh"
        curl -fsSL "$INSTALLER_URL/${name}.sh" -o "$tmp"
        source "$tmp"
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

# --- Bước 1: Core packages ---
((CURRENT_STEP++))
show_progress "Thư viện lõi"
if ask_continue "thư viện lõi (Python, Node.js, FFMpeg, MQTT)"; then
    setup_core
fi

# --- Bước 2: VENV ---
((CURRENT_STEP++))
show_progress "Môi trường Python"
if ask_continue "môi trường ảo Python (VENV)"; then
    setup_venv
fi

# --- Bước 3: AI Engine ---
((CURRENT_STEP++))
show_progress "AI Engine"
if ask_continue "AI Engine (Gemini / NVIDIA / Ollama)"; then
    setup_ai_engines
fi

# --- Bước 4: Camera & Config ---
((CURRENT_STEP++))
show_progress "Camera & Cấu hình"
if ask_continue "cấu hình Camera & Thiết bị"; then
    setup_config
fi

# --- Bước 5: Frigate ---
((CURRENT_STEP++))
show_progress "Frigate NVR"
if ask_continue "Frigate NVR (tuỳ chọn, cần Docker)"; then
    setup_frigate
fi

# --- Bước 6: Auth ---
((CURRENT_STEP++))
show_progress "Bảo mật Dashboard"
if ask_continue "xác thực đăng nhập Dashboard"; then
    setup_auth
fi

# --- Bước 7: Telegram ---
((CURRENT_STEP++))
show_progress "Telegram Bot"
if ask_continue "Telegram Bot 2 chiều"; then
    setup_telegram
fi

# --- Bước 8: Service ---
((CURRENT_STEP++))
show_progress "Services"
if ask_continue "đăng ký service chạy ngầm"; then
    setup_service
fi

# --- Bước 9: Dashboard ---
((CURRENT_STEP++))
show_progress "Dashboard Web"
if ask_continue "Dashboard Web"; then
    setup_dashboard
fi

# --- Kết nối Node về Gateway ---
if [[ "$NODE_ROLE" == "node" ]]; then
    echo -e "\n${BOLD}${CYAN}🔗 KẾT NỐI NODE VỀ GATEWAY${NC}"
    echo -e "${CYAN}  Chạy lệnh sau để kết nối Node về Gateway:${NC}"
    echo -e "${BOLD}  greenmind-connect --gateway $GATEWAY_ADDR --token $GATEWAY_TOKEN${NC}" 2>/dev/null || \
    echo -e "${YELLOW}  Cấu hình thủ công trong: $CONFIG_FILE${NC}"
    echo -e "  ${CYAN}GATEWAY_URL=$GATEWAY_ADDR${NC}"
    echo -e "  ${CYAN}GATEWAY_TOKEN=$GATEWAY_TOKEN${NC}"
fi

# --- Progress 100% ---
CURRENT_STEP=$TOTAL_STEPS
show_progress "Hoàn tất!"

# --- Tổng kết ---
echo -e "\n${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   🎉 CÀI ĐẶT GREENMIND HOÀN TẤT!        ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

if [[ "$NODE_ROLE" == "gateway" ]]; then
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    # Tạo pairing token ngẫu nhiên nếu chưa có
    if ! grep -q "PAIRING_TOKEN" "$CONFIG_FILE" 2>/dev/null; then
        PAIRING_TOKEN=$(openssl rand -hex 16)
        echo "PAIRING_TOKEN=$PAIRING_TOKEN" >> "$CONFIG_FILE"
    else
        PAIRING_TOKEN=$(grep "PAIRING_TOKEN" "$CONFIG_FILE" | cut -d= -f2)
    fi
    echo -e "${CYAN}  📊 Dashboard : http://localhost:${GREENMIND_PORT}${NC}"
    [[ -n "$LAN_IP" ]] && \
    echo -e "${CYAN}  🌐 LAN       : http://$LAN_IP:${GREENMIND_PORT}${NC}"
    echo -e "${CYAN}  ⚙️  Config    : /etc/greenmind/config.env${NC}"
    echo -e "${CYAN}  🔑 Node token: ${BOLD}$PAIRING_TOKEN${NC}"
else
    echo -e "${CYAN}  📡 Node đã kết nối về Gateway: $GATEWAY_ADDR${NC}"
fi
echo ""
