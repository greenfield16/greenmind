#!/usr/bin/env python3
"""
🌿 Greenmind — Telegram Bot 2 chiều
─────────────────────────────────────
Lệnh hỗ trợ:
  /start   — Chào mừng
  /help    — Danh sách lệnh
  /status  — Trạng thái hệ thống
  /cams    — Danh sách camera
  /snap <cam>  — Chụp ảnh camera
  /alerts [n]  — N cảnh báo gần nhất (mặc định 5)
  /arm     — Bật chế độ giám sát
  /disarm  — Tắt chế độ giám sát
"""

import os, re, time, logging, asyncio, json, requests
from pathlib import Path
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger('greenmind-bot')

# ── Auto-install ───────────────────────────────────────────────────────────
try:
    from telegram import Update, ReplyKeyboardMarkup
    from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'python-telegram-bot>=20.0', '-q'])
    from telegram import Update, ReplyKeyboardMarkup
    from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes

# ── Config ─────────────────────────────────────────────────────────────────
CONFIG_FILE  = os.environ.get('GREENMIND_CONFIG', '/etc/greenmind/config.env')
DATA_DIR     = Path(os.environ.get('GREENMIND_DATA', str(Path.home() / '.greenmind')))
ALERTS_LOG   = DATA_DIR / 'alerts.json'
DASHBOARD_URL = 'http://localhost:' + os.environ.get('GREENMIND_PORT', '8765')

def load_env():
    cfg = {}
    for f in [CONFIG_FILE, '/etc/greenmind/auth.env']:
        if not os.path.exists(f):
            continue
        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if line.startswith('#') or '=' not in line:
                    continue
                k, _, v = line.partition('=')
                cfg[k.strip()] = v.strip().strip('"\'')
    return cfg

cfg = load_env()
TOKEN    = cfg.get('TELEGRAM_TOKEN', '')
CHAT_ID  = cfg.get('TELEGRAM_CHAT_ID', '')
ARMED    = True  # trạng thái giám sát

def is_authorized(update: Update) -> bool:
    """Chỉ chấp nhận chat từ CHAT_ID đã cấu hình."""
    return str(update.effective_chat.id) == str(CHAT_ID)

# ── Dashboard API helpers ──────────────────────────────────────────────────
def api_get(path: str):
    try:
        r = requests.get(f'{DASHBOARD_URL}{path}', timeout=5)
        if r.status_code == 200:
            return r.json()
    except Exception as e:
        log.warning(f'API {path}: {e}')
    return None

def api_snapshot(cam_name: str) -> bytes | None:
    try:
        r = requests.get(f'{DASHBOARD_URL}/api/snapshot/{cam_name}', timeout=8)
        if r.status_code == 200:
            return r.content
    except Exception as e:
        log.warning(f'Snapshot {cam_name}: {e}')
    return None

def api_capture(cam_name: str) -> bool:
    try:
        r = requests.get(f'{DASHBOARD_URL}/api/capture/{cam_name}', timeout=10)
        return r.status_code == 200 and r.json().get('ok', False)
    except:
        return False

# ── Keyboard ───────────────────────────────────────────────────────────────
MAIN_KB = ReplyKeyboardMarkup(
    [['📊 /status', '📷 /cams'],
     ['🔔 /alerts', '🔄 /snap'],
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
        '🌿 *GREENMIND BOT — Lệnh hỗ trợ:*\n\n'
        '📊 /status — Trạng thái hệ thống\n'
        '📷 /cams — Danh sách camera\n'
        '📸 /snap \\<cam\\> — Chụp ảnh camera\n'
        '🔔 /alerts \\[n\\] — Cảnh báo gần nhất\n'
        '🟢 /arm — Bật giám sát\n'
        '🔴 /disarm — Tắt giám sát\n',
        parse_mode='MarkdownV2', reply_markup=MAIN_KB
    )

async def cmd_status(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    cams = api_get('/api/cameras') or []
    frigate = api_get('/api/frigate/status') or {}
    alerts_today = 0
    if ALERTS_LOG.exists():
        try:
            today = datetime.now().date()
            all_alerts = json.loads(ALERTS_LOG.read_text())
            alerts_today = sum(1 for a in all_alerts
                               if datetime.fromtimestamp(a.get('ts', 0)).date() == today)
        except: pass

    online  = sum(1 for c in cams if c.get('online'))
    offline = len(cams) - online
    arm_txt = '🟢 Đang giám sát' if ARMED else '🔴 Đã tắt giám sát'
    frigate_txt = '✅ Online' if frigate.get('online') else '❌ Offline'

    text = (
        f'🌿 *GREENMIND STATUS*\n'
        f'─────────────────\n'
        f'🕐 {datetime.now().strftime("%d/%m/%Y %H:%M:%S")}\n'
        f'🛡 Chế độ: {arm_txt}\n'
        f'📷 Camera: {online} online / {offline} offline\n'
        f'🎥 Frigate: {frigate_txt}\n'
        f'🔔 Cảnh báo hôm nay: {alerts_today}\n'
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
    lines.append(f'\n_Gõ /snap <tên cam> để chụp ảnh_')
    await update.message.reply_text('\n'.join(lines), parse_mode='Markdown')

async def cmd_snap(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not is_authorized(update): return
    args = ctx.args
    if not args:
        # Không có tên cam → hỏi
        cams = api_get('/api/cameras') or []
        if not cams:
            await update.message.reply_text('❌ Không có camera nào.')
            return
        cam_list = '\n'.join([f'• `{c["name"]}`' for c in cams])
        await update.message.reply_text(
            f'📷 Chọn camera để chụp:\n{cam_list}\n\n_Ví dụ: /snap CAM\\_KHO\\_01_',
            parse_mode='Markdown'
        )
        return

    cam_name = args[0].upper()
    msg = await update.message.reply_text(f'⏳ Đang chụp {cam_name}...')

    # Force capture trước
    api_capture(cam_name)
    time.sleep(1)
    photo = api_snapshot(cam_name)

    if photo:
        await update.message.reply_photo(
            photo=photo,
            caption=f'📷 *{cam_name}*\n_{datetime.now().strftime("%d/%m/%Y %H:%M:%S")}_',
            parse_mode='Markdown'
        )
        await msg.delete()
    else:
        await msg.edit_text(f'❌ Không chụp được {cam_name} — camera offline hoặc lỗi.')

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
            f'📷 *{a.get("cam", "?")}* — {a.get("label_vn", a.get("label", "?"))}\n'
            f'🕐 {a.get("ts_str", "")}\n'
            f'📝 {a.get("description", "—")}'
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

async def handle_text(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    """Xử lý text thường — hỗ trợ shortcut từ keyboard."""
    if not is_authorized(update): return
    text = update.message.text.strip()
    # Map button text sang lệnh
    mapping = {
        '📊 /status': cmd_status,
        '📷 /cams':   cmd_cams,
        '🔔 /alerts': cmd_alerts,
        '🔄 /snap':   cmd_snap,
        '🔴 /disarm': cmd_disarm,
        '🟢 /arm':    cmd_arm,
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
    app.add_handler(CommandHandler('alerts',  cmd_alerts))
    app.add_handler(CommandHandler('arm',     cmd_arm))
    app.add_handler(CommandHandler('disarm',  cmd_disarm))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    log.info(f'✅ Bot đang chạy | Chat ID: {CHAT_ID}')
    app.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()
