PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    ip TEXT NOT NULL UNIQUE,
    region TEXT NOT NULL DEFAULT 'US-EAST',
    capacity INTEGER NOT NULL CHECK (capacity > 0),
    load INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL CHECK (status IN ('active', 'offline', 'maintenance')),
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    email TEXT,
    telegram_id TEXT,
    token TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'suspended')),
    node_id INTEGER,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (node_id) REFERENCES nodes(id)
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    node_id INTEGER NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'suspended')),
    plan TEXT NOT NULL CHECK (plan IN ('basic', 'pro', 'elite')),
    start_at TEXT NOT NULL,
    end_at TEXT NOT NULL,
    config TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (node_id) REFERENCES nodes(id)
);

CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    provider TEXT NOT NULL DEFAULT 'paypal',
    paypal_event_id TEXT NOT NULL UNIQUE,
    event_id TEXT,
    paypal_capture_id TEXT,
    user_id TEXT NOT NULL,
    amount TEXT,
    currency TEXT,
    status TEXT NOT NULL,
    raw_event TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE IF NOT EXISTS events (
    paypal_event_id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('processed', 'ignored', 'failed')),
    received_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS tokens (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    node_id INTEGER,
    plan TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used INTEGER NOT NULL DEFAULT 0,
    used_at TEXT,
    ip_bound TEXT,
    paypal_event_id TEXT NOT NULL UNIQUE,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (node_id) REFERENCES nodes(id)
);
