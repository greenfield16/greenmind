#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 5: AI Engine (Ollama / Gemini / NVIDIA NIM)
# =================================================================

setup_ai_engines() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CẤU HÌNH TRÍ TUỆ NHÂN TẠO${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua AI Engine.${NC}"
        return 0
    fi

    echo -e "${CYAN}🤖 CHỌN AI ENGINE:${NC}"
    echo -e "  ${BLUE}1)${NC} ☁️  Gemini API (Google)     — Miễn phí, dễ cài"
    echo -e "       🔑 Lấy key: ${BOLD}https://aistudio.google.com/app/apikey${NC}"
    echo -e "  ${BLUE}2)${NC} ⚡ NVIDIA NIM (Gemma 4 31B) — Mạnh hơn, free tier"
    echo -e "       🔑 Lấy key: ${BOLD}https://build.nvidia.com/google/gemma-4-31b-it${NC}"
    echo -e "  ${BLUE}3)${NC} 🖥  Local Ollama             — Chạy offline, cần RAM ≥ 4GB"
    echo -e "  ${BLUE}4)${NC} ⏭  Bỏ qua — cấu hình sau\n"
    read -p "👉 Lựa chọn (1-4): " engine_choice

    case "$engine_choice" in
        1)
            echo -e "\n${CYAN}📋 Lấy Gemini API Key tại:${NC}"
            echo -e "   ${BOLD}https://aistudio.google.com/app/apikey${NC}"
            read -p "Nhập Gemini API Key: " gemini_key
            if [[ -n "$gemini_key" ]]; then
                sed -i "s/GEMINI_KEY=.*/GEMINI_KEY=$gemini_key/" "$CONFIG_FILE"
                sed -i "s/AI_ENGINE=.*/AI_ENGINE=gemini/"         "$CONFIG_FILE"
                export LOCAL_MODEL="gemini"
                echo -e "${GREEN} [✓] Đã lưu Gemini API Key.${NC}"
            fi
            ;;
        2)
            echo -e "\n${CYAN}📋 Lấy NVIDIA NIM API Key tại:${NC}"
            echo -e "   ${BOLD}https://build.nvidia.com/google/gemma-4-31b-it${NC}"
            echo -e "   → Đăng nhập → \"Get API Key\" → Copy key\n"
            read -p "Nhập NVIDIA NIM API Key: " nvidia_key
            if [[ -n "$nvidia_key" ]]; then
                grep -q "NVIDIA_KEY" "$CONFIG_FILE" && \
                    sed -i "s/NVIDIA_KEY=.*/NVIDIA_KEY=$nvidia_key/" "$CONFIG_FILE" || \
                    echo "NVIDIA_KEY=$nvidia_key" >> "$CONFIG_FILE"
                sed -i "s/AI_ENGINE=.*/AI_ENGINE=nvidia/" "$CONFIG_FILE"
                export LOCAL_MODEL="nvidia"
                echo -e "${GREEN} [✓] Đã lưu NVIDIA NIM API Key.${NC}"
                echo -e "${CYAN}     Model: google/gemma-4-31b-it (multimodal)${NC}"
            fi
            ;;
        3)
            # Kiểm tra RAM
            if [[ "$OS_TYPE" == "Linux" ]]; then
                TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
            elif [[ "$OS_TYPE" == "Darwin" ]]; then
                TOTAL_RAM=$(($(sysctl -n hw.memsize) / 1024 / 1024))
            fi

            if [ "${TOTAL_RAM:-0}" -lt 4000 ]; then
                echo -e "${YELLOW}⚠️  RAM thấp ($TOTAL_RAM MB) — Local AI có thể chậm.${NC}"
            fi

            if ! command -v ollama &> /dev/null; then
                run_with_process "Cài đặt Ollama" bash -c "curl -fsSL https://ollama.com/install.sh | sh"
            fi
            command -v systemctl &> /dev/null && systemctl start ollama > /dev/null 2>&1 || \
                ollama serve > /dev/null 2>&1 &

            echo -e "\n${CYAN}🧠 CHỌN MODEL LOCAL:${NC}"
            echo -e "  ${BLUE}1)${NC} gemma3:2b   — Nhẹ (~1.6GB), phù hợp ARM"
            echo -e "  ${BLUE}2)${NC} gemma3:7b   — Cân bằng (~4GB)"
            echo -e "  ${BLUE}3)${NC} llava:7b    — Có vision (xem ảnh được) (~4GB)"
            echo -e "  ${BLUE}4)${NC} gemma3:27b  — Mạnh nhất (~16GB)"
            read -p "👉 Chọn model (1-4): " model_choice
            case $model_choice in
                1) run_with_process "Kéo gemma3:2b"  ollama pull gemma3:2b;  export LOCAL_MODEL="gemma3:2b"  ;;
                2) run_with_process "Kéo gemma3:7b"  ollama pull gemma3:7b;  export LOCAL_MODEL="gemma3:7b"  ;;
                3) run_with_process "Kéo llava:7b"   ollama pull llava:7b;   export LOCAL_MODEL="llava:7b"   ;;
                4) run_with_process "Kéo gemma3:27b" ollama pull gemma3:27b; export LOCAL_MODEL="gemma3:27b" ;;
                *) export LOCAL_MODEL="gemma3:2b" ;;
            esac
            sed -i "s/AI_ENGINE=.*/AI_ENGINE=$LOCAL_MODEL/" "$CONFIG_FILE"
            echo -e "${GREEN} [✓] Ollama đã cài, model: $LOCAL_MODEL${NC}"
            ;;
        *)
            echo -e "${YELLOW}⏭ Bỏ qua — chỉnh sau trong /etc/greenmind/config.env${NC}"
            export LOCAL_MODEL="gemini"
            ;;
    esac
    echo ""
}
