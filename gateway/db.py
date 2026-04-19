#!/usr/bin/env python3
"""
🌿 Greenmind v3.0 — Smart Building AI Platform
Gateway Database Layer (sqlite3 thuần)
"""

import sqlite3, os, time, uuid
from pathlib import Path

DB_PATH = os.getenv('DB_PATH', '/var/lib/greenmind/greenmind.db')

def get_conn():
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_conn()
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS tenants (
            id TEXT PRIMARY KEY,
            name TEXT,
            telegram_chat_id TEXT,
            plan TEXT DEFAULT 'home',
            created_at INTEGER
        );
        CREATE TABLE IF NOT EXISTS locations (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            name TEXT,
            address TEXT,
            timezone TEXT DEFAULT 'Asia/Ho_Chi_Minh',
            created_at INTEGER
        );
        CREATE TABLE IF NOT EXISTS devices (
            id TEXT PRIMARY KEY,
            location_id TEXT,
            type TEXT,
            name TEXT,
            config_json TEXT,
            status TEXT DEFAULT 'offline',
            last_seen INTEGER
        );
        CREATE TABLE IF NOT EXISTS persons (
            id TEXT PRIMARY KEY,
            tenant_id TEXT,
            name TEXT,
            face_id TEXT,
            card_id TEXT,
            pin TEXT,
            role TEXT DEFAULT 'staff',
            schedule_json TEXT
        );
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            person_id TEXT,
            type TEXT,
            payload_json TEXT,
            ai_analysis TEXT,
            ts INTEGER
        );
        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER,
            channel TEXT,
            message TEXT,
            sent_at INTEGER
        );
    """)
    conn.commit()
    conn.close()

# ── Device CRUD ─────────────────────────────────────────────

def upsert_device(device_id: str, location_id: str, device_type: str, name: str, config_json: str = '{}'):
    conn = get_conn()
    now = int(time.time())
    conn.execute("""
        INSERT INTO devices (id, location_id, type, name, config_json, status, last_seen)
        VALUES (?, ?, ?, ?, ?, 'online', ?)
        ON CONFLICT(id) DO UPDATE SET status='online', last_seen=excluded.last_seen, name=excluded.name
    """, (device_id, location_id, device_type, name, config_json, now))
    conn.commit(); conn.close()

def set_device_status(device_id: str, status: str):
    conn = get_conn()
    conn.execute("UPDATE devices SET status=?, last_seen=? WHERE id=?",
                 (status, int(time.time()), device_id))
    conn.commit(); conn.close()

def get_devices():
    conn = get_conn()
    rows = conn.execute("SELECT * FROM devices ORDER BY name").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def get_device(device_id: str):
    conn = get_conn()
    row = conn.execute("SELECT * FROM devices WHERE id=?", (device_id,)).fetchone()
    conn.close()
    return dict(row) if row else None

# ── Event CRUD ──────────────────────────────────────────────

def insert_event(device_id: str, event_type: str, payload_json: str = '{}',
                 ai_analysis: str = '', person_id: str = None, ts: int = None):
    conn = get_conn()
    ts = ts or int(time.time())
    cur = conn.execute("""
        INSERT INTO events (device_id, person_id, type, payload_json, ai_analysis, ts)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (device_id, person_id, event_type, payload_json, ai_analysis, ts))
    event_id = cur.lastrowid
    conn.commit(); conn.close()
    return event_id

def get_events(limit: int = 50, offset: int = 0):
    conn = get_conn()
    rows = conn.execute("""
        SELECT e.*, d.name as device_name, d.type as device_type
        FROM events e LEFT JOIN devices d ON e.device_id = d.id
        ORDER BY e.ts DESC LIMIT ? OFFSET ?
    """, (limit, offset)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

# ── Alert CRUD ──────────────────────────────────────────────

def insert_alert(event_id: int, channel: str, message: str):
    conn = get_conn()
    conn.execute("INSERT INTO alerts (event_id, channel, message, sent_at) VALUES (?, ?, ?, ?)",
                 (event_id, channel, message, int(time.time())))
    conn.commit(); conn.close()

def count_alerts_today():
    conn = get_conn()
    midnight = int(time.time()) - (int(time.time()) % 86400)
    count = conn.execute("SELECT COUNT(*) FROM alerts WHERE sent_at >= ?", (midnight,)).fetchone()[0]
    conn.close()
    return count

# ── Locations ───────────────────────────────────────────────

def get_locations():
    conn = get_conn()
    rows = conn.execute("SELECT * FROM locations").fetchall()
    conn.close()
    return [dict(r) for r in rows]

def upsert_location(location_id: str, name: str, tenant_id: str = 'default'):
    conn = get_conn()
    conn.execute("""
        INSERT INTO locations (id, tenant_id, name, created_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name
    """, (location_id, tenant_id, name, int(time.time())))
    conn.commit(); conn.close()
