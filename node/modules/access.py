#!/usr/bin/env python3
"""🌿 Greenmind v3.0 — Node Access Module (stub)"""
import logging, threading
log = logging.getLogger(__name__)

class AccessModule:
    """Máy chấm công: ZKTeco, Hikvision DS-K, Ronald Jack..."""
    def __init__(self, cfg, stop_event):
        self.cfg = cfg; self.stop = stop_event
    def start(self):
        log.warning('⚠️ AccessModule chưa implement — TODO: ZKTeco SDK')
        self.stop.wait()
    def stop_module(self): self.stop.set()
