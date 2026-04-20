#!/bin/bash
# 🌿 04_node/01_packages.sh
show_step 2 4 "Cài packages Node"
ask_continue

run_step "Cập nhật danh sách gói" bash -c "apt-get update -q || true"
run_step "Cài Python, FFmpeg, Pillow" apt-get install -y python3 python3-pip ffmpeg python3-pil curl -q
print_success "Packages Node đã cài xong"
