#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 7: Frigate NVR
# =================================================================

setup_frigate() {
    ((CURRENT_STEP++))
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] FRIGATE NVR — AI OBJECT DETECTION${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua Frigate.${NC}"
        return 0
    fi

    echo -e "${CYAN}🎥 Frigate: NVR mã nguồn mở, AI phát hiện người/xe/vật thể.${NC}"
    echo -e "   Yêu cầu: Docker | RAM ≥ 4GB\n"
    read -p "👉 Cài Frigate? (y/n, mặc định n): " install_frigate
    [[ ! "$install_frigate" =~ ^[Yy]$ ]] && { echo -e "${YELLOW}⏭ Bỏ qua.${NC}"; return 0; }

    # Docker
    if ! command -v docker &> /dev/null; then
        run_with_process "Cài Docker" bash -c "curl -fsSL https://get.docker.com | sh"
        systemctl enable docker > /dev/null 2>&1
        systemctl start  docker > /dev/null 2>&1
    fi

    local FRIGATE_DIR="$GREENMIND_DIR/frigate"
    mkdir -p "$FRIGATE_DIR"

    # Build camera list từ config.env
    local FRIGATE_CAMERAS=""
    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^([A-Z0-9_]+)_RTSP=\"(.+)\"$ ]]; then
                local cname="${BASH_REMATCH[1]}"
                local crtsp="${BASH_REMATCH[2]}"
                local clow=$(echo "$cname" | tr '[:upper:]' '[:lower:]')
                FRIGATE_CAMERAS+="  ${clow}:
    ffmpeg:
      inputs:
        - path: ${crtsp}
          roles: [detect, record]
    detect:
      width: 1280
      height: 720
      fps: 5
"
                echo -e "  ${GREEN}[✓]${NC} $cname → Frigate"
            fi
        done < "$CONFIG_FILE"
    fi

    cat > "$FRIGATE_DIR/config.yml" <<EOF
mqtt:
  enabled: true
  host: localhost
  port: 1883

cameras:
${FRIGATE_CAMERAS}
record:
  enabled: true
  retain:
    days: 7
    mode: motion

snapshots:
  enabled: true
  retain:
    default: 14

detectors:
  cpu1:
    type: cpu
    num_threads: 3

objects:
  track: [person, car, motorcycle, bicycle]
EOF

    cat > "$FRIGATE_DIR/docker-compose.yml" <<EOF
services:
  frigate:
    container_name: frigate
    image: ghcr.io/blakeblackshear/frigate:stable
    restart: unless-stopped
    shm_size: "256mb"
    volumes:
      - $FRIGATE_DIR/config.yml:/config/config.yml
      - $FRIGATE_DIR/storage:/media/frigate
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "5000:5000"
      - "8971:8971"
      - "8554:8554"
EOF

    run_with_process "Khởi động Frigate NVR" docker compose -f "$FRIGATE_DIR/docker-compose.yml" up -d

    # Ghi vào config
    grep -q "FRIGATE_URL" "$CONFIG_FILE" || {
        echo "" >> "$CONFIG_FILE"
        echo "FRIGATE_URL=\"http://localhost:5000\"" >> "$CONFIG_FILE"
        echo "FRIGATE_ENABLED=true" >> "$CONFIG_FILE"
    }

    echo -e "${GREEN} [✓] Frigate chạy tại: http://localhost:5000${NC}"
    echo -e "${CYAN}     Config: $FRIGATE_DIR/config.yml${NC}"
}
