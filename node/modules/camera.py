#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — Node Camera Module
Motion detection + snapshot push lên Gateway
"""

import os, time, logging, subprocess, tempfile, threading, re, requests
from pathlib import Path

log = logging.getLogger(__name__)

def capture_frame(rtsp: str) -> bytes | None:
    """Chụp 1 frame từ RTSP bằng ffmpeg, trả về JPEG bytes."""
    try:
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
            tmp = f.name
        r = subprocess.run([
            'ffmpeg', '-y', '-loglevel', 'error',
            '-rtsp_transport', 'tcp',
            '-i', rtsp,
            '-frames:v', '1', '-q:v', '5',
            '-vf', 'scale=640:-1',
            tmp
        ], capture_output=True, timeout=15)
        if r.returncode != 0 or not Path(tmp).exists():
            return None
        data = open(tmp, 'rb').read()
        Path(tmp).unlink(missing_ok=True)
        return data if len(data) > 1000 else None
    except Exception as e:
        log.error(f'capture_frame: {e}')
        return None

def compare_frames(f1: bytes, f2: bytes) -> float:
    """So sánh 2 frame bằng Pillow pixel diff. Trả về 0-1 (1 = giống hệt)."""
    try:
        from PIL import Image, ImageChops
        import io
        img1 = Image.open(io.BytesIO(f1)).convert('L').resize((160, 90))
        img2 = Image.open(io.BytesIO(f2)).convert('L').resize((160, 90))
        diff = ImageChops.difference(img1, img2)
        pixels = list(diff.getdata())
        changed = sum(1 for p in pixels if p > 15)
        score = 1.0 - (changed / len(pixels))
        log.debug(f'Pixel diff: {changed}/{len(pixels)} → score={score:.3f}')
        return score
    except Exception as e:
        log.error(f'compare_frames: {e}')
        return 1.0

class CameraModule:
    def __init__(self, cfg: dict, stop_event: threading.Event):
        self.cfg         = cfg
        self.stop        = stop_event
        self.gateway     = cfg.get('GATEWAY_URL', 'http://localhost:8765')
        self.location_id = cfg.get('LOCATION_ID', 'default')
        self.snap_iv     = int(cfg.get('SNAP_INTERVAL', 60))
        self.motion_iv   = int(cfg.get('MOTION_INTERVAL', 30))
        self.threshold   = float(cfg.get('MOTION_THRESHOLD', 0.92))
        self.cooldown    = int(cfg.get('MOTION_COOLDOWN', 60))
        self.cameras     = self._load_cameras()

    def _load_cameras(self) -> dict:
        """Tìm CAM01_NAME/CAM01_RTSP, CAM02_NAME/CAM02_RTSP, ... trong config."""
        cams = {}
        i = 1
        while True:
            name = self.cfg.get(f'CAM{i:02d}_NAME') or self.cfg.get(f'CAM{i}_NAME')
            rtsp = self.cfg.get(f'CAM{i:02d}_RTSP') or self.cfg.get(f'CAM{i}_RTSP')
            # Fallback: tìm pattern {NAME}_RTSP
            if not name and not rtsp:
                # Scan tất cả _RTSP keys
                for k, v in self.cfg.items():
                    if k.endswith('_RTSP') and k not in [f'CAM{j:02d}_RTSP' for j in range(1, i)]:
                        cam_name = k.replace('_RTSP', '')
                        cams[cam_name] = v
                break
            if not name or not rtsp:
                break
            cams[name] = rtsp
            i += 1

        if cams:
            log.info(f'📷 Cameras: {list(cams.keys())}')
        else:
            log.warning('⚠️ Không tìm thấy camera nào trong config')
        return cams

    def push_snapshot(self, device_id: str, data: bytes, motion: bool = False):
        try:
            resp = requests.post(
                f'{self.gateway}/api/node/snapshot',
                files={'snapshot': (f'{device_id}.jpg', data, 'image/jpeg')},
                data={'device_id': device_id, 'location_id': self.location_id,
                      'ts': int(time.time()), 'motion': '1' if motion else '0'},
                timeout=10
            )
            tag = '🚨' if motion else '📷'
            if resp.status_code == 200:
                log.info(f'{tag} {device_id}: pushed OK ({len(data)//1024}KB)')
            else:
                log.warning(f'{device_id}: gateway {resp.status_code}')
        except Exception as e:
            log.error(f'{device_id}: push failed — {e}')

    def push_motion(self, device_id: str, data: bytes, score: float):
        try:
            requests.post(
                f'{self.gateway}/api/node/motion',
                files={'snapshot': (f'{device_id}.jpg', data, 'image/jpeg')},
                data={'device_id': device_id, 'location_id': self.location_id,
                      'ts': int(time.time()), 'score': str(round(score, 4))},
                timeout=10
            )
            log.info(f'🚨 Motion alert: {device_id} (score={score:.3f})')
        except Exception as e:
            log.error(f'{device_id}: motion push failed — {e}')

    def start(self):
        log.info(f'📷 CameraModule start | snap={self.snap_iv}s motion={self.motion_iv}s threshold={self.threshold}')
        last_snap   = {}
        last_alert  = {}
        prev_frame  = {}
        last_motion = {}

        while not self.stop.is_set():
            if not self.cameras:
                self.cameras = self._load_cameras()
                if not self.cameras:
                    self.stop.wait(30)
                    continue

            now = time.time()
            for name, rtsp in self.cameras.items():
                # Motion check
                if now - last_motion.get(name, 0) >= self.motion_iv:
                    last_motion[name] = now
                    frame = capture_frame(rtsp)
                    if frame:
                        if name in prev_frame:
                            score = compare_frames(prev_frame[name], frame)
                            if score < self.threshold:
                                if now - last_alert.get(name, 0) >= self.cooldown:
                                    last_alert[name] = now
                                    self.push_motion(name, frame, score)
                                    self.push_snapshot(name, frame, motion=True)
                                    last_snap[name] = now
                        prev_frame[name] = frame

                # Snapshot định kỳ
                if now - last_snap.get(name, 0) >= self.snap_iv:
                    frame = capture_frame(rtsp)
                    if frame:
                        self.push_snapshot(name, frame)
                        last_snap[name] = now
                        if name not in prev_frame:
                            prev_frame[name] = frame

            self.stop.wait(2)

    def stop_module(self):
        self.stop.set()
