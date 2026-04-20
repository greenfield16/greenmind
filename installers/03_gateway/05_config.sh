#!/bin/bash
# 🌿 03_gateway/05_config.sh
show_progress 6 7 "Cấu hình Gateway" "Tải code Greenmind, thiết lập Telegram bot và các thông số hệ thống"

# Tạo thư mục
mkdir -p /var/lib/greenmind /tmp/greenmind_snaps "$INSTALL_DIR"

# Tải code từ GitHub
BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
run_step "Tải Greenmind từ GitHub" bash -c "
mkdir -p '$INSTALL_DIR/gateway/templates'
for f in gateway/main.py gateway/db.py gateway/ai_engine.py \
          gateway/alert_engine.py gateway/telegram_bot.py gateway/mqtt_handler.py \
          gateway/templates/index.html gateway/templates/manifest.json gateway/templates/sw.js; do
    curl -fsSL '$BASE_URL/\$f' -o '$INSTALL_DIR/\$f'
done"

# Config defaults
write_config GREENMIND_PORT 8765
write_config DB_PATH /var/lib/greenmind/greenmind.db

# Telegram setup
oc_section "Telegram Bot" \
    "Greenmind giao tiếp qua Telegram bot." \
    "" \
    "Tạo bot tại @BotFather → /newbot → lấy token" \
    "Chat ID của bạn: nhắn gì đó cho @userinfobot"

oc_confirm "Cấu hình Telegram bot ngay bây giờ?" && {
    oc_input "Nhập Bot Token (1234567890:AAG...)" TG_TOKEN
    while [[ ! "$TG_TOKEN" =~ ^[0-9]+:AA ]]; do
        print_warn "Token không đúng định dạng"
        oc_input "Nhập lại Bot Token" TG_TOKEN
    done
    write_config TELEGRAM_TOKEN "$TG_TOKEN"

    oc_input "Nhập Chat ID của bạn (VD: 407008459)" TG_CHAT
    write_config TELEGRAM_CHAT_ID "$TG_CHAT"
    print_success "Telegram đã cấu hình"
} || {
    write_config TELEGRAM_TOKEN ""
    write_config TELEGRAM_CHAT_ID ""
    print_warn "Bỏ qua Telegram — có thể cấu hình sau trong $CONFIG_FILE"
}

print_success "Config Gateway xong"
