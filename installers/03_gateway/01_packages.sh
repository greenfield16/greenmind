#!/bin/bash
# 🌿 03_gateway/01_packages.sh
show_progress 2 6 "Cài packages hệ thống"
ask_continue

apt-get update -q
apt-get install -y python3 python3-pip python3-venv mosquitto mosquitto-clients ffmpeg curl git -q
print_success "Packages đã cài xong"
