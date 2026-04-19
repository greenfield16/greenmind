# Greenmind v3.0 — Smart Building AI Platform

AI-Powered Smart Building management system. Quản lý camera, chấm công, khoá thông minh, cảm biến và hơn nữa.

## Cài đặt nhanh

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/greenfield16/greenmind/main/greenmind_install.sh)
```

## Kiến trúc

```
Gateway (VPS/PC)          Node (Tinkerboard/Pi tại địa điểm)
├── AI Brain              ├── camera/    — RTSP + motion detection
├── Dashboard UI          ├── access/    — Máy chấm công
├── Telegram Bot          ├── lock/      — Khoá thông minh
├── MQTT Broker           ├── sensor/    — Cảm biến
└── Database              ├── relay/     — Đèn/relay
                          └── barrier/   — Barrier bãi xe
```

## Modules

| Module | Thiết bị | Trạng thái |
|--------|----------|-----------|
| camera | Hikvision, Dahua, ONVIF | ✅ Hoàn thiện |
| access | ZKTeco, Hikvision DS-K | 🚧 Đang phát triển |
| lock | TTLock, Tuya | 🚧 Đang phát triển |
| sensor | Zigbee, MQTT | 🚧 Đang phát triển |
| relay | Sonoff, Tasmota | 🚧 Đang phát triển |
| barrier | RS485 controller | 🚧 Đang phát triển |

## AI Engines

- **OpenRouter** (khuyên dùng) — nhiều model free, vision support
- **Gemini** — Google AI, cần API key
- **Ollama** — local AI, cần RAM ≥ 4GB

## Yêu cầu

**Gateway:** Ubuntu/Debian, RAM ≥ 2GB, Python 3.10+  
**Node:** Ubuntu/Debian/Raspbian, RAM ≥ 512MB, ffmpeg

## Cấu hình

Sau cài đặt, chỉnh sửa `/etc/greenmind/config.env`

## License

MIT — Greenfield Tech 🌿
