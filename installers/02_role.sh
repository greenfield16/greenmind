#!/bin/bash
# 🌿 02_role.sh — Chọn vai trò

echo ""
echo -e "  ${BOLD}Chọn vai trò cài đặt:${NC}"
echo ""
echo -e "  ${GREEN}${BOLD}  1) Gateway${NC}  — Não trung tâm (AI, Dashboard, Telegram)"
echo -e "  ${DIM}              Yêu cầu: RAM ≥ 2GB · Có IP/domain public${NC}"
echo -e "  ${DIM}              Phù hợp: VPS, PC, Mac Mini, Raspberry Pi 4${NC}"
echo ""
echo -e "  ${CYAN}${BOLD}  2) Node${NC}     — Tai mắt tại hiện trường (Camera, Cảm biến)"
echo -e "  ${DIM}              Yêu cầu: RAM ≥ 512MB · Cùng LAN với thiết bị${NC}"
echo -e "  ${DIM}              Phù hợp: Raspberry Pi, Tinkerboard, Orange Pi${NC}"
echo ""
read -rp "  Chọn [1/2]: " ROLE_CHOICE

case "$ROLE_CHOICE" in
    1) export ROLE=gateway; print_success "Vai trò: Gateway" ;;
    2) export ROLE=node;    print_success "Vai trò: Node" ;;
    *) print_error "Lựa chọn không hợp lệ"; exit 1 ;;
esac
