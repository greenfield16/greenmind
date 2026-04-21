#!/usr/bin/env python3
"""
🌿 Rux Agent — Greenmind AI chạy trực tiếp trên robot Letianpai
- Poll camera → DO Agent phân tích → TTS nói + Telegram alert
- Không cần FastAPI, không cần Telegram bot loop
- Chạy trong Termux trên Rux
"""

import os, time, subprocess, requests, base64, logging
from datetime import datetime
from io import BytesIO

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger(__name__)

# ── Config ───────────────────────────────────────────────────

def load_config():
    cfg = {}
    for cf in ['/etc/greenmind/config.env', os.path.expanduser('~/greenmind.env')]:
        if os.path.exists(cf):
            for line in open(cf):
                line = line.strip()
                if '=' in line and not line.startswith('#'):
                    k, _, v = line.partition('=')
                    cfg[k.strip()] = v.strip().strip('"\'')
    cfg.update(os.environ)
    return cfg

# ── TTS ──────────────────────────────────────────────────────

def speak(text: str):
    """Gửi text cho TTS Bridge APK qua broadcast."""
    log.info(f'🔊 TTS: {text}')
    try:
        subprocess.run([
            'am', 'broadcast',
            '-a', 'com.greenmind.tts',
            '-n', 'com.greenmind.ttsbridge/.TtsBridgeReceiver',
            '--es', 'text', text
        ], capture_output=True, timeout=5)
    except Exception as e:
        log.error(f'TTS error: {e}')

# ── Camera ───────────────────────────────────────────────────

def capture_snapshot(rtsp_url: str) -> bytes | None:
    """Chụp frame từ RTSP camera bằng ffmpeg."""
    try:
        result = subprocess.run([
            'ffmpeg', '-y', '-rtsp_transport', 'tcp',
            '-i', rtsp_url,
            '-vframes', '1',
            '-vf', 'scale=640:-1',
            '-f', 'image2', 'pipe:1'
        ], capture_output=True, timeout=15)
        if result.returncode == 0 and len(result.stdout) > 1000:
            return result.stdout
    except Exception as e:
        log.error(f'Capture error: {e}')
    return None

# ── AI ───────────────────────────────────────────────────────

def analyze_with_do_agent(cfg: dict, prompt: str, image_bytes: bytes = None) -> str:
    endpoint = cfg.get('DO_AGENT_ENDPOINT', '').rstrip('/')
    key = cfg.get('DO_AGENT_KEY', '')
    if not endpoint or not key:
        return ''

    messages = []
    if image_bytes:
        # DO Agent không có vision — dùng OpenRouter cho ảnh
        or_key = cfg.get('OPENROUTER_KEY', '')
        if or_key:
            return analyze_with_openrouter(cfg, prompt, image_bytes)
        # Fallback: chỉ gửi text prompt
        messages.append({'role': 'user', 'content': prompt})
    else:
        messages.append({'role': 'user', 'content': prompt})

    try:
        resp = requests.post(
            f'{endpoint}/api/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'messages': messages, 'stream': False, 'max_tokens': 256},
            timeout=30
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
        log.error(f'DO Agent {resp.status_code}: {resp.text[:100]}')
    except Exception as e:
        log.error(f'DO Agent error: {e}')
    return ''

def analyze_with_openrouter(cfg: dict, prompt: str, image_bytes: bytes) -> str:
    key = cfg.get('OPENROUTER_KEY', '')
    model = cfg.get('OPENROUTER_MODEL', 'nvidia/nemotron-nano-12b-v2-vl:free')
    b64 = base64.b64encode(image_bytes).decode()
    try:
        resp = requests.post(
            'https://openrouter.ai/api/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'model': model, 'messages': [{'role': 'user', 'content': [
                {'type': 'text', 'text': prompt},
                {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{b64}'}}
            ]}]},
            timeout=60
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
    except Exception as e:
        log.error(f'OpenRouter error: {e}')
    return ''

# ── Telegram ─────────────────────────────────────────────────

def telegram_send(cfg: dict, text: str, photo: bytes = None):
    token = cfg.get('TELEGRAM_TOKEN', '')
    chat_id = cfg.get('TELEGRAM_CHAT_ID', '')
    if not token or not chat_id:
        return
    try:
        if photo:
            requests.post(
                f'https://api.telegram.org/bot{token}/sendPhoto',
                data={'chat_id': chat_id, 'caption': text[:1024]},
                files={'photo': ('snap.jpg', photo, 'image/jpeg')},
                timeout=15
            )
        else:
            requests.post(
                f'https://api.telegram.org/bot{token}/sendMessage',
                json={'chat_id': chat_id, 'text': text},
                timeout=10
            )
    except Exception as e:
        log.error(f'Telegram error: {e}')

# ── Motion detection đơn giản ─────────────────────────────────

_last_snap = None
_last_alert_time = 0
ALERT_COOLDOWN = 60  # Tối thiểu 60s giữa 2 alert

def detect_motion(current: bytes, threshold: float = 0.03) -> bool:
    """So sánh SSIM đơn giản giữa 2 frame."""
    global _last_snap
    if _last_snap is None:
        _last_snap = current
        return False
    try:
        # So sánh kích thước file như proxy đơn giản
        diff = abs(len(current) - len(_last_snap)) / max(len(_last_snap), 1)
        _last_snap = current
        return diff > threshold
    except Exception:
        _last_snap = current
        return False

# ── Main loop ────────────────────────────────────────────────

def main():
    cfg = load_config()
    rtsp_url = cfg.get('RTSP_URL', cfg.get('NHA_RIENG_RTSP', ''))
    interval = int(cfg.get('MOTION_INTERVAL', '30'))
    cam_name = cfg.get('CAM_NAME', 'Camera')

    if not rtsp_url:
        log.error('❌ Chưa cấu hình RTSP_URL trong ~/greenmind.env')
        return

    log.info(f'🌿 Rux Agent khởi động — camera: {cam_name}, interval: {interval}s')
    speak('Greenmind đã khởi động, bắt đầu giám sát')

    global _last_alert_time

    while True:
        try:
            snap = capture_snapshot(rtsp_url)
            if snap is None:
                log.warning('⚠️ Không lấy được ảnh camera')
                time.sleep(interval)
                continue

            now = time.time()
            motion = detect_motion(snap)

            if motion and (now - _last_alert_time) > ALERT_COOLDOWN:
                _last_alert_time = now
                ts_str = datetime.now().strftime('%H:%M:%S %d/%m')
                log.info(f'🚨 Phát hiện chuyển động lúc {ts_str}')

                # AI phân tích
                prompt = (
                    f"Đây là ảnh từ camera an ninh '{cam_name}' lúc {ts_str}. "
                    "Mô tả ngắn gọn (1-2 câu): có người không, họ đang làm gì. "
                    "Trả lời tiếng Việt, ngắn gọn để đọc thành tiếng."
                )
                analysis = analyze_with_do_agent(cfg, prompt, snap)

                if analysis:
                    log.info(f'🤖 AI: {analysis}')
                    speak(analysis)
                    telegram_send(cfg, f'🚨 *Phát hiện chuyển động*\n📷 {cam_name} | {ts_str}\n🤖 {analysis}', snap)
                else:
                    speak(f'Phát hiện chuyển động tại {cam_name}')
                    telegram_send(cfg, f'🚨 Phát hiện chuyển động\n📷 {cam_name} | {ts_str}', snap)

        except KeyboardInterrupt:
            log.info('Dừng Rux Agent')
            speak('Greenmind tạm dừng giám sát')
            break
        except Exception as e:
            log.error(f'Loop error: {e}')

        time.sleep(interval)

if __name__ == '__main__':
    main()
