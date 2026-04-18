#!/usr/bin/env python3
"""
Greenmind Dashboard — FastAPI backend
Đọc camera từ /etc/greenmind/config.env, expose snapshot + status API
"""
import os, re, time, threading, subprocess
from pathlib import Path
from typing import Optional

try:
    from fastapi import FastAPI, Response
    from fastapi.staticfiles import StaticFiles
    from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
    import uvicorn
    import cv2
    import numpy as np
    import requests as req_lib
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install',
        'fastapi', 'uvicorn[standard]', 'opencv-python-headless', 'requests', '-q'])
    from fastapi import FastAPI, Response
    from fastapi.responses import HTMLResponse, JSONResponse
    import uvicorn

CONFIG_FILE = os.environ.get('GREENMIND_CONFIG', '/etc/greenmind/config.env')
SNAP_DIR    = Path(os.environ.get('GREENMIND_SNAP_DIR', '/tmp/greenmind_snaps'))
SNAP_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title='Greenmind Dashboard')

# ── Load cameras from config ──────────────────────────────────────────────────
def load_cameras():
    cams = {}
    if not os.path.exists(CONFIG_FILE):
        return cams
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            m = re.match(r'^([A-Z0-9_]+)_RTSP=["\']?(.+?)["\']?$', line)
            if m:
                name = m.group(1)
                rtsp = m.group(2)
                cams[name] = {'name': name, 'rtsp': rtsp, 'online': None, 'last_snap': None}
    return cams

cameras = load_cameras()

# ── Snapshot worker ───────────────────────────────────────────────────────────
def capture_snapshot(name: str, rtsp: str) -> Optional[bytes]:
    """Capture 1 frame from RTSP stream using OpenCV."""
    try:
        cap = cv2.VideoCapture(rtsp, cv2.CAP_FFMPEG)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        ret, frame = cap.read()
        cap.release()
        if ret and frame is not None:
            _, buf = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            return buf.tobytes()
    except Exception as e:
        print(f'[SNAP] {name}: {e}')
    return None

def check_rtsp_online(rtsp: str, timeout: int = 3) -> bool:
    """Quick check nếu host:port của RTSP đang mở."""
    import socket
    try:
        m = re.match(r'rtsp://[^@]*@?([^:/]+):?(\d+)?/', rtsp)
        if not m:
            return False
        host = m.group(1)
        port = int(m.group(2) or 554)
        s = socket.create_connection((host, port), timeout=timeout)
        s.close()
        return True
    except:
        return False

# ── Background refresh loop ───────────────────────────────────────────────────
def refresh_loop():
    while True:
        for name, cam in cameras.items():
            online = check_rtsp_online(cam['rtsp'])
            cameras[name]['online'] = online
            if online:
                data = capture_snapshot(name, cam['rtsp'])
                if data:
                    snap_path = SNAP_DIR / f'{name}.jpg'
                    snap_path.write_bytes(data)
                    cameras[name]['last_snap'] = time.time()
        time.sleep(15)

threading.Thread(target=refresh_loop, daemon=True).start()

# ── API Routes ────────────────────────────────────────────────────────────────
@app.get('/api/cameras')
def get_cameras():
    return JSONResponse([
        {
            'name': cam['name'],
            'rtsp': cam['rtsp'],
            'online': cam['online'],
            'last_snap': cam['last_snap'],
        }
        for cam in cameras.values()
    ])

@app.get('/api/snapshot/{name}')
def get_snapshot(name: str):
    snap_path = SNAP_DIR / f'{name}.jpg'
    if snap_path.exists():
        return Response(snap_path.read_bytes(), media_type='image/jpeg')
    # On-demand capture
    cam = cameras.get(name)
    if not cam:
        return Response(status_code=404)
    data = capture_snapshot(name, cam['rtsp'])
    if data:
        snap_path.write_bytes(data)
        cameras[name]['last_snap'] = time.time()
        return Response(data, media_type='image/jpeg')
    return Response(status_code=503)

@app.get('/api/capture/{name}')
def force_capture(name: str):
    """Force re-capture ngay lập tức."""
    cam = cameras.get(name)
    if not cam:
        return JSONResponse({'error': 'not found'}, status_code=404)
    online = check_rtsp_online(cam['rtsp'])
    cameras[name]['online'] = online
    if online:
        data = capture_snapshot(name, cam['rtsp'])
        if data:
            snap_path = SNAP_DIR / f'{name}.jpg'
            snap_path.write_bytes(data)
            cameras[name]['last_snap'] = time.time()
            return JSONResponse({'ok': True, 'ts': cameras[name]['last_snap']})
    return JSONResponse({'ok': False, 'online': online})

@app.get('/api/reload')
def reload_config():
    """Reload config.env để nhận cam mới."""
    global cameras
    cameras = load_cameras()
    return JSONResponse({'cameras': len(cameras)})

@app.get('/', response_class=HTMLResponse)
def index():
    html_path = Path(__file__).parent / 'templates' / 'index.html'
    if html_path.exists():
        return HTMLResponse(html_path.read_text())
    return HTMLResponse('<h1>Greenmind Dashboard</h1><p>Missing templates/index.html</p>')

if __name__ == '__main__':
    port = int(os.environ.get('GREENMIND_PORT', 8765))
    print(f'🌿 Greenmind Dashboard → http://0.0.0.0:{port}')
    uvicorn.run(app, host='0.0.0.0', port=port, log_level='warning')
