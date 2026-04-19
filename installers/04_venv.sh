#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 4: Python VENV + Dependencies
# =================================================================

setup_venv() {
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] THIẾT LẬP MÔI TRƯỜNG PYTHON${NC}"

    mkdir -p "$GREENMIND_DIR"
    if [ ! -d "$VENV_PATH" ]; then
        run_with_process "Tạo môi trường ảo Python (VENV)" python3 -m venv "$VENV_PATH"
    fi

    run_with_process "Nâng cấp PIP" "$VENV_PATH/bin/pip" install --upgrade pip
    run_with_process "Cài thư viện AI & Camera" "$VENV_PATH/bin/pip" install \
        opencv-python numpy requests google-generativeai paho-mqtt ezviz-python \
        fastapi "uvicorn[standard]" opencv-python-headless websockets psutil \
        python-multipart -q
}
