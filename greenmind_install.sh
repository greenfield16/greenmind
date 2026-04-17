#!/usr/bin/env bash
# Greenmind Installer - Ngoi nha biet nhin
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
GREENMIND_DIR="/opt/greenmind"
CONFIG_DIR="/etc/greenmind"
CONFIG_FILE="$CONFIG_DIR/config.env"
LOG_FILE="/var/log/greenmind_install.log"
INSTALLED_MODULES=()
AI_MODE="api"
NODE_ROLE="gateway"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; log "INFO: $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; log "OK: $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; log "WARN: $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; log "ERROR: $*"; exit 1; }

header() {
echo -e "\n${BOLD}${BLUE}============================================${NC}"
echo -e "${BOLD}${BLUE} $*${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}\n"
}

ask() {
local prompt="$1" default="${2:-}" ans
[[ -n "$default" ]] && read -rp "? $prompt [$default]: " ans || read -rp "? $prompt: " ans
echo "${ans:-$default}"
}

save_config() {
sed -i "/^${1}=/d" "$CONFIG_FILE" 2>/dev/null || true
echo "${1}=${2}" >> "$CONFIG_FILE"
}

init() {
[[ $EUID -ne 0 ]] && error "Can chay voi quyen root: sudo bash $0"
mkdir -p "$GREENMIND_DIR" "$CONFIG_DIR"
touch "$LOG_FILE" "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"
clear
echo -e "${BOLD}${GREEN}"
echo " +=========================================+"
echo " | GREENMIND INSTALLER |"
echo " | Ngoi nha biet nhin |"
echo " +=========================================+"
echo -e "${NC}"
info "Bat dau cai dat luc $(date)"
}

detect_hardware() {
header "Buoc 1: Phat hien phan cung"
ARCH=$(uname -m)
CPU_MODEL=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "Unknown")
CPU_CORES=$(nproc)
RAM_GB=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)
OS_ID=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "linux")
echo " CPU : $CPU_MODEL ($CPU_CORES cores)"
echo " RAM : ${RAM_GB} GB"
echo " ARCH : $ARCH"
echo " OS : $OS_ID"
GPU_VRAM=0
if command -v nvidia-smi &>/dev/null; then
GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | awk '{printf "%d",$1/1024}' || echo 0)
GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA")
echo " GPU : $GPU_NAME (${GPU_VRAM} GB VRAM)"
else
echo " GPU : Khong co GPU roi"
fi
echo ""
if [[ $GPU_VRAM -ge 4 && $RAM_GB -ge 8 ]]; then
RECOMMENDED_AI="local"
echo -e "${GREEN}-> Khuyen nghi: AI Local (Gemma 4 via Ollama)${NC}"
else
RECOMMENDED_AI="api"
echo -e "${YELLOW}-> Khuyen nghi: API Mode (Gemini API)${NC}"
fi
echo ""
echo "Chon che do AI:"
echo " [1] AI Local - Gemma 4 via Ollama (can GPU >=4GB, RAM >=8GB)"
echo " [2] API Mode - Gemini API (can internet + API key)"
local choice
choice=$(ask "Lua chon" "$([[ $RECOMMENDED_AI == local ]] && echo 1 || echo 2)")
[[ "$choice" == "1" ]] && AI_MODE="local" || AI_MODE="api"
save_config "AI_MODE" "$AI_MODE"
success "Che do AI: $AI_MODE"
}

install_openclaw() {
header "Buoc 2: Cai dat OpenClaw"
if ! command -v node &>/dev/null || [[ $(node -v 2>/dev/null | cut -d. -f1 | tr -d 'v') -lt 22 ]]; then
info "Cai Node.js v22..."
if [[ "$ARCH" == "x86_64" ]]; then
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
elif [[ "$ARCH" == "aarch64" ]]; then
curl -fsSL "https://nodejs.org/dist/v22.15.0/node-v22.15.0-linux-arm64.tar.xz" | tar -xJ -C /usr/local --strip-components=1
elif [[ "$ARCH" == "armv7l" ]]; then
curl -fsSL "https://nodejs.org/dist/v22.15.0/node-v22.15.0-linux-armv7l.tar.xz" | tar -xJ -C /usr/local --strip-components=1
fi
success "Node.js $(node -v) da cai"
else
success "Node.js $(node -v) da co san"
fi
if ! command -v openclaw &>/dev/null; then
info "Cai OpenClaw..."
[[ "$ARCH" == "armv7l" ]] && npm install -g openclaw --force || npm install -g openclaw
success "OpenClaw da cai"
else
success "OpenClaw da co san"
fi
}

configure_node_role() {
header "Buoc 3: Cau hinh Node"
echo "Chon vai tro:"
echo " [1] Gateway (node chinh)"
echo " [2] Child Node (node phu)"
local choice
choice=$(ask "Lua chon" "1")
if [[ "$choice" == "1" ]]; then
NODE_ROLE="gateway"
openclaw gateway start 2>/dev/null || true
systemctl enable openclaw-gateway 2>/dev/null || true
systemctl start openclaw-gateway 2>/dev/null || true
success "Gateway dang chay"
info "Token cho child nodes:"
openclaw gateway token 2>/dev/null || warn "Chay 'openclaw gateway token' de lay token"
else
NODE_ROLE="child"
echo "Kieu ket noi: [1] Local LAN [2] Internet"
local conn_type gw_addr gw_token
conn_type=$(ask "Lua chon" "1")
[[ "$conn_type" == "1" ]] && \
gw_addr=$(ask "IP gateway (vi du: 192.168.1.100)") || \
gw_addr=$(ask "Domain/IP gateway")
gw_token=$(ask "Pairing token tu gateway")
openclaw connect --gateway "$gw_addr" --token "$gw_token" 2>/dev/null || \
warn "Ket noi that bai - kiem tra lai dia chi va token"
save_config "GATEWAY_ADDR" "$gw_addr"
success "Da ket noi den $gw_addr"
fi
save_config "NODE_ROLE" "$NODE_ROLE"
}

setup_ai() {
header "Buoc 4: Cai dat AI"
if [[ "$AI_MODE" == "local" ]]; then
if ! command -v ollama &>/dev/null; then
info "Cai Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh
fi
systemctl enable ollama 2>/dev/null || true
systemctl start ollama 2>/dev/null || true
info "Tai Gemma 4 model..."
ollama pull gemma3:4b
save_config "OLLAMA_URL" "http://localhost:11434"
save_config "AI_MODEL" "gemma3:4b"
success "AI Local (Gemma3 4B) da san sang"
else
echo ""
echo " +------------------------------------------+"
echo " | Greenmind - AI API Setup |"
echo " | Lay key tai: aistudio.google.com |"
echo " +------------------------------------------+"
local gemini_key test_resp
gemini_key=$(ask "Gemini API Key")
test_resp=$(curl -s -o /dev/null -w "%{http_code}" \
"https://generativelanguage.googleapis.com/v1beta/models?key=$gemini_key")
save_config "GEMINI_API_KEY" "$gemini_key"
save_config "AI_MODEL" "gemini-2.0-flash-lite"
[[ "$test_resp" == "200" ]] && success "API key hop le!" || warn "HTTP $test_resp - kiem tra lai"
fi
}

install_ezviz_camera() {
header " Camera Ezviz"
apt-get install -y python3-pip -q 2>/dev/null || true
pip3 install pyezviz requests --break-system-packages -q
local phone pass region serial
phone=$(ask "So dien thoai Ezviz")
pass=$(ask "Mat khau Ezviz")
region=$(ask "Region" "apiisgp.ezvizlife.com")
serial=$(ask "Serial camera")
save_config "EZVIZ_PHONE" "$phone"
save_config "EZVIZ_PASS" "$pass"
save_config "EZVIZ_REGION" "$region"
save_config "EZVIZ_SERIAL" "$serial"

cat > "$GREENMIND_DIR/fall_detector.py" << 'FALLEOF'
#!/usr/bin/env python3
import json, time, os, requests, logging
from pyezviz import EzvizClient
from pyezviz.utils import decrypt_image

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s',
handlers=[logging.FileHandler('/var/log/fall_detector.log'), logging.StreamHandler()])
log = logging.getLogger(__name__)

cfg = {}
with open('/etc/greenmind/config.env') as f:
for line in f:
line = line.strip()
if '=' in line and not line.startswith('#'):
k, v = line.split('=', 1); cfg[k] = v

EZVIZ_USER=cfg.get('EZVIZ_PHONE',''); EZVIZ_PASS=cfg.get('EZVIZ_PASS','')
EZVIZ_REGION=cfg.get('EZVIZ_REGION','apiisgp.ezvizlife.com')
CAMERA_SERIAL=cfg.get('EZVIZ_SERIAL','')
BOT_TOKEN=cfg.get('TELEGRAM_BOT_TOKEN',''); CHAT_ID=cfg.get('TELEGRAM_CHAT_ID','')
SESSION_CACHE='/tmp/ezviz_session.json'; STATE_FILE='/tmp/fall_detector_state.json'
SNAP_FILE='/tmp/snap_fall_check.jpg'; POLL_INTERVAL=30; COOLDOWN=300

def load_state():
if os.path.exists(STATE_FILE):
with open(STATE_FILE) as f: return json.load(f)
return {'last_alarm_id': None, 'last_alert_time': 0}

def save_state(s):
with open(STATE_FILE, 'w') as f: json.dump(s, f)

def get_client():
c = EzvizClient(EZVIZ_USER, EZVIZ_PASS, EZVIZ_REGION)
if os.path.exists(SESSION_CACHE):
try:
with open(SESSION_CACHE) as f: cache = json.load(f)
if time.time() - cache.get('ts', 0) < 3600:
c._session.headers.update(cache['headers'])
for k, v in cache.get('cookies', {}).items():
c._session.cookies.set(k, v)
return c
except: pass
c.login()
with open(SESSION_CACHE, 'w') as f:
json.dump({'ts': time.time(), 'headers': dict(c._session.headers),
'cookies': dict(c._session.cookies)}, f)
return c

def main():
log.info("Fall detector started")
state = load_state()
while True:
try:
client = get_client()
alarms = client.get_alarminfo(CAMERA_SERIAL, limit=5)['alarms']
alarm = next((a for a in alarms if a.get('picUrl') or a.get('picUrlGroup')), None)
if alarm and alarm['alarmId'] != state['last_alarm_id']:
url = alarm.get('picUrl') or alarm.get('picUrlGroup')
resp = client._session.get(url, timeout=15)
data = decrypt_image(resp.content, EZVIZ_PASS)
with open(SNAP_FILE, 'wb') as f: f.write(data)
state['last_alarm_id'] = alarm['alarmId']; save_state(state)
now = time.time()
if now - state['last_alert_time'] > COOLDOWN and BOT_TOKEN:
requests.post(
f'https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto',
data={'chat_id': CHAT_ID,
'caption': f"[FALL_CHECK] {alarm['alarmStartTimeStr']}"},
files={'photo': open(SNAP_FILE, 'rb')}, timeout=15)
state['last_alert_time'] = now; save_state(state)
log.info("Sent [FALL_CHECK]")
except Exception as e: log.error(f"Error: {e}")
time.sleep(POLL_INTERVAL)

if __name__ == '__main__': main()
FALLEOF

cat > /etc/systemd/system/greenmind-camera.service << 'SVCEOF'
[Unit]
Description=Greenmind Camera Fall Detector
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/greenmind/fall_detector.py
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload && systemctl enable greenmind-camera && systemctl start greenmind-camera
INSTALLED_MODULES+=("Camera Ezviz")
success "Ezviz Camera da cai"
}

install_tts_speaker() {
header " TTS Speaker"
apt-get install -y python3-pip ffmpeg mpg123 bluez pulseaudio pulseaudio-module-bluetooth alsa-utils -q
pip3 install gtts --break-system-packages -q
echo " [1] 3.5mm jack [2] Bluetooth"
local audio_type
audio_type=$(ask "Loai audio" "1")
if [[ "$audio_type" == "2" ]]; then
info "Scan Bluetooth 10 giay..."
systemctl start bluetooth 2>/dev/null || true
bluetoothctl power on 2>/dev/null || true
bluetoothctl --timeout 10 scan on 2>/dev/null || true
bluetoothctl devices 2>/dev/null | head -10
local bt_mac
bt_mac=$(ask "MAC address loa Bluetooth")
bluetoothctl pair "$bt_mac" 2>/dev/null || true
bluetoothctl trust "$bt_mac" 2>/dev/null || true
pulseaudio --start 2>/dev/null || true; sleep 2
bluetoothctl connect "$bt_mac" 2>/dev/null || true
save_config "BT_SPEAKER_MAC" "$bt_mac"
fi
cat > "$GREENMIND_DIR/tts_speak.py" << 'TTSEOF'
#!/usr/bin/env python3
import sys, subprocess, tempfile, os
from gtts import gTTS

def speak(text, lang='vi'):
with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as f: tmp_mp3 = f.name
wav = tmp_mp3.replace('.mp3', '.wav')
gTTS(text, lang=lang).save(tmp_mp3)
subprocess.run(['ffmpeg','-y','-i',tmp_mp3,'-ar','44100','-ac','2',wav],
stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(['paplay', wav])
os.unlink(tmp_mp3); os.unlink(wav)

if __name__ == '__main__':
speak(' '.join(sys.argv[1:]))
TTSEOF
chmod +x "$GREENMIND_DIR/tts_speak.py"
python3 "$GREENMIND_DIR/tts_speak.py" "Greenmind da san sang" 2>/dev/null || warn "Kiem tra lai loa"
INSTALLED_MODULES+=("TTS Speaker")
success "TTS Speaker da cai"
}

install_dht_sensor() {
header " DHT Sensor"
apt-get install -y python3-pip python3-dev libgpiod2 -q
pip3 install adafruit-circuitpython-dht --break-system-packages -q
echo " [1] DHT11 [2] DHT22"
local sensor_type gpio_pin
sensor_type=$(ask "Loai cam bien" "2")
gpio_pin=$(ask "GPIO pin so" "4")
save_config "DHT_TYPE" "$([[ $sensor_type == 1 ]] && echo DHT11 || echo DHT22)"
save_config "DHT_PIN" "$gpio_pin"
cat > "$GREENMIND_DIR/dht_monitor.py" << 'DHTEOF'
#!/usr/bin/env python3
import time, logging, board, adafruit_dht
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s',
handlers=[logging.FileHandler('/var/log/greenmind_dht.log')])
log = logging.getLogger(__name__)
cfg = {}
with open('/etc/greenmind/config.env') as f:
for line in f:
if '=' in line: k,v=line.strip().split('=',1); cfg[k]=v
pin = getattr(board, f"D{cfg.get('DHT_PIN','4')}")
dht = adafruit_dht.DHT22(pin) if cfg.get('DHT_TYPE','DHT22')=='DHT22' else adafruit_dht.DHT11(pin)
while True:
try: log.info(f"Temp={dht.temperature:.1f}C Humidity={dht.humidity:.1f}%")
except Exception as e: log.warning(f"Read error: {e}")
time.sleep(60)
DHTEOF
cat > /etc/systemd/system/greenmind-dht.service << 'SVCEOF'
[Unit]
Description=Greenmind DHT Sensor
After=multi-user.target
[Service]
ExecStart=/usr/bin/python3 /opt/greenmind/dht_monitor.py
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload && systemctl enable greenmind-dht && systemctl start greenmind-dht
INSTALLED_MODULES+=("DHT Sensor")
success "DHT Sensor da cai"
}

install_relay_control() {
header " Relay Control"
apt-get install -y python3-gpiozero -q
local num_relays
num_relays=$(ask "So relay" "2")
declare -a relay_pins=()
for ((i=1; i<=num_relays; i++)); do
relay_pins+=("$(ask "GPIO pin relay $i")")
done
save_config "RELAY_COUNT" "$num_relays"
save_config "RELAY_PINS" "$(IFS=,; echo "${relay_pins[*]}")"
cat > "$GREENMIND_DIR/relay_control.py" << 'RELEOF'
#!/usr/bin/env python3
from gpiozero import OutputDevice; import sys
cfg = {}
with open('/etc/greenmind/config.env') as f:
for line in f:
if '=' in line: k,v=line.strip().split('=',1); cfg[k]=v
relays = [OutputDevice(int(p), active_high=False) for p in cfg.get('RELAY_PINS','').split(',') if p]
if __name__ == '__main__':
cmd, idx = sys.argv[1], int(sys.argv[2])
{'on': lambda r: r.on(), 'off': lambda r: r.off(),
'toggle': lambda r: r.toggle()}[cmd](relays[idx])
print(f"Relay {idx}: {cmd}")
RELEOF
INSTALLED_MODULES+=("Relay Control")
success "Relay Control da cai"
}

install_telegram_alerts() {
header " Telegram Alerts"
echo "Tao bot tai: https://t.me/BotFather"
local bot_token chat_id resp
bot_token=$(ask "Bot Token")
chat_id=$(ask "Chat ID")
save_config "TELEGRAM_BOT_TOKEN" "$bot_token"
save_config "TELEGRAM_CHAT_ID" "$chat_id"
resp=$(curl -s -o /dev/null -w "%{http_code}" \
"https://api.telegram.org/bot${bot_token}/sendMessage" \
--data-urlencode "chat_id=${chat_id}" \
--data-urlencode "text=Greenmind da ket noi - Ngoi nha biet nhin")
[[ "$resp" == "200" ]] && success "Telegram OK!" || warn "HTTP $resp"
INSTALLED_MODULES+=("Telegram Alerts")
success "Telegram Alerts da cai"
}

install_messaging_bot() {
header " Ket noi Telegram/WhatsApp voi AI"
echo " [1] Telegram [2] WhatsApp [3] Ca hai"
local choice
choice=$(ask "Lua chon" "1")
if [[ "$choice" == "1" || "$choice" == "3" ]]; then
local tg_token tg_chat
tg_token=$(ask "Telegram Bot Token")
tg_chat=$(ask "Telegram Chat ID")
save_config "TELEGRAM_BOT_TOKEN" "$tg_token"
save_config "TELEGRAM_CHAT_ID" "$tg_chat"
openclaw channel add telegram --bot-token "$tg_token" --allowed-users "$tg_chat" 2>/dev/null || \
warn "Cau hinh thu cong tai: docs.openclaw.ai"
success "Telegram OK - Nhan /start trong bot de bat dau"
fi
if [[ "$choice" == "2" || "$choice" == "3" ]]; then
openclaw channel add whatsapp 2>/dev/null || \
warn "Xem: openclaw channel info whatsapp"
success "WhatsApp da bat"
fi
systemctl restart openclaw-gateway 2>/dev/null || true
INSTALLED_MODULES+=("Messaging Bot")
success "Messaging Bot da cai"
}

select_iot_modules() {
header "Buoc 5: Module IoT"
echo "Chon module (nhap so cach nhau, hoac 'all'):"
echo ""
echo " 1. Camera Ezviz (fall detection, dem nguoi)"
echo " 2. TTS Speaker (gTTS + Bluetooth/3.5mm)"
echo " 3. Cam bien nhiet do/do am (DHT11/DHT22)"
echo " 4. Relay Control (den, quat)"
echo " 5. Telegram Alerts"
echo " 6. Ket noi Telegram/WhatsApp voi AI"
echo ""
local choices
read -rp "? Lua chon: " choices
declare -A sel=([1]=false [2]=false [3]=false [4]=false [5]=false [6]=false)
if [[ "$choices" == "all" ]]; then
for i in 1 2 3 4 5 6; do sel[$i]=true; done
else
for c in $choices; do [[ -v "sel[$c]" ]] && sel[$c]=true; done
fi
${sel[1]} && install_ezviz_camera
${sel[2]} && install_tts_speaker
${sel[3]} && install_dht_sensor
${sel[4]} && install_relay_control
${sel[5]} && install_telegram_alerts
${sel[6]} && install_messaging_bot
}

show_summary() {
echo ""
echo -e "${BOLD}${GREEN}"
echo " +================================================+"
echo " | Greenmind Installation Complete! |"
echo " +================================================+"
printf " | Node Role : %-32s|\n" "$NODE_ROLE"
printf " | AI Mode : %-32s|\n" "$AI_MODE"
echo " | Modules: |"
for m in "${INSTALLED_MODULES[@]}"; do
printf " | - %-42s|\n" "$m"
done
echo " | |"
echo " | Config : /etc/greenmind/config.env |"
echo " | Scripts: /opt/greenmind/ |"
echo " | Logs : /var/log/greenmind_install.log |"
echo " +================================================+"
echo -e "${NC}"
echo -e " ${BOLD}${CYAN}Greenmind - Ngoi nha biet nhin${NC}"
echo ""
}

main() {
init
detect_hardware
install_openclaw
configure_node_role
setup_ai
select_iot_modules
show_summary
}

main "$@"

