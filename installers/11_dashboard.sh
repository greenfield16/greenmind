#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 11: Dashboard Web
# =================================================================

setup_dashboard() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] CÀI ĐẶT DASHBOARD WEB${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua Dashboard.${NC}"
        return 0
    fi

    mkdir -p "$GREENMIND_DIR/templates"

    run_with_process "Tải dashboard backend"  curl -fsSL "$BASE_URL/dashboard.py"          -o "$GREENMIND_DIR/dashboard.py"
    run_with_process "Tải dashboard frontend" curl -fsSL "$BASE_URL/templates/index.html"  -o "$GREENMIND_DIR/templates/index.html"
    run_with_process "Tải dashboard styles"   curl -fsSL "$BASE_URL/templates/style.css"   -o "$GREENMIND_DIR/templates/style.css"
    run_with_process "Tải PWA manifest"       curl -fsSL "$BASE_URL/templates/manifest.json" -o "$GREENMIND_DIR/templates/manifest.json"
    run_with_process "Tải Service Worker"     curl -fsSL "$BASE_URL/templates/sw.js"       -o "$GREENMIND_DIR/templates/sw.js"

    local PORT="$GREENMIND_PORT"

    if [[ "$OS_TYPE" == "Linux" ]]; then
        cat > /etc/systemd/system/greenmind-dashboard.service <<EOF
[Unit]
Description=Greenmind Dashboard
After=network.target

[Service]
ExecStart=$VENV_PATH/bin/python3 $GREENMIND_DIR/dashboard.py
Restart=always
User=$SUDO_USER
Environment=GREENMIND_PORT=$PORT
EnvironmentFile=$CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable greenmind-dashboard
        systemctl start  greenmind-dashboard

    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        cat > /Library/LaunchDaemons/ai.greenmind.dashboard.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>ai.greenmind.dashboard</string>
  <key>ProgramArguments</key><array>
    <string>$VENV_PATH/bin/python3</string>
    <string>$GREENMIND_DIR/dashboard.py</string>
  </array>
  <key>EnvironmentVariables</key><dict>
    <key>GREENMIND_PORT</key><string>$PORT</string>
  </dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/var/log/greenmind_dashboard.log</string>
  <key>StandardErrorPath</key><string>/var/log/greenmind_dashboard.log</string>
</dict></plist>
EOF
        launchctl load -w /Library/LaunchDaemons/ai.greenmind.dashboard.plist 2>/dev/null || true
    fi

    local LAN_IP
    LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "${GREEN} [✓] Dashboard chạy tại: http://localhost:$PORT${NC}"
    [[ -n "$LAN_IP" ]] && echo -e "${CYAN}     LAN: http://$LAN_IP:$PORT${NC}"
}
