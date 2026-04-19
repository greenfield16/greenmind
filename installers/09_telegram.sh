#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 9: Telegram Bot 2 chiều
# =================================================================

setup_telegram() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] TELEGRAM BOT 2 CHIỀU${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua Telegram.${NC}"
        return 0
    fi

    echo -e "${CYAN}🤖 Telegram Bot cho phép:${NC}"
    echo -e "   • Nhận cảnh báo AI tự động (ảnh + mô tả)"
    echo -e "   • Nhắn lệnh: /snap <cam>, /status, /cams, /alerts\n"

    read -p "👉 Cấu hình Telegram Bot? (y/n, mặc định y): " setup_tg
    setup_tg="${setup_tg:-y}"

    if [[ ! "$setup_tg" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏭ Bỏ qua Telegram.${NC}"
        return 0
    fi

    echo -e "\n${CYAN}📋 Hướng dẫn:${NC}"
    echo -e "   1. Nhắn @BotFather trên Telegram → /newbot"
    echo -e "   2. Đặt tên bot → lấy Token (dạng: 123456:ABC-xxx)"
    echo -e "   3. Nhắn thử bot của bạn 1 tin → lấy Chat ID tại:"
    echo -e "      https://api.telegram.org/bot<TOKEN>/getUpdates\n"

    read -p "Nhập Telegram Bot Token: " tg_token
    read -p "Nhập Chat ID của bạn:    " tg_chat

    # Kiểm tra token hợp lệ
    local test_result
    test_result=$(curl -sf "https://api.telegram.org/bot${tg_token}/getMe" 2>/dev/null)
    if echo "$test_result" | grep -q '"ok":true'; then
        local bot_name
        bot_name=$(echo "$test_result" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN} [✓] Bot hợp lệ: @${bot_name}${NC}"
    else
        echo -e "${YELLOW} [!] Không xác minh được token — vẫn lưu lại, kiểm tra sau.${NC}"
    fi

    # Ghi vào config
    sed -i "s/TELEGRAM_TOKEN=.*/TELEGRAM_TOKEN=$tg_token/" "$CONFIG_FILE"
    sed -i "s/TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID=$tg_chat/" "$CONFIG_FILE"

    # Cài thư viện Telegram
    run_with_process "Cài python-telegram-bot" "$VENV_PATH/bin/pip" install \
        "python-telegram-bot>=20.0" -q

    # Download telegram_bot.py
    run_with_process "Tải Telegram Bot module" curl -fsSL \
        "$BASE_URL/telegram_bot.py" -o "$GREENMIND_DIR/telegram_bot.py"

    # Tạo systemd service cho bot
    if [[ "$OS_TYPE" == "Linux" ]]; then
        cat > /etc/systemd/system/greenmind-telegram.service <<EOF
[Unit]
Description=Greenmind Telegram Bot
After=network.target greenmind-dashboard.service

[Service]
ExecStart=$VENV_PATH/bin/python3 $GREENMIND_DIR/telegram_bot.py
Restart=always
User=$SUDO_USER
EnvironmentFile=$CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable greenmind-telegram
        systemctl start  greenmind-telegram
    fi

    # Gửi tin nhắn chào
    curl -sf "https://api.telegram.org/bot${tg_token}/sendMessage" \
        -d "chat_id=${tg_chat}" \
        -d "text=🌿 *Greenmind* đã kết nối thành công!%0AGõ /help để xem lệnh." \
        -d "parse_mode=Markdown" > /dev/null 2>&1

    echo -e "${GREEN} [✓] Telegram Bot đã chạy!${NC}"
    echo -e "${CYAN}     Gõ /help trong chat bot để xem lệnh.${NC}"
}
