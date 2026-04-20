#!/bin/bash
# 🌿 03_gateway/01_packages.sh
show_step 2 7 "Cài packages hệ thống"
ask_continue

run_step "Cập nhật danh sách gói" bash -c "apt-get update -q || true"
run_step "Cài Python, MQTT, FFmpeg" apt-get install -y python3 python3-pip python3-venv mosquitto mosquitto-clients ffmpeg curl git -q
print_success "Packages đã cài xong"
