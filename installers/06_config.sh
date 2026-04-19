#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 6: Cấu hình Camera & Thiết bị
# =================================================================

setup_config() {
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] THIẾT LẬP THIẾT BỊ & CAMERA${NC}"

    mkdir -p /etc/greenmind
    if [ ! -f "$CONFIG_FILE" ]; then
        cat <<EOF > "$CONFIG_FILE"
# GREENMIND SYSTEM CORE CONFIG
# =================================================================
# AI ENGINE: gemini | nvidia | ollama model name
AI_ENGINE=$LOCAL_MODEL

# Gemini API Key — https://aistudio.google.com/app/apikey
GEMINI_KEY=YOUR_GEMINI_KEY

# NVIDIA NIM API Key — https://build.nvidia.com/google/gemma-4-31b-it
NVIDIA_KEY=YOUR_NVIDIA_KEY

MQTT_BROKER=localhost
MQTT_PORT=1883
FRIGATE_URL=http://localhost:5000
TELEGRAM_TOKEN=
TELEGRAM_CHAT_ID=

# --- DANH SÁCH THIẾT BỊ ---
EOF
        chmod 600 "$CONFIG_FILE"
    fi

    echo -e "${CYAN}🤖 QUẢN LÝ THIẾT BỊ${NC}"
    while true; do
        read -p "👉 Thêm thiết bị vào hệ thống? (y/n): " add_device </dev/tty
        [[ ! "$add_device" =~ ^[Yy]$ ]] && break

        echo -e "\n  ${BLUE}1)${NC} 📷 Camera (CCTV)"
        echo -e "  ${BLUE}2)${NC} 🔊 Loa báo động"
        echo -e "  ${BLUE}3)${NC} ❄️  Smart Home (Tuya/Sonoff)"
        read -p "👉 Chọn loại (1-3): " dev_type </dev/tty

        if [[ "$dev_type" == "1" ]]; then
            echo -e "\n${CYAN}--- CẤU HÌNH CAMERA ---${NC}"
            echo -e "  1) Hikvision  2) Dahua/Kbvision  3) Ezviz/Imou  4) RTSP thủ công"
            read -p "👉 Hãng camera: " cam_brand </dev/tty

            if [[ "$cam_brand" == "4" ]]; then
                read -p "Nhập link RTSP: " cam_rtsp </dev/tty
            else
                read -p "IP Camera: " cam_ip </dev/tty
                read -p "Username (mặc định admin): " cam_user </dev/tty
                cam_user="${cam_user:-admin}"
                read -p "Password / Verification Code: " cam_pass </dev/tty
                case "$cam_brand" in
                    1|3) cam_rtsp="rtsp://${cam_user}:${cam_pass}@${cam_ip}:554/Streaming/Channels/101" ;;
                    2)   cam_rtsp="rtsp://${cam_user}:${cam_pass}@${cam_ip}:554/cam/realmonitor?channel=1&subtype=0" ;;
                    *)   cam_rtsp="rtsp://${cam_user}:${cam_pass}@${cam_ip}:554/11" ;;
                esac
            fi

            read -p "Tên camera (VD: CAM_KHO_01): " cam_name </dev/tty
            cam_name=$(echo "$cam_name" | tr '[:lower:]' '[:upper:]' | tr ' ' '_')
            echo "${cam_name}_RTSP=\"${cam_rtsp}\"" >> "$CONFIG_FILE"
            echo -e "${GREEN} [✓] Đã thêm ${cam_name}!${NC}\n"

        elif [[ "$dev_type" == "2" ]]; then
            read -p "IP Loa: " speaker_ip </dev/tty
            read -p "Tên Loa (VD: SPEAKER_01): " speaker_name </dev/tty
            echo "${speaker_name}_IP=\"${speaker_ip}\"" >> "$CONFIG_FILE"
            echo -e "${GREEN} [✓] Đã thêm ${speaker_name}!${NC}\n"

        elif [[ "$dev_type" == "3" ]]; then
            echo -e "${YELLOW}🛠️  Module Smart Home đang phát triển — sẽ có ở bản sau!${NC}\n"
        fi
    done

    echo -e "${GREEN} [✓] Cấu hình lưu tại: $CONFIG_FILE${NC}"
}
