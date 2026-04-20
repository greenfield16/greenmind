#!/bin/bash
# 🌿 03_gateway/04_ai.sh — Cấu hình AI Engine
show_step 5 7 "Cấu hình AI Engine" "Chọn AI để phân tích camera, nhận diện sự kiện và trả lời lệnh"

oc_section "AI Engine" \
    "Greenmind cần AI để xử lý ngôn ngữ tự nhiên và phân tích hình ảnh." \
    "" \
    "  OpenRouter — Cloud AI, free tier, nhiều model, không cần thẻ tín dụng" \
    "               → https://openrouter.ai/keys" \
    "" \
    "  Gemini     — Google AI Studio, free tier, cần Google account" \
    "               → https://aistudio.google.com/app/apikey" \
    "" \
    "  Ollama     — AI local, miễn phí hoàn toàn, cần RAM ≥ 4GB, không cần internet"

oc_radio "Chọn AI Engine" AI_CHOICE \
    "OpenRouter  (Khuyên dùng — free, cloud)" \
    "Gemini      (Google AI Studio — free)" \
    "Ollama      (Local AI — không cần internet)"

case "$AI_CHOICE" in
    2)
        write_config AI_ENGINE gemini
        oc_input "Nhập Gemini API Key (AIza...)" GEMINI_KEY
        while [[ ! "$GEMINI_KEY" =~ ^AIza ]]; do
            print_warn "Key không hợp lệ — phải bắt đầu bằng AIza"
            oc_input "Nhập lại Gemini API Key" GEMINI_KEY
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
        write_config OLLAMA_MODEL llama3.2:3b
        run_step "Tải model llama3.2:3b" ollama pull llama3.2:3b
        print_success "Đã cấu hình Ollama + llama3.2:3b"
        ;;
    *)
        write_config AI_ENGINE openrouter
        write_config OPENROUTER_MODEL "nvidia/nemotron-3-super-120b-a12b:free"
        oc_input "Nhập OpenRouter API Key (sk-or-v1-...)" OR_KEY
        while [[ ! "$OR_KEY" =~ ^sk-or-v1- ]]; do
            print_warn "Key không hợp lệ — phải bắt đầu bằng sk-or-v1-"
            oc_input "Nhập lại OpenRouter API Key" OR_KEY
        done
        write_config OPENROUTER_KEY "$OR_KEY"
        print_success "Đã cấu hình OpenRouter"
        ;;
esac
