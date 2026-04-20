#!/bin/bash
# 🌿 04_node/03_config.sh
show_progress 4 4 "Cấu hình Node" "Nhập địa chỉ Gateway và Pairing Token để kết nối"
ask_continue

read -rp "Nhập Gateway URL (vd: http://178.128.91.69:8765): " GW_URL
write_config GATEWAY_URL "$GW_URL"

read -rp "Nhập Location ID (vd: nha-rieng, van-phong-01): " LOC_ID
LOC_ID=${LOC_ID:-node}
write_config LOCATION_ID "$LOC_ID"
write_config MODULES "${SELECTED_MODULES:-camera}"
write_config SNAP_INTERVAL 60
write_config MOTION_INTERVAL 30
write_config MOTION_THRESHOLD 0.92
write_config MOTION_COOLDOWN 60

# Cấu hình từng module được chọn
if echo "${SELECTED_MODULES:-camera}" | grep -q "camera"; then
    echo -e "\n${BOLD}Cấu hình Camera:${NC}"
    CAM_NUM=1
    while true; do
        read -rp "Tên camera ${CAM_NUM} (Enter để bỏ qua): " CAM_NAME
        [ -z "$CAM_NAME" ] && break
        read -rp "RTSP URL: " CAM_RTSP
        write_config "CAM$(printf '%02d' $CAM_NUM)_NAME" "$CAM_NAME"
        write_config "CAM$(printf '%02d' $CAM_NUM)_RTSP" "$CAM_RTSP"
        CAM_NUM=$((CAM_NUM+1))
    done
fi

# Tải node code
BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
mkdir -p "$INSTALL_DIR/node/modules"
curl -fsSL "$BASE_URL/node/node_main.py" -o "$INSTALL_DIR/node/node_main.py"
for mod in camera access lock sensor relay barrier; do
    curl -fsSL "$BASE_URL/node/modules/${mod}.py" -o "$INSTALL_DIR/node/modules/${mod}.py"
done
touch "$INSTALL_DIR/node/modules/__init__.py"

print_success "Node config xong"
