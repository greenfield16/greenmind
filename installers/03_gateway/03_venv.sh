#!/bin/bash
# 🌿 03_gateway/03_venv.sh
show_progress 4 6 "Cài Python environment"
ask_continue

mkdir -p "$INSTALL_DIR"
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip -q
"$INSTALL_DIR/venv/bin/pip" install \
    fastapi uvicorn python-multipart aiofiles \
    requests paho-mqtt pillow \
    google-generativeai -q

print_success "Python venv + packages đã cài xong"
