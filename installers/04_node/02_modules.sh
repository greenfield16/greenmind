#!/bin/bash
# 🌿 04_node/02_modules.sh — Chọn modules
show_progress 3 4 "Chọn modules" "Chọn loại thiết bị sẽ kết nối: Camera, Cảm biến, Chấm công..."
ask_continue

echo -e "\n${BOLD}Chọn modules cần cài (nhập số, cách nhau bởi dấu phẩy):${NC}"
echo "  1) camera   — Camera IP (RTSP), motion detection"
echo "  2) access   — Máy chấm công (ZKTeco, Hikvision DS-K)"
echo "  3) lock     — Khoá thông minh (TTLock, Tuya)"
echo "  4) sensor   — Cảm biến (nhiệt độ, khói, cửa...)"
echo "  5) relay    — Relay/đèn thông minh (Sonoff, Tasmota)"
echo "  6) barrier  — Barrier bãi xe (RS485)"
echo ""
read -rp "Chọn modules [mặc định: 1]: " MOD_CHOICE
MOD_CHOICE=${MOD_CHOICE:-1}

MODULES=""
IFS=',' read -ra CHOICES <<< "$MOD_CHOICE"
for c in "${CHOICES[@]}"; do
    c=$(echo "$c" | tr -d ' ')
    case "$c" in
        1) MODULES="${MODULES}camera," ;;
        2) MODULES="${MODULES}access," ;;
        3) MODULES="${MODULES}lock," ;;
        4) MODULES="${MODULES}sensor," ;;
        5) MODULES="${MODULES}relay," ;;
        6) MODULES="${MODULES}barrier," ;;
    esac
done
MODULES=${MODULES%,}
export SELECTED_MODULES="$MODULES"
print_success "Modules chọn: $MODULES"
