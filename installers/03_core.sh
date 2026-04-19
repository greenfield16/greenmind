#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 3: Cài đặt Core Packages
# =================================================================

setup_core() {
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CHUẨN BỊ NỀN TẢNG HỆ THỐNG${NC}"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        run_with_process "Cập nhật danh sách gói (apt update)" apt-get update -y
        run_with_process "Cài đặt thư viện hệ thống" apt-get install -y \
            python3-venv python3-pip curl git nodejs npm ffmpeg \
            libsm6 libxext6 mosquitto mosquitto-clients
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        if ! command -v brew &> /dev/null; then
            run_with_process "Cài đặt Homebrew" bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        run_with_process "Cài đặt gói Brew (Python, Node, FFMpeg, Mosquitto)" \
            brew install python node ffmpeg mosquitto
    fi

    # Khởi động MQTT broker
    if command -v systemctl &> /dev/null; then
        systemctl enable mosquitto > /dev/null 2>&1
        systemctl start  mosquitto > /dev/null 2>&1
    fi
    echo -e "${GREEN} [✓] MQTT Broker (Mosquitto) đã sẵn sàng.${NC}"
}
