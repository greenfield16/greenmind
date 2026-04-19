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

show_progress() {
    local step=$1 total=$2 desc=$3
    local pct=$(( step * 100 / total ))
    local filled=$(( step * 30 / total ))
    local bar=$(printf '█%.0s' $(seq 1 $filled))$(printf '░%.0s' $(seq 1 $((30-filled))))
    echo -e "\n${CYAN}[${bar}] ${pct}% — Bước ${step}/${total}: ${desc}${NC}\n"
}

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
