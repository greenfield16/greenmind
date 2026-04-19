#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — Node Main
Orchestrator: load & start modules theo config
"""

import os, time, logging, signal, threading
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger(__name__)

CONFIG_FILE = os.getenv('CONFIG_FILE', '/etc/greenmind/config.env')
_stop_event = threading.Event()

def load_config():
    cfg = {}
    if os.path.exists(CONFIG_FILE):
        for line in open(CONFIG_FILE):
            line = line.strip()
            if '=' in line and not line.startswith('#'):
                k, _, v = line.partition('=')
                cfg[k.strip()] = v.strip().strip('"\'')
    cfg.update(os.environ)
    return cfg

def signal_handler(sig, frame):
    log.info('🛑 Nhận tín hiệu dừng, đang tắt...')
    _stop_event.set()

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

def main():
    cfg = load_config()
    modules_str = cfg.get('MODULES', 'camera')
    modules = [m.strip() for m in modules_str.split(',')]

    log.info(f'🌿 Greenmind Node khởi động')
    log.info(f'   Gateway : {cfg.get("GATEWAY_URL","?")}')
    log.info(f'   Location: {cfg.get("LOCATION_ID","default")}')
    log.info(f'   Modules : {", ".join(modules)}')

    threads = []

    for module_name in modules:
        try:
            if module_name == 'camera':
                from modules.camera import CameraModule
                mod = CameraModule(cfg, _stop_event)
            elif module_name == 'access':
                from modules.access import AccessModule
                mod = AccessModule(cfg, _stop_event)
            elif module_name == 'lock':
                from modules.lock import LockModule
                mod = LockModule(cfg, _stop_event)
            elif module_name == 'sensor':
                from modules.sensor import SensorModule
                mod = SensorModule(cfg, _stop_event)
            elif module_name == 'relay':
                from modules.relay import RelayModule
                mod = RelayModule(cfg, _stop_event)
            elif module_name == 'barrier':
                from modules.barrier import BarrierModule
                mod = BarrierModule(cfg, _stop_event)
            else:
                log.warning(f'⚠️ Module không hỗ trợ: {module_name}')
                continue

            t = threading.Thread(target=mod.start, name=f'module-{module_name}', daemon=True)
            t.start()
            threads.append(t)
            log.info(f'✅ Module {module_name} đã khởi động')

        except ImportError as e:
            log.error(f'❌ Không load được module {module_name}: {e}')
        except Exception as e:
            log.error(f'❌ Lỗi khởi động module {module_name}: {e}')

    if not threads:
        log.error('❌ Không có module nào chạy được. Thoát.')
        return

    # Chờ đến khi nhận tín hiệu dừng
    _stop_event.wait()
    log.info('🌿 Greenmind Node đã dừng.')

if __name__ == '__main__':
    main()
