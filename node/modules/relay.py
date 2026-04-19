#!/usr/bin/env python3
"""🌿 Greenmind v3.0 — Node Relay Module (stub)"""
import logging, threading
log = logging.getLogger(__name__)

class RelayModule:
    def __init__(self, cfg, stop_event):
        self.cfg = cfg; self.stop = stop_event
    def start(self):
        log.warning('⚠️ RelayModule chưa implement')
        self.stop.wait()
    def stop_module(self): self.stop.set()
