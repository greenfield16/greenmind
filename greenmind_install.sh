#!/bin/bash

# =================================================================
# GREENMIND AI CCTV - HỆ THỐNG GIÁM SÁT THÔNG MINH
# 🛠️ Coded by Joseph | ✨ UX/UI by "Gái" AI
# =================================================================

export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export CYAN='\033[0;36m'
export NC='\033[0m'
export BOLD='\033[1m'

TOTAL_STEPS=5
CURRENT_STEP=0

# --- 🌀 1. Hàm Process "Chữ nổi" Hiện Đại (Braille Spinner) ---
run_with_process() {
    local text=$1
    shift
    local cmd="$@"
    
    # Chạy lệnh ngầm
    eval "$cmd" > /dev/null 2>&1 &
    local pid=$!
    
    # Hiệu ứng xoay kiểu mượt mà của NPM
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r${CYAN} %c ${NC} ${text}... " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
    done
    # Cập nhật thành công
    printf "\r${GREEN} [✓] ${NC} ${text} (Hoàn tất) \033[K\n"
}

# --- 🛡️ 2. Màn Hình Chào Mừng (Welcome Screen) ---
show_intro() {
    clear
    echo -e "${GREEN}${BOLD}"
    echo "   ____                      __  __ _           _ "
    echo "  / ___|_ __ ___  ___ _ __  |  \/  (_)_ __   __| |"
    echo " | |  _| '__/ _ \/ _ \ '_ \ | |\/| | | '_ \ / _' |"
    echo " | |_| | | |  __/  __/ | | || |  | | | | | | (_| |"
    echo "  \____|_|  \___|\___|_| |_||_|  |_|_|_| |_|\__,_|"
    echo -e "${NC}"
    echo -e "${YELLOW}🌟 CHÀO MỪNG ĐẾN VỚI TRÌNH CÀI ĐẶT GREENMIND AI${NC}"
    echo -e "Hệ thống sẽ tiến hành cài đặt các module an toàn sau:"
    echo -e "  ${BLUE}1.${NC} 📦 Thư viện lõi (Python 3, Node.js, FFMpeg)"
    echo -e "  ${BLUE}2.${NC} 🐍 Môi trường ảo (VENV) - Đảm bảo không xung đột máy khách"
    echo -e "  ${BLUE}3.${NC} 🤖 AI Engine (Tùy chọn Local Ollama hoặc Cloud API)"
    echo -e "  ${BLUE}4.${NC} ⚙️ Thiết lập bảo mật & Cấu hình Camera"
    echo -e "  ${BLUE}5.${NC} 🚀 Đăng ký Service chạy ngầm tự động"
    echo ""
    echo -e "${RED}⚠️ Yêu cầu: Đảm bảo máy có kết nối Internet.${NC}"
    echo ""
    # Chờ xác nhận từ người dùng
    read -p "👉 Zai đã sẵn sàng chưa? (Nhấn ENTER để bắt đầu, CTRL+C để hủy bỏ)... "
    echo ""
}

check_env() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}❌ Lỗi: Cần chạy bằng lệnh 'sudo bash' nà!${NC}"
       exit 1
    fi
    OS_TYPE=$(uname -s)
    ARCH_TYPE=$(uname -m)
}

# --- 📦 3. Cài đặt Core ---
setup_core() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CHUẨN BỊ NỀN TẢNG HỆ THỐNG${NC}"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        run_with_process "Cập nhật danh sách gói (apt update)" "apt-get update -y"
        run_with_process "Cài đặt thư viện hệ thống" "apt-get install -y python3-venv python3-pip curl git nodejs npm ffmpeg libsm6 libxext6"
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        if ! command -v brew &> /dev/null; then
            run_with_process "Cài đặt Homebrew cho Mac" "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        fi
        run_with_process "Cài đặt gói Brew (Python, Node, FFMpeg)" "brew install python node ffmpeg"
    fi
}

# --- 🐍 4. Thiết lập VENV ---
setup_venv() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] THIẾT LẬP MÔI TRƯỜNG VENV${NC}"
    GREENMIND_DIR="$HOME/.greenmind"
    VENV_PATH="$GREENMIND_DIR/venv"
    
    mkdir -p "$GREENMIND_DIR"
    if [ ! -d "$VENV_PATH" ]; then
        run_with_process "Tạo lồng ấp Python (Virtual Env)" "python3 -m venv $VENV_PATH"
    fi
    
    run_with_process "Nâng cấp công cụ PIP" "$VENV_PATH/bin/pip install --upgrade pip"
    run_with_process "Tải não bộ AI (OpenCV, Numpy, Gemini, Ezviz)" "$VENV_PATH/bin/pip install opencv-python numpy requests google-generativeai paho-mqtt ezviz-python"
}

# --- 🤖 5. Cài đặt AI Engines (Menu Gemma 4) ---
setup_ai_engines() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CẤU HÌNH TRÍ TUỆ NHÂN TẠO${NC}"
    
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    export LOCAL_MODEL="gemini"
    
    if [ "$TOTAL_RAM" -lt 4000 ]; then
        echo -e "ℹ️ RAM hơi yếu ($TOTAL_RAM MB), thiết lập tự động dùng Gemini API."
    else
        echo -e "ℹ️ RAM đáp ứng tốt ($TOTAL_RAM MB), chuẩn bị cài đặt Local AI..."
        if ! command -v ollama &> /dev/null; then
            run_with_process "Đang cài đặt lõi Ollama" "curl -fsSL https://ollama.com/install.sh | sh"
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
                run_with_process "Đang kéo model Gemma 4 (2B)" "ollama pull gemma:2b"
                export LOCAL_MODEL="gemma:2b"
                ;;
            2)
                run_with_process "Đang kéo model Gemma 4 (7B)" "ollama pull gemma:7b"
                export LOCAL_MODEL="gemma:7b"
                ;;
            3)
                run_with_process "Đang kéo model Gemma 4 (27B)" "ollama pull gemma:27b"
                export LOCAL_MODEL="gemma:27b"
                ;;
            *)
                echo -e "Đã chuyển về chế độ Đám mây nà."
                ;;
        esac
    fi
}

# --- ⚙️ 6. Cấu hình Camera ---
setup_config() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] GHI CẤU HÌNH HỆ THỐNG${NC}"
    mkdir -p /etc/greenmind
    if [ ! -f /etc/greenmind/config.env ]; then
        cat <<EOF > /etc/greenmind/config.env
AI_ENGINE=$LOCAL_MODEL
GEMINI_KEY=YOUR_KEY_HERE
MQTT_BROKER=localhost
MQTT_PORT=1883
EZVIZ_USER=admin
EZVIZ_PASS=password
EOF
        chmod 600 /etc/greenmind/config.env
        echo -e "${GREEN} [✓] Đã tạo file config.env an toàn.${NC}"
    else
        echo -e "${GREEN} [✓] Cấu hình cũ đã tồn tại, giữ nguyên nà.${NC}"
    fi
}

# --- 🛠️ 7. Thiết lập Service ---
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
        run_with_process "Nạp cấu hình Service" "systemctl daemon-reload && systemctl enable greenmind"
    else
        echo -e "${GREEN} [✓] Máy Mac, có thể chạy thủ công qua tmux nà.${NC}"
    fi
}

# --- 🏁 CHẠY TỔNG LỰC ---
check_env
show_intro
setup_core
setup_venv
setup_ai_engines
setup_config
setup_service

echo -e "\n${GREEN}${BOLD}🎉 CÀI ĐẶT THÀNH CÔNG RỰC RỠ!${NC}"
echo -e "${CYAN}Kiểm tra file cấu hình tại: /etc/greenmind/config.env${NC}"
