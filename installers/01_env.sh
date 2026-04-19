#!/bin/bash
# 🌿 01_env.sh — Kiểm tra môi trường

echo -e "\n${BOLD}🌿 Greenmind v3.0 — Smart Building AI Platform${NC}"
echo -e "${CYAN}================================================${NC}\n"

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

# Kiểm tra RAM
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ "$RAM_MB" -lt 512 ]; then
    print_warn "RAM thấp (${RAM_MB}MB) — có thể ảnh hưởng hiệu suất"
fi
print_info "RAM: ${RAM_MB}MB"

# Chọn chế độ cài
echo -e "\n${BOLD}Chọn chế độ cài đặt:${NC}"
echo "  1) Tự động (không hỏi xác nhận)"
echo "  2) Từng bước (xác nhận mỗi bước)"
read -rp "Chọn [1/2, mặc định: 1]: " MODE_CHOICE
if [ "$MODE_CHOICE" = "2" ]; then
    export AUTO_MODE=0
    print_info "Chế độ: từng bước"
else
    export AUTO_MODE=1
    print_info "Chế độ: tự động"
fi
