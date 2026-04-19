#!/bin/bash
# 🌿 04_node/04_service.sh

cat > /etc/systemd/system/greenmind-node.service << EOF
[Unit]
Description=Greenmind Node
After=network.target

[Service]
WorkingDirectory=$INSTALL_DIR/node
ExecStart=/usr/bin/python3 node_main.py
EnvironmentFile=$CONFIG_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable greenmind-node
systemctl start greenmind-node
sleep 3

if systemctl is-active --quiet greenmind-node; then
    print_success "Greenmind Node đang chạy"
else
    print_warn "Node chưa khởi động — kiểm tra: journalctl -u greenmind-node -n 20"
fi
