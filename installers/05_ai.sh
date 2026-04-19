#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 5: AI Engine (Ollama / Gemini)
# =================================================================

setup_ai_engines() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CẤU HÌNH TRÍ TUỆ NHÂN TẠO${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua AI Engine.${NC}"
        return 0
    fi

    if [[ "$OS_TYPE" == "Linux" ]]; then
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        TOTAL_RAM=$(($(sysctl -n hw.memsize) / 1024 / 1024))
    fi

    export LOCAL_MODEL="gemini"

    if [ "$TOTAL_RAM" -lt 4000 ]; then
        echo -e "ℹ️  RAM thấp ($TOTAL_RAM MB) — tự động dùng Gemini API."
        return 0
    fi

    echo -e "ℹ️  RAM đủ mạnh ($TOTAL_RAM MB) — có thể dùng Local AI."
    if ! command -v ollama &> /dev/null; then
        run_with_process "Cài đặt Ollama" bash -c "curl -fsSL https://ollama.com/install.sh | sh"
    fi

    if command -v systemctl &> /dev/null; then
        systemctl start ollama > /dev/null 2>&1
    else
        ollama serve > /dev/null 2>&1 &
    fi

    echo -e "\n${CYAN}🧠 CHỌN NÃO BỘ AI:${NC}"
    echo -e "  ${BLUE}1)${NC} Gemma 4 (2B)  — Nhẹ, cho máy yếu"
    echo -e "  ${BLUE}2)${NC} Gemma 4 (7B)  — Chuẩn, cho Mac Mini / PC"
    echo -e "  ${BLUE}3)${NC} Gemma 4 (27B) — Mạnh, cho server"
    echo -e "  ${BLUE}4)${NC} Bỏ qua, dùng Gemini API"
    read -p "👉 Lựa chọn (1-4): " model_choice

    case $model_choice in
        1) run_with_process "Kéo model Gemma (2B)"  ollama pull gemma:2b;  export LOCAL_MODEL="gemma:2b"  ;;
        2) run_with_process "Kéo model Gemma (7B)"  ollama pull gemma:7b;  export LOCAL_MODEL="gemma:7b"  ;;
        3) run_with_process "Kéo model Gemma (27B)" ollama pull gemma:27b; export LOCAL_MODEL="gemma:27b" ;;
        *) echo -e "Dùng Gemini API." ;;
    esac
}
