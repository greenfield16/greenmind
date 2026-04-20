#!/bin/bash
# 🌿 02_role.sh — Chọn vai trò

oc_section "Greenmind setup" \
    "Greenmind hoạt động theo mô hình 2 tầng:" \
    "" \
    "  Gateway — Não trung tâm: AI, Dashboard, Telegram bot" \
    "            Phù hợp: VPS, PC, Mac Mini, Raspberry Pi 4" \
    "" \
    "  Node    — Tai mắt hiện trường: Camera, Cảm biến, Relay" \
    "            Phù hợp: Raspberry Pi, Tinkerboard, Orange Pi"

oc_radio "Chọn vai trò cài đặt" ROLE_CHOICE \
    "Gateway  (AI brain, Dashboard, Telegram)" \
    "Node     (Camera, cảm biến, thiết bị)"

case "$ROLE_CHOICE" in
    1) export ROLE=gateway; print_success "Vai trò: Gateway" ;;
    2) export ROLE=node;    print_success "Vai trò: Node" ;;
    *) print_error "Lựa chọn không hợp lệ"; exit 1 ;;
esac
