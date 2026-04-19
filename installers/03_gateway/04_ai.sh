#!/bin/bash
# 🌿 03_gateway/04_ai.sh
show_progress 5 6 "Cấu hình AI Engine"
ask_continue

echo -e "\n${BOLD}Chọn AI Engine:${NC}"
echo "  1) OpenRouter (khuyên dùng — nhiều model free, không cần thẻ)"
echo "     → https://openrouter.ai → Sign up → API Keys"
echo "  2) Gemini (Google AI Studio)"
echo "     → https://aistudio.google.com/app/apikey"
echo "  3) Ollama (local AI — cần RAM ≥ 4GB)"
echo ""
read -rp "Chọn [1/2/3, mặc định: 1]: " AI_CHOICE

case "$AI_CHOICE" in
    2)
        write_config AI_ENGINE gemini
        read -rp "Nhập Gemini API Key: " GEMINI_KEY
        write_config GEMINI_KEY "$GEMINI_KEY"
        print_success "Đã cấu hình Gemini"
        ;;
    3)
        write_config AI_ENGINE ollama
        write_config OLLAMA_URL http://localhost:11434
        if ! command -v ollama &>/dev/null; then
            print_info "Đang cài Ollama..."
            curl -fsSL https://ollama.ai/install.sh | sh
        fi
        write_config OLLAMA_MODEL moondream
        print_info "Đang pull model moondream (829MB)..."
        ollama pull moondream
        print_success "Đã cấu hình Ollama + moondream"
        ;;
    *)
        write_config AI_ENGINE openrouter
        write_config OPENROUTER_MODEL "nvidia/nemotron-nano-12b-v2-vl:free"
        read -rp "Nhập OpenRouter API Key (sk-or-v1-...): " OR_KEY
        write_config OPENROUTER_KEY "$OR_KEY"
        print_success "Đã cấu hình OpenRouter"
        ;;
esac
