#!/bin/bash
# 🌿 04_node/01_packages.sh
show_progress 2 4 "Cài packages Node"
ask_continue

apt-get update -q
apt-get install -y python3 python3-pip ffmpeg python3-pil curl -q
print_success "Packages Node đã cài xong"
