#!/usr/bin/env python3
"""
Greenmind Dashboard — FastAPI backend v2.0
─────────────────────────────────────────────
Kiến trúc:
  Frigate (NVR + Detection) → MQTT → Greenmind (AI Brain) → WebSocket → Browser
  Frigate WebRTC stream ──────────────────────────────────→ Browser (video)

Luồng alert:
  Frigate detect → MQTT event → Gemini phân tích → WS alert + Telegram
"""

import os, re, time, threading, json, asyncio, logging
from pathlib import Path
from typing import Optional
from datetime import datetime

# ── Auto-install dependencies ─────────────────────────────────────────────────
try:
    from fastapi import FastAPI, Response, UploadFile, File, WebSocket, WebSocketDisconnect
    from fastapi.responses import HTMLResponse, JSONResponse
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
    import cv2
    import paho.mqtt.client as mqtt
    import requests
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install',
        'fastapi', 'uvicorn[standard]', 'opencv-python-headless',
        'paho-mqtt', 'requests', 'websockets', '-q'])
    from fastapi import FastAPI, Response, UploadFile, File, WebSocket, WebSocketDisconnect
    from fastapi.responses import HTMLResponse, JSONResponse
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
    import cv2
    import paho.mqtt.client as mqtt
    import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('greenmind')

# ── Config ────────────────────────────────────────────────────────────────────
CONFIG_FILE    = os.environ.get('GREENMIND_CONFIG',   '/etc/greenmind/config.env')
SNAP_DIR       = Path(os.environ.get('GREENMIND_SNAP_DIR', '/tmp/greenmind_snaps'))
DATA_DIR       = Path(os.environ.get('GREENMIND_DATA', str(Path.home() / '.greenmind')))
FLOORPLAN_JSON = DATA_DIR / 'floorplan.json'
FLOORPLAN_IMG  = DATA_DIR / 'floorplan.png'
ALERTS_LOG     = DATA_DIR / 'alerts.json'

SNAP_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)

def load_env():
    """Đọc config.env → dict"""
    cfg = {}
    if not os.path.exists(CONFIG_FILE):
        return cfg
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            if line.startswith('#') or '=' not in line:
                continue
            k, _, v = line.partition('=')
            cfg[k.strip()] = v.strip().strip('"\'')
    return cfg

cfg = load_env()

MQTT_BROKER   = cfg.get('MQTT_BROKER', 'localhost')
MQTT_PORT     = int(cfg.get('MQTT_PORT', 1883))
GEMINI_KEY    = cfg.get('GEMINI_KEY', '')
FRIGATE_URL   = cfg.get('FRIGATE_URL', 'http://localhost:5000')
TELEGRAM_TOKEN = cfg.get('TELEGRAM_TOKEN', '')
TELEGRAM_CHAT  = cfg.get('TELEGRAM_CHAT_ID', '')

# ── Load cameras ──────────────────────────────────────────────────────────────
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
                cams[name] = {
                    'name': name, 'rtsp': rtsp,
                    'online': None, 'last_snap': None,
                    'last_alert': None, 'alert_count': 0
                }
    return cams

cameras = load_cameras()

# ── Alert store (in-memory + file) ───────────────────────────────────────────
alerts: list = []
MAX_ALERTS = 200

def push_alert(alert: dict):
    """Thêm alert vào store, ghi file."""
    alerts.append(alert)
    if len(alerts) > MAX_ALERTS:
        alerts.pop(0)
    # Cập nhật camera stats
    cam = cameras.get(alert.get('cam'))
    if cam:
        cam['last_alert'] = alert.get('ts')
        cam['alert_count'] = cam.get('alert_count', 0) + 1
    # Ghi file log
    try:
        ALERTS_LOG.write_text(json.dumps(alerts[-100:], indent=2))
    except:
        pass

# Load alerts cũ nếu có
if ALERTS_LOG.exists():
    try:
        alerts = json.loads(ALERTS_LOG.read_text())
    except:
        alerts = []

# ── WebSocket Manager ─────────────────────────────────────────────────────────
class WSManager:
    def __init__(self):
        self.connections: list[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.connections.append(ws)
        log.info(f'WS connected. Total: {len(self.connections)}')

    def disconnect(self, ws: WebSocket):
        self.connections.remove(ws)
        log.info(f'WS disconnected. Total: {len(self.connections)}')

    async def broadcast(self, data: dict):
        if not self.connections:
            return
        msg = json.dumps(data)
        dead = []
        for ws in self.connections:
            try:
                await ws.send_text(msg)
            except:
                dead.append(ws)
        for ws in dead:
            self.connections.remove(ws)

ws_manager = WSManager()

# ── Gemini AI analyze ─────────────────────────────────────────────────────────
def gemini_analyze(cam_name: str, snapshot_url: str, event_type: str) -> str:
    """Gửi snapshot cho Gemini, nhận mô tả ngữ cảnh."""
    if not GEMINI_KEY or GEMINI_KEY == 'YOUR_KEY_HERE':
        return f'{event_type} tại {cam_name}'
    try:
        # Tải ảnh
        img_resp = requests.get(snapshot_url, timeout=5)
        if img_resp.status_code != 200:
            return f'{event_type} tại {cam_name}'
        import base64
        img_b64 = base64.b64encode(img_resp.content).decode()

        prompt = (
            f'Camera an ninh [{cam_name}] vừa phát hiện: {event_type}. '
            f'Hãy mô tả ngắn gọn (1-2 câu tiếng Việt) những gì thấy trong ảnh, '
            f'tập trung vào đối tượng được phát hiện và mức độ đáng chú ý.'
        )
        payload = {
            'contents': [{
                'parts': [
                    {'text': prompt},
                    {'inline_data': {'mime_type': 'image/jpeg', 'data': img_b64}}
                ]
            }]
        }
        r = requests.post(
            f'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={GEMINI_KEY}',
            json=payload, timeout=10
        )
        if r.status_code == 200:
            return r.json()['candidates'][0]['content']['parts'][0]['text'].strip()
    except Exception as e:
        log.warning(f'Gemini error: {e}')
    return f'{event_type} tại {cam_name}'

# ── Telegram notify ───────────────────────────────────────────────────────────
def telegram_notify(cam_name: str, description: str, snapshot_url: str):
    """Gửi ảnh + mô tả qua Telegram."""
    if not TELEGRAM_TOKEN or not TELEGRAM_CHAT:
        return
    try:
        caption = f'🚨 *{cam_name}*\n{description}\n_{datetime.now().strftime("%d/%m/%Y %H:%M:%S")}_'
        img_resp = requests.get(snapshot_url, timeout=5)
        if img_resp.status_code == 200:
            requests.post(
                f'https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendPhoto',
                data={'chat_id': TELEGRAM_CHAT, 'caption': caption, 'parse_mode': 'Markdown'},
                files={'photo': ('snap.jpg', img_resp.content, 'image/jpeg')},
                timeout=10
            )
        else:
            requests.post(
                f'https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage',
                json={'chat_id': TELEGRAM_CHAT, 'text': caption, 'parse_mode': 'Markdown'},
                timeout=10
            )
    except Exception as e:
        log.warning(f'Telegram error: {e}')

# ── MQTT → Frigate events ─────────────────────────────────────────────────────
_loop: asyncio.AbstractEventLoop = None  # set khi app start

def on_frigate_event(client, userdata, msg):
    """
    Nhận MQTT event từ Frigate.
    Topic: frigate/events  (payload JSON)
    hoặc: frigate/<camera>/person  (payload JSON)
    """
    try:
        payload = json.loads(msg.payload.decode())
        topic = msg.topic

        # Frigate gửi qua topic frigate/events
        if topic == 'frigate/events':
            event_type = payload.get('type', '')
            if event_type != 'new':  # chỉ xử lý event mới
                return
            before = payload.get('before', {})
            after  = payload.get('after',  {})
            cam_name  = (after.get('camera') or before.get('camera', 'UNKNOWN')).upper()
            label     = after.get('label') or before.get('label', 'object')
            score     = after.get('top_score') or before.get('top_score', 0)
            box       = after.get('box') or before.get('box', [0,0,0,0])
            event_id  = after.get('id') or before.get('id', '')

        # Frigate cũng push theo topic riêng frigate/<cam>/<label>
        elif re.match(r'^frigate/.+/.+$', topic):
            parts     = topic.split('/')
            cam_name  = parts[1].upper()
            label     = parts[2]
            score     = payload.get('score', payload.get('top_score', 0))
            box       = payload.get('box', [0, 0, 0, 0])
            event_id  = payload.get('id', '')
        else:
            return

        # Map tên camera Frigate → tên trong config (frigate dùng lowercase)
        cam_key = next((k for k in cameras if k.upper() == cam_name.replace('-','_')), cam_name)

        # Snapshot URL từ Frigate
        snapshot_url = f'{FRIGATE_URL}/api/{cam_name.lower()}/latest.jpg?bbox=1'

        ts = time.time()
        label_vn = {
            'person': 'Phát hiện người',
            'car': 'Phát hiện xe hơi',
            'motorcycle': 'Phát hiện xe máy',
            'bicycle': 'Phát hiện xe đạp',
            'dog': 'Phát hiện chó',
            'cat': 'Phát hiện mèo',
        }.get(label, f'Phát hiện {label}')

        log.info(f'Frigate event: {cam_name} / {label} ({score:.0%})')

        # Chạy AI + Telegram trong thread riêng (không block MQTT)
        def process():
            description = gemini_analyze(cam_key, snapshot_url, label_vn)
            alert = {
                'id':          event_id,
                'cam':         cam_key,
                'cam_display': cam_name,
                'label':       label,
                'label_vn':    label_vn,
                'description': description,
                'score':       round(score, 3),
                'box':         box,   # [x1,y1,x2,y2] pixel hoặc normalized
                'ts':          ts,
                'ts_str':      datetime.fromtimestamp(ts).strftime('%d/%m %H:%M:%S'),
                'snapshot_url': snapshot_url,
            }
            push_alert(alert)
            telegram_notify(cam_key, description, snapshot_url)

            # Broadcast qua WebSocket (thread-safe)
            if _loop and not _loop.is_closed():
                asyncio.run_coroutine_threadsafe(ws_manager.broadcast(alert), _loop)

        threading.Thread(target=process, daemon=True).start()

    except Exception as e:
        log.error(f'MQTT event error: {e}')

def start_mqtt():
    """Kết nối MQTT broker và subscribe Frigate topics."""
    client = mqtt.Client(client_id='greenmind-dashboard')
    client.on_message = on_frigate_event

    def on_connect(c, userdata, flags, rc):
        if rc == 0:
            log.info(f'MQTT connected to {MQTT_BROKER}:{MQTT_PORT}')
            c.subscribe('frigate/events')
            c.subscribe('frigate/#')
        else:
            log.warning(f'MQTT connect failed: rc={rc}')

    client.on_connect = on_connect
    try:
        client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
        client.loop_start()
    except Exception as e:
        log.warning(f'MQTT unavailable: {e} — alerts disabled until broker starts')

# ── Snapshot (fallback từ Greenmind nếu Frigate chưa cài) ────────────────────
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
        log.warning(f'Snapshot {name}: {e}')
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
    """Background: check online status + cache snapshot mỗi 15s."""
    while True:
        for name, cam in list(cameras.items()):
            online = check_rtsp_online(cam['rtsp'])
            cameras[name]['online'] = online
            if online:
                # Ưu tiên snapshot từ Frigate nếu có
                snap_data = None
                frigate_snap = f'{FRIGATE_URL}/api/{name.lower()}/latest.jpg'
                try:
                    r = requests.get(frigate_snap, timeout=3)
                    if r.status_code == 200:
                        snap_data = r.content
                except:
                    pass
                if not snap_data:
                    snap_data = capture_snapshot(name, cam['rtsp'])
                if snap_data:
                    (SNAP_DIR / f'{name}.jpg').write_bytes(snap_data)
                    cameras[name]['last_snap'] = time.time()
        time.sleep(15)

# ── Floorplan helpers ─────────────────────────────────────────────────────────
def load_floorplan():
    if FLOORPLAN_JSON.exists():
        return json.loads(FLOORPLAN_JSON.read_text())
    return {'image': None, 'cameras': {}}

def save_floorplan(data: dict):
    FLOORPLAN_JSON.write_text(json.dumps(data, indent=2))

# ── FastAPI App ───────────────────────────────────────────────────────────────
app = FastAPI(title='Greenmind Dashboard', version='2.0')
app.add_middleware(CORSMiddleware, allow_origins=['*'], allow_methods=['*'], allow_headers=['*'])

# Serve static files (style.css, etc.)
_static_dir = DATA_DIR / 'templates'
if _static_dir.exists():
    from fastapi.staticfiles import StaticFiles
    app.mount('/static', StaticFiles(directory=str(_static_dir)), name='static')

@app.on_event('startup')
async def startup():
    global _loop
    _loop = asyncio.get_event_loop()
    threading.Thread(target=refresh_loop, daemon=True).start()
    threading.Thread(target=start_mqtt,   daemon=True).start()
    log.info('🌿 Greenmind Dashboard v2.0 started')

# ── WebSocket endpoint ────────────────────────────────────────────────────────
@app.websocket('/ws/alerts')
async def ws_alerts(ws: WebSocket):
    await ws_manager.connect(ws)
    # Gửi 10 alerts gần nhất ngay khi connect
    for a in alerts[-10:]:
        await ws.send_text(json.dumps(a))
    try:
        while True:
            await ws.receive_text()  # giữ connection
    except WebSocketDisconnect:
        ws_manager.disconnect(ws)

# ── Camera API ────────────────────────────────────────────────────────────────
@app.get('/api/cameras')
def get_cameras():
    return JSONResponse([
        {
            'name':        c['name'],
            'rtsp':        c['rtsp'],
            'online':      c['online'],
            'last_snap':   c['last_snap'],
            'last_alert':  c['last_alert'],
            'alert_count': c['alert_count'],
            'stream_url':  f'{FRIGATE_URL}/api/{c["name"].lower()}/latest.jpg',
            'webrtc_url':  f'{FRIGATE_URL}/live/webrtc/{c["name"].lower()}',
        }
        for c in cameras.values()
    ])

@app.get('/api/snapshot/{name}')
def get_snapshot(name: str):
    # Ưu tiên snapshot từ Frigate
    try:
        r = requests.get(f'{FRIGATE_URL}/api/{name.lower()}/latest.jpg', timeout=3)
        if r.status_code == 200:
            return Response(r.content, media_type='image/jpeg')
    except:
        pass
    # Fallback: cache local
    snap = SNAP_DIR / f'{name}.jpg'
    if snap.exists():
        return Response(snap.read_bytes(), media_type='image/jpeg')
    cam = cameras.get(name)
    if not cam:
        return Response(status_code=404)
    data = capture_snapshot(name, cam['rtsp'])
    if data:
        snap.write_bytes(data)
        cameras[name]['last_snap'] = time.time()
        return Response(data, media_type='image/jpeg')
    return Response(status_code=503)

@app.get('/api/capture/{name}')
def force_capture(name: str):
    cam = cameras.get(name)
    if not cam:
        return JSONResponse({'error': 'not found'}, status_code=404)
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

# ── Alerts API ────────────────────────────────────────────────────────────────
@app.get('/api/alerts')
def get_alerts(limit: int = 50, cam: str = None):
    result = alerts[-limit:]
    if cam:
        result = [a for a in result if a.get('cam') == cam]
    return JSONResponse(list(reversed(result)))

@app.delete('/api/alerts')
def clear_alerts():
    alerts.clear()
    try: ALERTS_LOG.unlink()
    except: pass
    return JSONResponse({'ok': True})

# ── Frigate proxy info ────────────────────────────────────────────────────────
@app.get('/api/frigate/status')
def frigate_status():
    try:
        r = requests.get(f'{FRIGATE_URL}/api/version', timeout=3)
        if r.status_code == 200:
            return JSONResponse({'online': True, 'version': r.json(), 'url': FRIGATE_URL})
    except:
        pass
    return JSONResponse({'online': False, 'url': FRIGATE_URL})

@app.get('/api/frigate/recordings/{name}')
def frigate_recordings(name: str, limit: int = 20):
    """Lấy danh sách recording từ Frigate cho 1 camera."""
    try:
        r = requests.get(f'{FRIGATE_URL}/api/{name.lower()}/recordings', timeout=5)
        if r.status_code == 200:
            return JSONResponse(r.json()[:limit])
    except Exception as e:
        return JSONResponse({'error': str(e)}, status_code=502)
    return JSONResponse([], status_code=200)

# ── Floorplan API ─────────────────────────────────────────────────────────────
@app.get('/api/floorplan')
def get_floorplan():
    fp = load_floorplan()
    fp['has_image'] = FLOORPLAN_IMG.exists()
    return JSONResponse(fp)

@app.post('/api/floorplan/image')
async def upload_floorplan(file: UploadFile = File(...)):
    content = await file.read()
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
    fp = load_floorplan()
    fp['cameras'] = request_data
    save_floorplan(fp)
    return JSONResponse({'ok': True, 'saved': len(request_data)})

# ── Frontend ──────────────────────────────────────────────────────────────────
@app.get('/', response_class=HTMLResponse)
def index():
    for p in [DATA_DIR / 'templates' / 'index.html',
              Path(__file__).parent / 'templates' / 'index.html']:
        if p.exists():
            return HTMLResponse(p.read_text())
    return HTMLResponse('<h1>Greenmind</h1><p>Missing templates/index.html</p>')

if __name__ == '__main__':
    port = int(os.environ.get('GREENMIND_PORT', 8765))
    log.info(f'🌿 Greenmind Dashboard → http://0.0.0.0:{port}')
    uvicorn.run(app, host='0.0.0.0', port=port, log_level='warning')
