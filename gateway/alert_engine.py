#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — Alert Engine
Rule-based alert processing
"""

import time, logging
from datetime import datetime

log = logging.getLogger(__name__)

def process_event(event_type: str, payload: dict, device: dict, ai_analysis: str, ts: int = None) -> list:
    """
    Xử lý sự kiện và trả về list alert messages cần gửi.
    Trả về [] nếu không cần alert.
    """
    ts = ts or int(time.time())
    dt = datetime.fromtimestamp(ts)
    hour = dt.hour
    device_name = device.get('name', device.get('id', 'unknown')) if device else 'Unknown'
    alerts = []

    if event_type == 'motion':
        # Ngoài giờ 22:00-06:00 → alert ngay
        if hour >= 22 or hour < 6:
            alerts.append(
                f"🚨 Phát hiện chuyển động ngoài giờ tại *{device_name}*\n"
                f"🕐 {dt.strftime('%d/%m/%Y %H:%M:%S')}\n"
                f"🤖 {ai_analysis or 'Chưa có phân tích AI'}"
            )
        # Giờ bình thường → chỉ alert nếu AI phát hiện người
        elif ai_analysis and any(kw in ai_analysis.lower() for kw in
                                  ['người', 'đàn ông', 'phụ nữ', 'trẻ em', 'người lạ', 'ai đó']):
            alerts.append(
                f"👤 Phát hiện người tại *{device_name}*\n"
                f"🕐 {dt.strftime('%d/%m/%Y %H:%M:%S')}\n"
                f"🤖 {ai_analysis}"
            )

    elif event_type == 'checkin':
        person_name = payload.get('name', 'Không rõ')
        # Kiểm tra ngoài giờ làm (mặc định 07:00-18:00)
        if hour < 7 or hour >= 18:
            alerts.append(
                f"⚠️ Chấm công ngoài giờ: *{person_name}*\n"
                f"🕐 {dt.strftime('%d/%m/%Y %H:%M:%S')}\n"
                f"📍 {device_name}"
            )

    elif event_type == 'door_open':
        if hour >= 22 or hour < 6:
            alerts.append(
                f"🔓 Cửa mở ngoài giờ: *{device_name}*\n"
                f"🕐 {dt.strftime('%d/%m/%Y %H:%M:%S')}"
            )

    elif event_type == 'alarm':
        alerts.append(
            f"🆘 CẢNH BÁO: *{device_name}*\n"
            f"📋 {payload.get('message', event_type)}\n"
            f"🕐 {dt.strftime('%d/%m/%Y %H:%M:%S')}"
        )

    elif event_type == 'sensor_data':
        temp = payload.get('temperature')
        smoke = payload.get('smoke')
        if temp and float(temp) > 40:
            alerts.append(f"🌡️ Nhiệt độ cao bất thường: *{temp}°C* tại {device_name}")
        if smoke and float(smoke) > 0.5:
            alerts.append(f"🔥 Phát hiện khói tại *{device_name}*!")

    return alerts
