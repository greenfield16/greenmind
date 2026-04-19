#!/bin/bash
# 🌿 03_gateway/02_mqtt.sh
show_progress 3 6 "Cấu hình MQTT Broker"
ask_continue

systemctl enable mosquitto --quiet
systemctl restart mosquitto
sleep 1
if systemctl is-active --quiet mosquitto; then
    print_success "MQTT Broker đang chạy"
else
    print_warn "MQTT không khởi động được — tiếp tục cài"
fi
