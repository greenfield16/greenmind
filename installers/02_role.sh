#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 2: Chọn vai trò Gateway / Node
# =================================================================

select_node_role() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] VAI TRÒ CỦA MÁY NÀY${NC}"
    echo ""
    echo -e "  ${BLUE}1)${NC} 🌐 Gateway  — Não chính: cài đầy đủ AI, kết nối Telegram/WhatsApp"
    echo -e "               Phù hợp: Mac Mini, VPS, PC"
    echo -e "  ${BLUE}2)${NC} 📡 Node     — Tai mắt: cài nhẹ, chuyên camera/cảm biến/relay"
    echo -e "               Phù hợp: Tinkerboard, Raspberry Pi, máy yếu"
    echo ""
    read -p "👉 Chọn vai trò (1/2, mặc định 1): " role_choice </dev/tty
    case "$role_choice" in
        2)
            export NODE_ROLE="node"
            echo -e "${GREEN} [✓] Chế độ NODE — Sẽ bỏ qua cài AI Engine nặng.${NC}"
            read -p "Nhập IP/Domain của Gateway (VD: 192.168.1.100 hoặc myhome.ddns.net): " GATEWAY_ADDR </dev/tty
            read -p "Nhập Pairing Token từ Gateway: " GATEWAY_TOKEN </dev/tty
            export GATEWAY_ADDR GATEWAY_TOKEN
            ;;
        *)
            export NODE_ROLE="gateway"
            echo -e "${GREEN} [✓] Chế độ GATEWAY — Cài đầy đủ.${NC}"
            ;;
    esac
    echo ""
}
