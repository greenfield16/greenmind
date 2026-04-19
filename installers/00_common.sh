#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Common: Colors, Spinner, Progress Bar, Shared Variables
# =================================================================

export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export CYAN='\033[0;36m'
export NC='\033[0m'
export BOLD='\033[1m'

export TOTAL_STEPS=9   # Số bước thực tế (không tính check_env, show_intro, select_role)
export CURRENT_STEP=0
export NODE_ROLE="gateway"
export LOCAL_MODEL="gemini"
export GREENMIND_DIR="${GREENMIND_DIR:-$HOME/.greenmind}"
export VENV_PATH="$GREENMIND_DIR/venv"
export CONFIG_FILE="/etc/greenmind/config.env"
export GREENMIND_PORT="${GREENMIND_PORT:-8765}"
export BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
export INSTALL_MODE="auto"   # auto | step

# =================================================================
# 🔄 Spinner (dùng khi chạy lệnh nền)
# =================================================================
run_with_process() {
    local text=$1
    shift
    "$@" > /dev/null 2>&1 &
    local pid=$!
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN} %c ${NC} ${text}... " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r${GREEN} [✓] ${NC} ${text} (Hoàn tất) \033[K\n"
}

# =================================================================
# 📊 Thanh tiến độ tổng thể
# =================================================================
_draw_progress() {
    local step=$1
    local total=$2
    local label="${3:-}"
    local width=40
    local filled=$(( step * width / total ))
    local empty=$(( width - filled ))
    local pct=$(( step * 100 / total ))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done

    printf "\r${CYAN}  [${bar}] ${pct}%% ${label}${NC}\033[K"
    echo ""
}

show_progress() {
    local label="${1:-}"
    _draw_progress "$CURRENT_STEP" "$TOTAL_STEPS" "$label"
}

# =================================================================
# ❓ Hỏi tiếp tục (chỉ dùng trong step mode)
# =================================================================
ask_continue() {
    local step_name="$1"
    if [[ "$INSTALL_MODE" == "step" ]]; then
        echo ""
        read -p "👉 Tiếp tục cài ${step_name}? (y/n, mặc định y): " _ans
        _ans="${_ans:-y}"
        [[ "$_ans" =~ ^[Yy]$ ]]
    else
        return 0   # auto mode: luôn tiếp tục
    fi
}
