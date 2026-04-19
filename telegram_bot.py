#!/usr/bin/env python3
"""
🌿 Greenmind — Telegram Bot 2 chiều
─────────────────────────────────────
Lệnh hỗ trợ:
  /start   — Chào mừng
  /help    — Danh sách lệnh
  /status  — Trạng thái hệ thống
  /cams    — Danh sách camera
  /snap <cam>  — Chụp ảnh + phân tích AI
  /ai <cam>    — Phân tích AI ảnh mới nhất
  /alerts [n]  — N cảnh báo gần nhất (mặc định 5)
  /arm     — Bật chế độ giám sát
  /disarm  — Tắt chế độ giám sát
  /reload  — Tải lại danh sách camera
"""

import os, time, logging, asyncio, json, requests, base64
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('greenmind-bot')

try:
    from telegram import Update, ReplyKeyboardMarkup
    from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'python-telegram-bot>=20.0', '-q'])
    from telegram import Update, ReplyKeyboardMarkup
    from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes

# ── Config ─────────────────────────────────────────────────────────────────
CONFIG_FILE   = os.environ.get('GREENMIND_CONFIG', '/etc/greenmind/config.env')
DATA_DIR      = Path(os.environ.get('GREENMIND_DATA', str(Path.home() / '.greenmind')))
SNAP_DIR      = Path('/tmp/greenmind_snaps')
DASHBOARD_URL = 'http://localhost:' + os.environ.get('GREENMIND_PORT', '8765')

def load_env():
    cfg = {}
    for f in [CONFIG_FILE, '/etc/greenmind/auth.env']:
        if not os.path.exists(f): continue
        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if line.startswith('#') or '=' not in line: continue
                k, _, v = line.partition('=')
                cfg[k.strip()] = v.strip().strip('"\'')
    return cfg

cfg = load_env()
TOKEN   = cfg.get('TELEGRAM_TOKEN', '')
CHAT_ID = cfg.get('TELEGRAM_CHAT_ID', '')
ARMED   = True

def is_authorized(update: Update) -> bool:
    return str(update.effective_chat.id) == str(CHAT_ID)

# ── Dashboard API ──────────────────────────────────────────────────────────
def api_get(path):
    try:
        r = requests.get(f'{DASHBOARD_URL}{path}', timeout=5)
        if r.status_code == 200: return r.json()
    except Exception as e:
        log.warning(f'API {path}: {e}')
    return None

def api_snapshot(cam_name):
    try:
        r = requests.get(f'{DASHBOARD_URL}/api/snapshot/{cam_name}', timeout=8)
        if r.status_code == 200: return r.content
    except: pass
    return None

def api_capture(cam_name):
    try:
        r = requests.get(f'{DASHBOARD_URL}/api/capture/{cam_name}', timeout=10)
        return r.status_code == 200 and r.json().get('ok', False)
    except:
        return False

# ── AI Analysis ────────────────────────────────────────────────────────────
def ai_analyze_image(photo_bytes, cam_name):
    cfg2   = load_env()
    engine = cfg2.get('AI_ENGINE', 'gemini')
    prompt = (
        f'Đây là ảnh từ camera an ninh [{cam_name}]. '
        f'Hãy mô tả ngắn gọn những gì bạn thấy: '
        f'có người không, họ đang làm gì, có vật thể đáng ngờ không, '
        f'thời điểm (ngày/đêm), điều kiện ánh sáng. '
        f'Trả lời bằng tiếng Việt, tối đa 3 câu.'
    )

    if engine == 'gemini':
        key = cfg2.get('GEMINI_KEY', '')
        if not key or key == 'YOUR_GEMINI_KEY':
            return '⚠️ Chưa cấu hình Gemini API key.'
        try:
            import google.generativeai as genai
            import PIL.Image, io
            genai.configure(api_key=key)
            model = genai.GenerativeModel('gemini-1.5-flash')
            img = PIL.Image.open(io.BytesIO(photo_bytes))
            resp = model.generate_content([prompt, img])
            return resp.text.strip()
        except Exception as e:
            return f'⚠️ Gemini lỗi: {str(e)[:100]}'

    # Ollama local
    ollama_url = cfg2.get('OLLAMA_URL', 'http://localhost:11434')
    try:
        img_b64 = base64.b64encode(photo_bytes).decode()
        resp = requests.post(
            f'{ollama_url}/api/generate',
            json={'model': engine, 'prompt': prompt, 'images': [img_b64], 'stream': False},
            timeout=60
        )
        if resp.status_code == 200:
            result = resp.json().get('response', '').strip()
            return result if result else '⚠️ AI không trả lời.'
        return f'⚠️ Ollama trả {resp.status_code}'
    except Exception as e:
        return f'⚠️ AI lỗi: {str(e)[:100]}'

# ── Keyboard ───────────────────────────────────────────────────────────────
MAIN_KB = ReplyKeyboardMarkup(
    [['📊 /status', '📷 /cams'],
     ['📸 /snap', '🤖 /ai'],
     ['🔔 /alerts', '🔄 /reload'],
     ['🔴 /disarm', '🟢 /arm']],
    resize_keyboard=True
)

# ── Handlers ───────────────────────────────────────────────────────────────
async def cmd_start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    await update.message.reply_text(
        '🌿 *Greenmind* đang bảo vệ ngôi nhà của bạn!\n\nGõ /help để xem lệnh.',
        parse_mode='Markdown', reply_markup=MAIN_KB
    )

async def cmd_help(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    await update.message.reply_text(
        '🌿 *GREENMIND — Lệnh hỗ trợ:*\n\n'
        '📊 /status — Trạng thái hệ thống\n'
        '📷 /cams — Danh sách camera\n'
        '📸 /snap \\<cam\\> — Chụp ảnh \\+ phân tích AI\n'
        '🤖 /ai \\<cam\\> — Phân tích AI ảnh mới nhất\n'
        '🔔 /alerts \\[n\\] — Cảnh báo gần nhất\n'
        '🟢 /arm — Bật giám sát\n'
        '🔴 /disarm — Tắt giám sát\n'
        '🔄 /reload — Tải lại danh sách camera\n',
        parse_mode='MarkdownV2', reply_markup=MAIN_KB
    )

async def cmd_status(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    cams   = api_get('/api/cameras') or []
    health = api_get('/api/health') or {}
    online  = sum(1 for c in cams if c.get('online'))
    offline = len(cams) - online
    arm_txt = '🟢 Đang giám sát' if ARMED else '🔴 Đã tắt'
    engine  = load_env().get('AI_ENGINE', 'chưa cấu hình')
    text = (
        f'🌿 *GREENMIND STATUS*\n'
        f'─────────────────\n'
        f'🕐 {datetime.now().strftime("%d/%m/%Y %H:%M:%S")}\n'
        f'🛡 Chế độ: {arm_txt}\n'
        f'📷 Camera: {online} online / {offline} offline\n'
        f'🤖 AI Engine: `{engine}`\n'
        f'💾 RAM: {health.get("ram_used_mb","?")}MB / {health.get("ram_total_mb","?")}MB\n'
        f'🔔 Cảnh báo hôm nay: {health.get("alerts_today", 0)}\n'
    )
    await update.message.reply_text(text, parse_mode='Markdown')

async def cmd_cams(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    cams = api_get('/api/cameras') or []
    if not cams:
        await update.message.reply_text('❌ Không kết nối được dashboard.')
        return
    lines = ['📷 *DANH SÁCH CAMERA:*\n']
    for c in cams:
        status = '🟢' if c.get('online') else '🔴'
        alerts = c.get('alert_count', 0)
        lines.append(f'{status} `{c["name"]}` {"🔔 " + str(alerts) if alerts else ""}')
    lines.append('\n_/snap <tên cam> để chụp \\+ AI_')
    await update.message.reply_text('\n'.join(lines), parse_mode='Markdown')

async def cmd_snap(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    args = ctx.args
    if not args:
        cams = api_get('/api/cameras') or []
        if not cams:
            await update.message.reply_text('❌ Không có camera nào.')
            return
        cam_list = '\n'.join([f'• `{c["name"]}`' for c in cams])
        await update.message.reply_text(
            f'📷 Chọn camera:\n{cam_list}\n\n_Ví dụ: /snap NHA\\_RIENG_',
            parse_mode='Markdown'
        )
        return

    cam_name = args[0].upper()
    msg = await update.message.reply_text(f'⏳ Đang chụp {cam_name}...')
    api_capture(cam_name)
    time.sleep(1)
    photo = api_snapshot(cam_name)

    if not photo:
        await msg.edit_text(f'❌ Không chụp được {cam_name}.')
        return

    await msg.edit_text('🤖 Đang phân tích AI...')
    loop = asyncio.get_event_loop()
    description = await loop.run_in_executor(None, ai_analyze_image, photo, cam_name)

    caption = (
        f'📷 *{cam_name}*\n'
        f'🕐 {datetime.now().strftime("%d/%m/%Y %H:%M:%S")}\n\n'
        f'🤖 *AI:* {description}'
    )
    await update.message.reply_photo(photo=photo, caption=caption, parse_mode='Markdown')
    await msg.delete()

async def cmd_ai(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    args = ctx.args
    if not args:
        cams = api_get('/api/cameras') or []
        cam_list = '\n'.join([f'• `{c["name"]}`' for c in cams]) if cams else '_Không có camera_'
        await update.message.reply_text(
            f'🤖 Chọn camera để phân tích AI:\n{cam_list}\n\n_Ví dụ: /ai NHA\\_RIENG_',
            parse_mode='Markdown'
        )
        return

    cam_name = args[0].upper()
    snap_file = SNAP_DIR / f'{cam_name}.jpg'
    if snap_file.exists():
        photo = snap_file.read_bytes()
    else:
        photo = api_snapshot(cam_name)

    if not photo:
        await update.message.reply_text(f'❌ Không có ảnh của {cam_name}.')
        return

    msg = await update.message.reply_text(f'🤖 Đang phân tích {cam_name}...')
    loop = asyncio.get_event_loop()
    description = await loop.run_in_executor(None, ai_analyze_image, photo, cam_name)

    caption = (
        f'🤖 *AI phân tích {cam_name}*\n'
        f'🕐 {datetime.now().strftime("%d/%m/%Y %H:%M:%S")}\n\n'
        f'{description}'
    )
    await update.message.reply_photo(photo=photo, caption=caption, parse_mode='Markdown')
    await msg.delete()

async def cmd_alerts(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    n = 5
    if ctx.args:
        try: n = min(int(ctx.args[0]), 20)
        except: pass
    all_alerts = api_get(f'/api/alerts?limit={n}') or []
    if not all_alerts:
        await update.message.reply_text('✅ Không có cảnh báo nào gần đây.')
        return
    await update.message.reply_text(f'🔔 *{n} CẢNH BÁO GẦN NHẤT:*', parse_mode='Markdown')
    for a in all_alerts[:n]:
        text = (
            f'📷 *{a.get("cam","?")}* — {a.get("label_vn", a.get("label","?"))}\n'
            f'🕐 {a.get("ts_str","")}\n'
            f'📝 {a.get("description","—")}'
        )
        snap_url = a.get('snapshot_url')
        try:
            if snap_url:
                r = requests.get(snap_url, timeout=5)
                if r.status_code == 200:
                    await update.message.reply_photo(photo=r.content, caption=text, parse_mode='Markdown')
                    continue
        except: pass
        await update.message.reply_text(text, parse_mode='Markdown')

async def cmd_arm(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    global ARMED
    ARMED = True
    await update.message.reply_text('🟢 Đã *bật* chế độ giám sát!', parse_mode='Markdown')

async def cmd_disarm(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    global ARMED
    ARMED = False
    await update.message.reply_text('🔴 Đã *tắt* chế độ giám sát.\nGõ /arm để bật lại.', parse_mode='Markdown')

async def cmd_reload(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    result = api_get('/api/reload')
    if result:
        await update.message.reply_text(f'🔄 Đã tải lại — {result.get("cameras", 0)} camera.')
    else:
        await update.message.reply_text('❌ Không reload được.')

async def handle_text(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    text = update.message.text.strip()
    mapping = {
        '📊 /status': cmd_status, '📷 /cams': cmd_cams,
        '📸 /snap':   cmd_snap,   '🤖 /ai':   cmd_ai,
        '🔔 /alerts': cmd_alerts, '🔄 /reload': cmd_reload,
        '🔴 /disarm': cmd_disarm, '🟢 /arm':  cmd_arm,
    }
    if text in mapping:
        await mapping[text](update, ctx)

# ── Main ───────────────────────────────────────────────────────────────────
def main():
    if not TOKEN:
        log.error('TELEGRAM_TOKEN chưa cấu hình trong /etc/greenmind/config.env')
        return
    log.info('🌿 Greenmind Telegram Bot đang khởi động...')
    app = ApplicationBuilder().token(TOKEN).build()
    app.add_handler(CommandHandler('start',   cmd_start))
    app.add_handler(CommandHandler('help',    cmd_help))
    app.add_handler(CommandHandler('status',  cmd_status))
    app.add_handler(CommandHandler('cams',    cmd_cams))
    app.add_handler(CommandHandler('snap',    cmd_snap))
    app.add_handler(CommandHandler('ai',      cmd_ai))
    app.add_handler(CommandHandler('alerts',  cmd_alerts))
    app.add_handler(CommandHandler('arm',     cmd_arm))
    app.add_handler(CommandHandler('disarm',  cmd_disarm))
    app.add_handler(CommandHandler('reload',  cmd_reload))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    log.info(f'✅ Bot đang chạy | Chat ID: {CHAT_ID}')
    app.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()
