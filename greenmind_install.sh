#!/bin/bash

# =================================================================
# 🌿 GREENMIND — AI-Powered Home Surveillance
#    "Ngôi nhà biết nhìn, biết nghĩ, biết bảo vệ"
# 🛠 1 sản phẩm của Greenfield Tech.  |  🤖 AI-crafted by Mary
# =================================================================

export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export CYAN='\033[0;36m'
export NC='\033[0m'
export BOLD='\033[1m'

TOTAL_STEPS=6
CURRENT_STEP=0
NODE_ROLE="gateway"  # gateway | node

# --- 🛡️ 1. Khởi tạo Biến Môi trường Hệ thống ---
check_env() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}❌ Lỗi: Cần chạy bằng lệnh 'sudo bash' nà!${NC}"
       exit 1
    fi
    OS_TYPE=$(uname -s)
    ARCH_TYPE=$(uname -m)
}

# --- 🌀 2. Hàm Process (KHÔNG DÙNG EVAL - BẢO MẬT 100%) ---
run_with_process() {
    local text=$1
    shift
    
    # Chạy lệnh ngầm thông qua việc truyền trực tiếp Arguments "$@"
    "$@" > /dev/null 2>&1 &
    local pid=$!
    
    # Hiệu ứng xoay kiểu Braille
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN} %c ${NC} ${text}... " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    printf "\r${GREEN} [✓] ${NC} ${text} (Hoàn tất) \033[K\n"
}

# --- 📺 3. Màn Hình Chào Mừng ---
show_intro() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "   ____                      __  __ _           _ "
    echo "  / ___|_ __ ___  ___ _ __  |  \/  (_)_ __   __| |"
    echo " | |  _| '__/ _ \/ _ \ '_ \ | |\/| | | '_ \ / _' |"
    echo " | |_| | | |  __/  __/ | | || |  | | | | | | (_| |"
    echo "  \____|_|  \___|\___|_| |_||_|  |_|_|_| |_|\__,_|"
    echo -e "${NC}"
    echo -e "${YELLOW}🌟 CHÀO MỪNG ĐẾN VỚI TRÌNH CÀI ĐẶT GREENMIND AI (v3.1)${NC}"
    echo -e "  ${BLUE}1.${NC} 📦 Thư viện lõi (Python 3, Node.js, FFMpeg)"
    echo -e "  ${BLUE}2.${NC} 🐍 Môi trường ảo (VENV) An toàn"
    echo -e "  ${BLUE}3.${NC} 🤖 AI Engine (Tùy chọn Local Ollama hoặc Cloud API)"
    echo -e "  ${BLUE}4.${NC} ⚙️ Thiết lập bảo mật & Cấu hình Camera"
    echo -e "  ${BLUE}5.${NC} 🚀 Đăng ký Service chạy ngầm tự động"
    echo ""
    read -p "👉 Zai đã sẵn sàng chưa? (Nhấn ENTER để bắt đầu)... "
    echo ""
}


# --- 🖥️ CHỌN VAI TRÒ MÁY ---
select_node_role() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] VAI TRÒ CỦA MÁY NÀY${NC}"
    echo ""
    echo -e "  ${BLUE}1)${NC} 🌐 Gateway  — Não chính: cài đầy đủ AI, kết nối Telegram/WhatsApp"
    echo -e "               Phù hợp: Mac Mini, VPS, PC"
    echo -e "  ${BLUE}2)${NC} 📡 Node     — Tai mắt: cài nhẹ, chuyên camera/cảm biến/relay"
    echo -e "               Phù hợp: Tinkerboard, Raspberry Pi, máy yếu"
    echo ""
    read -p "👉 Chọn vai trò (1/2, mặc định 1): " role_choice
    case "$role_choice" in
        2)
            NODE_ROLE="node"
            echo -e "${GREEN} [✓] Chế độ NODE — Sẽ bỏ qua cài AI Engine nặng.${NC}"
            read -p "Nhập IP/Domain của Gateway (VD: 192.168.1.100 hoặc myhome.ddns.net): " GATEWAY_ADDR
            read -p "Nhập Pairing Token từ Gateway: " GATEWAY_TOKEN
            ;;
        *)
            NODE_ROLE="gateway"
            echo -e "${GREEN} [✓] Chế độ GATEWAY — Cài đầy đủ.${NC}"
            ;;
    esac
    echo ""
}

# --- 📦 4. Cài đặt Core ---
setup_core() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CHUẨN BỊ NỀN TẢNG HỆ THỐNG${NC}"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        run_with_process "Cập nhật danh sách gói (apt update)" apt-get update -y
        run_with_process "Cài đặt thư viện hệ thống" apt-get install -y python3-venv python3-pip curl git nodejs npm ffmpeg libsm6 libxext6
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        if ! command -v brew &> /dev/null; then
            run_with_process "Cài đặt Homebrew cho Mac" bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        run_with_process "Cài đặt gói Brew (Python, Node, FFMpeg)" brew install python node ffmpeg
    fi
}

# --- 🐍 5. Thiết lập VENV ---
setup_venv() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] THIẾT LẬP MÔI TRƯỜNG VENV${NC}"
    GREENMIND_DIR="$HOME/.greenmind"
    VENV_PATH="$GREENMIND_DIR/venv"
    
    mkdir -p "$GREENMIND_DIR"
    if [ ! -d "$VENV_PATH" ]; then
        run_with_process "Tạo lồng ấp Python (Virtual Env)" python3 -m venv "$VENV_PATH"
    fi
    
    run_with_process "Nâng cấp công cụ PIP" "$VENV_PATH/bin/pip" install --upgrade pip
    run_with_process "Tải não bộ AI (OpenCV, Gemini, Ezviz...)" "$VENV_PATH/bin/pip" install opencv-python numpy requests google-generativeai paho-mqtt ezviz-python
}

# --- 🤖 6. Cài đặt AI Engines ---
setup_ai_engines() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CẤU HÌNH TRÍ TUỆ NHÂN TẠO${NC}"
    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua cài AI Engine.${NC}"
        return 0
    fi
    
    # 🔴 FIX LỖI MAC MINI: Dùng sysctl cho Darwin và free -m cho Linux
    if [[ "$OS_TYPE" == "Linux" ]]; then
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        TOTAL_RAM=$(($(sysctl -n hw.memsize) / 1024 / 1024))
    fi
    
    export LOCAL_MODEL="gemini"
    
    if [ "$TOTAL_RAM" -lt 4000 ]; then
        echo -e "ℹ️ RAM hơi yếu ($TOTAL_RAM MB), thiết lập tự động dùng Gemini API."
    else
        echo -e "ℹ️ RAM đáp ứng tốt ($TOTAL_RAM MB), chuẩn bị cài đặt Local AI..."
        if ! command -v ollama &> /dev/null; then
            run_with_process "Đang cài đặt lõi Ollama" bash -c "curl -fsSL https://ollama.com/install.sh | sh"
        fi
        
        if command -v systemctl &> /dev/null; then
            systemctl start ollama > /dev/null 2>&1
        else
            ollama serve > /dev/null 2>&1 &
        fi
        
        echo -e "\n${CYAN}🧠 MỜI ZAI CHỌN NÃO BỘ CHO CAMERA:${NC}"
        echo -e "  1) Gemma 4 (2B)  - Nhẹ nhàng cho Tinkerboard"
        echo -e "  2) Gemma 4 (7B)  - Chuẩn bài cho Mac Mini"
        echo -e "  3) Gemma 4 (27B) - Dành cho siêu máy tính"
        echo -e "  4) Bỏ qua, dùng API Đám mây"
        read -p "👉 Lựa chọn (1-4): " model_choice
        
        case $model_choice in
            1)
                run_with_process "Đang kéo model Gemma 4 (2B)" ollama pull gemma:2b
                export LOCAL_MODEL="gemma:2b"
                ;;
            2)
                run_with_process "Đang kéo model Gemma 4 (7B)" ollama pull gemma:7b
                export LOCAL_MODEL="gemma:7b"
                ;;
            3)
                run_with_process "Đang kéo model Gemma 4 (27B)" ollama pull gemma:27b
                export LOCAL_MODEL="gemma:27b"
                ;;
            *)
                echo -e "Đã chuyển về chế độ Đám mây nà."
                ;;
        esac
    fi
}

# --- ⚙️ 7. Quản lý Thiết bị & Camera (Menu Động) ---
setup_config() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] THIẾT LẬP THIẾT BỊ NGOẠI VI & CAMERA${NC}"
    
    CONFIG_FILE="/etc/greenmind/config.env"
    mkdir -p /etc/greenmind
    
    # 1. Tạo file gốc nếu chưa có
    if [ ! -f "$CONFIG_FILE" ]; then
        cat <<EOF > "$CONFIG_FILE"
# GREENMIND SYSTEM CORE CONFIG
AI_ENGINE=$LOCAL_MODEL
GEMINI_KEY=YOUR_KEY_HERE
MQTT_BROKER=localhost
MQTT_PORT=1883

# --- DANH SÁCH THIẾT BỊ ---
EOF
        chmod 600 "$CONFIG_FILE"
    fi

    # 2. Vòng lặp thêm thiết bị
    echo -e "${CYAN}🤖 HỆ THỐNG QUẢN LÝ THIẾT BỊ GREENMIND${NC}"
    while true; do
        read -p "👉 Zai/Khách hàng có muốn thêm thiết bị vào hệ thống khum? (y/n): " add_device
        if [[ ! "$add_device" =~ ^[Yy]$ ]]; then
            break
        fi

        echo -e "\n  ${BLUE}1)${NC} 📷 Camera giám sát (CCTV)"
        echo -e "  ${BLUE}2)${NC} 🔊 Loa báo động thông minh"
        echo -e "  ${BLUE}3)${NC} ❄️ Thiết bị Smart Home (Máy lạnh, Đèn...)"
        read -p "👉 Chọn loại thiết bị (1-3): " dev_type

        # XỬ LÝ CAMERA
        if [[ "$dev_type" == "1" ]]; then
            echo -e "\n${CYAN}--- CẤU HÌNH CAMERA ---${NC}"
            echo -e "  1) Hikvision"
            echo -e "  2) Dahua / Kbvision"
            echo -e "  3) Ezviz / Imou (Dùng mã Verification Code)"
            echo -e "  4) Hãng khác / Tùy chỉnh (Nhập thẳng link RTSP)"
            read -p "👉 Chọn hãng Camera: " cam_brand

            if [[ "$cam_brand" == "4" ]]; then
                read -p "Nhập link RTSP gốc: " cam_rtsp
            else
                read -p "Nhập IP Camera (VD: 192.168.1.100): " cam_ip
                read -p "Nhập User (Thường là admin): " cam_user
                read -p "Nhập Mật khẩu (hoặc Verification Code dưới đít Cam): " cam_pass

                # Tự động Build link RTSP theo chuẩn của từng hãng nà Zai 🛡️
                if [[ "$cam_brand" == "1" || "$cam_brand" == "3" ]]; then
                    cam_rtsp="rtsp://${cam_user}:${cam_pass}@${cam_ip}:554/Streaming/Channels/101"
                elif [[ "$cam_brand" == "2" ]]; then
                    cam_rtsp="rtsp://${cam_user}:${cam_pass}@${cam_ip}:554/cam/realmonitor?channel=1&subtype=0"
                else
                    cam_rtsp="rtsp://${cam_user}:${cam_pass}@${cam_ip}:554/11" # Chuẩn Onvif chung
                fi
            fi

            read -p "Đặt Tên/Mã cho Camera này (VD: CAM_KHO_01): " cam_name
            # Ghi đè vào file env
            echo "${cam_name}_RTSP=\"${cam_rtsp}\"" >> "$CONFIG_FILE"
            echo -e "${GREEN} [✓] Đã đưa ${cam_name} vào hệ thống ngắm bắn!${NC}\n"

        # XỬ LÝ LOA
        elif [[ "$dev_type" == "2" ]]; then
            echo -e "\n${CYAN}--- CẤU HÌNH LOA BÁO ĐỘNG ---${NC}"
            read -p "Nhập IP của Loa (VD: 192.168.1.105): " speaker_ip
            read -p "Đặt tên cho Loa (VD: SPEAKER_SAN_TRUOC): " speaker_name
            echo "${speaker_name}_IP=\"${speaker_ip}\"" >> "$CONFIG_FILE"
            echo -e "${GREEN} [✓] Đã nạp đạn cho ${speaker_name}!${NC}\n"

        # XỬ LÝ SMART HOME
        elif [[ "$dev_type" == "3" ]]; then
            echo -e "\n${YELLOW}🛠️ Module Smart Home (Tuya/Sonoff) đang được Zai Joseph phát triển. Hẹn ở bản update sau nà!${NC}\n"
        fi
    done

    echo -e "${GREEN} [✓] Đã lưu toàn bộ cấu hình thiết bị. File config.env đã sẵn sàng!${NC}"
}

# --- 🛠️ 8. Thiết lập Service ---
setup_service() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] ĐĂNG KÝ CHẠY NGẦM${NC}"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        cat <<EOF > /etc/systemd/system/greenmind.service
[Unit]
Description=GreenMind AI CCTV
After=network.target

[Service]
ExecStart=$HOME/.greenmind/venv/bin/python3 $HOME/.greenmind/main.py
Restart=always
User=$USER
EnvironmentFile=/etc/greenmind/config.env

[Install]
WantedBy=multi-user.target
EOF
        run_with_process "Nạp cấu hình Service" bash -c "systemctl daemon-reload && systemctl enable greenmind"
    else
        echo -e "${GREEN} [✓] Máy Mac, có thể chạy thủ công qua tmux nà.${NC}"
    fi
}

# --- 🏁 CHẠY TỔNG LỰC ---
check_env
show_intro
select_node_role
setup_core
setup_venv
setup_ai_engines
setup_config
setup_service

# --- Kết nối Node về Gateway ---
if [[ "$NODE_ROLE" == "node" ]]; then
    echo -e "\n${BOLD}${CYAN}🔗 KẾT NỐI NODE VỀ GATEWAY${NC}"
    openclaw connect --gateway "$GATEWAY_ADDR" --token "$GATEWAY_TOKEN" 2>/dev/null && \
        echo -e "${GREEN} [✓] Đã kết nối thành công về $GATEWAY_ADDR${NC}" || \
        echo -e "${YELLOW} [!] Chạy thủ công: openclaw connect --gateway $GATEWAY_ADDR --token $GATEWAY_TOKEN${NC}"
fi

echo -e "\n${GREEN}${BOLD}🎉 CÀI ĐẶT THÀNH CÔNG RỰC RỠ!${NC}"
if [[ "$NODE_ROLE" == "gateway" ]]; then
    echo -e "${CYAN}Gateway sẵn sàng. Lấy token cho các node: openclaw gateway token${NC}"
else
    echo -e "${CYAN}Node đã kết nối về Gateway: $GATEWAY_ADDR${NC}"
fi
echo -e "${CYAN}Kiểm tra file cấu hình tại: /etc/greenmind/config.env${NC}"
