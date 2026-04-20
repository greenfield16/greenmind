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

# ── Workspace ────────────────────────────────────────────────
# OpenClaw chạy với user thường (không root)
OC_USER=$(who am i | awk '{print $1}')
[ -z "$OC_USER" ] && OC_USER=$(logname 2>/dev/null || echo "root")
OC_HOME=$(eval echo "~$OC_USER")
WORKSPACE="$OC_HOME/.openclaw/workspace"

mkdir -p "$WORKSPACE/memory"

cat > "$WORKSPACE/SOUL.md" << 'SOUL'
# SOUL.md — Greenmind AI

Tôi là Greenmind — AI quản lý toà nhà thông minh của Greenfield Tech.

## Tính cách
- Chuyên nghiệp, ngắn gọn, đi thẳng vào vấn đề
- Chủ động cảnh báo khi phát hiện bất thường
- Trả lời tiếng Việt, không dài dòng

## Ưu tiên
1. An toàn — cảnh báo ngay khi có nguy hiểm
2. Chính xác — không đoán mò, dùng dữ liệu thực
3. Tiện lợi — ngắn gọn, rõ ràng

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

# ── OpenClaw setup (chạy với user thường) ───────────────────
TG_TOKEN=$(grep '^TELEGRAM_TOKEN=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")
TG_CHAT=$(grep '^TELEGRAM_CHAT_ID=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")
OR_KEY=$(grep '^OPENROUTER_KEY=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 || echo "")

# Install gateway service
if [ "$OC_USER" = "root" ]; then
    openclaw gateway install 2>/dev/null || true
    openclaw gateway start 2>/dev/null || true
else
    su - "$OC_USER" -c "openclaw gateway install 2>/dev/null; openclaw gateway start 2>/dev/null" || true
fi

sleep 3

# ── Fix OpenRouter API key trong models.json ─────────────────
OC_MODELS="$OC_HOME/.openclaw/agents/main/agent/models.json"
OC_AUTH="$OC_HOME/.openclaw/agents/main/agent/auth-profiles.json"
OC_CONFIG="$OC_HOME/.openclaw/openclaw.json"

if [ -n "$OR_KEY" ] && [ -f "$OC_MODELS" ]; then
    python3 << PYEOF
import json, os

KEY = "$OR_KEY"
models_path = "$OC_MODELS"
auth_path = "$OC_AUTH"

# Fix models.json
try:
    with open(models_path) as f:
        cfg = json.load(f)

    # Fix custom-openrouter-ai provider
    if 'custom-openrouter-ai' in cfg.get('providers', {}):
        cfg['providers']['custom-openrouter-ai']['baseUrl'] = 'https://openrouter.ai/api/v1'
        cfg['providers']['custom-openrouter-ai']['apiKey'] = KEY

    # Fix openrouter provider (apiKey literal)
    if 'openrouter' in cfg.get('providers', {}):
        cfg['providers']['openrouter']['apiKey'] = KEY
        # Thêm nemotron-3-super nếu chưa có
        model_ids = [m['id'] for m in cfg['providers']['openrouter'].get('models', [])]
        if 'nvidia/nemotron-3-super-120b-a12b:free' not in model_ids:
            cfg['providers']['openrouter']['models'].append({
                'id': 'nvidia/nemotron-3-super-120b-a12b:free',
                'name': 'Nemotron 3 Super 120B (free)',
                'reasoning': False,
                'input': ['text'],
                'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
                'contextWindow': 128000,
                'maxTokens': 4096
            })

    with open(models_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print('  ✔  models.json đã cập nhật')
except Exception as e:
    print(f'  ⚠  models.json: {e}')

# Fix auth-profiles.json
try:
    if os.path.exists(auth_path):
        with open(auth_path) as f:
            auth = json.load(f)
    else:
        auth = {'version': 1, 'profiles': {}}

    auth['profiles']['custom-openrouter-ai:default'] = {
        'type': 'api_key',
        'provider': 'custom-openrouter-ai',
        'key': KEY
    }
    auth['profiles']['openrouter:default'] = {
        'type': 'api_key',
        'provider': 'openrouter',
        'key': KEY
    }

    os.makedirs(os.path.dirname(auth_path), exist_ok=True)
    with open(auth_path, 'w') as f:
        json.dump(auth, f, indent=2)
    print('  ✔  auth-profiles.json đã cập nhật')
except Exception as e:
    print(f'  ⚠  auth-profiles.json: {e}')
PYEOF

    # Set primary model
    if [ "$OC_USER" = "root" ]; then
        openclaw config set 'agents.defaults.model.primary' 'custom-openrouter-ai/nvidia/nemotron-3-super-120b-a12b:free' 2>/dev/null || true
    else
        su - "$OC_USER" -c "openclaw config set 'agents.defaults.model.primary' 'custom-openrouter-ai/nvidia/nemotron-3-super-120b-a12b:free' 2>/dev/null" || true
    fi
    print_success "AI model: nemotron-3-super-120b (free)"
fi

# ── Config Telegram ──────────────────────────────────────────
if [ -n "$TG_TOKEN" ] && [ -f "$OC_CONFIG" ]; then
    python3 << PYEOF
import json

config_path = "$OC_CONFIG"
token = "$TG_TOKEN"
chat_id = "$TG_CHAT"

try:
    with open(config_path) as f:
        cfg = json.load(f)

    if 'channels' not in cfg:
        cfg['channels'] = {}
    cfg['channels']['telegram'] = {
        'enabled': True,
        'botToken': token,
        'groups': {'*': {'requireMention': True}}
    }

    with open(config_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print('  ✔  Telegram đã cấu hình')
except Exception as e:
    print(f'  ⚠  Telegram config: {e}')
PYEOF
fi

# ── Restart với config mới ────────────────────────────────────
if [ "$OC_USER" = "root" ]; then
    openclaw gateway restart 2>/dev/null || true
else
    su - "$OC_USER" -c "openclaw gateway restart 2>/dev/null" || true
fi

print_success "OpenClaw AI Brain đã cài xong"
