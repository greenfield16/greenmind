#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 5: AI Engine (Gemini / NVIDIA NIM / Ollama Local)
# =================================================================

setup_ai_engines() {
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CẤU HÌNH TRÍ TUỆ NHÂN TẠO${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua AI Engine.${NC}"
        return 0
    fi

    echo -e "${CYAN}🤖 CHỌN AI ENGINE:${NC}"
    echo -e "  ${BLUE}1)${NC} ☁️  Gemini API       — Miễn phí, không cần GPU"
    echo -e "       🔑 ${BOLD}https://aistudio.google.com/app/apikey${NC}"
    echo -e "  ${BLUE}2)${NC} ⚡ NVIDIA NIM       — Gemma 4 31B, free tier, mạnh hơn Gemini"
    echo -e "       🔑 ${BOLD}https://build.nvidia.com/google/gemma-4-31b-it${NC}"
    echo -e "  ${BLUE}3)${NC} 🖥  Local AI (Ollama) — Chạy offline hoàn toàn, cần máy mạnh"
    echo -e "  ${BLUE}4)${NC} ⏭  Bỏ qua — cấu hình sau\n"
    read -p "👉 Lựa chọn (1-4): " engine_choice

    case "$engine_choice" in
        1) _setup_gemini   ;;
        2) _setup_nvidia   ;;
        3) _setup_ollama   ;;
        *) echo -e "${YELLOW}⏭ Bỏ qua — chỉnh sau trong $CONFIG_FILE${NC}"
           export LOCAL_MODEL="gemini" ;;
    esac
    echo ""
}

# ── Gemini ─────────────────────────────────────────────────────────────────
_setup_gemini() {
    echo -e "\n${CYAN}📋 Lấy Gemini API Key:${NC}"
    echo -e "   1. Truy cập: ${BOLD}https://aistudio.google.com/app/apikey${NC}"
    echo -e "   2. Đăng nhập Google → \"Create API Key\" → Copy\n"
    read -p "Nhập Gemini API Key: " gemini_key
    if [[ -z "$gemini_key" ]]; then
        echo -e "${YELLOW}⏭ Bỏ qua Gemini.${NC}"; return
    fi
    sed -i "s/GEMINI_KEY=.*/GEMINI_KEY=$gemini_key/" "$CONFIG_FILE"
    sed -i "s/AI_ENGINE=.*/AI_ENGINE=gemini/"        "$CONFIG_FILE"
    export LOCAL_MODEL="gemini"
    echo -e "${GREEN} [✓] Gemini API đã sẵn sàng.${NC}"
}

# ── NVIDIA NIM ─────────────────────────────────────────────────────────────
_setup_nvidia() {
    echo -e "\n${CYAN}📋 Lấy NVIDIA NIM API Key:${NC}"
    echo -e "   1. Truy cập: ${BOLD}https://build.nvidia.com/google/gemma-4-31b-it${NC}"
    echo -e "   2. Đăng nhập NVIDIA → \"Get API Key\" → Copy\n"
    read -p "Nhập NVIDIA NIM API Key: " nvidia_key
    if [[ -z "$nvidia_key" ]]; then
        echo -e "${YELLOW}⏭ Bỏ qua NVIDIA NIM.${NC}"; return
    fi
    grep -q "NVIDIA_KEY" "$CONFIG_FILE" && \
        sed -i "s/NVIDIA_KEY=.*/NVIDIA_KEY=$nvidia_key/" "$CONFIG_FILE" || \
        echo "NVIDIA_KEY=$nvidia_key" >> "$CONFIG_FILE"
    sed -i "s/AI_ENGINE=.*/AI_ENGINE=nvidia/" "$CONFIG_FILE"
    export LOCAL_MODEL="nvidia"
    echo -e "${GREEN} [✓] NVIDIA NIM (Gemma 4 31B) đã sẵn sàng.${NC}"
}

# ── Ollama Local ────────────────────────────────────────────────────────────
_setup_ollama() {
    # Detect RAM
    if [[ "$OS_TYPE" == "Linux" ]]; then
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        TOTAL_RAM=$(($(sysctl -n hw.memsize) / 1024 / 1024))
    fi
    TOTAL_RAM=${TOTAL_RAM:-2048}

    echo -e "\n${BOLD}${CYAN}=== YEU CAU PHAN CUNG CHO LOCAL AI ===${NC}"
    echo -e ""
    echo -e "  Model            | VRAM (GPU)  | RAM (CPU)   | RAM de nghi | Vision | Toc do"
    echo -e "  -----------------|-------------|-------------|-------------|--------|-------"
    echo -e "  gemma3:2b        |    2 GB     |    2 GB     |    3 GB     |  YES   | Fast"
    echo -e "  qwen2.5vl:3b     |    3 GB     |    3 GB     |    4 GB     |  YES   | Fast"
    echo -e "  gemma3:4b        |    4 GB     |    4 GB     |    5 GB     |  YES   | Fast"
    echo -e "  qwen2.5vl:7b     |    6 GB     |    6 GB     |    8 GB     |  YES   | Medium"
    echo -e "  gemma3:12b       |    8 GB     |    8 GB     |   12 GB     |  YES   | Medium"
    echo -e "  llava:13b        |   10 GB     |   10 GB     |   16 GB     |  YES   | Medium"
    echo -e "  gemma3:27b       |   16 GB     |   18 GB     |   24 GB     |  YES   | Slow"
    echo -e "  llava:34b        |   20 GB     |   20 GB     |   32 GB     |  YES   | Slow"
    echo -e ""
    echo -e "  ${BOLD}Ghi chu quan trong:${NC}"
    echo -e "  [*] Co GPU NVIDIA/AMD: Model chay trong VRAM -> nhanh hon CPU 10-50x"
    echo -e "  [*] Khong co GPU: Model chay bang RAM he thong -> cham hon nhung van OK"
    echo -e "  [*] Model > VRAM: Ollama tu offload phan du sang RAM (cham hon)"
    echo -e "  [*] GPU pho thong: RTX 3060 (12GB VRAM), RTX 4060 (8GB), RX 7600 (8GB)"
    echo -e "  [*] RAM may nay: ${BOLD}${TOTAL_RAM} MB${NC}"
    echo -e "  [*] Xem them model: https://ollama.com/library\n"

    # Gợi ý model dựa trên RAM
    echo -e "${CYAN}🎯 GỢI Ý DỰA TRÊN RAM HIỆN TẠI (${TOTAL_RAM} MB):${NC}"
    if   [ "$TOTAL_RAM" -ge 20000 ]; then
        SUGGESTED="llava:34b";    SUGGESTED_DESC="Mạnh nhất, chất lượng cao nhất"
    elif [ "$TOTAL_RAM" -ge 16000 ]; then
        SUGGESTED="gemma3:27b";   SUGGESTED_DESC="Rất mạnh, mô tả chi tiết"
    elif [ "$TOTAL_RAM" -ge 10000 ]; then
        SUGGESTED="llava:13b";    SUGGESTED_DESC="Mạnh, cân bằng tốt"
    elif [ "$TOTAL_RAM" -ge 7000 ]; then
        SUGGESTED="gemma3:12b";   SUGGESTED_DESC="Tốt, phù hợp PC 8GB"
    elif [ "$TOTAL_RAM" -ge 5000 ]; then
        SUGGESTED="qwen2.5vl:7b"; SUGGESTED_DESC="Nhẹ, vision tốt, phổ biến"
    elif [ "$TOTAL_RAM" -ge 3500 ]; then
        SUGGESTED="gemma3:4b";    SUGGESTED_DESC="Cân bằng cho máy 4GB"
    elif [ "$TOTAL_RAM" -ge 2500 ]; then
        SUGGESTED="qwen2.5vl:3b"; SUGGESTED_DESC="Nhẹ, vẫn có vision"
    else
        SUGGESTED="gemma3:2b";    SUGGESTED_DESC="Nhẹ nhất, phù hợp ARM/Tinkerboard"
    fi
    echo -e "   → ${BOLD}${GREEN}${SUGGESTED}${NC} — ${SUGGESTED_DESC}\n"

    echo -e "${CYAN}📋 CHỌN MODEL:${NC}"
    echo -e "  ${BLUE}1)${NC} gemma3:2b      — Tối thiểu 2GB RAM  | Tinkerboard/Pi"
    echo -e "  ${BLUE}2)${NC} qwen2.5vl:3b   — Tối thiểu 3GB RAM  | Vision tốt, nhẹ"
    echo -e "  ${BLUE}3)${NC} gemma3:4b      — Tối thiểu 4GB RAM  | Cân bằng"
    echo -e "  ${BLUE}4)${NC} qwen2.5vl:7b   — Tối thiểu 6GB RAM  | Vision mạnh ⭐"
    echo -e "  ${BLUE}5)${NC} gemma3:12b     — Tối thiểu 8GB RAM  | PC phổ thông ⭐"
    echo -e "  ${BLUE}6)${NC} llava:13b      — Tối thiểu 10GB RAM | Vision chuyên dụng"
    echo -e "  ${BLUE}7)${NC} gemma3:27b     — Tối thiểu 18GB RAM | Workstation"
    echo -e "  ${BLUE}8)${NC} llava:34b      — Tối thiểu 20GB RAM | Mạnh nhất"
    echo -e "  ${BLUE}9)${NC} Nhập tên model khác (tìm tại ollama.com/library)\n"
    read -p "👉 Chọn model (mặc định: $SUGGESTED): " model_choice

    case "$model_choice" in
        1) SELECTED_MODEL="gemma3:2b"     ;;
        2) SELECTED_MODEL="qwen2.5vl:3b"  ;;
        3) SELECTED_MODEL="gemma3:4b"     ;;
        4) SELECTED_MODEL="qwen2.5vl:7b"  ;;
        5) SELECTED_MODEL="gemma3:12b"    ;;
        6) SELECTED_MODEL="llava:13b"     ;;
        7) SELECTED_MODEL="gemma3:27b"    ;;
        8) SELECTED_MODEL="llava:34b"     ;;
        9) read -p "Nhập tên model (VD: mistral:7b): " SELECTED_MODEL ;;
        "") SELECTED_MODEL="$SUGGESTED"   ;;
        *) SELECTED_MODEL="$SUGGESTED"    ;;
    esac

    echo -e "\n${CYAN}📦 Cài đặt Ollama + model ${BOLD}${SELECTED_MODEL}${NC}..."

    # Cài Ollama nếu chưa có
    if ! command -v ollama &> /dev/null; then
        run_with_process "Cài đặt Ollama" bash -c "curl -fsSL https://ollama.com/install.sh | sh"
    fi

    # Khởi động Ollama
    if command -v systemctl &> /dev/null; then
        systemctl enable ollama > /dev/null 2>&1
        systemctl start  ollama > /dev/null 2>&1
    else
        ollama serve > /dev/null 2>&1 &
        sleep 2
    fi

    # Pull model (có progress bar của Ollama)
    echo -e "${CYAN}⬇️  Đang tải model ${SELECTED_MODEL} (có thể mất vài phút)...${NC}"
    ollama pull "$SELECTED_MODEL"

    # Cấu hình Ollama API endpoint vào config
    grep -q "OLLAMA_URL" "$CONFIG_FILE" || \
        echo "OLLAMA_URL=http://localhost:11434" >> "$CONFIG_FILE"
    sed -i "s/AI_ENGINE=.*/AI_ENGINE=$SELECTED_MODEL/" "$CONFIG_FILE"
    export LOCAL_MODEL="$SELECTED_MODEL"

    # Test model
    echo -e "\n${CYAN}🧪 Kiểm tra model...${NC}"
    TEST_RESP=$(curl -sf http://localhost:11434/api/generate \
        -d "{\"model\":\"$SELECTED_MODEL\",\"prompt\":\"Trả lời: OK\",\"stream\":false}" \
        2>/dev/null | grep -o '"response":"[^"]*"' | head -1)

    if [[ -n "$TEST_RESP" ]]; then
        echo -e "${GREEN} [✓] Model ${SELECTED_MODEL} hoạt động tốt!${NC}"
        echo -e "${CYAN}     API: http://localhost:11434${NC}"
        echo -e "${CYAN}     Model: $SELECTED_MODEL${NC}"
        echo -e "${CYAN}     Tìm thêm model: ${BOLD}https://ollama.com/library${NC}"
    else
        echo -e "${YELLOW} [!] Model chưa phản hồi — thử lại sau khi load xong.${NC}"
    fi
}
