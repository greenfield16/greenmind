#!/bin/bash
# 🌿 Greenmind v3.1 — Common utilities

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'
MAGENTA='\033[0;35m'; NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

INSTALL_DIR=/opt/greenmind
CONFIG_FILE=/etc/greenmind/config.env
AUTO_MODE=0

# ── Print helpers ────────────────────────────────────────────
print_info()    { echo -e "  ${CYAN}ℹ  $1${NC}"; }
print_success() { echo -e "  ${GREEN}✔  $1${NC}"; }
print_error()   { echo -e "  ${RED}✘  $1${NC}"; }
print_warn()    { echo -e "  ${YELLOW}⚠  $1${NC}"; }

# ── Section header ───────────────────────────────────────────
section_header() {
    local step=$1 total=$2 title=$3 desc="${4:-}"
    echo ""
    echo -e "${BOLD}${CYAN}  ┌─────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}  │  [$step/$total]  $title$(printf '%*s' $((39 - ${#title} - ${#step} - ${#total} - 6)) '')│${NC}"
    echo -e "${BOLD}${CYAN}  └─────────────────────────────────────────┘${NC}"
    [ -n "$desc" ] && echo -e "  ${DIM}$desc${NC}"
}
show_step()     { section_header "$1" "$2" "$3" "${4:-}"; }
show_progress() { section_header "$1" "$2" "$3" "${4:-}"; }

# ── Spinner + run_step ───────────────────────────────────────
_SPIN_PID=""
_SPIN_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

_spin_animate() {
    local title="$1"
    local i=0
    while true; do
        local c="${_SPIN_CHARS:$((i % 10)):1}"
        echo -ne "\r  ${CYAN}${c}${NC}  ${title}..."
        i=$((i + 1))
        sleep 0.1
    done
}

run_step() {
    local title="$1"; shift
    _spin_animate "$title" &
    _SPIN_PID=$!
    local exit_code=0
    "$@" >> /tmp/greenmind_install.log 2>&1 || exit_code=$?
    kill "$_SPIN_PID" 2>/dev/null
    wait "$_SPIN_PID" 2>/dev/null
    _SPIN_PID=""
    if [ "$exit_code" -eq 0 ]; then
        echo -e "\r  ${GREEN}✔${NC}  ${title}$(printf '%*s' 5 '')${NC}"
    else
        echo -e "\r  ${YELLOW}⚠${NC}  ${title} (bỏ qua lỗi)$(printf '%*s' 5 '')${NC}"
        print_warn "Xem log: tail -20 /tmp/greenmind_install.log"
    fi
    return 0  # Không exit khi lỗi
}

# ── Input helpers ────────────────────────────────────────────
prompt_input() {
    # Usage: prompt_input "Tên biến" "Câu hỏi" "default"
    local __var="$1" msg="$2" default="${3:-}"
    local input
    if [ -n "$default" ]; then
        echo -ne "\n  ${BOLD}${msg}${NC} ${DIM}[${default}]${NC}: "
    else
        echo -ne "\n  ${BOLD}${msg}${NC}: "
    fi
    read -r input
    [ -z "$input" ] && input="$default"
    eval "$__var='$input'"
}

prompt_confirm() {
    # Usage: prompt_confirm "Câu hỏi?" [Y/n]
    local msg="$1" default="${2:-Y}"
    local yn
    echo -ne "\n  ${BOLD}${msg}${NC} ${DIM}[${default}]${NC}: "
    read -r yn
    [ -z "$yn" ] && yn="$default"
    [[ "$yn" =~ ^[Yy] ]]
}

ask_continue() {
    echo -ne "\n  ${DIM}Nhấn Enter để tiếp tục...${NC}"
    read -r
}

# ── Config helpers ───────────────────────────────────────────
write_config() {
    local key=$1 val=$2
    mkdir -p "$(dirname $CONFIG_FILE)"
    if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$CONFIG_FILE"
    else
        echo "${key}=${val}" >> "$CONFIG_FILE"
    fi
}
