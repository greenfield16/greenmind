#!/bin/bash
# 🌿 03_gateway/02_mqtt.sh
show_step 3 6 "Cấu hình MQTT Broker" "Mosquitto — kênh giao tiếp giữa Gateway và các Node thiết bị"
ask_continue

run_step "Kích hoạt Mosquitto MQTT" systemctl enable mosquitto
run_step "Khởi động Mosquitto" systemctl restart mosquitto

sleep 1
if systemctl is-active --quiet mosquitto; then
    print_success "MQTT Broker đang chạy"
else
    print_warn "MQTT không khởi động được — tiếp tục cài"
fi
