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

import os, re, time, threading, json, asyncio, logging, hashlib, secrets
from pathlib import Path
from typing import Optional
from datetime import datetime, timedelta

# ── Auto-install dependencies ─────────────────────────────────────────────────
try:
    from fastapi import FastAPI, Response, UploadFile, File, Form, WebSocket, WebSocketDisconnect, Request, Depends, Cookie
    from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
    from fastapi.middleware.cors import CORSMiddleware
    import uvicorn
    import cv2
    import paho.mqtt.client as mqtt
    import requests
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install',
        'fastapi', 'uvicorn[standard]', 'opencv-python-headless',
        'paho-mqtt', 'requests', 'websockets', 'psutil', '-q'])
    from fastapi import FastAPI, Response, UploadFile, File, Form, WebSocket, WebSocketDisconnect, Request, Depends, Cookie
    from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
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

# ── Auth config ───────────────────────────────────────────────────────────────
AUTH_ENABLED  = cfg.get('DASHBOARD_AUTH', 'false').lower() == 'true'
AUTH_USER     = cfg.get('DASHBOARD_USER', 'admin')
AUTH_HASH     = cfg.get('DASHBOARD_PASS_HASH', '')   # salt:sha256
AUTH_SECRET   = cfg.get('DASHBOARD_SECRET', secrets.token_hex(32))
# Sessions: token → expiry timestamp
_sessions: dict[str, float] = {}
SESSION_TTL = 60 * 60 * 8  # 8 giờ

def _verify_password(password: str) -> bool:
    if not AUTH_HASH or ':' not in AUTH_HASH:
        return True  # chưa set pass → cho qua
    salt, stored = AUTH_HASH.split(':', 1)
    h = hashlib.sha256((salt + password).encode()).hexdigest()
    return h == stored

def _create_session() -> str:
    token = secrets.token_urlsafe(32)
    _sessions[token] = time.time() + SESSION_TTL
    return token

def _valid_session(token: str | None) -> bool:
    if not AUTH_ENABLED:
        return True
    if not token or token not in _sessions:
        return False
    if _sessions[token] < time.time():
        del _sessions[token]
        return False
    return True

def require_auth(request: Request, session: str | None = Cookie(default=None)):
    if not _valid_session(session):
        raise HTTPException(status_code=302, headers={'Location': '/login'})
    return True

# HTTPException cần import thêm
from fastapi import HTTPException

MQTT_BROKER   = cfg.get('MQTT_BROKER', 'localhost')
MQTT_PORT     = int(cfg.get('MQTT_PORT', 1883))
GEMINI_KEY    = cfg.get('GEMINI_KEY', '')
NVIDIA_KEY    = cfg.get('NVIDIA_KEY', '')
AI_ENGINE     = cfg.get('AI_ENGINE', 'gemini')   # gemini | nvidia | ollama
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

# ── AI analyze (Gemini / NVIDIA NIM / Ollama) ─────────────────────────────────
def ai_analyze(cam_name: str, snapshot_url: str, event_type: str) -> str:
    """Gửi snapshot cho AI engine, nhận mô tả ngữ cảnh tiếng Việt."""
    prompt = (
        f'Camera an ninh [{cam_name}] vừa phát hiện: {event_type}. '
        f'Hãy mô tả ngắn gọn (1-2 câu tiếng Việt) những gì thấy trong ảnh, '
        f'tập trung vào đối tượng được phát hiện và mức độ đáng chú ý.'
    )
    try:
        img_resp = requests.get(snapshot_url, timeout=5)
        if img_resp.status_code != 200:
            return f'{event_type} tại {cam_name}'
        import base64
        img_b64 = base64.b64encode(img_resp.content).decode()

        # ── NVIDIA NIM ────────────────────────────────────────────────────
        if AI_ENGINE == 'nvidia' and NVIDIA_KEY and NVIDIA_KEY != 'YOUR_NVIDIA_KEY':
            payload = {
                'model': 'google/gemma-4-31b-it',
                'messages': [{
                    'role': 'user',
                    'content': [
                        {'type': 'text', 'text': prompt},
                        {'type': 'image_url', 'image_url': {
                            'url': f'data:image/jpeg;base64,{img_b64}'
                        }}
                    ]
                }],
                'max_tokens': 256,
                'temperature': 0.4,
            }
            r = requests.post(
                'https://integrate.api.nvidia.com/v1/chat/completions',
                headers={'Authorization': f'Bearer {NVIDIA_KEY}',
                         'Content-Type': 'application/json'},
                json=payload, timeout=15
            )
            if r.status_code == 200:
                return r.json()['choices'][0]['message']['content'].strip()
            log.warning(f'NVIDIA NIM error: {r.status_code} {r.text[:200]}')

        # ── Gemini ────────────────────────────────────────────────────────
        elif AI_ENGINE in ('gemini', '') and GEMINI_KEY and GEMINI_KEY != 'YOUR_KEY_HERE':
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
            log.warning(f'Gemini error: {r.status_code}')

        # ── Ollama (local) ────────────────────────────────────────────────
        elif AI_ENGINE not in ('gemini', 'nvidia'):
            payload = {
                'model': AI_ENGINE,
                'prompt': prompt,
                'images': [img_b64],
                'stream': False
            }
            r = requests.post('http://localhost:11434/api/generate',
                              json=payload, timeout=30)
            if r.status_code == 200:
                return r.json().get('response', '').strip()

    except Exception as e:
        log.warning(f'AI analyze error: {e}')

    return f'{event_type} tại {cam_name}'

# Alias cũ để backward compat
def gemini_analyze(cam_name, snapshot_url, event_type):
    return ai_analyze(cam_name, snapshot_url, event_type)

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

# ── Version & Health check ────────────────────────────────────────────────────
GREENMIND_VERSION = '2.1'

def get_latest_version() -> str:
    try:
        r = requests.get(
            'https://raw.githubusercontent.com/greenfield16/greenmind/main/VERSION',
            timeout=5
        )
        if r.status_code == 200:
            return r.text.strip()
    except:
        pass
    return ''

def get_system_health() -> dict:
    health = {}
    try:
        import shutil, psutil
        # CPU
        health['cpu_percent'] = psutil.cpu_percent(interval=0.5)
        # RAM
        mem = psutil.virtual_memory()
        health['ram_used_mb']  = round(mem.used  / 1024 / 1024)
        health['ram_total_mb'] = round(mem.total / 1024 / 1024)
        health['ram_percent']  = mem.percent
        # Disk
        disk = psutil.disk_usage(str(DATA_DIR))
        health['disk_used_gb']  = round(disk.used  / 1024 / 1024 / 1024, 1)
        health['disk_total_gb'] = round(disk.total / 1024 / 1024 / 1024, 1)
        health['disk_percent']  = disk.percent
        # Uptime
        health['uptime_s'] = int(time.time() - psutil.boot_time())
    except ImportError:
        # psutil chưa cài — fallback sang /proc
        try:
            with open('/proc/meminfo') as f:
                lines = {l.split(':')[0]: int(l.split()[1]) for l in f if ':' in l}
            total = lines.get('MemTotal', 0)
            avail = lines.get('MemAvailable', 0)
            used  = total - avail
            health['ram_used_mb']  = round(used  / 1024)
            health['ram_total_mb'] = round(total / 1024)
            health['ram_percent']  = round(used / total * 100, 1) if total else 0
        except: pass
        try:
            import shutil
            disk = shutil.disk_usage(str(DATA_DIR))
            health['disk_used_gb']  = round(disk.used  / 1024**3, 1)
            health['disk_total_gb'] = round(disk.total / 1024**3, 1)
            health['disk_percent']  = round(disk.used / disk.total * 100, 1) if disk.total else 0
        except: pass
        try:
            with open('/proc/loadavg') as f:
                health['cpu_percent'] = round(float(f.read().split()[0]) * 100 / os.cpu_count(), 1)
        except: pass
        try:
            with open('/proc/uptime') as f:
                health['uptime_s'] = int(float(f.read().split()[0]))
        except: pass
    return health

@app.get('/api/health')
def get_health():
    health = get_system_health()
    # Version check (cache 1h)
    latest = get_latest_version()
    health['version']         = GREENMIND_VERSION
    health['latest_version']  = latest
    health['update_available'] = bool(latest and latest != GREENMIND_VERSION)
    health['cameras_total']   = len(cameras)
    health['cameras_online']  = sum(1 for c in cameras.values() if c.get('online'))
    health['alerts_total']    = len(alerts)
    health['alerts_today']    = sum(1 for a in alerts if isToday_py(a.get('ts', 0)))
    health['ws_connections']  = len(ws_manager.connections)
    health['mqtt_broker']     = MQTT_BROKER
    return JSONResponse(health)

def isToday_py(ts: float) -> bool:
    from datetime import date
    try:
        return datetime.fromtimestamp(ts).date() == date.today()
    except:
        return False


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
def frigate_recordings(name: str, limit: int = 30):
    """Lấy danh sách recording từ Frigate cho 1 camera."""
    try:
        r = requests.get(f'{FRIGATE_URL}/api/{name.lower()}/recordings', timeout=5)
        if r.status_code == 200:
            return JSONResponse(r.json()[:limit])
    except Exception as e:
        return JSONResponse({'error': str(e)}, status_code=502)
    return JSONResponse([])

@app.get('/api/frigate/stream/{name}/{recording_id}')
def frigate_stream(name: str, recording_id: str):
    """Proxy video stream từ Frigate về browser."""
    try:
        url = f'{FRIGATE_URL}/vod/recording/{recording_id}/index.m3u8'
        r = requests.get(url, timeout=5, stream=True)
        if r.status_code == 200:
            return Response(
                content=r.content,
                media_type=r.headers.get('Content-Type', 'application/x-mpegurl')
            )
        # Fallback: thử mp4 trực tiếp
        url_mp4 = f'{FRIGATE_URL}/api/recording/{recording_id}/clip.mp4'
        r2 = requests.get(url_mp4, timeout=10, stream=True)
        if r2.status_code == 200:
            return Response(content=r2.content, media_type='video/mp4')
    except Exception as e:
        log.warning(f'Stream {recording_id}: {e}')
    return Response(status_code=404)

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

@app.get('/static/manifest.json')
def serve_manifest():
    p = DATA_DIR / 'templates' / 'manifest.json'
    if not p.exists():
        p = Path(__file__).parent / 'templates' / 'manifest.json'
    if p.exists():
        return Response(p.read_text(), media_type='application/manifest+json')
    return Response(status_code=404)

@app.get('/static/sw.js')
def serve_sw():
    p = DATA_DIR / 'templates' / 'sw.js'
    if not p.exists():
        p = Path(__file__).parent / 'templates' / 'sw.js'
    if p.exists():
        return Response(p.read_text(), media_type='application/javascript')
    return Response(status_code=404)

# ── Login page ────────────────────────────────────────────────────────────────
@app.get('/login', response_class=HTMLResponse)
def login_page():
    return HTMLResponse('''<!DOCTYPE html>
<html lang="vi"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>🌿 Greenmind — Đăng nhập</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0f1117;display:flex;align-items:center;justify-content:center;min-height:100vh;font-family:'Segoe UI',sans-serif}
.box{background:#1a1d27;border:1px solid #2a2d3a;border-radius:14px;padding:36px 32px;width:360px;max-width:95vw}
h1{color:#4caf7d;font-size:22px;margin-bottom:6px;text-align:center}
p{color:#666;font-size:13px;text-align:center;margin-bottom:28px}
label{color:#aaa;font-size:12px;display:block;margin-bottom:5px}
input{width:100%;background:#13151f;border:1px solid #2a2d3a;border-radius:7px;padding:10px 14px;color:#ddd;font-size:14px;outline:none;margin-bottom:16px}
input:focus{border-color:#4caf7d}
button{width:100%;background:#4caf7d;color:#fff;border:none;border-radius:7px;padding:11px;font-size:15px;font-weight:600;cursor:pointer}
button:hover{background:#3d9e6e}
.err{background:#e74c3c22;border:1px solid #e74c3c44;color:#e74c3c;border-radius:6px;padding:9px 14px;font-size:13px;margin-bottom:14px;display:none}
</style></head>
<body><div class="box">
<h1>🌿 GREENMIND</h1>
<p>AI CCTV Dashboard</p>
<div class="err" id="err">Sai tên đăng nhập hoặc mật khẩu.</div>
<form onsubmit="doLogin(event)">
  <label>Tên đăng nhập</label>
  <input type="text" id="u" autocomplete="username" autofocus>
  <label>Mật khẩu</label>
  <input type="password" id="p" autocomplete="current-password">
  <button type="submit">Đăng nhập</button>
</form></div>
<script>
async function doLogin(e){
  e.preventDefault();
  const r = await fetch('/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({username:document.getElementById('u').value, password:document.getElementById('p').value})});
  if(r.ok){ location.href='/'; }
  else{ document.getElementById('err').style.display='block'; }
}
</script></body></html>''')

@app.post('/auth/login')
async def do_login(data: dict):
    username = data.get('username', '')
    password = data.get('password', '')
    if username == AUTH_USER and _verify_password(password):
        token = _create_session()
        resp = JSONResponse({'ok': True})
        resp.set_cookie('session', token, httponly=True, max_age=SESSION_TTL)
        return resp
    raise HTTPException(status_code=401, detail='Invalid credentials')

@app.post('/auth/logout')
async def do_logout(session: str | None = Cookie(default=None)):
    if session and session in _sessions:
        del _sessions[session]
    resp = JSONResponse({'ok': True})
    resp.delete_cookie('session')
    return resp

# ── Frontend ──────────────────────────────────────────────────────────────────
@app.get('/', response_class=HTMLResponse)
def index(request: Request, session: str | None = Cookie(default=None)):
    if AUTH_ENABLED and not _valid_session(session):
        return RedirectResponse('/login')
    for p in [DATA_DIR / 'templates' / 'index.html',
              Path(__file__).parent / 'templates' / 'index.html']:
        if p.exists():
            return HTMLResponse(p.read_text())
    return HTMLResponse('<h1>Greenmind</h1><p>Missing templates/index.html</p>')


# ── Node Relay API ─────────────────────────────────────────────────────────────
@app.post('/api/node/snapshot')
async def node_snapshot(camera: str = Form(...), ts: int = Form(0), snapshot: UploadFile = File(...)):
    name = camera.upper().replace('-', '_')
    data = await snapshot.read()
    if len(data) < 1000:
        return JSONResponse({'error': 'invalid snapshot'}, status_code=400)
    (SNAP_DIR / f'{name}.jpg').write_bytes(data)
    if name not in cameras:
        cameras[name] = {'name': name, 'rtsp': '', 'online': True, 'last_snap': time.time(), 'last_alert': None, 'alert_count': 0}
    else:
        cameras[name]['online'] = True
        cameras[name]['last_snap'] = time.time()
    log.info(f'Node snapshot: {name} ({len(data)//1024}KB)')
    return JSONResponse({'ok': True, 'camera': name, 'size': len(data)})


@app.post('/api/node/motion')
async def node_motion(camera: str = Form(...), ts: int = Form(0), ssim: str = Form('0'), label: str = Form('motion'), snapshot: UploadFile = File(...)):
    name = camera.upper().replace('-', '_')
    data = await snapshot.read()
    if len(data) < 1000:
        return JSONResponse({'error': 'invalid snapshot'}, status_code=400)
    (SNAP_DIR / f'{name}.jpg').write_bytes(data)
    if name not in cameras:
        cameras[name] = {'name': name, 'rtsp': '', 'online': True, 'last_snap': time.time(), 'last_alert': None, 'alert_count': 0}
    cameras[name]['online'] = True
    cameras[name]['last_snap'] = time.time()
    cameras[name]['last_alert'] = time.time()
    cameras[name]['alert_count'] = cameras[name].get('alert_count', 0) + 1
    alert = {
        'cam': name, 'label': label, 'label_vn': 'Phát hiện chuyển động',
        'ts': ts or time.time(),
        'ts_str': datetime.fromtimestamp(ts or time.time()).strftime('%d/%m/%Y %H:%M:%S'),
        'ssim': ssim, 'snapshot_url': f'/api/snapshot/{name}', 'description': ''
    }
    alerts.append(alert)
    threading.Thread(target=_process_motion_alert, args=(name, data, alert), daemon=True).start()
    log.info(f'Motion: {name} SSIM={ssim}')
    return JSONResponse({'ok': True, 'camera': name})

def _process_motion_alert(name, data, alert):
    try:
        description = ai_analyze(name, f'/api/snapshot/{name}', 'motion')
        alert['description'] = description
        telegram_notify(name, description, f'http://localhost:{os.environ.get("GREENMIND_PORT","8765")}/api/snapshot/{name}')
    except Exception as e:
        log.error(f'motion alert: {e}')

if __name__ == '__main__':
    port = int(os.environ.get('GREENMIND_PORT', 8765))
    log.info(f'🌿 Greenmind Dashboard → http://0.0.0.0:{port}')
    uvicorn.run(app, host='0.0.0.0', port=port, log_level='warning')

@app.post('/api/node/motion')
async def node_motion(camera: str = Form(...), ts: int = Form(0), ssim: str = Form('0'), label: str = Form('motion'), snapshot: UploadFile = File(...)):
    name = camera.upper().replace('-', '_')
    data = await snapshot.read()
    if len(data) < 1000:
        return JSONResponse({'error': 'invalid snapshot'}, status_code=400)
    # Lưu snapshot
    snap_path = SNAP_DIR / f'{name}.jpg'
    snap_path.write_bytes(data)
    # Cập nhật camera state
    if name not in cameras:
        cameras[name] = {'name': name, 'rtsp': '', 'online': True, 'last_snap': time.time(), 'last_alert': None, 'alert_count': 0}
    cameras[name]['online'] = True
    cameras[name]['last_snap'] = time.time()
    cameras[name]['last_alert'] = time.time()
    cameras[name]['alert_count'] = cameras[name].get('alert_count', 0) + 1
    # Ghi alert log
    alert = {
        'cam': name, 'label': label, 'label_vn': 'Phát hiện chuyển động',
        'ts': ts or time.time(),
        'ts_str': datetime.fromtimestamp(ts or time.time()).strftime('%d/%m/%Y %H:%M:%S'),
        'ssim': ssim,
        'snapshot_url': f'/api/snapshot/{name}',
        'description': ''
    }
    alerts.append(alert)
    # Trigger AI + Telegram trong background
    threading.Thread(target=_process_motion_alert, args=(name, data, alert), daemon=True).start()
    log.info(f'🚨 Motion: {name} SSIM={ssim}')
    return JSONResponse({'ok': True, 'camera': name})

def _process_motion_alert(name, data, alert):
    try:
        description = ai_analyze(name, f'/api/snapshot/{name}', 'motion')
        alert['description'] = description
        telegram_notify(name, description, f'http://localhost:{os.environ.get(GREENMIND_PORT,8765)}/api/snapshot/{name}')
    except Exception as e:
        log.error(f'motion alert processing: {e}')
