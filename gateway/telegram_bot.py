#!/usr/bin/env python3
"""
🌿 Greenmind v3.1 — Telegram Bot
Hỗ trợ: commands + chat AI tự nhiên + proactive alerts
"""

import os, time, logging, requests, json
from datetime import datetime
from pathlib import Path

log = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

SNAP_DIR  = Path('/tmp/greenmind_snaps')
# Memory chat mỗi user: {chat_id: [{"role": "user/assistant", "content": "..."}]}
_chat_history = {}

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

def send_message(token, chat_id, text, photo_path=None):
    if photo_path and Path(photo_path).exists():
        with open(photo_path, 'rb') as f:
            requests.post(f'https://api.telegram.org/bot{token}/sendPhoto',
                data={'chat_id': chat_id, 'caption': text[:1024], 'parse_mode': 'Markdown'},
                files={'photo': f}, timeout=15)
    else:
        # Chia nhỏ nếu quá dài
        for i in range(0, len(text), 4096):
            requests.post(f'https://api.telegram.org/bot{token}/sendMessage',
                json={'chat_id': chat_id, 'text': text[i:i+4096], 'parse_mode': 'Markdown'},
                timeout=10)

def get_gateway_data(endpoint, params=None):
    cfg = load_config()
    port = cfg.get('GREENMIND_PORT', '8765')
    try:
        r = requests.get(f'http://localhost:{port}{endpoint}', params=params, timeout=5)
        return r.json()
    except Exception:
        return {}

def build_system_context():
    """Lấy dữ liệu hệ thống để cung cấp cho AI."""
    try:
        devices = get_gateway_data('/api/devices') or []
        events = get_gateway_data('/api/events', {'limit': 10}) or []
        online = [d for d in devices if d.get('status') == 'online']
        lines = [f"Thiết bị online ({len(online)}/{len(devices)}):"]
        for d in online[:5]:
            lines.append(f"- {d.get('name', d['id'])} ({d.get('type','')})")
        lines.append(f"\n{len(events)} sự kiện gần nhất:")
        for e in events[:5]:
            ts_str = datetime.fromtimestamp(e.get('ts', 0)).strftime('%H:%M %d/%m')
            lines.append(f"- [{ts_str}] {e.get('type','')} tại {e.get('device_name','?')}: {(e.get('ai_analysis') or '')[:80]}")
        return '\n'.join(lines)
    except Exception:
        return ''

def handle_command(token, chat_id, text):
    cfg = load_config()
    parts = text.strip().split()
    cmd = parts[0].lower().split('@')[0]

    if cmd == '/start':
        msg = (
            "🌿 *Greenmind v3.1* — Smart Building AI\n\n"
            "Các lệnh:\n"
            "/status — Trạng thái hệ thống\n"
            "/devices — Danh sách thiết bị\n"
            "/snap <id> — Chụp ảnh + AI\n"
            "/events [n] — Sự kiện gần nhất\n"
            "/report — Báo cáo hôm nay\n"
            "/clear — Xoá lịch sử chat\n\n"
            "💬 Hoặc nhắn tin tự nhiên để chat với AI!"
        )
        send_message(token, chat_id, msg)

    elif cmd == '/status':
        h = get_gateway_data('/api/health')
        devices = get_gateway_data('/api/devices') or []
        online = sum(1 for d in devices if d.get('status') == 'online')
        msg = (
            f"🌿 *Greenmind v{h.get('version','?')}*\n"
            f"⏱ Uptime: {h.get('uptime','?')}\n"
            f"📹 Thiết bị online: {online}/{len(devices)}\n"
            f"📋 Tổng sự kiện: {h.get('events_count','?')}"
        )
        send_message(token, chat_id, msg)

    elif cmd == '/devices':
        devices = get_gateway_data('/api/devices') or []
        if not devices:
            send_message(token, chat_id, '❌ Không có thiết bị nào.')
            return
        lines = ['🔧 *Danh sách thiết bị:*']
        for d in devices:
            icon = {'camera':'📷','access':'⏰','lock':'🔐','sensor':'🌡️','relay':'💡','barrier':'🚗'}.get(d.get('type',''),'📦')
            status = '🟢' if d.get('status') == 'online' else '🔴'
            lines.append(f"{status} {icon} `{d['id']}` — {d['name']}")
        send_message(token, chat_id, '\n'.join(lines))

    elif cmd == '/snap':
        if len(parts) < 2:
            send_message(token, chat_id, '⚠️ Dùng: /snap <device_id>')
            return
        device_id = parts[1].upper()
        snap_path = SNAP_DIR / f'{device_id}.jpg'
        if not snap_path.exists():
            send_message(token, chat_id, f'❌ Không có ảnh cho `{device_id}`')
            return
        send_message(token, chat_id, '📷 Đang phân tích...')
        from ai_engine import analyze_image
        with open(snap_path, 'rb') as f:
            analysis = analyze_image(f.read())
        caption = f"📷 *{device_id}*\n🕐 {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}\n🤖 {analysis}"
        send_message(token, chat_id, caption, str(snap_path))

    elif cmd == '/events':
        n = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 5
        events = get_gateway_data('/api/events', {'limit': n}) or []
        if not events:
            send_message(token, chat_id, '📋 Chưa có sự kiện nào.')
            return
        lines = [f'📋 *{n} sự kiện gần nhất:*']
        for e in events:
            ts_str = datetime.fromtimestamp(e.get('ts', 0)).strftime('%H:%M:%S %d/%m')
            ai = (e.get('ai_analysis') or '')[:60]
            lines.append(f"• `{ts_str}` [{e.get('type','')}] {e.get('device_name','')} {ai}")
        send_message(token, chat_id, '\n'.join(lines))

    elif cmd == '/report':
        events = get_gateway_data('/api/events', {'limit': 100}) or []
        today = datetime.now().date()
        today_events = [e for e in events if datetime.fromtimestamp(e.get('ts',0)).date() == today]
        motion = sum(1 for e in today_events if e.get('type') == 'motion')
        checkin = sum(1 for e in today_events if e.get('type') == 'checkin')
        msg = (
            f"📊 *Báo cáo hôm nay* ({today.strftime('%d/%m/%Y')})\n\n"
            f"🚶 Phát hiện chuyển động: {motion}\n"
            f"⏰ Lượt chấm công: {checkin}\n"
            f"📋 Tổng sự kiện: {len(today_events)}"
        )
        send_message(token, chat_id, msg)

    elif cmd == '/clear':
        _chat_history[chat_id] = []
        send_message(token, chat_id, '🗑 Đã xoá lịch sử chat.')

    else:
        # Không phải command → chat AI tự nhiên
        handle_chat(token, chat_id, text)

def handle_chat(token, chat_id, user_text):
    """Xử lý chat tự nhiên với AI."""
    from ai_engine import chat as ai_chat

    # Gửi typing indicator
    try:
        cfg = load_config()
        requests.post(
            f'https://api.telegram.org/bot{cfg.get("TELEGRAM_TOKEN","")}/sendChatAction',
            json={'chat_id': chat_id, 'action': 'typing'}, timeout=5
        )
    except Exception:
        pass

    # Lấy history
    history = _chat_history.get(chat_id, [])

    # Build context hệ thống
    context = build_system_context()

    # Gọi AI
    reply = ai_chat(user_text, history=history, system_context=context)

    # Cập nhật history
    history.append({'role': 'user', 'content': user_text})
    history.append({'role': 'assistant', 'content': reply})
    _chat_history[chat_id] = history[-20:]  # Giữ 20 tin nhắn gần nhất

    send_message(token, chat_id, reply)

def main():
    cfg = load_config()
    token = cfg.get('TELEGRAM_TOKEN', '')
    chat_id = cfg.get('TELEGRAM_CHAT_ID', '')
    if not token:
        log.error('❌ Chưa cấu hình TELEGRAM_TOKEN')
        return

    log.info('🌿 Greenmind Telegram Bot v3.1 khởi động...')
    SNAP_DIR.mkdir(exist_ok=True)
    offset = 0

    while True:
        try:
            r = requests.get(f'https://api.telegram.org/bot{token}/getUpdates',
                params={'offset': offset, 'timeout': 30}, timeout=35)
            updates = r.json().get('result', [])
            for u in updates:
                offset = u['update_id'] + 1
                msg = u.get('message') or u.get('edited_message')
                if not msg or 'text' not in msg:
                    continue
                cid = str(msg['chat']['id'])
                if chat_id and cid != str(chat_id):
                    continue
                handle_command(token, cid, msg['text'])
        except Exception as e:
            log.error(f'Bot lỗi: {e}')
            time.sleep(5)

if __name__ == '__main__':
    main()
