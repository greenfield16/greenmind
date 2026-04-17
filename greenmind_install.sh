#!/bin/bash

# =================================================================
# GREENMIND AI CCTV - HỆ THỐNG GIÁM SÁT THÔNG MINH
# 🛠️ Coded by Joseph | ✨ Refined by "Gái" AI
# =================================================================

# --- 🎨 1. Định nghĩa Màu sắc & UI ---
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m'
export BOLD='\033[1m'

# --- 🌀 2. Hàm hiệu ứng Spinner ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "${BLUE} [%c] Đang xử lý... ${NC}" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_header() {
    echo -e "${GREEN}${BOLD}
    ================================================
    🚀 GREENMIND AI CCTV - GIẢI PHÁP GIÁM SÁT THÔNG MINH
    Tối ưu cho: Mac Mini | Tinkerboard | Ubuntu VPS
    ================================================
    ${NC}"
}

# --- 🛡️ 3. Kiểm tra Hệ thống & Phân quyền ---
check_env() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}❌ Lỗi: Zai phải dùng 'sudo bash' để chạy nà!${NC}"
       exit 1
    fi
    OS_TYPE=$(uname -s)
    ARCH_TYPE=$(uname -m)
    echo -e "${BLUE}ℹ️ Detected: $OS_TYPE ($ARCH_TYPE)${NC}"
}

# --- 📦 4. Cài đặt Core Dependencies ---
setup_core() {
    echo -e "${YELLOW}🔹 Bước 1: Cài đặt nền tảng hệ thống...${NC}"
    if [[ "$OS_TYPE" == "Linux" ]]; then
        apt-get update -y > /dev/null 2>&1 & spinner $!
        apt-get install -y python3-venv python3-pip curl git nodejs npm ffmpeg libsm6 libxext6 > /dev/null 2>&1 & spinner $!
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${YELLOW}Cài đặt Homebrew cho Mac...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1 & spinner $!
        fi
        brew install python node ffmpeg > /dev/null 2>&1 & spinner $!
    fi
}

# --- 🐍 5. Thiết lập Python Virtual Environment (VENV) ---
setup_venv() {
    echo -e "${YELLOW}🔹 Bước 2: Thiết lập môi trường ảo AI (VENV)...${NC}"
    GREENMIND_DIR="$HOME/.greenmind"
    VENV_PATH="$GREENMIND_DIR/venv"
    
    mkdir -p "$GREENMIND_DIR"
    if [ ! -d "$VENV_PATH" ]; then
        python3 -m venv "$VENV_PATH"
    fi
    
    # Cài đặt các thư viện lõi từ bản 400 dòng của Zai
    echo -e "${BLUE}Đang cài đặt các thư viện AI & Camera...${NC}"
    "$VENV_PATH/bin/pip" install --upgrade pip > /dev/null 2>&1
    "$VENV_PATH/bin/pip" install opencv-python numpy requests google-generativeai paho-mqtt ezviz-python > /dev/null 2>&1 & spinner $!
}

# --- 🤖 6. Cài đặt AI Engines (Ollama & Gemma 4 Logic) ---
setup_ai_engines() {
    echo -e "${YELLOW}🔹 Bước 3: Cấu hình Não bộ AI (Local & Cloud)...${NC}"
    
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    export LOCAL_MODEL="gemini" # Mặc định nếu khum chọn gì
    
    if [ "$TOTAL_RAM" -lt 4000 ]; then
        echo -e "${BLUE}ℹ️ RAM hệ thống ($TOTAL_RAM MB) quá thấp, tự động chạy Gemini API cho nhẹ máy nà.${NC}"
    else
        echo -e "${BLUE}ℹ️ RAM \"Khủng\" ($TOTAL_RAM MB), tiến hành chuẩn bị Ollama Local AI...${NC}"
        if ! command -v ollama &> /dev/null; then
            curl -fsSL https://ollama.com/install.sh | sh > /dev/null 2>&1 & spinner $!
        fi
        
        # Đảm bảo Ollama đang chạy ngầm để tải model (Hỗ trợ cả Mac và Linux)
        if command -v systemctl &> /dev/null; then
            systemctl start ollama > /dev/null 2>&1
        else
            ollama serve > /dev/null 2>&1 &
        fi
        
        echo -e "\n${YELLOW}🧠 ZAI MUỐN CÀI ĐẶT MODEL GEMMA 4 NÀO CHO KHÁCH ĐÂY?${NC}"
        echo -e "  ${GREEN}1)${NC} Gemma 4 (2B)  - Nhẹ nhất, chạy mượt trên Tinkerboard/4GB RAM"
        echo -e "  ${GREEN}2)${NC} Gemma 4 (7B)  - Cân bằng, khuyên dùng cho Mac Mini/8GB RAM"
        echo -e "  ${GREEN}3)${NC} Gemma 4 (27B) - Siêu cấp, chỉ dùng khi có 16GB RAM + VGA rời"
        echo -e "  ${GREEN}4)${NC} Khum cài bây giờ, tui xài Cloud API"
        
        read -p "👉 Lựa chọn của Zai (1-4): " model_choice
        
        case $model_choice in
            1)
                echo -e "${BLUE}Đang kéo Gemma 4 (2B) về nhà... Zai đợi chút nà!${NC}"
                ollama pull gemma:2b > /dev/null 2>&1 & spinner $!
                export LOCAL_MODEL="gemma:2b"
                ;;
            2)
                echo -e "${BLUE}Đang kéo Gemma 4 (7B) về nhà...${NC}"
                ollama pull gemma:7b > /dev/null 2>&1 & spinner $!
                export LOCAL_MODEL="gemma:7b"
                ;;
            3)
                echo -e "${BLUE}Đang kéo cỗ xe tăng Gemma 4 (27B) về nhà...${NC}"
                ollama pull gemma:27b > /dev/null 2>&1 & spinner $!
                export LOCAL_MODEL="gemma:27b"
                ;;
            *)
                echo -e "${YELLOW}Đã chuyển về chế độ dùng API Cloud nà.${NC}"
                ;;
        esac
    fi
}

# --- ⚙️ 7. Cấu hình Camera & Hệ thống ---
setup_config() {
    echo -e "${YELLOW}🔹 Bước 4: Tạo tệp cấu hình (Lưu Model đã chọn)...${NC}"
    mkdir -p /etc/greenmind
    if [ ! -f /etc/greenmind/config.env ]; then
        cat <<EOF > /etc/greenmind/config.env
# GREENMIND CONFIGURATION
AI_ENGINE=$LOCAL_MODEL
GEMINI_KEY=YOUR_KEY_HERE
MQTT_BROKER=localhost
MQTT_PORT=1883
EZVIZ_USER=admin
EZVIZ_PASS=password
EOF
        chmod 600 /etc/greenmind/config.env
    fi
}

# --- 🛠️ 8. Thiết lập Service & Uninstaller ---
setup_service_and_clean() {
    echo -e "${YELLOW}🔹 Bước 5: Tạo Service chạy ngầm & Uninstaller...${NC}"
    
    # Service cho Linux (Tinkerboard/VPS)
    if [[ "$OS_TYPE" == "Linux" ]]; then
        cat <<EOF > /etc/systemd/system/greenmind.service
[Unit]
Description=GreenMind AI CCTV Service
After=network.target

[Service]
ExecStart=$HOME/.greenmind/venv/bin/python3 $HOME/.greenmind/main.py
Restart=always
User=$USER
EnvironmentFile=/etc/greenmind/config.env

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable greenmind > /dev/null 2>&1
    fi

    # Uninstaller 
    cat <<EOF > "$HOME/.greenmind/uninstall.sh"
#!/bin/bash
echo "Đang gỡ bỏ GreenMind..."
if command -v systemctl &> /dev/null && [ -f /etc/systemd/system/greenmind.service ]; then
    systemctl stop greenmind
    systemctl disable greenmind
    rm /etc/systemd/system/greenmind.service
fi
rm -rf "$HOME/.greenmind"
rm -rf /etc/greenmind
echo "Đã dọn dẹp sạch sẽ nà Zai!"
EOF
    chmod +x "$HOME/.greenmind/uninstall.sh"
}

# --- 🏁 CHẠY TỔNG LỰC ---
print_header
check_env
setup_core
setup_venv
setup_ai_engines
setup_config
setup_service_and_clean

echo -e "\n${GREEN}${BOLD}✅ CÀI ĐẶT HOÀN TẤT - TIẾN LÊN TỔNG TÀI!${NC}"
echo -e "${YELLOW}Zai hãy kiểm tra config tại: /etc/greenmind/config.env${NC}"
if [[ "$OS_TYPE" == "Linux" ]]; then
    echo -e "${BLUE}Khởi động bằng lệnh: sudo systemctl start greenmind${NC}"
else
    echo -e "${BLUE}Khởi động bằng lệnh: source ~/.greenmind/venv/bin/activate && python3 main.py${NC}"
fi
