#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — AI Engine
Support: nvidia | openrouter | gemini | ollama | do_agent
"""

import os, base64, requests, logging
from io import BytesIO

log = logging.getLogger(__name__)

def _resize(image_bytes: bytes, max_width: int = 640) -> bytes:
    """Resize ảnh xuống max_width để giảm tải AI."""
    try:
        from PIL import Image
        img = Image.open(BytesIO(image_bytes))
        if img.width > max_width:
            ratio = max_width / img.width
            img = img.resize((max_width, int(img.height * ratio)), Image.LANCZOS)
        buf = BytesIO()
        img.save(buf, format='JPEG', quality=75)
        return buf.getvalue()
    except Exception:
        return image_bytes

def _load_config():
    cfg = {}
    config_file = os.getenv('CONFIG_FILE', '/etc/greenmind/config.env')
    if os.path.exists(config_file):
        for line in open(config_file):
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, _, v = line.partition('=')
                cfg[k.strip()] = v.strip().strip('"\'')
    cfg.update({k: v for k, v in os.environ.items()})
    return cfg

def analyze_image(image_bytes: bytes, context: str = 'security') -> str:
    """Phân tích ảnh camera, trả về mô tả tiếng Việt."""
    cfg = _load_config()
    engine = cfg.get('AI_ENGINE', 'openrouter')
    prompt = (
        "Đây là ảnh từ camera an ninh. Mô tả ngắn gọn (2-3 câu) những gì thấy: "
        "có người không, họ đang làm gì, có gì bất thường không. Trả lời bằng tiếng Việt."
    )
    small = _resize(image_bytes)
    b64 = base64.b64encode(small).decode()

    if engine == 'nvidia':
        return _nvidia_image(cfg, b64, prompt)
    elif engine == 'openrouter':
        return _openrouter_image(cfg, b64, prompt)
    elif engine == 'gemini':
        return _gemini_image(cfg, small, prompt)
    elif engine == 'ollama':
        return _ollama_image(cfg, b64, prompt)
    elif engine == 'do_agent':
        return _do_agent_image(cfg, b64, prompt)
    return '⚠️ Chưa cấu hình AI engine.'

def analyze_event(event_type: str, payload: dict, device_name: str) -> str:
    """Phân tích sự kiện không có ảnh (checkin, sensor...), trả về nhận xét tiếng Việt."""
    cfg = _load_config()
    engine = cfg.get('AI_ENGINE', 'openrouter')
    prompt = (
        f"Thiết bị '{device_name}' ghi nhận sự kiện '{event_type}': {payload}. "
        f"Nhận xét ngắn gọn (1 câu) có gì bất thường không. Trả lời tiếng Việt."
    )
    if engine == 'nvidia':
        return _nvidia_text(cfg, prompt)
    elif engine == 'openrouter':
        return _openrouter_text(cfg, prompt)
    elif engine == 'gemini':
        return _gemini_text(cfg, prompt)
    elif engine == 'ollama':
        return _ollama_text(cfg, prompt)
    elif engine == 'do_agent':
        return _do_agent_text(cfg, prompt)
    return ''

# ── NVIDIA NIM ──────────────────────────────────────────────

def _nvidia_image(cfg, b64: str, prompt: str) -> str:
    key = cfg.get('NVIDIA_KEY', '')
    model = cfg.get('NVIDIA_MODEL', 'nvidia/llama-3.2-90b-vision-instruct')
    if not key:
        return '⚠️ Chưa cấu hình NVIDIA_KEY.'
    try:
        resp = requests.post(
            'https://integrate.api.nvidia.com/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'model': model, 'max_tokens': 512, 'messages': [{'role': 'user', 'content': [
                {'type': 'text', 'text': prompt},
                {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{b64}'}}
            ]}]},
            timeout=60
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
        return f'⚠️ NVIDIA {resp.status_code}: {resp.text[:100]}'
    except Exception as e:
        return f'⚠️ NVIDIA lỗi: {str(e)[:100]}'

def _nvidia_text(cfg, prompt: str) -> str:
    key = cfg.get('NVIDIA_KEY', '')
    model = cfg.get('NVIDIA_TEXT_MODEL', 'meta/llama-3.1-70b-instruct')
    if not key:
        return ''
    try:
        resp = requests.post(
            'https://integrate.api.nvidia.com/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'model': model, 'max_tokens': 256,
                  'messages': [{'role': 'user', 'content': prompt}]},
            timeout=30
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
    except Exception as e:
        log.error(f'NVIDIA text: {e}')
    return ''

# ── OpenRouter ──────────────────────────────────────────────

def _openrouter_image(cfg, b64: str, prompt: str) -> str:
    key = cfg.get('OPENROUTER_KEY', '')
    model = cfg.get('OPENROUTER_MODEL', 'nvidia/nemotron-nano-12b-v2-vl:free')
    if not key:
        return '⚠️ Chưa cấu hình OPENROUTER_KEY.'
    try:
        resp = requests.post(
            'https://openrouter.ai/api/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'model': model, 'messages': [{'role': 'user', 'content': [
                {'type': 'text', 'text': prompt},
                {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{b64}'}}
            ]}]},
            timeout=60
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
        return f'⚠️ OpenRouter {resp.status_code}: {resp.text[:100]}'
    except Exception as e:
        return f'⚠️ OpenRouter lỗi: {str(e)[:100]}'

def _openrouter_text(cfg, prompt: str) -> str:
    key = cfg.get('OPENROUTER_KEY', '')
    model = cfg.get('OPENROUTER_MODEL', 'nvidia/nemotron-nano-12b-v2-vl:free')
    if not key:
        return ''
    try:
        resp = requests.post(
            'https://openrouter.ai/api/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={'model': model, 'messages': [{'role': 'user', 'content': prompt}]},
            timeout=30
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
    except Exception as e:
        log.error(f'OpenRouter text: {e}')
    return ''

# ── Gemini ──────────────────────────────────────────────────

def _gemini_image(cfg, image_bytes: bytes, prompt: str) -> str:
    key = cfg.get('GEMINI_KEY', '')
    if not key:
        return '⚠️ Chưa cấu hình GEMINI_KEY.'
    try:
        import google.generativeai as genai
        from PIL import Image
        genai.configure(api_key=key)
        model = genai.GenerativeModel('gemini-2.0-flash-lite')
        img = Image.open(BytesIO(image_bytes))
        resp = model.generate_content([prompt, img])
        return resp.text.strip()
    except Exception as e:
        return f'⚠️ Gemini lỗi: {str(e)[:100]}'

def _gemini_text(cfg, prompt: str) -> str:
    key = cfg.get('GEMINI_KEY', '')
    if not key:
        return ''
    try:
        import google.generativeai as genai
        genai.configure(api_key=key)
        model = genai.GenerativeModel('gemini-2.0-flash-lite')
        return model.generate_content(prompt).text.strip()
    except Exception as e:
        log.error(f'Gemini text: {e}')
    return ''

# ── Ollama ──────────────────────────────────────────────────

def _ollama_image(cfg, b64: str, prompt: str) -> str:
    url = cfg.get('OLLAMA_URL', 'http://localhost:11434')
    model = cfg.get('OLLAMA_MODEL', 'moondream')
    try:
        resp = requests.post(f'{url}/api/generate',
            json={'model': model, 'prompt': prompt, 'images': [b64], 'stream': False},
            timeout=120)
        if resp.status_code == 200:
            return resp.json().get('response', '').strip()
        return f'⚠️ Ollama {resp.status_code}'
    except Exception as e:
        return f'⚠️ Ollama lỗi: {str(e)[:100]}'

def _ollama_text(cfg, prompt: str) -> str:
    url = cfg.get('OLLAMA_URL', 'http://localhost:11434')
    model = cfg.get('OLLAMA_MODEL', 'gemma3:1b')
    try:
        resp = requests.post(f'{url}/api/generate',
            json={'model': model, 'prompt': prompt, 'stream': False},
            timeout=60)
        if resp.status_code == 200:
            return resp.json().get('response', '').strip()
    except Exception as e:
        log.error(f'Ollama text: {e}')
    return ''

# ── DigitalOcean GenAI Agent ─────────────────────────────────

def _do_agent_image(cfg, b64: str, prompt: str) -> str:
    """DO GenAI Agent — text only (Llama 3.3 70B không hỗ trợ vision)."""
    # DO Agent hiện chưa support vision, fallback về text mô tả
    return _do_agent_text(cfg, prompt + " (không có ảnh đính kèm)")

def _do_agent_text(cfg, prompt: str) -> str:
    endpoint = cfg.get('DO_AGENT_ENDPOINT', '')
    key = cfg.get('DO_AGENT_KEY', '')
    if not endpoint or not key:
        return '⚠️ Chưa cấu hình DO_AGENT_ENDPOINT hoặc DO_AGENT_KEY.'
    try:
        resp = requests.post(
            f'{endpoint}/api/v1/chat/completions',
            headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
            json={
                'messages': [{'role': 'user', 'content': prompt}],
                'stream': False,
                'max_tokens': 256
            },
            timeout=30
        )
        if resp.status_code == 200:
            return resp.json()['choices'][0]['message']['content'].strip()
        return f'⚠️ DO Agent {resp.status_code}: {resp.text[:100]}'
    except Exception as e:
        return f'⚠️ DO Agent lỗi: {str(e)[:100]}'
