#!/bin/bash
# 🌿 03_gateway/01_packages.sh
show_step 2 7 "Cài packages hệ thống" "Python, MQTT broker, FFmpeg, Git và các công cụ cần thiết"

apt-get update -q >> /tmp/greenmind_install.log 2>&1 || true
print_success "Đã cập nhật danh sách gói"

run_step "Cài Python, MQTT, FFmpeg" apt-get install -y python3 python3-pip python3-venv mosquitto mosquitto-clients ffmpeg curl git -q

# ── Swap ──────────────────────────────────────────────────────
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
SWAP_MB=$(free -m | awk '/^Swap:/{print $2}')

if [ "$SWAP_MB" -lt 512 ]; then
    if [ "$RAM_MB" -lt 2048 ]; then
        SWAP_SIZE="2G"
    else
        SWAP_SIZE="4G"
    fi
    if [ ! -f /swapfile ]; then
        run_step "Tạo swap ${SWAP_SIZE}" bash -c "
            fallocate -l ${SWAP_SIZE} /swapfile &&
            chmod 600 /swapfile &&
            mkswap /swapfile &&
            swapon /swapfile &&
            grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab"
        print_success "Swap ${SWAP_SIZE} đã tạo"
    else
        print_info "Swapfile đã tồn tại — bỏ qua"
    fi
else
    print_info "Swap đã có (${SWAP_MB}MB) — bỏ qua"
fi

print_success "Packages đã cài xong"
