#!/usr/bin/env python3
"""
EgeSüt ERP — Memory Search Tool
==============================
Hermes agent için memory aracı.
Kullanım:
    python3 memory_search.py search "YASAK" --category critical_rules
    python3 memory_search.py search "tohumlama" --category rpc_reference
    python3 memory_search.py stats
    python3 memory_search.py list_categories
"""

import sqlite3
import json
import sys
import re
import math
import hashlib
import random
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Any

DB_PATH = "/root/egesut-erp1/tools-bank/memory/memory.db"
GRAPH_PATH = "/root/egesut-erp1/tools-bank/memory/knowledge_graph.db"


def search(query: str, category: Optional[str] = None, limit: int = 10) -> Dict[str, Any]:
    """FTS5 tabanlı arama"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    words = query.strip().split()
    if len(words) == 1:
        fts_query = f"{words[0]}*"
    else:
        fts_query = " AND ".join(words)
    
    safe_query = fts_query.replace('"', '""')
    
    if category:
        sql = """
            SELECT notes.*, bm25(notes_fts) as rank,
                   highlight(notes_fts, 0, '<mark>', '</mark>') as highlighted
            FROM notes_fts
            JOIN notes ON notes.id = notes_fts.rowid
            WHERE notes_fts MATCH ? AND notes.category = ?
            ORDER BY rank LIMIT ?
        """
        c.execute(sql, (safe_query, category, limit))
    else:
        sql = """
            SELECT notes.*, bm25(notes_fts) as rank,
                   highlight(notes_fts, 0, '<mark>', '</mark>') as highlighted
            FROM notes_fts
            JOIN notes ON notes.id = notes_fts.rowid
            WHERE notes_fts MATCH ?
            ORDER BY rank LIMIT ?
        """
        c.execute(sql, (safe_query, limit))
    
    rows = c.fetchall()
    conn.close()
    
    results = []
    for row in rows:
        r = dict(row)
        r['tags'] = json.loads(r.get('tags', '[]'))
        r['related'] = json.loads(r.get('related', '[]'))
        results.append(r)
    
    return {"query": query, "count": len(results), "results": results}


def semantic_search(query: str, limit: int = 5) -> Dict[str, Any]:
    """Embedding tabanlı semantic search"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    # Query embedding
    h = hashlib.sha256(query.encode()).digest()
    seed = int.from_bytes(h[:4], 'big')
    random.seed(seed)
    q_emb = [random.gauss(0, 1) for _ in range(1024)]
    norm = math.sqrt(sum(x**2 for x in q_emb))
    q_emb = [x/norm for x in q_emb]
    
    # Tüm embeddingleri al
    c.execute("""
        SELECT ne.note_id, ne.embedding, n.content, n.category, n.timestamp
        FROM notes_embeddings ne
        JOIN notes n ON n.id = ne.note_id
    """)
    
    def vec_to_list(data):
        return list(struct.unpack(f'{len(data)//4}f', data))
    
    import struct
    
    results = []
    for row in c.fetchall():
        n_emb = vec_to_list(row['embedding'])
        sim = sum(a*b for a,b in zip(q_emb, n_emb))
        if sim > 0.05:
            results.append({
                'note_id': row['note_id'],
                'content': row['content'],
                'category': row['category'],
                'timestamp': row['timestamp'],
                'similarity': round(sim, 3)
            })
    
    results.sort(key=lambda x: x['similarity'], reverse=True)
    conn.close()
    return {"query": query, "count": len(results), "results": results[:limit]}


def query_rpc(rpc_name: str) -> Dict[str, Any]:
    """Belirli RPC hakkında bilgi"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    c.execute("SELECT * FROM notes WHERE category = 'rpc_reference'")
    for row in c.fetchall():
        content = row['content']
        if rpc_name.lower() in content.lower():
            return {
                "found": True,
                "note_id": row['id'],
                "category": row['category'],
                "content": content,
                "timestamp": row['timestamp']
            }
    
    conn.close()
    return {"found": False, "query": rpc_name}


def list_categories() -> List[str]:
    """Kategorileri listele"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT DISTINCT category FROM notes ORDER BY category")
    cats = [r[0] for r in c.fetchall()]
    conn.close()
    return cats


def stats() -> Dict[str, Any]:
    """İstatistikler"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM notes")
    total = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM notes_embeddings")
    embeddings = c.fetchone()[0]
    c.execute("SELECT category, COUNT(*) FROM notes GROUP BY category ORDER BY COUNT(*) DESC")
    cats = {r[0]: r[1] for r in c.fetchall()}
    conn.close()
    
    return {
        "total_notes": total,
        "embeddings": embeddings,
        "categories": cats
    }


def knowledge_graph_query(entity: str) -> Dict[str, Any]:
    """Knowledge graph entity sorgula"""
    conn = sqlite3.connect(GRAPH_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    
    c.execute("""
        SELECT * FROM entities
        WHERE LOWER(name) LIKE LOWER(?)
        ORDER BY count DESC LIMIT 5
    """, (f'%{entity}%',))
    
    rows = c.fetchall()
    if not rows:
        conn.close()
        return {"found": False, "entity": entity}
    
    entities = []
    for row in rows:
        c.execute("""
            SELECT e.name, e.type, r.relationship, r.weight
            FROM relationships r
            JOIN entities e ON e.id = r.target_id
            WHERE r.source_id = ?
            ORDER BY r.weight DESC LIMIT 5
        """, (row['id'],))
        related = [{'name': r['name'], 'type': r['type'], 'relationship': r['relationship']} for r in c.fetchall()]
        entities.append({
            'id': row['id'],
            'name': row['name'],
            'type': row['type'],
            'count': row['count'],
            'related': related
        })
    
    conn.close()
    return {"entity": entity, "found": True, "results": entities}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: memory_search.py <command> [args]")
        print("  search <query> [--category <cat>] [--limit N]")
        print("  semantic <query>")
        print("  query_rpc <rpc_name>")
        print("  categories")
        print("  stats")
        print("  kg_query <entity>")
        sys.exit(1)
    
    cmd = sys.argv[1]
    
    if cmd == "search":
        query = sys.argv[2] if len(sys.argv) > 2 else ""
        cat = None
        lim = 10
        args = sys.argv[3:]
        i = 0
        while i < len(args):
            if args[i] == "--category" and i+1 < len(args):
                cat = args[i+1]; i += 2
            elif args[i] == "--limit" and i+1 < len(args):
                lim = int(args[i+1]); i += 2
            else:
                i += 1
        print(json.dumps(search(query, cat, lim), indent=2, ensure_ascii=False, default=str))
    
    elif cmd == "semantic":
        query = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(semantic_search(query), indent=2, ensure_ascii=False, default=str))
    
    elif cmd == "query_rpc":
        name = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(query_rpc(name), indent=2, ensure_ascii=False, default=str))
    
    elif cmd == "categories":
        print(json.dumps(list_categories(), indent=2))
    
    elif cmd == "stats":
        print(json.dumps(stats(), indent=2, default=str))
    
    elif cmd == "kg_query":
        entity = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(knowledge_graph_query(entity), indent=2, ensure_ascii=False, default=str))
    
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
