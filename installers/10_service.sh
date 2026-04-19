#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 10: Systemd Services
# =================================================================

setup_service() {
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] ĐĂNG KÝ DỊCH VỤ CHẠY NGẦM${NC}"

    if [[ "$OS_TYPE" == "Linux" ]]; then
        # Service chính (AI engine)
        cat > /etc/systemd/system/greenmind.service <<EOF
[Unit]
Description=Greenmind AI CCTV Engine
After=network.target

[Service]
ExecStart=$VENV_PATH/bin/python3 $GREENMIND_DIR/main.py
Restart=always
User=$SUDO_USER
EnvironmentFile=$CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF

        run_with_process "Đăng ký Greenmind services" bash -c \
            "systemctl daemon-reload && systemctl enable greenmind"
        echo -e "${GREEN} [✓] Services đã đăng ký.${NC}"

    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        echo -e "${GREEN} [✓] Mac: chạy thủ công bằng tmux hoặc launchd.${NC}"
    fi
}
