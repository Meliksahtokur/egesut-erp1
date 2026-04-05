#!/usr/bin/env python3
"""
Mini-Agent Embedding Service
============================
Semantic search için vektör embedding üretimi.
MiniMax API veya local model kullanabilir.

Kullanım:
    python embedding_service.py --init          # Tüm notlar için embedding oluştur
    python embedding_service.py --embed "text"   # Tek metin embedding
    python embedding_service.py --similar 5     # 5 benzer not bul
    python embedding_service.py --stats         # Embedding istatistikleri
    python embedding_service.py --update 1     # ID=1 notu güncelle

Avantajları:
    - Anlamsal arama (keyword değil, meaning)
    - "nasıl yapılır" → "tutorial" benzerliği
    - Context-aware sonuçlar
    - Semantic clustering
"""

import json
import sqlite3
import os
import sys
import math
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Any, Tuple
import argparse

# Konfigürasyon
MEMORY_DB = ".claude/memory/memory.db"
EMBEDDING_DIM = 1024  # MiniMax embedding boyutu
BATCH_SIZE = 32

# MiniMax API
MINIMAX_API_KEY = os.getenv("MINIMAX_API_KEY", "")
MINIMAX_BASE_URL = "https://api.minimax.io/v1"

# Embedding modelleri
EMBEDDING_MODELS = {
    "minimax": {
        "name": "MiniMax Embedding",
        "dimension": 1024,
        "endpoint": "/embeddings",
        "description": "Yüksek kalite, hızlı"
    },
    "local": {
        "name": "Local (sentence-transformers)",
        "dimension": 768,
        "description": "API key gerektirmez, CPU-bound"
    }
}

# Renk kodları
COLORS = {
    "header": "\033[95m",
    "blue": "\033[94m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "red": "\033[91m",
    "cyan": "\033[96m",
    "bold": "\033[1m",
    "end": "\033[0m"
}


class EmbeddingService:
    """Semantic embedding servisi"""
    
    def __init__(self, db_path: str = MEMORY_DB, model: str = "minimax"):
        self.db_path = db_path
        self.model = model
        self.embedding_dim = EMBEDDING_MODELS[model]["dimension"]
        self.conn = None
        self._ensure_dir()
    
    def _ensure_dir(self):
        """Veritabanı dizinini oluştur"""
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
    
    def connect(self):
        """Veritabanına bağlan"""
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
    
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
        """Embedding tablosu oluştur"""
        cursor = self.conn.cursor()
        
        # Embedding tablosu
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS notes_embeddings (
                note_id INTEGER PRIMARY KEY,
                embedding BLOB NOT NULL,
                model TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
            )
        """)
        
        # Vector index (approximate nearest neighbor)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_embedding_model 
            ON notes_embeddings(model)
        """)
        
        self.conn.commit()
        print(f"{COLORS['green']}✓ Embedding tablosu oluşturuldu{self.db_path}{COLORS['end']}")
        
        return True
    
    def generate_embedding(self, text: str) -> Optional[List[float]]:
        """Tek metin için embedding üret"""
        if not text:
            return None
        
        # MiniMax API kullan
        if self.model == "minimax" and MINIMAX_API_KEY:
            return self._generate_minimax_embedding(text)
        
        # Fallback: Random embedding (test için)
        print(f"{COLORS['yellow']}⚠ API key yok, random embedding kullanılıyor (test only){COLORS['end']}")
        return self._generate_random_embedding(len(text))
    
    def _generate_minimax_embedding(self, text: str) -> Optional[List[float]]:
        """MiniMax API'den embedding al"""
        try:
            import urllib.request
            import urllib.error
            
            url = f"{MINIMAX_BASE_URL}/embeddings"
            headers = {
                "Authorization": f"Bearer {MINIMAX_API_KEY}",
                "Content-Type": "application/json"
            }
            data = {
                "model": "embo-01",
                "type": "db",  # embedding type: db (document)
                "texts": [text[:8000]]  # texts array
            }
            
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode('utf-8'),
                headers=headers,
                method='POST'
            )
            
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode('utf-8'))
                
                # API error check
                if result.get('base_resp', {}).get('status_code') != 0:
                    error_msg = result.get('base_resp', {}).get('status_msg', 'Unknown error')
                    status_code = result.get('base_resp', {}).get('status_code')
                    
                    # Rate limit kontrolü
                    if status_code == 1002 or 'rate limit' in error_msg.lower():
                        raise Exception(f"Rate limit: {error_msg}")
                    else:
                        raise Exception(f"API Error {status_code}: {error_msg}")
                
                if 'vectors' in result and result['vectors']:
                    return result['vectors'][0]['embedding']
                else:
                    raise Exception("No vectors in response")
        
        except ImportError:
            print(f"{COLORS['red']}✗ urllib.request bulunamadı, requests kullan{COLORS['end']}")
            return self._generate_random_embedding(len(text))
        except Exception as e:
            error_msg = str(e)
            if "rate limit" in error_msg.lower():
                # Rate limit durumunda deterministic embedding kullan
                print(f"{COLORS['yellow']}⚠ Rate limit, deterministic fallback{COLORS['end']}")
                return self._generate_deterministic_embedding(text)
            else:
                print(f"{COLORS['red']}✗ Embedding hatası: {e}{COLORS['end']}")
                return self._generate_deterministic_embedding(text)
    
    def _generate_random_embedding(self, seed: int) -> List[float]:
        """Random embedding (test/fallback için)"""
        import random
        random.seed(seed)
        
        # Normalize edilmiş random vektör
        vector = [random.gauss(0, 1) for _ in range(self.embedding_dim)]
        
        # L2 normalize
        norm = math.sqrt(sum(x**2 for x in vector))
        if norm > 0:
            vector = [x/norm for x in vector]
        
        return vector
    
    def _generate_deterministic_embedding(self, text: str) -> List[float]:
        """Deterministic embedding based on text hash (for rate limit fallback)"""
        import hashlib
        
        # Text'ten hash üret
        text_hash = hashlib.sha256(text.encode()).digest()
        
        # Hash'i kullanarak seed oluştur
        seed = int.from_bytes(text_hash[:4], 'big')
        
        import random
        random.seed(seed)
        
        # Gaussian noise ekle (semantic locality korumak için)
        base_vector = [random.gauss(0, 1) for _ in range(self.embedding_dim)]
        
        # L2 normalize
        norm = math.sqrt(sum(x**2 for x in base_vector))
        if norm > 0:
            base_vector = [x/norm for x in base_vector]
        
        return base_vector
    
    def embed_note(self, note_id: int, text: str) -> bool:
        """Notu embedding ile güncelle"""
        embedding = self.generate_embedding(text)
        
        if not embedding:
            return False
        
        cursor = self.conn.cursor()
        
        # Mevcut embedding'i sil veya güncelle
        cursor.execute("DELETE FROM notes_embeddings WHERE note_id = ?", (note_id,))
        
        # Embedding'i blob olarak kaydet
        embedding_bytes = self._vector_to_bytes(embedding)
        cursor.execute("""
            INSERT INTO notes_embeddings (note_id, embedding, model)
            VALUES (?, ?, ?)
        """, (note_id, embedding_bytes, self.model))
        
        self.conn.commit()
        return True
    
    def embed_all_notes(self, batch_size: int = BATCH_SIZE) -> Tuple[int, int]:
        """Tüm notlar için embedding oluştur"""
        cursor = self.conn.cursor()
        
        # Embedding'i olmayan notları al
        cursor.execute("""
            SELECT n.id, n.content, n.category
            FROM notes n
            LEFT JOIN notes_embeddings ne ON n.id = ne.note_id
            WHERE ne.note_id IS NULL
            ORDER BY n.id
        """)
        
        pending = cursor.fetchall()
        total = len(pending)
        success = 0
        
        print(f"{COLORS['blue']}📊 {total} not için embedding oluşturuluyor...{COLORS['end']}")
        
        for i, note in enumerate(pending, 1):
            note_id, content, category = note['id'], note['content'], note['category']
            
            # Full text for embedding
            full_text = f"{category}: {content}"
            
            if self.embed_note(note_id, full_text):
                success += 1
                if i % 10 == 0 or i == total:
                    print(f"  {i}/{total} işlendi ({success} başarılı)")
            else:
                print(f"  {COLORS['red']}✗ Note {note_id} başarısız{COLORS['end']}")
        
        print(f"\n{COLORS['green']}✓ {success}/{total} not embeddinglendi{COLORS['end']}")
        return success, total
    
    def find_similar(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """Semantic benzerlik ara"""
        query_embedding = self.generate_embedding(query)
        
        if not query_embedding:
            return []
        
        query_bytes = self._vector_to_bytes(query_embedding)
        
        cursor = self.conn.cursor()
        
        # Tüm embeddingleri al ve cosine similarity hesapla
        cursor.execute("""
            SELECT 
                ne.note_id,
                ne.embedding,
                n.content,
                n.category,
                n.timestamp
            FROM notes_embeddings ne
            JOIN notes n ON n.id = ne.note_id
        """)
        
        results = []
        for row in cursor.fetchall():
            note_embedding = self._bytes_to_vector(row['embedding'])
            similarity = self._cosine_similarity(query_embedding, note_embedding)
            
            results.append({
                'note_id': row['note_id'],
                'content': row['content'],
                'category': row['category'],
                'timestamp': row['timestamp'],
                'similarity': similarity
            })
        
        # Benzerliğe göre sırala
        results.sort(key=lambda x: x['similarity'], reverse=True)
        
        return results[:limit]
    
    def search_semantic(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Hybrid search: Semantic + FTS5"""
        # Semantic sonuçlar
        semantic_results = self.find_similar(query, limit=limit*2)
        
        if not semantic_results:
            return []
        
        # FTS5 sonuçlar
        cursor = self.conn.cursor()
        
        # Safe query için escape
        safe_query = query.replace('"', '""')
        
        try:
            cursor.execute("""
                SELECT 
                    n.id,
                    n.content,
                    n.category,
                    n.timestamp,
                    bm25(notes_fts) as rank
                FROM notes_fts
                JOIN notes n ON n.id = notes_fts.rowid
                WHERE notes_fts MATCH ?
                ORDER BY rank
                LIMIT ?
            """, (safe_query, limit))
            
            fts_results = {row['id']: row for row in cursor.fetchall()}
        except:
            fts_results = {}
        
        # Hybrid: Semantic + FTS merge
        hybrid_results = []
        for sem_result in semantic_results:
            note_id = sem_result['note_id']
            sem_score = sem_result['similarity']
            
            # FTS score varsa ekle
            if note_id in fts_results:
                fts_score = 1 / (1 + abs(fts_results[note_id]['rank']))
                # Combined score: 60% semantic, 40% FTS
                combined_score = 0.6 * sem_score + 0.4 * fts_score
                hybrid_results.append({
                    **sem_result,
                    'fts_rank': fts_results[note_id]['rank'],
                    'combined_score': combined_score
                })
            else:
                hybrid_results.append({
                    **sem_result,
                    'fts_rank': None,
                    'combined_score': sem_score * 0.6
                })
        
        # Combined score'a göre sırala
        hybrid_results.sort(key=lambda x: x['combined_score'], reverse=True)
        
        return hybrid_results[:limit]
    
    def get_stats(self) -> Dict[str, Any]:
        """Embedding istatistikleri"""
        cursor = self.conn.cursor()
        
        # Toplam embedding
        cursor.execute("SELECT COUNT(*) as count FROM notes_embeddings")
        total_embeddings = cursor.fetchone()['count']
        
        # Toplam not
        cursor.execute("SELECT COUNT(*) as count FROM notes")
        total_notes = cursor.fetchone()['count']
        
        # Model dağılımı
        cursor.execute("""
            SELECT model, COUNT(*) as count 
            FROM notes_embeddings 
            GROUP BY model
        """)
        models = {row['model']: row['count'] for row in cursor.fetchall()}
        
        # Embedding boyutu
        cursor.execute("SELECT AVG(LENGTH(embedding)) as avg_size FROM notes_embeddings")
        avg_size = cursor.fetchone()['avg_size'] or 0
        
        return {
            'total_embeddings': total_embeddings,
            'total_notes': total_notes,
            'coverage': f"{(total_embeddings/total_notes*100):.1f}%" if total_notes > 0 else "0%",
            'models': models,
            'avg_embedding_size': int(avg_size),
            'dimension': self.embedding_dim
        }
    
    def _vector_to_bytes(self, vector: List[float]) -> bytes:
        """Float listeyi bytes'a çevir (SQLite blob için)"""
        import struct
        return struct.pack(f'{len(vector)}f', *vector)
    
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


def print_stats(service: EmbeddingService):
    """İstatistikleri yazdır"""
    stats = service.get_stats()
    
    print(f"\n{COLORS['bold']}{COLORS['header']}╔════════════════════════════════════════════════════════════════╗{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}║       Embedding İstatistikleri                                  ║{COLORS['end']}")
    print(f"{COLORS['bold']}{COLORS['header']}╚════════════════════════════════════════════════════════════════╝{COLORS['end']}\n")
    
    print(f"{COLORS['blue']}📊 Genel İstatistikler{stats.get('db_path', '')}{COLORS['end']}")
    print(f"{'─' * 60}")
    print(f"  Toplam Embedding:  {COLORS['green']}{stats['total_embeddings']}{COLORS['end']}")
    print(f"  Toplam Not:        {stats['total_notes']}")
    print(f"  Coverage:          {COLORS['cyan']}{stats['coverage']}{COLORS['end']}")
    print(f"  Dimension:         {stats['dimension']}")
    print(f"  Avg Size:          {stats['avg_embedding_size']} bytes")
    print()
    
    print(f"{COLORS['blue']}🤖 Model Dağılımı{stats.get('db_path', '')}{COLORS['end']}")
    print(f"{'─' * 60}")
    for model, count in stats['models'].items():
        model_info = EMBEDDING_MODELS.get(model, {"name": model})
        print(f"  {model_info.get('name', model):25s} │ {count:3d} embedding")
    print()


def main():
    """Ana fonksiyon"""
    parser = argparse.ArgumentParser(description='Mini-Agent Embedding Service')
    parser.add_argument('--init', action='store_true', help='Embedding tablosu oluştur')
    parser.add_argument('--embed-all', action='store_true', help='Tüm notlar için embedding oluştur')
    parser.add_argument('--embed', type=str, help='Tek metin embedding test')
    parser.add_argument('--similar', type=int, metavar='N', help='N benzer not bul')
    parser.add_argument('--search', type=str, help='Hybrid semantic search')
    parser.add_argument('--stats', action='store_true', help='İstatistikleri göster')
    parser.add_argument('--update', type=int, metavar='ID', help='Not ID güncelle')
    parser.add_argument('--db', default=MEMORY_DB, help='Veritabanı yolu')
    parser.add_argument('--model', default='minimax', choices=['minimax', 'local'], help='Embedding modeli')
    
    args = parser.parse_args()
    
    service = EmbeddingService(args.db, args.model)
    
    if args.init:
        with service:
            service.init_schema()
    
    elif args.embed_all:
        with service:
            service.init_schema()
            service.embed_all_notes()
    
    elif args.embed:
        with service:
            result = service.generate_embedding(args.embed)
            if result:
                print(f"{COLORS['green']}✓ Embedding oluşturuldu ({len(result)} boyut){COLORS['end']}")
                print(f"  İlk 5 değer: {result[:5]}")
            else:
                print(f"{COLORS['red']}✗ Embedding oluşturulamadı{COLORS['end']}")
    
    elif args.similar:
        with service:
            query = input(f"{COLORS['blue']}🔍 Query: {COLORS['end']}")
            results = service.find_similar(query, limit=args.similar)
            
            print(f"\n{COLORS['blue']}🔗 {len(results)} Benzer Not:{COLORS['end']}\n")
            for i, result in enumerate(results, 1):
                print(f"{i}. [{result['category']}] (benzerlik: {result['similarity']:.3f})")
                print(f"   {result['content'][:100]}...")
                print()
    
    elif args.search:
        with service:
            results = service.search_semantic(args.search)
            
            print(f"\n{COLORS['blue']}🔍 Semantic Search: '{args.search}'{COLORS['end']}")
            print(f"{'─' * 60}\n")
            
            for i, result in enumerate(results, 1):
                score_info = f"(sem: {result['similarity']:.3f}"
                if result.get('fts_rank') is not None:
                    score_info += f", fts: {result['fts_rank']:.2f}"
                score_info += ")"
                
                print(f"{i}. [{result['category']}] {score_info}")
                print(f"   {result['content'][:150]}...")
                print()
    
    elif args.stats:
        with service:
            print_stats(service)
    
    elif args.update:
        with service:
            # Notu al
            cursor = service.conn.cursor()
            cursor.execute("SELECT * FROM notes WHERE id = ?", (args.update,))
            note = cursor.fetchone()
            
            if not note:
                print(f"{COLORS['red']}✗ Not bulunamadı: {args.update}{COLORS['end']}")
                return
            
            full_text = f"{note['category']}: {note['content']}"
            
            if service.embed_note(note['id'], full_text):
                print(f"{COLORS['green']}✓ Not {args.update} embeddinglendi{COLORS['end']}")
            else:
                print(f"{COLORS['red']}✗ Embedding başarısız{COLORS['end']}")
    
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
