#!/bin/bash
# 🌿 03_gateway/05_config.sh
show_progress 6 6 "Cấu hình Gateway"
ask_continue

# Tạo thư mục
mkdir -p /var/lib/greenmind /tmp/greenmind_snaps "$INSTALL_DIR"

# Tải code từ GitHub
BASE_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main"
print_info "Tải Greenmind v3.0 từ GitHub..."
mkdir -p "$INSTALL_DIR/gateway/templates"
for f in gateway/main.py gateway/db.py gateway/ai_engine.py \
          gateway/alert_engine.py gateway/telegram_bot.py gateway/mqtt_handler.py \
          gateway/templates/index.html gateway/templates/manifest.json gateway/templates/sw.js; do
    curl -fsSL "$BASE_URL/$f" -o "$INSTALL_DIR/$f"
done

# Config defaults
write_config GREENMIND_PORT 8765
write_config DB_PATH /var/lib/greenmind/greenmind.db
[ -z "$(grep '^TELEGRAM_TOKEN=' $CONFIG_FILE 2>/dev/null)" ] && write_config TELEGRAM_TOKEN ""
[ -z "$(grep '^TELEGRAM_CHAT_ID=' $CONFIG_FILE 2>/dev/null)" ] && write_config TELEGRAM_CHAT_ID ""

# Telegram setup
echo ""
read -rp "Nhập Telegram Bot Token (bỏ qua nếu chưa có): " TG_TOKEN
if [ -n "$TG_TOKEN" ]; then
    write_config TELEGRAM_TOKEN "$TG_TOKEN"
    read -rp "Nhập Telegram Chat ID: " TG_CHAT
    write_config TELEGRAM_CHAT_ID "$TG_CHAT"
    print_success "Telegram đã cấu hình"
fi

print_success "Config Gateway xong"
