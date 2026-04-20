#!/bin/bash
# 🌿 Greenmind v3.0 — Common utilities

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

INSTALL_DIR=/opt/greenmind
CONFIG_FILE=/etc/greenmind/config.env
AUTO_MODE=${AUTO_MODE:-0}

print_info()    { echo -e "${CYAN}ℹ  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }
print_warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }

# ── Progress bar theo từng tiến trình ──────────────────────
# Dùng:
#   run_step "Mô tả bước" <command> [args...]
#     → chạy command, hiện thanh chạy, ✅ hoặc ❌ khi xong

_PROG_PID=""

_prog_animate() {
    local title="$1"
    local i=0
    local width=30
    while true; do
        local filled=$(( i % (width + 1) ))
        local bar=""
        [ "$filled" -gt 0 ] && bar=$(printf '█%.0s' $(seq 1 $filled))
        local empty=$(( width - filled ))
        local empty_str=""
        [ "$empty" -gt 0 ] && empty_str=$(printf '░%.0s' $(seq 1 $empty))
        echo -ne "\r  ${CYAN}[${bar}${empty_str}]${NC} ${title}..."
        i=$(( i + 1 ))
        sleep 0.12
    done
}

run_step() {
    local title="$1"; shift
    echo -ne "\n${BOLD}⏳ ${title}${NC}\n"
    _prog_animate "$title" &
    _PROG_PID=$!
    local exit_code=0
    "$@" >> /tmp/greenmind_install.log 2>&1 || exit_code=$?
    kill "$_PROG_PID" 2>/dev/null
    wait "$_PROG_PID" 2>/dev/null
    _PROG_PID=""
    local full_bar
    full_bar=$(printf '█%.0s' $(seq 1 30))
    if [ "$exit_code" -eq 0 ]; then
        echo -e "\r  ${GREEN}[${full_bar}] ✅ ${title}${NC}      "
    else
        local empty_bar
        empty_bar=$(printf '░%.0s' $(seq 1 30))
        echo -e "\r  ${RED}[${empty_bar}] ❌ ${title} (lỗi)${NC}      "
        print_warn "Xem log: tail -20 /tmp/greenmind_install.log"
    fi
    return $exit_code
}

# ── Step header ─────────────────────────────────────────────
show_step() {
    local step=$1 total=$2 title=$3
    echo -e "\n${BOLD}${CYAN}━━━ Bước ${step}/${total}: ${title} ━━━${NC}"
}

# Giữ lại show_progress để tương thích ngược
show_progress() { show_step "$1" "$2" "$3"; }

ask_continue() {
    local msg=${1:-"Tiếp tục?"}
    if [ "$AUTO_MODE" != "1" ]; then
        echo -e "${YELLOW}${msg} [Enter để tiếp tục / Ctrl+C để dừng]${NC}"
        read -r
    fi
}

write_config() {
    local key=$1 val=$2
    mkdir -p "$(dirname $CONFIG_FILE)"
    if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$CONFIG_FILE"
    else
        echo "${key}=${val}" >> "$CONFIG_FILE"
    fi
}
