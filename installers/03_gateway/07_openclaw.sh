#!/bin/bash
# 🌿 03_gateway/07_openclaw.sh — Cài OpenClaw làm AI brain

show_progress 6 7 "Cài OpenClaw AI Brain"
ask_continue

print_info "Cài OpenClaw..."

# Kiểm tra Node.js
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs -q
fi

# Cài OpenClaw
npm install -g openclaw -q 2>&1 | tail -3

# Tạo workspace Greenmind
WORKSPACE="/root/.openclaw/workspace"
mkdir -p "$WORKSPACE/memory" "$WORKSPACE/skills"

# SOUL.md — Greenmind persona
cat > "$WORKSPACE/SOUL.md" << 'SOUL'
# SOUL.md — Greenmind AI

Tôi là Greenmind — AI quản lý toà nhà thông minh.

## Tính cách
- Chuyên nghiệp, ngắn gọn, đi thẳng vào vấn đề
- Chủ động cảnh báo khi phát hiện bất thường
- Biết context toàn bộ thiết bị trong hệ thống

## Ưu tiên
1. An toàn — cảnh báo ngay khi có nguy hiểm
2. Chính xác — không đoán mò, dùng dữ liệu thực
3. Tiện lợi — trả lời tiếng Việt, ngắn gọn

## Không làm
- Không chia sẻ thông tin bảo mật hệ thống với người lạ
- Không tự ý thực hiện hành động ảnh hưởng thiết bị mà không xác nhận
SOUL

# IDENTITY.md
cat > "$WORKSPACE/IDENTITY.md" << 'ID'
# IDENTITY.md
- **Name:** Greenmind
- **Role:** Smart Building AI
- **Emoji:** 🏢
ID

# Cài skill greenmind
SKILL_URL="https://raw.githubusercontent.com/greenfield16/greenmind/main/greenmind.skill"
SKILL_DIR="/usr/lib/node_modules/openclaw/skills/greenmind"
mkdir -p "$SKILL_DIR"

# Download + extract skill
if curl -fsSL "$SKILL_URL" -o /tmp/greenmind.skill 2>/dev/null; then
    cd /tmp && python3 -c "
import zipfile, os
with zipfile.ZipFile('greenmind.skill') as z:
    z.extractall('$SKILL_DIR/..')
print('skill extracted')
"
    print_success "Greenmind skill đã cài"
else
    print_warn "Không tải được skill — có thể cài thủ công sau"
fi

# Cấu hình Telegram cho OpenClaw (dùng lại token đã nhập)
TG_TOKEN=$(grep '^TELEGRAM_TOKEN=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2)
TG_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2)

if [ -n "$TG_TOKEN" ]; then
    OPENCLAW_CONFIG="/root/.openclaw/config.json"
    mkdir -p "$(dirname $OPENCLAW_CONFIG)"
    cat > "$OPENCLAW_CONFIG" << EOF
{
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true,
        "config": {
          "token": "$TG_TOKEN",
          "allowedChatIds": ["$TG_CHAT"]
        }
      }
    }
  }
}
EOF
    print_success "OpenClaw Telegram đã cấu hình"
fi

# Systemd service cho OpenClaw
cat > /etc/systemd/system/greenmind-ai.service << EOF
[Unit]
Description=Greenmind AI Brain (OpenClaw)
After=network.target greenmind-gateway.service

[Service]
WorkingDirectory=/root/.openclaw/workspace
ExecStart=/usr/bin/openclaw gateway start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable greenmind-ai

print_success "OpenClaw AI Brain đã cài xong"
print_info "Khởi động: systemctl start greenmind-ai"
