#!/usr/bin/env python3
"""
Initialize local SQLite memory database with FTS5.
Creates memory_notes table + FTS5 virtual table + categories seed data.
"""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory.db")


def get_db_path():
    return DB_PATH


def init_db(path=None):
    if path is None:
        path = DB_PATH
    conn = sqlite3.connect(path)
    c = conn.cursor()

    # Main notes table
    c.execute("""
        CREATE TABLE IF NOT EXISTS memory_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'general',
            priority TEXT NOT NULL DEFAULT 'medium'
                CHECK(priority IN ('high', 'medium', 'low')),
            tags TEXT DEFAULT '',
            source TEXT DEFAULT 'manual',
            created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)

    # FTS5 virtual table for full-text search
    c.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS memory_notes_fts USING fts5(
            content,
            category,
            tags,
            content=memory_notes,
            content_rowid=id,
            tokenize='unicode61'
        )
    """)

    # Triggers to keep FTS in sync
    c.execute("""
        CREATE TRIGGER IF NOT EXISTS memory_notes_ai AFTER INSERT ON memory_notes BEGIN
            INSERT INTO memory_notes_fts(rowid, content, category, tags)
            VALUES (new.id, new.content, new.category, new.tags);
        END
    """)
    c.execute("""
        CREATE TRIGGER IF NOT EXISTS memory_notes_ad AFTER DELETE ON memory_notes BEGIN
            INSERT INTO memory_notes_fts(memory_notes_fts, rowid, content, category, tags)
            VALUES ('delete', old.id, old.content, old.category, old.tags);
        END
    """)
    c.execute("""
        CREATE TRIGGER IF NOT EXISTS memory_notes_au AFTER UPDATE ON memory_notes BEGIN
            INSERT INTO memory_notes_fts(memory_notes_fts, rowid, content, category, tags)
            VALUES ('delete', old.id, old.content, old.category, old.tags);
            INSERT INTO memory_notes_fts(rowid, content, category, tags)
            VALUES (new.id, new.content, new.category, new.tags);
        END
    """)

    # Schema migration: obsolete + superseded_by (safe to run multiple times)
    try:
        c.execute("ALTER TABLE memory_notes ADD COLUMN obsolete INTEGER NOT NULL DEFAULT 0")
    except sqlite3.OperationalError:
        pass  # already exists
    try:
        c.execute("ALTER TABLE memory_notes ADD COLUMN superseded_by INTEGER REFERENCES memory_notes(id)")
    except sqlite3.OperationalError:
        pass  # already exists

    # Index for category queries
    c.execute("""
        CREATE INDEX IF NOT EXISTS idx_memory_notes_category
        ON memory_notes(category)
    """)
    c.execute("""
        CREATE INDEX IF NOT EXISTS idx_memory_notes_priority
        ON memory_notes(priority)
    """)
    c.execute("""
        CREATE INDEX IF NOT EXISTS idx_memory_notes_created
        ON memory_notes(created_at DESC)
    """)
    c.execute("""
        CREATE INDEX IF NOT EXISTS idx_memory_notes_obsolete
        ON memory_notes(obsolete)
    """)

    conn.commit()
    conn.close()
    return True


def seed_default_categories(path=None):
    """Insert system default categories if empty"""
    if path is None:
        path = DB_PATH
    conn = sqlite3.connect(path)
    c = conn.cursor()
    count = c.execute("SELECT COUNT(*) FROM memory_notes").fetchone()[0]
    if count > 0:
        conn.close()
        return

    seeds = [
        {
            "content": "Write operations must go through Supabase RPC, never direct REST INSERT/UPDATE/DELETE. This is a security rule.",
            "category": "critical_rules", "priority": "high", "tags": "rpc,security,supabase"
        },
        {
            "content": "All changes must be committed + pushed. Commit is proof of work.",
            "category": "critical_rules", "priority": "high", "tags": "git,workflow"
        },
        {
            "content": "Migration files must be idempotent: DROP IF EXISTS + CREATE OR REPLACE pattern.",
            "category": "critical_rules", "priority": "high", "tags": "migration,sql,idempotent"
        },
        {
            "content": "hayvan_ekle(kup_no, dogum_tarihi, cinsiyet, irk, giris_tarihi, padok_id) → returns hayvan_id",
            "category": "rpc_reference", "priority": "high", "tags": "rpc,hayvan"
        },
        {
            "content": "hayvan_guncelle(hayvan_id, kup_no?, dogum_tarihi?, cinsiyet?) → returns hayvan",
            "category": "rpc_reference", "priority": "high", "tags": "rpc,hayvan"
        },
        {
            "content": "tohumlama_sonuc_gebe(tohumlama_id, muayene_tarihi) → marks tohumlama as gebe",
            "category": "rpc_reference", "priority": "high", "tags": "rpc,tohumlama"
        },
        {
            "content": "tohumlama_sonuc_bos(tohumlama_id) → marks as bos",
            "category": "rpc_reference", "priority": "medium", "tags": "rpc,tohumlama"
        },
        {
            "content": "stok_duzelt(stok_id, miktar, aciklama) → stock correction",
            "category": "rpc_reference", "priority": "high", "tags": "rpc,stok"
        },
        {
            "content": "Süt çiftliği domain: hayvan → tohumlama → dogum → laktasyon → kuru dönem döngüsü",
            "category": "domain_rules", "priority": "high", "tags": "domain,cow,cycle"
        },
    ]
    for s in seeds:
        c.execute(
            "INSERT INTO memory_notes (content, category, priority, tags, source) VALUES (?, ?, ?, ?, 'system')",
            (s["content"], s["category"], s["priority"], s["tags"])
        )
    conn.commit()
    conn.close()
    print(f"Seeded {len(seeds)} default memory notes.")


if __name__ == "__main__":
    init_db()
    seed_default_categories()
    print(f"Memory DB initialized at: {DB_PATH}")
