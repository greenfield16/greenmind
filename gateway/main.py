#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — Gateway Main (FastAPI)
"""

import os, time, json, asyncio, logging
from pathlib import Path
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, Form, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

import db, ai_engine, alert_engine

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger(__name__)

SNAP_DIR   = Path('/tmp/greenmind_snaps')
TMPL_DIR   = Path(__file__).parent / 'templates'
START_TIME = time.time()
VERSION    = '3.0'

# Config
def load_config():
    cfg = {}
    cf = os.getenv('CONFIG_FILE', '/etc/greenmind/config.env')
    if os.path.exists(cf):
        for line in open(cf):
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, _, v = line.partition('=')
                cfg[k.strip()] = v.strip().strip('"\'')
    cfg.update(os.environ)
    return cfg

# WebSocket manager
class WSManager:
    def __init__(self): self.connections = []
    async def connect(self, ws: WebSocket):
        await ws.accept(); self.connections.append(ws)
    def disconnect(self, ws: WebSocket):
        self.connections = [c for c in self.connections if c != ws]
    async def broadcast(self, data: dict):
        dead = []
        for ws in self.connections:
            try: await ws.send_json(data)
            except: dead.append(ws)
        for ws in dead: self.disconnect(ws)

ws_manager = WSManager()

def telegram_alert(message: str, photo_path: str = None):
    """Gửi alert Telegram."""
    import threading
    def _send():
        cfg = load_config()
        token = cfg.get('TELEGRAM_TOKEN', '')
        chat_id = cfg.get('TELEGRAM_CHAT_ID', '')
        if not token or not chat_id:
            return
        import requests as req
        try:
            if photo_path and Path(photo_path).exists():
                with open(photo_path, 'rb') as f:
                    req.post(f'https://api.telegram.org/bot{token}/sendPhoto',
                        data={'chat_id': chat_id, 'caption': message, 'parse_mode': 'Markdown'},
                        files={'photo': f}, timeout=15)
            else:
                req.post(f'https://api.telegram.org/bot{token}/sendMessage',
                    json={'chat_id': chat_id, 'text': message, 'parse_mode': 'Markdown'}, timeout=10)
        except Exception as e:
            log.error(f'Telegram alert: {e}')
    threading.Thread(target=_send, daemon=True).start()

@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init_db()
    SNAP_DIR.mkdir(exist_ok=True)
    log.info(f'🌿 Greenmind Gateway v{VERSION} khởi động')
    yield

app = FastAPI(title='Greenmind Gateway', version=VERSION, lifespan=lifespan)

# Static files
if TMPL_DIR.exists():
    app.mount('/static', StaticFiles(directory=str(TMPL_DIR)), name='static')

@app.get('/', response_class=HTMLResponse)
async def index():
    f = TMPL_DIR / 'index.html'
    return HTMLResponse(f.read_text() if f.exists() else '<h1>🌿 Greenmind v3.0</h1>')

@app.get('/api/health')
async def health():
    uptime_s = int(time.time() - START_TIME)
    h, m, s = uptime_s//3600, (uptime_s%3600)//60, uptime_s%60
    events = db.get_events(limit=1)
    conn = db.get_conn()
    count = conn.execute('SELECT COUNT(*) FROM events').fetchone()[0]
    conn.close()
    return {'status': 'ok', 'version': VERSION, 'uptime': f'{h:02d}:{m:02d}:{s:02d}',
            'events_count': count}

@app.get('/api/locations')
async def locations():
    return db.get_locations()

@app.get('/api/devices')
async def devices():
    return db.get_devices()

@app.get('/api/events')
async def events(limit: int = 50, offset: int = 0):
    return db.get_events(limit=limit, offset=offset)

@app.get('/api/snapshot/{device_id}')
async def snapshot(device_id: str):
    path = SNAP_DIR / f'{device_id.upper()}.jpg'
    if not path.exists():
        return JSONResponse({'error': 'not found'}, status_code=404)
    return FileResponse(str(path), media_type='image/jpeg')

@app.post('/api/node/snapshot')
async def node_snapshot(
    device_id: str = Form(...),
    location_id: str = Form('default'),
    ts: int = Form(0),
    motion: str = Form('0'),
    snapshot: UploadFile = File(...)
):
    data = await snapshot.read()
    if len(data) < 1000:
        return JSONResponse({'error': 'invalid snapshot'}, status_code=400)
    name = device_id.upper()
    (SNAP_DIR / f'{name}.jpg').write_bytes(data)
    db.upsert_device(name, location_id, 'camera', name)
    log.info(f'📷 Snapshot: {name} ({len(data)//1024}KB)')
    return JSONResponse({'ok': True, 'device_id': name})

@app.post('/api/node/motion')
async def node_motion(
    device_id: str = Form(...),
    location_id: str = Form('default'),
    ts: int = Form(0),
    score: str = Form('0'),
    snapshot: UploadFile = File(...)
):
    data = await snapshot.read()
    if len(data) < 1000:
        return JSONResponse({'error': 'invalid snapshot'}, status_code=400)
    name = device_id.upper()
    (SNAP_DIR / f'{name}.jpg').write_bytes(data)
    db.upsert_device(name, location_id, 'camera', name)

    # AI + Alert trong background
    import threading
    def _process():
        try:
            analysis = ai_engine.analyze_image(data)
            device = db.get_device(name) or {'id': name, 'name': name}
            event_ts = ts or int(time.time())
            event_id = db.insert_event(name, 'motion',
                json.dumps({'score': score}), analysis, ts=event_ts)
            alerts = alert_engine.process_event('motion', {'score': score}, device, analysis, event_ts)
            for msg in alerts:
                db.insert_alert(event_id, 'telegram', msg)
                telegram_alert(msg, str(SNAP_DIR / f'{name}.jpg'))
            # Broadcast WS
            asyncio.run(ws_manager.broadcast({
                'type': 'motion', 'device_id': name, 'analysis': analysis,
                'ts': event_ts, 'ts_str': datetime.fromtimestamp(event_ts).strftime('%d/%m/%Y %H:%M:%S')
            }))
        except Exception as e:
            log.error(f'Motion process: {e}')
    threading.Thread(target=_process, daemon=True).start()
    log.info(f'🚨 Motion: {name} score={score}')
    return JSONResponse({'ok': True})

@app.post('/api/node/event')
async def node_event(payload: dict):
    device_id = payload.get('device_id', '').upper()
    event_type = payload.get('type', 'unknown')
    event_payload = payload.get('payload_json', {})
    ts = payload.get('ts', int(time.time()))
    device = db.get_device(device_id) or {'id': device_id, 'name': device_id}
    analysis = ai_engine.analyze_event(event_type, event_payload, device.get('name', device_id))
    event_id = db.insert_event(device_id, event_type, json.dumps(event_payload), analysis, ts=ts)
    alerts = alert_engine.process_event(event_type, event_payload, device, analysis, ts)
    for msg in alerts:
        db.insert_alert(event_id, 'telegram', msg)
        telegram_alert(msg)
    log.info(f'📋 Event: {device_id} [{event_type}]')
    return JSONResponse({'ok': True, 'event_id': event_id})

@app.websocket('/ws/events')
async def ws_events(websocket: WebSocket):
    await ws_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)

@app.get('/api/reports/attendance')
async def report_attendance(location_id: str = '', date: str = ''):
    conn = db.get_conn()
    if date:
        from datetime import date as dt_date
        d = datetime.strptime(date, '%Y-%m-%d').date()
    else:
        d = datetime.now().date()
    start = int(datetime(d.year, d.month, d.day).timestamp())
    end   = start + 86400
    rows = conn.execute("""
        SELECT e.*, d.name as device_name FROM events e
        LEFT JOIN devices d ON e.device_id = d.id
        WHERE e.type IN ('checkin','checkout') AND e.ts >= ? AND e.ts < ?
        ORDER BY e.ts
    """, (start, end)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

if __name__ == '__main__':
    import uvicorn
    port = int(os.environ.get('GREENMIND_PORT', 8765))
    log.info(f'🌿 Greenmind Gateway → http://0.0.0.0:{port}')
    uvicorn.run(app, host='0.0.0.0', port=port, log_level='warning')
