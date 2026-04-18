#!/usr/bin/env python3
"""
Greenmind Dashboard — FastAPI backend
Đọc camera từ /etc/greenmind/config.env, expose snapshot + status + floorplan API
"""
import os, re, time, threading, json, shutil
from pathlib import Path
from typing import Optional

try:
    from fastapi import FastAPI, Response, UploadFile, File
    from fastapi.responses import HTMLResponse, JSONResponse
    import uvicorn
    import cv2
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install',
        'fastapi', 'uvicorn[standard]', 'opencv-python-headless', 'requests', '-q'])
    from fastapi import FastAPI, Response, UploadFile, File
    from fastapi.responses import HTMLResponse, JSONResponse
    import uvicorn

CONFIG_FILE   = os.environ.get('GREENMIND_CONFIG', '/etc/greenmind/config.env')
SNAP_DIR      = Path(os.environ.get('GREENMIND_SNAP_DIR', '/tmp/greenmind_snaps'))
DATA_DIR      = Path(os.environ.get('GREENMIND_DATA',   str(Path.home() / '.greenmind')))
FLOORPLAN_JSON = DATA_DIR / 'floorplan.json'
FLOORPLAN_IMG  = DATA_DIR / 'floorplan.png'

SNAP_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

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
                name, rtsp = m.group(1), m.group(2)
                cams[name] = {'name': name, 'rtsp': rtsp, 'online': None, 'last_snap': None}
    return cams

cameras = load_cameras()

# ── Snapshot ──────────────────────────────────────────────────────────────────
def capture_snapshot(name: str, rtsp: str) -> Optional[bytes]:
    try:
        cap = cv2.VideoCapture(rtsp, cv2.CAP_FFMPEG)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        ret, frame = cap.read()
        cap.release()
        if ret and frame is not None:
            _, buf = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            return buf.tobytes()
    except Exception as e:
        print(f'[SNAP] {name}: {e}')
    return None

def check_rtsp_online(rtsp: str, timeout: int = 3) -> bool:
    import socket
    try:
        m = re.match(r'rtsp://[^@]*@?([^:/]+):?(\d+)?/', rtsp)
        if not m: return False
        host, port = m.group(1), int(m.group(2) or 554)
        s = socket.create_connection((host, port), timeout=timeout)
        s.close()
        return True
    except:
        return False

def refresh_loop():
    while True:
        for name, cam in list(cameras.items()):
            online = check_rtsp_online(cam['rtsp'])
            cameras[name]['online'] = online
            if online:
                data = capture_snapshot(name, cam['rtsp'])
                if data:
                    (SNAP_DIR / f'{name}.jpg').write_bytes(data)
                    cameras[name]['last_snap'] = time.time()
        time.sleep(15)

threading.Thread(target=refresh_loop, daemon=True).start()

# ── Floorplan helpers ─────────────────────────────────────────────────────────
def load_floorplan():
    if FLOORPLAN_JSON.exists():
        return json.loads(FLOORPLAN_JSON.read_text())
    return {'image': None, 'cameras': {}}

def save_floorplan(data: dict):
    FLOORPLAN_JSON.write_text(json.dumps(data, indent=2))

# ── API ───────────────────────────────────────────────────────────────────────
@app.get('/api/cameras')
def get_cameras():
    return JSONResponse([
        {'name': c['name'], 'rtsp': c['rtsp'], 'online': c['online'], 'last_snap': c['last_snap']}
        for c in cameras.values()
    ])

@app.get('/api/snapshot/{name}')
def get_snapshot(name: str):
    snap = SNAP_DIR / f'{name}.jpg'
    if snap.exists():
        return Response(snap.read_bytes(), media_type='image/jpeg')
    cam = cameras.get(name)
    if not cam: return Response(status_code=404)
    data = capture_snapshot(name, cam['rtsp'])
    if data:
        snap.write_bytes(data)
        cameras[name]['last_snap'] = time.time()
        return Response(data, media_type='image/jpeg')
    return Response(status_code=503)

@app.get('/api/capture/{name}')
def force_capture(name: str):
    cam = cameras.get(name)
    if not cam: return JSONResponse({'error': 'not found'}, status_code=404)
    online = check_rtsp_online(cam['rtsp'])
    cameras[name]['online'] = online
    if online:
        data = capture_snapshot(name, cam['rtsp'])
        if data:
            (SNAP_DIR / f'{name}.jpg').write_bytes(data)
            cameras[name]['last_snap'] = time.time()
            return JSONResponse({'ok': True, 'ts': cameras[name]['last_snap']})
    return JSONResponse({'ok': False, 'online': online})

@app.get('/api/reload')
def reload_config():
    global cameras
    cameras = load_cameras()
    return JSONResponse({'cameras': len(cameras)})

# ── Floorplan API ─────────────────────────────────────────────────────────────
@app.get('/api/floorplan')
def get_floorplan():
    fp = load_floorplan()
    fp['has_image'] = FLOORPLAN_IMG.exists()
    return JSONResponse(fp)

@app.post('/api/floorplan/image')
async def upload_floorplan(file: UploadFile = File(...)):
    """Upload ảnh mặt bằng."""
    content = await file.read()
    # Lưu dưới dạng PNG
    import io
    try:
        import numpy as np
        arr = np.frombuffer(content, np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        cv2.imwrite(str(FLOORPLAN_IMG), img)
    except:
        FLOORPLAN_IMG.write_bytes(content)
    fp = load_floorplan()
    fp['image'] = 'floorplan.png'
    save_floorplan(fp)
    return JSONResponse({'ok': True})

@app.get('/api/floorplan/image')
def get_floorplan_image():
    if not FLOORPLAN_IMG.exists():
        return Response(status_code=404)
    return Response(FLOORPLAN_IMG.read_bytes(), media_type='image/png')

@app.post('/api/floorplan/layout')
async def save_layout(request_data: dict):
    """Lưu vị trí camera: {"CAM_01": {"x": 0.15, "y": 0.3}, ...}"""
    fp = load_floorplan()
    fp['cameras'] = request_data
    save_floorplan(fp)
    return JSONResponse({'ok': True, 'saved': len(request_data)})

@app.get('/', response_class=HTMLResponse)
def index():
    html_path = DATA_DIR / 'templates' / 'index.html'
    if not html_path.exists():
        html_path = Path(__file__).parent / 'templates' / 'index.html'
    if html_path.exists():
        return HTMLResponse(html_path.read_text())
    return HTMLResponse('<h1>Greenmind Dashboard</h1><p>Missing templates/index.html</p>')

if __name__ == '__main__':
    port = int(os.environ.get('GREENMIND_PORT', 8765))
    print(f'🌿 Greenmind Dashboard → http://0.0.0.0:{port}')
    uvicorn.run(app, host='0.0.0.0', port=port, log_level='warning')
