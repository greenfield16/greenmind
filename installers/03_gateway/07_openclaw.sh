#!/bin/bash
# 🌿 03_gateway/07_openclaw.sh — Cài OpenClaw AI Brain
show_step 7 7 "Cài OpenClaw AI Brain" "Node.js runtime + OpenClaw — não AI xử lý ngôn ngữ tự nhiên qua Telegram"

# ── Node.js ──────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
    run_step "Thêm NodeSource repo" bash -c "curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
    run_step "Cài Node.js 22" apt-get install -y nodejs -q
else
    print_info "Node.js đã có: $(node -v)"
fi

run_step "Cài OpenClaw" npm install -g openclaw -q

# ── Lấy thông tin từ config ───────────────────────────────────
AI_ENGINE=$(grep '^AI_ENGINE=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "openrouter")
TG_TOKEN=$(grep '^TELEGRAM_TOKEN=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")
TG_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")
OR_KEY=$(grep '^OPENROUTER_KEY=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")
OLLAMA_MODEL_VAL=$(grep '^OLLAMA_MODEL=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "llama3.2:3b")

# ── User context ─────────────────────────────────────────────
OC_USER=$(who am i | awk '{print $1}')
[ -z "$OC_USER" ] && OC_USER=$(logname 2>/dev/null || echo "root")
OC_HOME=$(eval echo "~$OC_USER")
WORKSPACE="$OC_HOME/.openclaw/workspace"

# ── Workspace / SOUL ─────────────────────────────────────────
mkdir -p "$WORKSPACE/memory"

cat > "$WORKSPACE/SOUL.md" << 'SOUL'
# SOUL.md — Greenmind AI

Tôi là Greenmind — AI quản lý toà nhà thông minh của Greenfield Tech.

## Quy tắc bắt buộc
- Trả lời NGẮN GỌN — tối đa 2-3 câu
- Không giải thích kỹ thuật, không liệt kê bước dài dòng
- Không đề cập đến OpenClaw, memory_search, tool call hay lỗi nội bộ
- Nếu không biết → nói thẳng "Tôi không có thông tin đó"
- Ưu tiên tiếng Việt

## Vai trò
- Nhận lệnh điều khiển thiết bị trong toà nhà
- Báo cáo trạng thái camera, cảm biến
- Cảnh báo khi phát hiện bất thường
- Trả lời câu hỏi về hệ thống Greenmind

## Giới hạn
- Không chia sẻ thông tin bảo mật với người lạ
- Không tự thực hiện hành động ảnh hưởng thiết bị mà chưa xác nhận
SOUL

cat > "$WORKSPACE/IDENTITY.md" << 'ID'
# IDENTITY.md
- **Name:** Greenmind
- **Role:** Smart Building AI
- **Made by:** Greenfield Tech
- **Emoji:** 🏢
ID

print_success "Workspace đã tạo tại $WORKSPACE"

# ── Start OpenClaw lần đầu để tạo config files ───────────────
if [ "$OC_USER" = "root" ]; then
    openclaw gateway install 2>/dev/null || true
    openclaw gateway start 2>/dev/null || true
else
    su - "$OC_USER" -c "openclaw gateway install 2>/dev/null; openclaw gateway start 2>/dev/null" || true
fi

run_step "Khởi tạo OpenClaw config" sleep 5

# ── Auto-config AI Engine ─────────────────────────────────────
OC_MODELS="$OC_HOME/.openclaw/agents/main/agent/models.json"
OC_AUTH="$OC_HOME/.openclaw/agents/main/agent/auth-profiles.json"
OC_CONFIG="$OC_HOME/.openclaw/openclaw.json"
OC_AGENT_CONFIG="$OC_HOME/.openclaw/openclaw.json"

python3 << PYEOF
import json, os, subprocess

ai_engine   = "$AI_ENGINE"
or_key      = "$OR_KEY"
ollama_model = "$OLLAMA_MODEL_VAL"
models_path = "$OC_MODELS"
auth_path   = "$OC_AUTH"
config_path = "$OC_CONFIG"
tg_token    = "$TG_TOKEN"
tg_chat     = "$TG_CHAT"
oc_user     = "$OC_USER"

def set_config(key, val):
    cmd = f"openclaw config set '{key}' '{val}'"
    if oc_user != 'root':
        cmd = f"su - {oc_user} -c \"{cmd}\""
    os.system(cmd + ' 2>/dev/null')

# ── Load models.json ──────────────────────────────────────────
try:
    with open(models_path) as f:
        cfg = json.load(f)
except:
    cfg = {'providers': {}}

# ── Ollama config ─────────────────────────────────────────────
if ai_engine == 'ollama':
    provider_name = 'custom-ollama-local'
    if provider_name not in cfg.get('providers', {}):
        cfg.setdefault('providers', {})[provider_name] = {
            'type': 'openai-compatible',
            'baseUrl': 'http://localhost:11434/v1',
            'apiKey': 'ollama',
            'models': []
        }
    p = cfg['providers'][provider_name]
    model_ids = [m['id'] for m in p.get('models', [])]
    if ollama_model not in model_ids:
        p.setdefault('models', []).append({
            'id': ollama_model,
            'name': f'Ollama {ollama_model}',
            'reasoning': False,
            'input': ['text'],
            'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
            'contextWindow': 131072,
            'maxTokens': 4096
        })
    primary_model = f'{provider_name}/{ollama_model}'
    print(f'  ✔  Ollama config: {primary_model}')

# ── OpenRouter config ─────────────────────────────────────────
elif ai_engine == 'openrouter' and or_key:
    provider_name = 'custom-openrouter-ai'
    cfg.setdefault('providers', {}).setdefault(provider_name, {
        'type': 'openai-compatible',
        'baseUrl': 'https://openrouter.ai/api/v1',
        'apiKey': or_key,
        'models': []
    })
    cfg['providers'][provider_name]['apiKey'] = or_key
    cfg['providers'][provider_name]['baseUrl'] = 'https://openrouter.ai/api/v1'
    model_id = 'nvidia/nemotron-3-super-120b-a12b:free'
    model_ids = [m['id'] for m in cfg['providers'][provider_name].get('models', [])]
    if model_id not in model_ids:
        cfg['providers'][provider_name].setdefault('models', []).append({
            'id': model_id,
            'name': 'Nemotron 3 Super 120B (free)',
            'reasoning': False,
            'input': ['text'],
            'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
            'contextWindow': 128000,
            'maxTokens': 4096
        })
    # Fix openrouter built-in apiKey
    if 'openrouter' in cfg.get('providers', {}):
        cfg['providers']['openrouter']['apiKey'] = or_key
    # Auth profile
    try:
        auth = json.load(open(auth_path)) if os.path.exists(auth_path) else {'version': 1, 'profiles': {}}
        auth['profiles'][f'{provider_name}:default'] = {'type': 'api_key', 'provider': provider_name, 'key': or_key}
        os.makedirs(os.path.dirname(auth_path), exist_ok=True)
        json.dump(auth, open(auth_path, 'w'), indent=2)
    except Exception as e:
        print(f'  ⚠  auth-profiles: {e}')
    primary_model = f'{provider_name}/{model_id}'
    print(f'  ✔  OpenRouter config: {model_id}')

else:
    primary_model = None
    print(f'  ⚠  AI engine "{ai_engine}" không xác định — bỏ qua')

# ── Ghi models.json ───────────────────────────────────────────
try:
    os.makedirs(os.path.dirname(models_path), exist_ok=True)
    json.dump(cfg, open(models_path, 'w'), indent=2)
    print('  ✔  models.json đã cập nhật')
except Exception as e:
    print(f'  ⚠  models.json: {e}')

# ── Set primary model + disable timeout ──────────────────────
if primary_model:
    set_config('agents.defaults.model.primary', primary_model)
    set_config('agents.defaults.llm.idleTimeoutSeconds', '0')
    print(f'  ✔  Primary model: {primary_model}')
    print('  ✔  LLM timeout: disabled')

# ── Telegram config ───────────────────────────────────────────
if tg_token:
    try:
        c = json.load(open(config_path)) if os.path.exists(config_path) else {}
        c.setdefault('channels', {})['telegram'] = {
            'enabled': True,
            'botToken': tg_token,
            'groups': {'*': {'requireMention': True}}
        }
        json.dump(c, open(config_path, 'w'), indent=2)
        print('  ✔  Telegram đã cấu hình')
    except Exception as e:
        print(f'  ⚠  Telegram: {e}')
PYEOF

# ── Restart với config mới ────────────────────────────────────
run_step "Restart OpenClaw" bash -c "
if [ '$OC_USER' = 'root' ]; then
    openclaw gateway restart 2>/dev/null
else
    su - '$OC_USER' -c 'openclaw gateway restart 2>/dev/null'
fi"

print_success "OpenClaw AI Brain đã cài và cấu hình xong"
