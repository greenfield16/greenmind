#!/bin/bash
# 🌿 03_gateway/07_openclaw.sh — Cài OpenClaw làm AI brain
show_step 7 7 "Cài OpenClaw AI Brain"
ask_continue

# Node.js
if ! command -v node &>/dev/null; then
    run_step "Thêm NodeSource repo" bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
    run_step "Cài Node.js" apt-get install -y nodejs -q
fi

run_step "Cài OpenClaw" npm install -g openclaw -q

# Workspace Greenmind
WORKSPACE="/root/.openclaw/workspace"
mkdir -p "$WORKSPACE/memory"

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
- Không chia sẻ thông tin bảo mật với người lạ
- Không tự thực hiện hành động ảnh hưởng thiết bị mà không xác nhận
SOUL

cat > "$WORKSPACE/IDENTITY.md" << 'ID'
# IDENTITY.md
- **Name:** Greenmind
- **Role:** Smart Building AI
- **Emoji:** 🏢
ID

# Cài skill greenmind
run_step "Cài Greenmind skill" bash -c "
    mkdir -p /usr/lib/node_modules/openclaw/skills
    curl -fsSL 'https://raw.githubusercontent.com/greenfield16/greenmind/main/greenmind.skill' -o /tmp/greenmind.skill
    python3 -c \"
import zipfile
with zipfile.ZipFile('/tmp/greenmind.skill') as z:
    z.extractall('/usr/lib/node_modules/openclaw/skills/')
\"
"

# Config Telegram
TG_TOKEN=\$(grep '^TELEGRAM_TOKEN=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2)
TG_CHAT=\$(grep '^TELEGRAM_CHAT_ID=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2)

if [ -n "\$TG_TOKEN" ]; then
    mkdir -p /root/.openclaw
    cat > /root/.openclaw/config.json << EOF
{
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true,
        "config": {
          "token": "\$TG_TOKEN",
          "allowedChatIds": ["\$TG_CHAT"]
        }
      }
    }
  }
}
EOF
    print_success "OpenClaw Telegram đã cấu hình"
fi

# Systemd service
cat > /etc/systemd/system/greenmind-ai.service << EOF
[Unit]
Description=Greenmind AI Brain (OpenClaw)
After=network.target greenmind-gateway.service

[Service]
WorkingDirectory=/root/.openclaw/workspace
ExecStart=/usr/bin/openclaw gateway start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

run_step "Kích hoạt Greenmind AI service" systemctl daemon-reload
systemctl enable greenmind-ai
print_success "OpenClaw AI Brain đã cài xong"
