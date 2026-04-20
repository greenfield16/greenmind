#!/bin/bash
# 🌿 Greenmind v3.1 — Common utilities (OpenClaw-style)

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'
GREEN=\033[0;32m
ORANGE=\033[0;33m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'

INSTALL_DIR=/opt/greenmind
CONFIG_FILE=/etc/greenmind/config.env
AUTO_MODE=0

# ── OpenClaw-style section ────────────────────────────────────
# Usage: oc_section "Tiêu đề" "nội dung dòng 1" "nội dung dòng 2" ...
oc_section() {
    local title="$1"; shift
    echo ""
    echo -e "${GREEN}${BOLD}◆ ${title}${NC}"
    echo -e "  ${DIM}│${NC}"
    for line in "$@"; do
        if [ -z "$line" ]; then
            echo -e "  ${DIM}│${NC}"
        else
            echo -e "  ${DIM}│${NC}  ${line}"
        fi
    done
    echo -e "  ${DIM}│${NC}"
}

# ── OpenClaw-style confirm ────────────────────────────────────
# Usage: oc_confirm "Câu hỏi?" → trả về 0 nếu yes
oc_confirm() {
    local msg="$1"
    echo ""
    echo -e "${GREEN}◇ ${WHITE}${msg}${NC}"
    echo -ne "  ${DIM}Yes${NC} / No: "
    local yn
    read -r yn
    [[ -z "$yn" || "$yn" =~ ^[Yy] ]]
}

# ── OpenClaw-style radio select ───────────────────────────────
# Usage: oc_radio "Câu hỏi" VAR_NAME "Option 1" "Option 2" ...
# Sets VAR_NAME to 1-based index of chosen option
oc_radio() {
    local msg="$1" varname="$2"; shift 2
    local options=("$@")
    local selected=0

    echo ""
    echo -e "${GREEN}◇ ${WHITE}${msg}${NC}"
    echo ""
    for i in "${!options[@]}"; do
        if [ "$i" -eq "$selected" ]; then
            echo -e "  ${GREEN}●${NC} ${WHITE}${options[$i]}${NC}"
        else
            echo -e "  ${DIM}○ ${options[$i]}${NC}"
        fi
    done
    echo ""
    echo -ne "  ${DIM}Chọn [1-${#options[@]}]:${NC} "
    local choice
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
        eval "$varname=$choice"
    else
        eval "$varname=1"
    fi
}

# ── OpenClaw-style text input ─────────────────────────────────
# Usage: oc_input "Câu hỏi" VAR_NAME "default"
oc_input() {
    local msg="$1" varname="$2" default="${3:-}"
    echo ""
    if [ -n "$default" ]; then
        echo -e "${GREEN}◇ ${WHITE}${msg}${NC} ${DIM}(mặc định: ${default})${NC}"
    else
        echo -e "${GREEN}◇ ${WHITE}${msg}${NC}"
    fi
    echo -ne "  "
    local val
    read -r val
    [ -z "$val" ] && val="$default"
    eval "$varname='$val'"
}

# ── Step indicator ────────────────────────────────────────────
show_step() {
    local step=$1 total=$2 title=$3 desc="${4:-}"
    echo ""
    echo -e "${GREEN}${BOLD}◆ ${title}${NC}  ${DIM}[${step}/${total}]${NC}"
    [ -n "$desc" ] && echo -e "  ${DIM}${desc}${NC}"
    echo ""
}

# ── Print helpers ─────────────────────────────────────────────
print_info()    { echo -e "  ${CYAN}ℹ  $1${NC}"; }
print_success() { echo -e "  ${GREEN}✔  $1${NC}"; }
print_error()   { echo -e "  ${RED}✘  $1${NC}"; }
print_warn()    { echo -e "  ${YELLOW}⚠  $1${NC}"; }

# ── Spinner ───────────────────────────────────────────────────
_SPIN_PID=""
_SPIN_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

_spin_animate() {
    local title="$1"
    local i=0
    while true; do
        local c="${_SPIN_CHARS:$((i % 10)):1}"
        echo -ne "\r  ${GREEN}${c}${NC}  ${title}..."
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
        echo -e "\r  ${GREEN}✔${NC}  ${title}$(printf '%*s' 10 '')${NC}"
    else
        echo -e "\r  ${YELLOW}⚠${NC}  ${title} ${DIM}(bỏ qua lỗi)${NC}$(printf '%*s' 5 '')${NC}"
    fi
    return 0
}

# ── Config helpers ────────────────────────────────────────────
write_config() {
    local key=$1 val=$2
    mkdir -p "$(dirname $CONFIG_FILE)"
    if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$CONFIG_FILE"
    else
        echo "${key}=${val}" >> "$CONFIG_FILE"
    fi
}
