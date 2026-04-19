#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 1: Check Environment & Intro
# =================================================================

check_env() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Lỗi: Cần chạy bằng lệnh 'sudo bash' nà!${NC}"
        exit 1
    fi
    export OS_TYPE=$(uname -s)
    export ARCH_TYPE=$(uname -m)
}

show_intro() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "   ____                      __  __ _           _ "
    echo "  / ___|_ __ ___  ___ _ __  |  \/  (_)_ __   __| |"
    echo " | |  _| '__/ _ \/ _ \ '_ \ | |\/| | | '_ \ / _' |"
    echo " | |_| | | |  __/  __/ | | || |  | | | | | | (_| |"
    echo "  \____|_|  \___|\___|_| |_||_|  |_|_|_| |_|\__,_|"
    echo -e "${NC}"
    echo -e "${YELLOW}🌟 CHÀO MỪNG ĐẾN VỚI TRÌNH CÀI ĐẶT GREENMIND AI (v3.2)${NC}"
    echo -e ""
    echo -e "  Các bước cài đặt:"
    echo -e "  ${BLUE}1.${NC} 📦 Thư viện lõi (Python 3, Node.js, FFMpeg)"
    echo -e "  ${BLUE}2.${NC} 🐍 Môi trường ảo (VENV) An toàn"
    echo -e "  ${BLUE}3.${NC} 🤖 AI Engine (Local Ollama hoặc Cloud API)"
    echo -e "  ${BLUE}4.${NC} ⚙️  Cấu hình Camera & Thiết bị"
    echo -e "  ${BLUE}5.${NC} 🎥 Frigate NVR (tuỳ chọn)"
    echo -e "  ${BLUE}6.${NC} 🔐 Xác thực đăng nhập Dashboard"
    echo -e "  ${BLUE}7.${NC} 🤖 Telegram Bot 2 chiều"
    echo -e "  ${BLUE}8.${NC} 🚀 Service chạy ngầm tự động"
    echo -e "  ${BLUE}9.${NC} 📊 Dashboard Web"
    echo ""
    echo -e "${CYAN}⚡ CHỌN CHẾ ĐỘ CÀI ĐẶT:${NC}"
    echo -e "  ${BLUE}1)${NC} 🚀 Tự động  — Cài toàn bộ, chỉ hỏi thông tin cần thiết"
    echo -e "  ${BLUE}2)${NC} 🔧 Từng bước — Xác nhận trước mỗi bước, linh hoạt hơn"
    echo ""
    read -p "👉 Chọn chế độ (1/2, mặc định 1): " _mode_choice
    case "$_mode_choice" in
        2)
            export INSTALL_MODE="step"
            echo -e "${GREEN} [✓] Chế độ: Từng bước${NC}"
            ;;
        *)
            export INSTALL_MODE="auto"
            echo -e "${GREEN} [✓] Chế độ: Tự động${NC}"
            ;;
    esac
    echo ""
}
