#!/bin/bash
# 🌿 01_env.sh — Banner + kiểm tra môi trường

clear
echo -e "${GREEN}${BOLD}"
echo "    ██████╗ ██████╗ ███████╗███████╗███╗   ██╗███╗   ███╗██╗███╗   ██╗██████╗ "
echo "   ██╔════╝ ██╔══██╗██╔════╝██╔════╝████╗  ██║████╗ ████║██║████╗  ██║██╔══██╗"
echo "   ██║  ███╗██████╔╝█████╗  █████╗  ██╔██╗ ██║██╔████╔██║██║██╔██╗ ██║██║  ██║"
echo "   ██║   ██║██╔══██╗██╔══╝  ██╔══╝  ██║╚██╗██║██║╚██╔╝██║██║██║╚██╗██║██║  ██║"
echo "   ╚██████╔╝██║  ██║███████╗███████╗██║ ╚████║██║ ╚═╝ ██║██║██║ ╚████║██████╔╝"
echo "    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═══╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═════╝ "
echo -e "${NC}"
echo -e "  ${CYAN}${BOLD}Smart Building AI Platform${NC}  ${DIM}v3.1 by Greenfield Tech${NC}"
echo -e "  ${DIM}──────────────────────────────────────────────────${NC}"
echo ""

# Kiểm tra root
if [ "$EUID" -ne 0 ]; then
    print_error "Cần chạy với quyền root: sudo bash greenmind_install.sh"
    exit 1
fi

# Kiểm tra OS
if ! command -v apt-get &>/dev/null; then
    print_error "Chỉ hỗ trợ Ubuntu/Debian"
    exit 1
fi

# System info
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
DISK_FREE=$(df -h / | awk 'NR==2{print $4}')
OS_NAME=$(. /etc/os-release && echo "$PRETTY_NAME")
HOST=$(hostname)

echo -e "  ${BOLD}Thông tin hệ thống:${NC}"
echo -e "  ${DIM}  OS      :${NC} $OS_NAME"
echo -e "  ${DIM}  Host    :${NC} $HOST"
echo -e "  ${DIM}  RAM     :${NC} ${RAM_MB}MB"
echo -e "  ${DIM}  CPU     :${NC} ${CPU_CORES} cores"
echo -e "  ${DIM}  Disk    :${NC} ${DISK_FREE} trống"
echo ""

# Check RAM
if [ "$RAM_MB" -lt 512 ]; then
    print_warn "RAM thấp (${RAM_MB}MB) — có thể ảnh hưởng hiệu suất"
fi

# Check internet
if ! curl -fsSL --connect-timeout 5 https://github.com > /dev/null 2>&1; then
    print_error "Không có kết nối internet"
    exit 1
fi
print_success "Kết nối internet OK"
