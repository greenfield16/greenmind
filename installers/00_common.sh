#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Common: Colors, Spinner, Shared Variables
# =================================================================

export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export CYAN='\033[0;36m'
export NC='\033[0m'
export BOLD='\033[1m'

export TOTAL_STEPS=11
export CURRENT_STEP=0
export NODE_ROLE="gateway"
export LOCAL_MODEL="gemini"
export GREENMIND_DIR="${GREENMIND_DIR:-$HOME/.greenmind}"
export VENV_PATH="$GREENMIND_DIR/venv"
export CONFIG_FILE="/etc/greenmind/config.env"
export GREENMIND_PORT="${GREENMIND_PORT:-8765}"
export BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"

# --- Spinner ---
run_with_process() {
    local text=$1
    shift
    "$@" > /dev/null 2>&1 &
    local pid=$!
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN} %c ${NC} ${text}... " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r${GREEN} [✓] ${NC} ${text} (Hoàn tất) \033[K\n"
}
