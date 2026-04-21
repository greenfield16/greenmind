# 🌿 Greenmind RUX Bridge

Android app chạy trên robot RUX, tạo HTTP server để nhận lệnh từ Greenmind Gateway.

## API Endpoints

| Method | Endpoint | Body | Mô tả |
|--------|----------|------|-------|
| GET | `/status` | — | Kiểm tra robot online |
| POST | `/speak` | `{"text":"xin chào"}` | Robot nói |
| POST | `/move` | `{"dir":"forward","steps":3}` | Di chuyển |
| POST | `/light` | `{"color":"red"}` | Đèn anten |
| POST | `/motor/on` | — | Bật servo |
| POST | `/motor/off` | — | Tắt servo |
| POST | `/dance` | — | Nhảy múa |

**Dir values:** `forward`, `backward`, `left`, `right`  
**Color values:** `red`, `green`, `blue`, `white`, `off`

## Cài đặt

### 1. Lấy Robot SDK (.aar)
```bash
# Kết nối ADB vào robot
adb connect <ip_robot>:5555
adb pull /system/app/RobotService/RobotService.apk
# Hoặc tìm trong repo Letianpai:
# https://github.com/Letianpai-Robot
```

### 2. Build & Install
```bash
# Copy .aar vào app/libs/
cp RobotSDK.aar app/libs/

# Build
./gradlew assembleDebug

# Install lên robot qua ADB
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 3. Config Greenmind
Thêm vào `/etc/greenmind/config.env`:
```
RUX_IP=192.168.1.xxx
RUX_PORT=8080
```

## Test nhanh
```bash
# Kiểm tra online
curl http://192.168.1.xxx:8080/status

# Robot nói
curl -X POST http://192.168.1.xxx:8080/speak \
     -H "Content-Type: application/json" \
     -d '{"text":"Xin chào, tôi là Greenmind"}'

# Đèn đỏ cảnh báo
curl -X POST http://192.168.1.xxx:8080/light \
     -d '{"color":"red"}'
```
