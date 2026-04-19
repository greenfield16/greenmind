#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — MQTT Handler
Subscribe events từ Node qua MQTT
"""

import os, json, time, logging
import paho.mqtt.client as mqtt

log = logging.getLogger(__name__)

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

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        log.info('✅ MQTT connected')
        client.subscribe('greenmind/#')
    else:
        log.error(f'❌ MQTT connect failed: {rc}')

def on_message(client, userdata, msg):
    """
    Topic format: greenmind/{tenant}/{location}/{device_type}/{device_id}/event
    """
    try:
        parts = msg.topic.split('/')
        if len(parts) < 4:
            return
        payload = json.loads(msg.payload.decode())
        device_id = parts[-2] if len(parts) >= 5 else parts[-1]
        device_type = parts[-3] if len(parts) >= 5 else 'unknown'
        log.info(f'📡 MQTT: {msg.topic} → {payload}')
        # TODO: xử lý event qua REST API nội bộ hoặc gọi trực tiếp db/alert
    except Exception as e:
        log.error(f'MQTT message: {e}')

def start_mqtt():
    cfg = load_config()
    broker = cfg.get('MQTT_HOST', 'localhost')
    port   = int(cfg.get('MQTT_PORT', 1883))
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    try:
        client.connect(broker, port, keepalive=60)
        client.loop_forever()
    except Exception as e:
        log.error(f'MQTT start: {e}')

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    start_mqtt()
