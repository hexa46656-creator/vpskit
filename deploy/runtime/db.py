from __future__ import annotations

import sqlite3
from pathlib import Path

from config import settings


def connect() -> sqlite3.Connection:
    Path(settings.db_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.db_path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 30000")
    return conn


def init_db() -> None:
    schema = Path(__file__).with_name("schema.sql").read_text(encoding="utf-8")
    with connect() as conn:
        conn.executescript(schema)
        migrate_existing_schema(conn)
        create_indexes(conn)
        seed_nodes(conn)


def _columns(conn: sqlite3.Connection, table: str) -> set[str]:
    return {row["name"] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()}


def _add_column(conn: sqlite3.Connection, table: str, name: str, definition: str) -> None:
    if name not in _columns(conn, table):
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {name} {definition}")


def migrate_existing_schema(conn: sqlite3.Connection) -> None:
    maybe_rebuild_subscriptions_for_elite(conn)
    _add_column(conn, "nodes", "region", "TEXT NOT NULL DEFAULT 'US-EAST'")
    _add_column(conn, "nodes", "load", "INTEGER NOT NULL DEFAULT 0")
    _add_column(conn, "users", "telegram_id", "TEXT")
    _add_column(conn, "payments", "provider", "TEXT NOT NULL DEFAULT 'paypal'")
    _add_column(conn, "payments", "event_id", "TEXT")
    _add_column(conn, "tokens", "node_id", "INTEGER")
    _add_column(conn, "tokens", "ip_bound", "TEXT")
    if "bound_ip" in _columns(conn, "tokens"):
        conn.execute("UPDATE tokens SET ip_bound = COALESCE(ip_bound, bound_ip)")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_provider_event ON payments(provider, paypal_event_id)")


def create_indexes(conn: sqlite3.Connection) -> None:
    conn.execute("CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_users_token ON users(token)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes(status)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_nodes_region_status ON nodes(region, status)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_tokens_user_id ON tokens(user_id)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_tokens_expires_at ON tokens(expires_at)")


def maybe_rebuild_subscriptions_for_elite(conn: sqlite3.Connection) -> None:
    row = conn.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='subscriptions'").fetchone()
    if not row or "plan IN ('basic', 'pro')" not in row["sql"]:
        return
    conn.execute("PRAGMA foreign_keys=OFF")
    conn.execute("ALTER TABLE subscriptions RENAME TO subscriptions_old")
    conn.execute(
        """
        CREATE TABLE subscriptions (
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
        )
        """
    )
    conn.execute(
        """
        INSERT INTO subscriptions (id,user_id,node_id,status,plan,start_at,end_at,config,created_at,updated_at)
        SELECT id,user_id,node_id,status,plan,start_at,end_at,config,created_at,updated_at
        FROM subscriptions_old
        """
    )
    conn.execute("DROP TABLE subscriptions_old")
    conn.execute("PRAGMA foreign_keys=ON")


def seed_nodes(conn: sqlite3.Connection) -> None:
    now = "1970-01-01T00:00:00+00:00"
    nodes = [
        ("US-East", "144.202.122.130", "US-EAST", 500),
        ("US-West", "203.0.113.20", "US-WEST", 500),
        ("Europe", "203.0.113.30", "EU", 500),
    ]
    for name, ip, region, capacity in nodes:
        conn.execute(
            """
            INSERT OR IGNORE INTO nodes (name, ip, region, capacity, load, status, created_at)
            VALUES (?, ?, ?, ?, 0, 'active', ?)
            """,
            (name, ip, region, capacity, now),
        )
        conn.execute(
            "UPDATE nodes SET region = ?, capacity = ? WHERE name = ?",
            (region, capacity, name),
        )
