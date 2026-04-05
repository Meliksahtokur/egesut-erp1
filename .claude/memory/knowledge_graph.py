#!/usr/bin/env python3
"""
Mini-Agent Knowledge Graph
==========================
Entity extraction and relationship mapping for memory.
Builds a graph of interconnected entities.

Kullanım:
    python knowledge_graph.py --extract              # Tüm notlardan entity çıkar
    python knowledge_graph.py --graph                # Graph istatistikleri
    python knowledge_graph.py --query "entity"        # Entity ara
    python knowledge_graph.py --relate e1 e2          # İki entity arasındaki ilişki
    python knowledge_graph.py --path e1 e2           # Entity yolu bul
    python knowledge_graph.py --export                # Graph export et
"""

import json
import sqlite3
import re
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Set, Optional, Any, Tuple
from collections import defaultdict
import argparse

# Konfigürasyon
MEMORY_DB = ".claude/memory/memory.db"
GRAPH_DB = ".claude/memory/knowledge_graph.db"

# Entity türleri
ENTITY_TYPES = {
    'file': r'\b[\w\-\./]+\.(py|js|html|css|json|md|sql|yml|yaml|toml)\b',
    'function': r'\b([a-z_][a-z0-9_]*)\s*\(',
    'table': r'\b([a-z_][a-z0-9_]*)\s+(?:TABLE|table)',
    'variable': r'\b([A-Z_][A-Z0-9_]*)\b',
    'command': r'`([^`]+)`',
    'url': r'https?://[^\s]+',
    'person': r'@([A-Z][a-z]+)',
    'project': r'(EgeSüt|egesut|Mini-Agent|mini-agent)',
    'technology': r'\b(React|Vue|Angular|Node|Python|JavaScript|SQL|GraphQL|REST)\b',
    'concept': r'\b(RPC|FK|PK|API|CLI|UI|UX|Cache|Database|Backend|Frontend)\b'
}

# Renk kodları
COLORS = {
    "header": "\033[95m",
    "blue": "\033[94m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "red": "\033[91m",
    "cyan": "\033[96m",
    "magenta": "\033[35m",
    "bold": "\033[1m",
    "end": "\033[0m"
}


class KnowledgeGraph:
    """Knowledge graph for entities and relationships"""
    
    def __init__(self, memory_db: str = MEMORY_DB, graph_db: str = GRAPH_DB):
        self.memory_db = memory_db
        self.graph_db = graph_db
        self.conn = None
        self._ensure_dir()
    
    def _ensure_dir(self):
        Path(self.graph_db).parent.mkdir(parents=True, exist_ok=True)
    
    def connect(self):
        """Graph veritabanına bağlan"""
        self.conn = sqlite3.connect(self.graph_db)
        self.conn.row_factory = sqlite3.Row
    
    def close(self):
        if self.conn:
            self.conn.close()
            self.conn = None
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    def init_schema(self):
        """Graph şemasını oluştur"""
        cursor = self.conn.cursor()
        
        # Entities tablosu
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS entities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                type TEXT NOT NULL,
                count INTEGER DEFAULT 1,
                first_seen TEXT DEFAULT CURRENT_TIMESTAMP,
                last_seen TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Relationships tablosu
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS relationships (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL,
                target_id INTEGER NOT NULL,
                relationship TEXT NOT NULL,
                weight REAL DEFAULT 1.0,
                context TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (source_id) REFERENCES entities(id) ON DELETE CASCADE,
                FOREIGN KEY (target_id) REFERENCES entities(id) ON DELETE CASCADE,
                UNIQUE(source_id, target_id, relationship)
            )
        """)
        
        # Entity-Not bağlantısı
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS entity_notes (
                entity_id INTEGER NOT NULL,
                note_id INTEGER NOT NULL,
                position INTEGER,
                context TEXT,
                PRIMARY KEY (entity_id, note_id),
                FOREIGN KEY (entity_id) REFERENCES entities(id) ON DELETE CASCADE
            )
        """)
        
        # Indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_entity_name ON entities(name)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_entity_type ON entities(type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_rel_source ON relationships(source_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_rel_target ON relationships(target_id)")
        
        self.conn.commit()
        print(f"{COLORS['green']}✓ Knowledge graph schema oluşturuldu{self.graph_db}{COLORS['end']}")
        
        return True
    
    def extract_entities(self, text: str, note_id: int) -> List[Dict]:
        """Metinden entity çıkar"""
        entities = []
        
        for entity_type, pattern in ENTITY_TYPES.items():
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                # Group'i al (tuple ise)
                if isinstance(match, tuple):
                    match = match[0]
                
                entities.append({
                    'name': match.strip(),
                    'type': entity_type,
                    'note_id': note_id
                })
        
        return entities
    
    def extract_all(self, memory_db: str = MEMORY_DB) -> Tuple[int, int]:
        """Tüm notlardan entity çıkar"""
        # Memory DB'ye bağlan
        mem_conn = sqlite3.connect(memory_db)
        mem_conn.row_factory = sqlite3.Row
        
        cursor = self.conn.cursor()
        
        # Tüm notları al
        mem_cursor = mem_conn.cursor()
        mem_cursor.execute("SELECT id, content, category FROM notes")
        notes = mem_cursor.fetchall()
        
        total_entities = 0
        total_rels = 0
        
        print(f"{COLORS['blue']}📊 {len(notes)} nottan entity çıkarılıyor...{COLORS['end']}")
        
        for note in notes:
            note_id, content, category = note['id'], note['content'], note['category']
            
            # Entity çıkar
            entities = self.extract_entities(content, note_id)
            
            # Tüm entity'leri tek seferde ekle
            seen_entities = {}
            for entity in entities:
                name = entity['name']
                etype = entity['type']
                key = (name, etype)
                
                if key in seen_entities:
                    continue
                
                # Entity'yi kaydet veya güncelle
                cursor.execute("""
                    INSERT INTO entities (name, type, count)
                    VALUES (?, ?, 1)
                    ON CONFLICT(name) DO UPDATE SET 
                        count = count + 1,
                        last_seen = CURRENT_TIMESTAMP
                    WHERE entities.name = ? AND entities.type = ?
                """, (name, etype, name, etype))
                
                # Entity-ID al
                cursor.execute("SELECT id FROM entities WHERE name = ? AND type = ?",
                             (name, etype))
                row = cursor.fetchone()
                if row:
                    entity_id = row['id']
                    seen_entities[key] = entity_id
                    
                    # Entity-Not bağlantısı
                    cursor.execute("""
                        INSERT OR IGNORE INTO entity_notes (entity_id, note_id)
                        VALUES (?, ?)
                    """, (entity_id, note_id))
                
                total_entities += 1
            
            # İlişkileri çıkar (co-occurrence)
            unique_entities = list(seen_entities.keys())
            for i, (e1_name, e1_type) in enumerate(unique_entities):
                for e2_name, e2_type in unique_entities[i+1:]:
                    e1_id = seen_entities[(e1_name, e1_type)]
                    e2_id = seen_entities[(e2_name, e2_type)]
                    
                    # İlişki ekle veya güncelle
                    cursor.execute("""
                        INSERT INTO relationships (source_id, target_id, relationship, weight)
                        VALUES (?, ?, 'co-occurs', 1.0)
                        ON CONFLICT(source_id, target_id, relationship) 
                        DO UPDATE SET weight = weight + 0.5
                    """, (e1_id, e2_id))
                    
                    total_rels += 1
            
            self.conn.commit()
        
        mem_conn.close()
        
        print(f"{COLORS['green']}✓ {total_entities} entity, {total_rels} ilişki çıkarıldı{COLORS['end']}")
        return total_entities, total_rels
    
    def query_entity(self, name: str) -> Optional[Dict]:
        """Entity ara"""
        cursor = self.conn.cursor()
        
        cursor.execute("""
            SELECT * FROM entities 
            WHERE LOWER(name) LIKE LOWER(?)
            ORDER BY count DESC
            LIMIT 10
        """, (f'%{name}%',))
        
        results = cursor.fetchall()
        
        if not results:
            return None
        
        entities = []
        for row in results:
            # İlişkili entity'leri al
            cursor.execute("""
                SELECT e.*, r.relationship, r.weight
                FROM relationships r
                JOIN entities e ON e.id = r.target_id
                WHERE r.source_id = ?
                ORDER BY r.weight DESC
                LIMIT 5
            """, (row['id'],))
            
            related = [{'name': r['name'], 'type': r['type'], 'relationship': r['relationship']} 
                      for r in cursor.fetchall()]
            
            entities.append({
                'id': row['id'],
                'name': row['name'],
                'type': row['type'],
                'count': row['count'],
                'related': related
            })
        
        return {'query': name, 'results': entities}
    
    def find_path(self, entity1: str, entity2: str) -> List[Dict]:
        """İki entity arasındaki yolu bul (BFS)"""
        cursor = self.conn.cursor()
        
        # Entity ID'leri al
        cursor.execute("SELECT id, name FROM entities WHERE name = ?", (entity1,))
        start = cursor.fetchone()
        
        cursor.execute("SELECT id, name FROM entities WHERE name = ?", (entity2,))
        end = cursor.fetchone()
        
        if not start or not end:
            return []
        
        # BFS
        visited = {start['id']}
        queue = [(start['id'], [start['name']])]
        
        while queue:
            current_id, path = queue.pop(0)
            
            if current_id == end['id']:
                return [{'path': path, 'length': len(path) - 1}]
            
            # Komşuları al
            cursor.execute("""
                SELECT target_id FROM relationships WHERE source_id = ?
                UNION
                SELECT source_id FROM relationships WHERE target_id = ?
            """, (current_id, current_id))
            
            for row in cursor.fetchall():
                next_id = row['target_id']
                
                if next_id not in visited:
                    visited.add(next_id)
                    
                    # Entity name al
                    cursor.execute("SELECT name FROM entities WHERE id = ?", (next_id,))
                    name = cursor.fetchone()['name']
                    
                    queue.append((next_id, path + [name]))
        
        return []
    
    def get_stats(self) -> Dict[str, Any]:
        """Graph istatistikleri"""
        cursor = self.conn.cursor()
        
        # Toplam entity
        cursor.execute("SELECT COUNT(*) as count FROM entities")
        total_entities = cursor.fetchone()['count']
        
        # Toplam ilişki
        cursor.execute("SELECT COUNT(*) as count FROM relationships")
        total_rels = cursor.fetchone()['count']
        
        # Entity türleri
        cursor.execute("""
            SELECT type, COUNT(*) as count 
            FROM entities 
            GROUP BY type 
            ORDER BY count DESC
        """)
        entity_types = {row['type']: row['count'] for row in cursor.fetchall()}
        
        # En sık geçen entity'ler
        cursor.execute("""
            SELECT name, type, count 
            FROM entities 
            ORDER BY count DESC 
            LIMIT 10
        """)
        top_entities = [dict(row) for row in cursor.fetchall()]
        
        # En güçlü ilişkiler
        cursor.execute("""
            SELECT e1.name as source, e2.name as target, r.relationship, r.weight
            FROM relationships r
            JOIN entities e1 ON e1.id = r.source_id
            JOIN entities e2 ON e2.id = r.target_id
            ORDER BY r.weight DESC
            LIMIT 10
        """)
        top_relations = [dict(row) for row in cursor.fetchall()]
        
        return {
            'total_entities': total_entities,
            'total_relations': total_rels,
            'entity_types': entity_types,
            'top_entities': top_entities,
            'top_relations': top_relations
        }
    
    def export_graph(self, output_path: str = ".claude/memory/knowledge_graph.json"):
        """Graph'ı JSON'a export et"""
        stats = self.get_stats()
        
        export = {
            'exported_at': datetime.now().isoformat(),
            'stats': {
                'total_entities': stats['total_entities'],
                'total_relations': stats['total_relations']
            },
            'entities': stats['top_entities'],
            'relationships': stats['top_relations']
        }
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(export, f, indent=2, ensure_ascii=False)
        
        print(f"{COLORS['green']}✓ Graph {output_path}'e export edildi{COLORS['end']}")
        return export


def print_stats(stats: Dict):
    """İstatistikleri yazdır"""
    print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║  Knowledge Graph İstatistikleri                              ║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
    
    print(f"{COLORS['blue']}📊 Genel İstatistikler{COLORS['end']}")
    print(f"{'─' * 60}")
    print(f"  Toplam Entity:      {COLORS['green']}{stats['total_entities']}{COLORS['end']}")
    print(f"  Toplam İlişki:      {COLORS['green']}{stats['total_relations']}{COLORS['end']}")
    print()
    
    print(f"{COLORS['blue']}📁 Entity Türleri{COLORS['end']}")
    print(f"{'─' * 60}")
    total = sum(stats['entity_types'].values())
    for etype, count in sorted(stats['entity_types'].items(), key=lambda x: x[1], reverse=True):
        pct = (count / total * 100) if total > 0 else 0
        bar_len = int(pct / 5)
        bar = '█' * bar_len + '░' * (20 - bar_len)
        print(f"  {etype:15s} │ {bar} │ {count:3d} ({pct:5.1f}%)")
    print()
    
    print(f"{COLORS['blue']}🏆 En Sık Geçen Entity'ler{COLORS['end']}")
    print(f"{'─' * 60}")
    for i, entity in enumerate(stats['top_entities'][:5], 1):
        print(f"  {i}. [{entity['type']}] {entity['name']} ({entity['count']} kez)")
    print()
    
    print(f"{COLORS['blue']}🔗 En Güçlü İlişkiler{COLORS['end']}")
    print(f"{'─' * 60}")
    for i, rel in enumerate(stats['top_relations'][:5], 1):
        print(f"  {i}. {rel['source']} → {rel['target']} ({rel['weight']:.1f})")


def main():
    """Ana fonksiyon"""
    parser = argparse.ArgumentParser(description='Mini-Agent Knowledge Graph')
    parser.add_argument('--init', action='store_true', help='Graph schema oluştur')
    parser.add_argument('--extract', action='store_true', help='Tüm notlardan entity çıkar')
    parser.add_argument('--graph', action='store_true', help='Graph istatistikleri')
    parser.add_argument('--query', type=str, help='Entity ara')
    parser.add_argument('--relate', nargs=2, metavar=('E1', 'E2'), help='İki entity ilişkisi')
    parser.add_argument('--path', nargs=2, metavar=('E1', 'E2'), help='Entity yolu bul')
    parser.add_argument('--export', action='store_true', help='Graph export et')
    parser.add_argument('--memory-db', default=MEMORY_DB, help='Memory DB yolu')
    parser.add_argument('--graph-db', default=GRAPH_DB, help='Graph DB yolu')
    
    args = parser.parse_args()
    
    graph = KnowledgeGraph(args.memory_db, args.graph_db)
    
    if args.init:
        with graph:
            graph.init_schema()
    
    elif args.extract:
        with graph:
            graph.init_schema()
            graph.extract_all(args.memory_db)
    
    elif args.graph:
        with graph:
            stats = graph.get_stats()
            print_stats(stats)
    
    elif args.query:
        with graph:
            result = graph.query_entity(args.query)
            
            if not result:
                print(f"{COLORS['yellow']}⚠ Entity bulunamadı: {args.query}{COLORS['end']}")
                return
            
            print(f"\n{COLORS['blue']}🔍 '{args.query}' için Sonuçlar:{COLORS['end']}\n")
            
            for entity in result['results']:
                print(f"  {COLORS['cyan']}[{entity['type']}]{COLORS['end']} {entity['name']} ({entity['count']} kez)")
                
                if entity['related']:
                    related_str = ', '.join([f"{r['name']} ({r['relationship']})" for r in entity['related']])
                    print(f"    İlişkili: {related_str}")
                print()
    
    elif args.relate:
        with graph:
            e1, e2 = args.relate
            
            result = graph.query_entity(e1)
            if not result:
                print(f"{COLORS['red']}✗ Entity bulunamadı: {e1}{COLORS['end']}")
                return
            
            e1_data = result['results'][0]
            
            # İlişki ara
            cursor = graph.conn.cursor()
            cursor.execute("""
                SELECT e.name, e.type, r.relationship, r.weight
                FROM relationships r
                JOIN entities e ON e.id = r.target_id
                WHERE r.source_id = ? AND LOWER(e.name) LIKE LOWER(?)
            """, (e1_data['id'], f'%{e2}%'))
            
            rels = cursor.fetchall()
            
            print(f"\n{COLORS['blue']}🔗 {e1} → {e2} İlişkileri:{COLORS['end']}\n")
            
            if rels:
                for rel in rels:
                    print(f"  {COLORS['cyan']}[{rel['relationship']}]{COLORS['end']} {rel['name']} (weight: {rel['weight']:.1f})")
            else:
                print(f"  {COLORS['yellow']}⚠ Doğrudan ilişki yok{COLORS['end']}")
                
                # Path bul
                paths = graph.find_path(e1, e2)
                if paths:
                    print(f"\n  Alternatif yol: {' → '.join(paths[0]['path'])}")
    
    elif args.path:
        with graph:
            paths = graph.find_path(args.path[0], args.path[1])
            
            print(f"\n{COLORS['blue']}🛤️  {args.path[0]} → {args.path[1]} Yolu:{COLORS['end']}\n")
            
            if paths:
                for path in paths[:3]:
                    print(f"  {COLORS['green']}{' → '.join(path['path'])}{COLORS['end']}")
                    print(f"  (Uzunluk: {path['length']} adım)\n")
            else:
                print(f"  {COLORS['yellow']}⚠ Yol bulunamadı{COLORS['end']}")
    
    elif args.export:
        with graph:
            graph.export_graph()
    
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
