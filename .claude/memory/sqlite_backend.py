#!/usr/bin/env python3
"""
Mini-Agent SQLite Backend
==========================
JSON dosyasını SQLite veritabanına dönüştürür ve FTS5 ile full-text search sağlar.

Kullanım:
    python sqlite_backend.py --init          # Veritabanı oluştur
    python sqlite_backend.py --migrate       # JSON'dan import et
    python sqlite_backend.py --stats         # İstatistikleri göster
    python sqlite_backend.py --search "query"  # Ara

Avantajları:
    - 10-100x daha hızlı sorgular
    - FTS5 full-text search (BM25 ranking)
    - Milyonlarca not ölçeği
    - Backup/restore kolaylığı
    - Index'leme desteği
"""

import json
import sqlite3
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Any

# Konfigürasyon
MEMORY_JSON = ".agent_memory.json"
MEMORY_DB = ".claude/memory/memory.db"
SCHEMA_VERSION = 2

# Renk kodları
COLORS = {
    "header": "\033[95m",
    "blue": "\033[94m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "red": "\033[91m",
    "bold": "\033[1m",
    "end": "\033[0m"
}


class MemorySQLite:
    """SQLite tabanlı bellek yönetim sistemi"""
    
    def __init__(self, db_path=MEMORY_DB):
        self.db_path = db_path
        self.conn = None
        self._ensure_dir()
    
    def _ensure_dir(self):
        """Veritabanı dizinini oluştur"""
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
    
    def connect(self):
        """Veritabanına bağlan"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        # FTS5 için pragma'lar
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute("PRAGMA synchronous=NORMAL")
        self.conn.execute("PRAGMA cache_size=10000")
    
    def close(self):
        """Bağlantıyı kapat"""
        if self.conn:
            self.conn.close()
            self.conn = None
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    def init_schema(self):
        """Veritabanı şemasını oluştur"""
        cursor = self.conn.cursor()
        
        # Ana tablo
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                category TEXT NOT NULL,
                content TEXT NOT NULL,
                -- Extended fields (schema v2)
                priority TEXT DEFAULT 'medium',
                tags TEXT DEFAULT '[]',
                confidence REAL DEFAULT 1.0,
                source TEXT DEFAULT 'manual',
                expires TEXT,
                related TEXT DEFAULT '[]',
                -- Meta
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                search_text TEXT
            )
        """)
        
        # FTS5 virtual table for full-text search
        cursor.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
                content,
                category,
                tags,
                content='notes',
                content_rowid='id',
                tokenize='trigram'
            )
        """)
        
        # Index'ler
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_category ON notes(category)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_timestamp ON notes(timestamp)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_priority ON notes(priority)")
        
        # Trigger'lar (FTS sync için)
        cursor.execute("""
            CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
                INSERT INTO notes_fts(rowid, content, category, tags)
                VALUES (new.id, new.content, new.category, new.tags);
            END
        """)
        
        cursor.execute("""
            CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
                INSERT INTO notes_fts(notes_fts, rowid, content, category, tags)
                VALUES ('delete', old.id, old.content, old.category, old.tags);
            END
        """)
        
        cursor.execute("""
            CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
                INSERT INTO notes_fts(notes_fts, rowid, content, category, tags)
                VALUES ('delete', old.id, old.content, old.category, old.tags);
                INSERT INTO notes_fts(rowid, content, category, tags)
                VALUES (new.id, new.content, new.category, new.tags);
            END
        """)
        
        self.conn.commit()
        print(f"{COLORS['green']}✓ Şema oluşturuldu{self.db_path}{COLORS['end']}")
    
    def migrate_from_json(self, json_path=MEMORY_JSON):
        """JSON dosyasından SQLite'e geçiş yap"""
        if not os.path.exists(json_path):
            print(f"{COLORS['red']}✗ JSON dosyası bulunamadı: {json_path}{COLORS['end']}")
            return False
        
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                notes = json.load(f)
        except json.JSONDecodeError as e:
            print(f"{COLORS['red']}✗ JSON parse hatası: {e}{COLORS['end']}")
            return False
        
        cursor = self.conn.cursor()
        migrated = 0
        
        for note in notes:
            cursor.execute("""
                INSERT INTO notes (timestamp, category, content, priority, tags, confidence, source)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                note.get('timestamp', datetime.now().isoformat()),
                note.get('category', 'general'),
                note.get('content', ''),
                note.get('priority', 'medium'),
                json.dumps(note.get('tags', [])),
                note.get('confidence', 1.0),
                note.get('source', 'json_migration')
            ))
            migrated += 1
        
        self.conn.commit()
        print(f"{COLORS['green']}✓ {migrated} not SQLite'e aktarıldı{COLORS['end']}")
        
        # JSON backup oluştur
        backup_path = f"{json_path}.backup"
        os.rename(json_path, backup_path)
        print(f"{COLORS['yellow']}⚠ JSON yedeklendi: {backup_path}{COLORS['end']}")
        
        return True
    
    def save_note(self, category: str, content: str, **kwargs) -> int:
        """Yeni not kaydet"""
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO notes (timestamp, category, content, priority, tags, confidence, source, expires, related)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            datetime.now().isoformat(),
            category,
            content,
            kwargs.get('priority', 'medium'),
            json.dumps(kwargs.get('tags', [])),
            kwargs.get('confidence', 1.0),
            kwargs.get('source', 'manual'),
            kwargs.get('expires'),
            json.dumps(kwargs.get('related', []))
        ))
        self.conn.commit()
        return cursor.lastrowid
    
    def load_notes(self, category: Optional[str] = None, limit: int = 100) -> List[Dict]:
        """Notları yükle"""
        cursor = self.conn.cursor()
        
        if category:
            cursor.execute("""
                SELECT * FROM notes WHERE category = ? ORDER BY timestamp DESC LIMIT ?
            """, (category, limit))
        else:
            cursor.execute("""
                SELECT * FROM notes ORDER BY timestamp DESC LIMIT ?
            """, (limit,))
        
        rows = cursor.fetchall()
        return [dict(row) for row in rows]
    
    def search_notes(self, query: str, category: Optional[str] = None, 
                    limit: int = 10) -> List[Dict[str, Any]]:
        """Full-text search (FTS5)"""
        cursor = self.conn.cursor()
        
        if category:
            # FTS with category filter
            cursor.execute("""
                SELECT notes.*, bm25(notes_fts) as rank,
                       highlight(notes_fts, 0, '<mark>', '</mark>') as highlighted_content
                FROM notes_fts
                JOIN notes ON notes.id = notes_fts.rowid
                WHERE notes_fts MATCH ? AND notes.category = ?
                ORDER BY rank
                LIMIT ?
            """, (query, category, limit))
        else:
            # Pure FTS search
            cursor.execute("""
                SELECT notes.*, bm25(notes_fts) as rank,
                       highlight(notes_fts, 0, '<mark>', '</mark>') as highlighted_content
                FROM notes_fts
                JOIN notes ON notes.id = notes_fts.rowid
                WHERE notes_fts MATCH ?
                ORDER BY rank
                LIMIT ?
            """, (query, limit))
        
        rows = cursor.fetchall()
        results = []
        for row in rows:
            result = dict(row)
            # Parse JSON fields
            result['tags'] = json.loads(result.get('tags', '[]'))
            result['related'] = json.loads(result.get('related', '[]'))
            results.append(result)
        
        return results
    
    def get_categories(self) -> Dict[str, int]:
        """Kategori istatistiklerini al"""
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT category, COUNT(*) as count 
            FROM notes 
            GROUP BY category 
            ORDER BY count DESC
        """)
        return {row['category']: row['count'] for row in cursor.fetchall()}
    
    def get_stats(self) -> Dict[str, Any]:
        """İstatistikleri al"""
        cursor = self.conn.cursor()
        
        # Toplam not
        cursor.execute("SELECT COUNT(*) as total FROM notes")
        total = cursor.fetchone()['total']
        
        # Dosya boyutu
        size = os.path.getsize(self.db_path) if os.path.exists(self.db_path) else 0
        
        # Kategori dağılımı
        categories = self.get_categories()
        
        # Ortalama içerik uzunluğu
        cursor.execute("SELECT AVG(LENGTH(content)) as avg_len FROM notes")
        avg_len = cursor.fetchone()['avg_len'] or 0
        
        return {
            'total_notes': total,
            'file_size': size,
            'categories': categories,
            'avg_content_length': int(avg_len)
        }
    
    def delete_note(self, note_id: int) -> bool:
        """Not sil"""
        cursor = self.conn.cursor()
        cursor.execute("DELETE FROM notes WHERE id = ?", (note_id,))
        self.conn.commit()
        return cursor.rowcount > 0
    
    def export_to_json(self, output_path: str = MEMORY_JSON):
        """JSON'a export et"""
        notes = self.load_notes(limit=10000)
        
        # Extended fields'ı çıkar
        export = []
        for note in notes:
            export_note = {
                'timestamp': note['timestamp'],
                'category': note['category'],
                'content': note['content']
            }
            # Optional fields ekle
            if note.get('priority') != 'medium':
                export_note['priority'] = note['priority']
            if note.get('tags'):
                export_note['tags'] = note['tags']
            if note.get('confidence', 1.0) != 1.0:
                export_note['confidence'] = note['confidence']
            
            export.append(export_note)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(export, f, indent=2, ensure_ascii=False)
        
        print(f"{COLORS['green']}✓ {len(export)} not {output_path}'e export edildi{COLORS['end']}")
        return True


def print_stats(db: MemorySQLite):
    """İstatistikleri yazdır"""
    stats = db.get_stats()
    
    print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║       SQLite Bellek İstatistikleri                              ║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
    
    print(f"{COLORS['blue']}📊 Temel İstatistikler{db.db_path}{COLORS['end']}")
    print(f"{'─' * 60}")
    print(f"  Toplam Not:        {COLORS['green']}{stats['total_notes']}{COLORS['end']}")
    print(f"  Dosya Boyutu:     {stats['file_size']:,} byte ({stats['file_size']/1024:.2f} KB)")
    print(f"  Ortalama İçerik:  {stats['avg_content_length']} karakter")
    print()
    
    print(f"{COLORS['blue']}📁 Kategori Dağılımı{db.db_path}{COLORS['end']}")
    print(f"{'─' * 60}")
    categories = stats['categories']
    total = sum(categories.values())
    for cat, count in sorted(categories.items(), key=lambda x: x[1], reverse=True):
        pct = (count / total * 100) if total > 0 else 0
        bar_len = int(pct / 5)
        bar = '█' * bar_len + '░' * (20 - bar_len)
        print(f"  {cat:20s} │ {bar} │ {count:2d} ({pct:5.1f}%)")
    print()


def main():
    """Ana fonksiyon"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Mini-Agent SQLite Backend')
    parser.add_argument('--init', action='store_true', help='Veritabanı oluştur')
    parser.add_argument('--migrate', action='store_true', help='JSON\'dan import et')
    parser.add_argument('--stats', action='store_true', help='İstatistikleri göster')
    parser.add_argument('--search', type=str, help='Ara')
    parser.add_argument('--export', action='store_true', help='JSON\'a export et')
    parser.add_argument('--db', default=MEMORY_DB, help='Veritabanı yolu')
    args = parser.parse_args()
    
    db = MemorySQLite(args.db)
    
    if args.init:
        with db:
            db.init_schema()
            print(f"{COLORS['green']}✓ Veritabanı hazır: {args.db}{COLORS['end']}")
    
    elif args.migrate:
        with db:
            db.init_schema()
            db.migrate_from_json()
    
    elif args.stats:
        with db:
            print_stats(db)
    
    elif args.search:
        with db:
            results = db.search_notes(args.search)
            print(f"\n{COLORS['blue']}🔍 Sonuçlar: {len(results)} bulundu{db.db_path}{COLORS['end']}\n")
            for i, result in enumerate(results, 1):
                print(f"{i}. [{result['category']}] {result.get('highlighted_content', result['content'])[:100]}...")
                print()
    
    elif args.export:
        with db:
            db.export_to_json()
    
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
