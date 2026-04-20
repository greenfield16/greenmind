#!/bin/bash
# 🌿 03_gateway/01_packages.sh
show_step 2 7 "Cài packages hệ thống" "Python, MQTT broker, FFmpeg, Git và các công cụ cần thiết"
ask_continue

apt-get update -q >> /tmp/greenmind_install.log 2>&1 || true
print_success "Đã cập nhật danh sách gói"

run_step "Cài Python, MQTT, FFmpeg" apt-get install -y python3 python3-pip python3-venv mosquitto mosquitto-clients ffmpeg curl git -q
print_success "Packages đã cài xong"
