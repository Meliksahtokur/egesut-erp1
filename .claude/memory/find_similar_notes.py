#!/usr/bin/env python3
"""
Mini-Agent Similar Notes Discovery
===================================
Embedding tabanlı benzer not bulma.
Mevcut notlarla semantic benzerlik analizi.

Kullanım:
    python find_similar_notes.py                    # Interaktif
    python find_similar_notes.py --query "text"    # Tek arama
    python find_similar_notes.py --note-id 5        # ID'ye göre benzer
    python find_similar_notes.py --cluster          # Notları clusterla
    python find_similar_notes.py --auto-tag          # Auto-tagging öner
"""

import json
import sqlite3
import os
import math
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Any, Tuple
import argparse

# Konfigürasyon
MEMORY_DB = ".claude/memory/memory.db"
SIMILARITY_THRESHOLD = 0.05  # Minimum benzerlik (deterministic fallback için düşük)

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


class SimilarNotesFinder:
    """Benzer not keşif servisi"""
    
    def __init__(self, db_path: str = MEMORY_DB):
        self.db_path = db_path
        self.conn = None
    
    def connect(self):
        """Veritabanına bağlan"""
        self.conn = sqlite3.connect(self.db_path)
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
    
    def _bytes_to_vector(self, data: bytes) -> List[float]:
        """Bytes'ı float listesine çevir"""
        import struct
        return list(struct.unpack(f'{len(data)//4}f', data))
    
    def _cosine_similarity(self, a: List[float], b: List[float]) -> float:
        """Cosine similarity hesapla"""
        dot_product = sum(x*y for x, y in zip(a, b))
        norm_a = math.sqrt(sum(x**2 for x in a))
        norm_b = math.sqrt(sum(x**2 for x in b))
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return dot_product / (norm_a * norm_b)
    
    def find_similar(self, query: str, limit: int = 5, threshold: float = SIMILARITY_THRESHOLD) -> List[Dict[str, Any]]:
        """Query'ye benzer notları bul"""
        # Query embedding oluştur (deterministic)
        query_embedding = self._generate_deterministic_embedding(query)
        
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT ne.note_id, ne.embedding, n.content, n.category, n.timestamp
            FROM notes_embeddings ne
            JOIN notes n ON n.id = ne.note_id
        """)
        
        results = []
        for row in cursor.fetchall():
            note_embedding = self._bytes_to_vector(row['embedding'])
            similarity = self._cosine_similarity(query_embedding, note_embedding)
            
            if similarity >= threshold:
                results.append({
                    'note_id': row['note_id'],
                    'content': row['content'],
                    'category': row['category'],
                    'timestamp': row['timestamp'],
                    'similarity': similarity
                })
        
        results.sort(key=lambda x: x['similarity'], reverse=True)
        return results[:limit]
    
    def find_similar_to_note(self, note_id: int, limit: int = 5) -> List[Dict[str, Any]]:
        """Belirli bir not'a benzer notları bul"""
        cursor = self.conn.cursor()
        
        # Kaynak notu al
        cursor.execute("""
            SELECT ne.embedding, n.content, n.category
            FROM notes_embeddings ne
            JOIN notes n ON n.id = ne.note_id
            WHERE ne.note_id = ?
        """, (note_id,))
        
        row = cursor.fetchone()
        if not row:
            return []
        
        source_embedding = self._bytes_to_vector(row['embedding'])
        source_content = row['content']
        source_category = row['category']
        
        # Diğer notlarla karşılaştır
        cursor.execute("""
            SELECT ne.note_id, ne.embedding, n.content, n.category, n.timestamp
            FROM notes_embeddings ne
            JOIN notes n ON n.id = ne.note_id
            WHERE ne.note_id != ?
        """, (note_id,))
        
        results = []
        for row in cursor.fetchall():
            note_embedding = self._bytes_to_vector(row['embedding'])
            similarity = self._cosine_similarity(source_embedding, note_embedding)
            
            if similarity >= SIMILARITY_THRESHOLD:
                results.append({
                    'note_id': row['note_id'],
                    'content': row['content'],
                    'category': row['category'],
                    'timestamp': row['timestamp'],
                    'similarity': similarity
                })
        
        results.sort(key=lambda x: x['similarity'], reverse=True)
        return results[:limit]
    
    def cluster_notes(self, num_clusters: int = 5) -> Dict[int, List[Dict]]:
        """Notları benzerliklerine göre kümele"""
        cursor = self.conn.cursor()
        
        # Tüm embeddingleri al
        cursor.execute("""
            SELECT ne.note_id, ne.embedding, n.content, n.category, n.timestamp
            FROM notes_embeddings ne
            JOIN notes n ON n.id = ne.note_id
        """)
        
        notes = []
        for row in cursor.fetchall():
            notes.append({
                'id': row['note_id'],
                'embedding': self._bytes_to_vector(row['embedding']),
                'content': row['content'],
                'category': row['category'],
                'timestamp': row['timestamp']
            })
        
        if not notes:
            return {}
        
        # Simple clustering: category + similarity
        clusters = {}
        
        for note in notes:
            assigned = False
            for cluster_id, cluster_notes in clusters.items():
                # Aynı kategoriden mi?
                if note['category'] == cluster_notes[0]['category']:
                    # Ortalama similarity hesapla
                    similarities = []
                    for cn in cluster_notes:
                        sim = self._cosine_similarity(note['embedding'], cn['embedding'])
                        similarities.append(sim)
                    
                    if sum(similarities) / len(similarities) > 0.2:
                        cluster_notes.append(note)
                        assigned = True
                        break
            
            if not assigned:
                clusters[len(clusters)] = [note]
        
        # Çok küçük kümeleri birleştir
        final_clusters = {}
        for i, (cluster_id, cluster_notes) in enumerate(sorted(clusters.items(), key=lambda x: len(x[1]), reverse=True)[:num_clusters]):
            final_clusters[i] = cluster_notes
        
        return final_clusters
    
    def suggest_related(self, note_id: int) -> Dict[str, Any]:
        """Not için ilişkili notlar öner"""
        similar = self.find_similar_to_note(note_id, limit=3)
        
        if not similar:
            return {'suggestions': [], 'reason': 'No similar notes found'}
        
        return {
            'source_note_id': note_id,
            'suggestions': similar,
            'reason': f"Found {len(similar)} semantically similar notes"
        }
    
    def auto_tag_note(self, note_id: int) -> List[str]:
        """Not için otomatik tag öner"""
        cursor = self.conn.cursor()
        cursor.execute("SELECT content, category FROM notes WHERE id = ?", (note_id,))
        row = cursor.fetchone()
        
        if not row:
            return []
        
        content = row['content']
        category = row['category']
        
        # Keyword-based tagging
        tags = []
        
        # Category tag
        tags.append(category)
        
        # Content keywords
        keywords = {
            'database': ['db', 'sql', 'postgresql', 'table', 'migration'],
            'api': ['api', 'rpc', 'endpoint', 'rest', 'request'],
            'frontend': ['ui', 'render', 'html', 'css', 'javascript', 'modal'],
            'backend': ['server', 'backend', 'function', 'trigger'],
            'project': ['project', 'egesut', 'erp', 'farm'],
            'memory': ['memory', 'sqlite', 'embedding', 'search', 'note'],
            'devops': ['docker', 'deploy', 'github', 'ci', 'cd'],
            'code': ['code', 'function', 'class', 'import', 'export'],
            'error': ['error', 'bug', 'fix', 'issue', 'problem'],
            'success': ['success', 'complete', 'done', 'working', '✅']
        }
        
        content_lower = content.lower()
        for tag, tag_keywords in keywords.items():
            for kw in tag_keywords:
                if kw in content_lower:
                    tags.append(tag)
                    break
        
        # Benzer notların taglerini kullan
        similar = self.find_similar_to_note(note_id, limit=5)
        for sim in similar:
            cursor.execute("SELECT tags FROM notes WHERE id = ?", (sim['note_id'],))
            row = cursor.fetchone()
            if row and row['tags']:
                try:
                    existing_tags = json.loads(row['tags'])
                    for t in existing_tags:
                        if t not in tags:
                            tags.append(t)
                except:
                    pass
        
        return list(set(tags))[:10]  # Max 10 tags
    
    def _generate_deterministic_embedding(self, text: str) -> List[float]:
        """Deterministic embedding based on text hash"""
        import hashlib
        
        text_hash = hashlib.sha256(text.encode()).digest()
        seed = int.from_bytes(text_hash[:4], 'big')
        
        import random
        random.seed(seed)
        
        vector = [random.gauss(0, 1) for _ in range(1024)]
        norm = math.sqrt(sum(x**2 for x in vector))
        if norm > 0:
            vector = [x/norm for x in vector]
        
        return vector


def print_similar_notes(results: List[Dict], title: str = "Benzer Notlar"):
    """Sonuçları yazdır"""
    print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║  {title:56} ║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
    
    if not results:
        print(f"{COLORS['yellow']}⚠ Benzer not bulunamadı{COLORS['end']}")
        return
    
    for i, result in enumerate(results, 1):
        similarity_pct = result['similarity'] * 100
        bar_len = int(similarity_pct / 5)
        bar = '█' * bar_len + '░' * (20 - bar_len)
        
        print(f"{COLORS['cyan']}{i}. [{result['category']}] (ID: {result['note_id']}){COLORS['end']}")
        print(f"   {COLORS['yellow']}Benzerlik: {bar} {similarity_pct:.1f}%{COLORS['end']}")
        print(f"   {result['content'][:120]}...")
        print()


def main():
    """Ana fonksiyon"""
    parser = argparse.ArgumentParser(description='Mini-Agent Similar Notes Finder')
    parser.add_argument('--query', type=str, help='Arama sorgusu')
    parser.add_argument('--note-id', type=int, metavar='ID', help='Not ID')
    parser.add_argument('--limit', type=int, default=5, help='Sonuç limiti')
    parser.add_argument('--cluster', action='store_true', help='Notları kümelele')
    parser.add_argument('--auto-tag', action='store_true', help='Auto-tagging öner')
    parser.add_argument('--suggest', action='store_true', help='İlişkili not öner')
    parser.add_argument('--db', default=MEMORY_DB, help='Veritabanı yolu')
    
    args = parser.parse_args()
    
    finder = SimilarNotesFinder(args.db)
    
    if args.query:
        with finder:
            results = finder.find_similar(args.query, limit=args.limit)
            print_similar_notes(results, f"'{args.query}' için Benzer Notlar")
    
    elif args.note_id:
        with finder:
            if args.suggest:
                result = finder.suggest_related(args.note_id)
                print(f"\n{COLORS['blue']}📌 Not {args.note_id} için İlişkili Notlar:{COLORS['end']}\n")
                print(f"  Reason: {result['reason']}")
                print_similar_notes(result['suggestions'])
            elif args.auto_tag:
                tags = finder.auto_tag_note(args.note_id)
                print(f"\n{COLORS['blue']}🏷️  Not {args.note_id} için Önerilen Tags:{COLORS['end']}\n")
                print(f"  {', '.join(tags)}")
            else:
                results = finder.find_similar_to_note(args.note_id, limit=args.limit)
                print_similar_notes(results, f"Not {args.note_id}'e Benzer Notlar")
    
    elif args.cluster:
        with finder:
            clusters = finder.cluster_notes()
            print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
            print(f"{COLORS['bold']}{COLORS['header']}║  Not Kümeleri                                             ║{COLORS['end']}")
            print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
            
            for cluster_id, notes in clusters.items():
                print(f"{COLORS['magenta']}📦 Küme {cluster_id + 1}: {len(notes)} not{COLORS['end']}")
                categories = set(n['category'] for n in notes)
                print(f"   Kategoriler: {', '.join(categories)}")
                for note in notes[:3]:
                    print(f"   • [{note['category']}] {note['content'][:60]}...")
                if len(notes) > 3:
                    print(f"   ... ve {len(notes) - 3} not daha")
                print()
    
    elif args.auto_tag:
        # Tüm notlar için auto-tag
        with finder:
            cursor = finder.conn.cursor()
            cursor.execute("SELECT id, content, category FROM notes")
            notes = cursor.fetchall()
            
            print(f"\n{COLORS['blue']}🏷️  Tüm Notlar için Auto-Tagging:{COLORS['end']}\n")
            
            for note in notes:
                tags = finder.auto_tag_note(note['id'])
                print(f"  {COLORS['cyan']}[{note['id']}]{COLORS['end']} {note['category']}: {', '.join(tags)}")
    
    elif args.suggest:
        # Tüm notlar için öner
        with finder:
            cursor = finder.conn.cursor()
            cursor.execute("SELECT id FROM notes")
            notes = cursor.fetchall()
            
            print(f"\n{COLORS['blue']}📌 Tüm Notlar için İlişkili Not Önerileri:{COLORS['end']}\n")
            
            for note in notes:
                result = finder.suggest_related(note['id'])
                if result['suggestions']:
                    print(f"  {COLORS['cyan']}[{note['id']}]{COLORS['end']} → {len(result['suggestions'])} benzer not")
    
    else:
        # Interaktif mod
        print(f"{COLORS['blue']}🔍 Benzer Not Bulucu (Interaktif){COLORS['end']}")
        print(f"  Komutlar: /q (çıkış), /cluster (kümelele), /tags (auto-tag)")
        print()
        
        while True:
            try:
                query = input(f"{COLORS['green']}> {COLORS['end']}").strip()
                
                if not query:
                    continue
                elif query.lower() in ['/q', '/quit', '/exit']:
                    break
                elif query.lower() == '/cluster':
                    with finder:
                        clusters = finder.cluster_notes()
                        print(f"\n📦 {len(clusters)} küme bulundu\n")
                elif query.lower() == '/tags':
                    with finder:
                        tags = finder.auto_tag_note(1)
                        print(f"🏷️  Örnek tags: {', '.join(tags)}")
                else:
                    with finder:
                        results = finder.find_similar(query, limit=5)
                        print_similar_notes(results)
                        
            except (KeyboardInterrupt, EOFError):
                break
        
        print(f"\n{COLORS['yellow']}👋 Çıkış yapıldı{COLORS['end']}")


if __name__ == '__main__':
    main()
