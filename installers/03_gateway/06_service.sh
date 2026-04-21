#!/bin/bash
# 🌿 03_gateway/06_service.sh — Tạo systemd services

show_step 6 6 "Tạo services" "Cài systemd services cho Greenmind Gateway và Telegram Bot"

VENV="$INSTALL_DIR/venv/bin/python3"
GDIR="$INSTALL_DIR/gateway"

# greenmind-gateway.service
cat > /etc/systemd/system/greenmind-gateway.service << EOF
[Unit]
Description=Greenmind Gateway
After=network.target mosquitto.service

[Service]
WorkingDirectory=$GDIR
ExecStart=$VENV main.py
EnvironmentFile=$CONFIG_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# greenmind-telegram.service
cat > /etc/systemd/system/greenmind-telegram.service << EOF
[Unit]
Description=Greenmind Telegram Bot
After=network.target greenmind-gateway.service

[Service]
WorkingDirectory=$GDIR
ExecStart=$VENV telegram_bot.py
EnvironmentFile=$CONFIG_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable greenmind-gateway greenmind-telegram
systemctl start greenmind-gateway greenmind-telegram
sleep 3

if systemctl is-active --quiet greenmind-gateway; then
    print_success "Greenmind Gateway đang chạy tại port $(grep GREENMIND_PORT $CONFIG_FILE | cut -d= -f2)"
else
    print_warn "Gateway chưa khởi động — kiểm tra: journalctl -u greenmind-gateway -n 20"
fi

if systemctl is-active --quiet greenmind-telegram; then
    print_success "Greenmind Telegram Bot đang chạy"
else
    print_warn "Telegram Bot chưa khởi động — kiểm tra: journalctl -u greenmind-telegram -n 20"
fi
