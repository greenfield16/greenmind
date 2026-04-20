#!/bin/bash
# 🌿 04_node/01_packages.sh
show_step 2 4 "Cài packages Node"
ask_continue

apt-get update -q >> /tmp/greenmind_install.log 2>&1 || true
print_success "Đã cập nhật danh sách gói"

run_step "Cài Python, FFmpeg, Pillow" apt-get install -y python3 python3-pip ffmpeg python3-pil curl -q
print_success "Packages Node đã cài xong"
