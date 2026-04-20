#!/bin/bash
# 🌿 03_gateway/03_venv.sh
show_step 4 7 "Cài Python environment"
ask_continue

mkdir -p "$INSTALL_DIR"
run_step "Tạo Python virtual environment" python3 -m venv "$INSTALL_DIR/venv"
run_step "Nâng cấp pip" "$INSTALL_DIR/venv/bin/pip" install --upgrade pip -q
run_step "Cài FastAPI + dependencies" "$INSTALL_DIR/venv/bin/pip" install \
    fastapi uvicorn python-multipart aiofiles \
    requests paho-mqtt pillow \
    google-generativeai -q

print_success "Python venv + packages đã cài xong"
