#!/bin/bash
# 🌿 02_role.sh — Chọn vai trò

show_progress 1 6 "Chọn vai trò"

echo -e "\n${BOLD}Chọn vai trò cài đặt:${NC}"
echo "  1) Gateway — Máy chủ trung tâm (AI, Dashboard, Telegram)"
echo "     Yêu cầu: RAM ≥ 2GB, có IP public hoặc domain"
echo ""
echo "  2) Node    — Hub thiết bị tại địa điểm (Camera, Cảm biến, Chấm công...)"
echo "     Yêu cầu: RAM ≥ 512MB, cùng LAN với thiết bị"
echo ""
read -rp "Chọn [1/2]: " ROLE_CHOICE

case "$ROLE_CHOICE" in
    1) export ROLE=gateway; print_success "Vai trò: Gateway" ;;
    2) export ROLE=node;    print_success "Vai trò: Node" ;;
    *) print_error "Lựa chọn không hợp lệ"; exit 1 ;;
esac
