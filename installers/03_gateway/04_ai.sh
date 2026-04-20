#!/bin/bash
# 🌿 03_gateway/04_ai.sh — Cấu hình AI Engine
show_step 5 7 "Cấu hình AI Engine"

echo ""
echo -e "  ${BOLD}Chọn AI Engine:${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}  1) OpenRouter${NC}  ${GREEN}(Khuyên dùng)${NC}"
echo -e "  ${DIM}              Free tier · Nhiều model · Không cần thẻ tín dụng${NC}"
echo -e "  ${DIM}              → https://openrouter.ai/keys${NC}"
echo ""
echo -e "  ${CYAN}${BOLD}  2) Gemini${NC}      (Google AI Studio)"
echo -e "  ${DIM}              Free tier · Cần Google account${NC}"
echo -e "  ${DIM}              → https://aistudio.google.com/app/apikey${NC}"
echo ""
echo -e "  ${CYAN}${BOLD}  3) Ollama${NC}      (Local AI — không cần internet)"
echo -e "  ${DIM}              Miễn phí · Cần RAM ≥ 4GB${NC}"
echo ""
read -rp "  Chọn [1/2/3, mặc định: 1]: " AI_CHOICE

case "$AI_CHOICE" in
    2)
        write_config AI_ENGINE gemini
        echo -ne "\n  ${BOLD}Nhập Gemini API Key${NC} (AIza...): "
        read -r GEMINI_KEY
        while [[ ! "$GEMINI_KEY" =~ ^AIza ]]; do
            print_warn "Key không hợp lệ (phải bắt đầu bằng AIza)"
            echo -ne "  ${BOLD}Nhập lại${NC}: "
            read -r GEMINI_KEY
        done
        write_config GEMINI_KEY "$GEMINI_KEY"
        print_success "Đã cấu hình Gemini"
        ;;
    3)
        write_config AI_ENGINE ollama
        write_config OLLAMA_URL http://localhost:11434
        if ! command -v ollama &>/dev/null; then
            run_step "Cài Ollama" bash -c "curl -fsSL https://ollama.ai/install.sh | sh"
        fi
        write_config OLLAMA_MODEL moondream
        run_step "Tải model moondream" ollama pull moondream
        print_success "Đã cấu hình Ollama + moondream"
        ;;
    *)
        write_config AI_ENGINE openrouter
        write_config OPENROUTER_MODEL "nvidia/nemotron-3-super-120b-a12b:free"
        echo ""
        echo -e "  ${DIM}Lấy API key tại: ${CYAN}https://openrouter.ai/keys${NC}"
        echo -ne "  ${BOLD}Nhập OpenRouter API Key${NC} (sk-or-v1-...): "
        read -r OR_KEY
        while [[ ! "$OR_KEY" =~ ^sk-or-v1- ]]; do
            print_warn "Key không hợp lệ (phải bắt đầu bằng sk-or-v1-)"
            echo -ne "  ${BOLD}Nhập lại${NC}: "
            read -r OR_KEY
        done
        write_config OPENROUTER_KEY "$OR_KEY"
        print_success "Đã cấu hình OpenRouter (model: nemotron-3-super-120b)"
        ;;
esac
