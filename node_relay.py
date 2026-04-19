#!/usr/bin/env python3
"""
🌿 Greenmind Node Relay + Motion Detection
- Chụp snapshot mỗi SNAP_INTERVAL giây (push lên Gateway)
- So sánh frame liên tiếp bằng ffmpeg SSIM
- Nếu motion detected → push alert lên Gateway → AI phân tích → Telegram
"""

import os, time, logging, subprocess, tempfile, requests, re, json
from pathlib import Path
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger(__name__)

# ── Config ─────────────────────────────────────────────────────────────────
GATEWAY_URL      = os.getenv('GATEWAY_URL',      'http://178.128.91.69:8765')
GATEWAY_TOKEN    = os.getenv('GATEWAY_TOKEN',    '')
SNAP_INTERVAL    = int(os.getenv('SNAP_INTERVAL',    '60'))   # giây chụp định kỳ
MOTION_INTERVAL  = int(os.getenv('MOTION_INTERVAL',  '10'))   # giây check motion
MOTION_THRESHOLD = float(os.getenv('MOTION_THRESHOLD', '0.85'))  # SSIM < ngưỡng = có motion
MOTION_COOLDOWN  = int(os.getenv('MOTION_COOLDOWN',  '30'))   # giây chờ sau alert
CONFIG_FILE      = os.getenv('CONFIG_FILE', '/etc/greenmind/config.env')

def load_cameras():
    cams = {}
    if not os.path.exists(CONFIG_FILE):
        log.warning(f'Config không tồn tại: {CONFIG_FILE}')
        return cams
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            m = re.match(r'^([A-Z0-9_]+)_RTSP=["\']?(.+?)["\']?\s*$', line)
            if m:
                cams[m.group(1)] = m.group(2)
    return cams

def capture_frame(rtsp: str) -> bytes | None:
    """Chụp 1 frame bằng ffmpeg, trả về bytes JPEG."""
    try:
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
            tmp = f.name
        result = subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error',
            '-rtsp_transport', 'tcp',
            '-i', rtsp,
            '-frames:v', '1',
            '-q:v', '5',
            '-vf', 'scale=640:-1',   # resize nhỏ để nhẹ
            tmp
        ], capture_output=True, timeout=15)

        if result.returncode != 0 or not os.path.exists(tmp):
            return None

        with open(tmp, 'rb') as f:
            data = f.read()
        os.unlink(tmp)
        return data if len(data) > 1000 else None
    except Exception as e:
        log.error(f'capture_frame: {e}')
        return None

def compare_frames(frame1: bytes, frame2: bytes) -> float:
    """So sánh 2 frame bằng ffmpeg SSIM. Trả về score 0-1 (1 = giống hệt)."""
    try:
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f1, \
             tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f2:
            f1.write(frame1); tmp1 = f1.name
            f2.write(frame2); tmp2 = f2.name

        result = subprocess.run([
            'ffmpeg', '-loglevel', 'error',
            '-i', tmp1, '-i', tmp2,
            '-lavfi', 'ssim',
            '-f', 'null', '-'
        ], capture_output=True, timeout=10, text=True)

        os.unlink(tmp1); os.unlink(tmp2)

        # Parse SSIM score từ stderr
        m = re.search(r'All:(\d+\.\d+)', result.stderr)
        if m:
            return float(m.group(1))
        return 1.0  # assume no motion nếu không parse được
    except Exception as e:
        log.error(f'compare_frames: {e}')
        return 1.0

def push_snapshot(name: str, data: bytes, motion: bool = False):
    """Push ảnh lên Gateway."""
    try:
        headers = {}
        if GATEWAY_TOKEN:
            headers['X-Node-Token'] = GATEWAY_TOKEN
        resp = requests.post(
            f'{GATEWAY_URL}/api/node/snapshot',
            files={'snapshot': (f'{name}.jpg', data, 'image/jpeg')},
            data={'camera': name, 'ts': int(time.time()), 'motion': '1' if motion else '0'},
            headers=headers,
            timeout=10
        )
        if resp.status_code == 200:
            tag = '🚨 MOTION' if motion else '📷'
            log.info(f'{tag} {name}: pushed OK ({len(data)//1024}KB)')
        else:
            log.warning(f'{name}: gateway trả {resp.status_code}')
    except Exception as e:
        log.error(f'{name}: push failed — {e}')

def push_motion_alert(name: str, data: bytes, ssim: float):
    """Push motion alert lên Gateway để trigger AI + Telegram."""
    try:
        headers = {}
        if GATEWAY_TOKEN:
            headers['X-Node-Token'] = GATEWAY_TOKEN
        requests.post(
            f'{GATEWAY_URL}/api/node/motion',
            files={'snapshot': (f'{name}.jpg', data, 'image/jpeg')},
            data={
                'camera': name,
                'ts': int(time.time()),
                'ssim': str(round(ssim, 4)),
                'label': 'motion'
            },
            headers=headers,
            timeout=10
        )
        log.info(f'🚨 Motion alert sent: {name} (SSIM={ssim:.3f})')
    except Exception as e:
        log.error(f'{name}: motion alert failed — {e}')

def main():
    log.info(f'🌿 Greenmind Node Relay + Motion Detection')
    log.info(f'   Gateway       : {GATEWAY_URL}')
    log.info(f'   Snap interval : {SNAP_INTERVAL}s')
    log.info(f'   Motion check  : {MOTION_INTERVAL}s')
    log.info(f'   Motion threshold (SSIM): {MOTION_THRESHOLD}')

    # State per camera
    last_snap   = {}   # camera → timestamp lần push cuối
    last_alert  = {}   # camera → timestamp alert cuối
    prev_frame  = {}   # camera → bytes frame trước
    last_motion = {}   # camera → timestamp motion check cuối

    while True:
        cameras = load_cameras()
        if not cameras:
            log.warning('Không tìm thấy camera — chờ 30s')
            time.sleep(30)
            continue

        now = time.time()

        for name, rtsp in cameras.items():
            # ── Motion detection ──────────────────────────────────────
            if now - last_motion.get(name, 0) >= MOTION_INTERVAL:
                last_motion[name] = now
                frame = capture_frame(rtsp)

                if frame:
                    if name in prev_frame:
                        ssim = compare_frames(prev_frame[name], frame)
                        log.debug(f'{name}: SSIM={ssim:.3f}')

                        if ssim < MOTION_THRESHOLD:
                            cooldown_ok = now - last_alert.get(name, 0) >= MOTION_COOLDOWN
                            if cooldown_ok:
                                log.info(f'🚨 Motion detected: {name} (SSIM={ssim:.3f})')
                                last_alert[name] = now
                                push_motion_alert(name, frame, ssim)
                                push_snapshot(name, frame, motion=True)
                                last_snap[name] = now

                    prev_frame[name] = frame

            # ── Định kỳ push snapshot (không phụ thuộc motion) ───────
            if now - last_snap.get(name, 0) >= SNAP_INTERVAL:
                frame = capture_frame(rtsp)
                if frame:
                    push_snapshot(name, frame, motion=False)
                    last_snap[name] = now
                    if name not in prev_frame:
                        prev_frame[name] = frame

        time.sleep(2)

if __name__ == '__main__':
    main()
