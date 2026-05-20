#!/usr/bin/env python3
"""
Jina AI embedding service — jina-embeddings-v3.
Stores embeddings in SQLite, uses cosine similarity at search time.
~100ms per API call, ~1sn for 10 notes.

Usage:
  python3 embedding_service.py --rebuild        # Rebuild all embeddings
  python3 embedding_service.py --search "query"  # Semantic search
  python3 embedding_service.py --stats           # DB statistics
"""

import sqlite3
import json
import os
import sys
import struct
import math
import urllib.request, urllib.error

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory.db")
JINA_API_KEY = "jina_a9b0ff962ff94ee98f9d7f8d4f7feee9_-qMCCMAbTSnJHf6m7vOaCGbloC0"
JINA_URL = "https://api.jina.ai/v1/embeddings"
DIMENSION = 1024  # jina-embeddings-v3 output


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def ensure_embeddings_table():
    conn = get_conn()
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS memory_embeddings (
            note_id INTEGER PRIMARY KEY,
            embedding BLOB NOT NULL,
            updated_at TEXT NOT NULL DEFAULT (datetime('now')),
            FOREIGN KEY (note_id) REFERENCES memory_notes(id) ON DELETE CASCADE
        )
    """)
    conn.commit()
    conn.close()


def get_embeddings(texts):
    """Call Jina AI embedding API."""
    if isinstance(texts, str):
        texts = [texts]

    payload = json.dumps({
        "model": "jina-embeddings-v3",
        "task": "retrieval.query",
        "normalized": True,
        "input": texts
    }).encode("utf-8")

    req = urllib.request.Request(
        JINA_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {JINA_API_KEY}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0",
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            if "data" in data and len(data["data"]) > 0:
                return [item["embedding"] for item in data["data"]]
            raise Exception(f"Unexpected response: {str(data)[:200]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        raise Exception(f"Jina API error ({e.code}): {body[:200]}")
    except Exception as e:
        raise Exception(f"Jina embedding error: {str(e)}")


def float_list_to_blob(floats):
    return struct.pack(f"<{len(floats)}d", *floats)


def blob_to_float_list(blob):
    count = len(blob) // 8
    return list(struct.unpack(f"<{count}d", blob))


def cosine_similarity(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)


def rebuild_embeddings():
    """Rebuild all embeddings via Jina AI API."""
    ensure_embeddings_table()
    conn = get_conn()
    c = conn.cursor()

    notes = c.execute("SELECT id, content FROM memory_notes ORDER BY id").fetchall()
    if not notes:
        print("No notes to embed.")
        conn.close()
        return

    total = len(notes)
    print(f"Rebuilding embeddings for {total} notes via Jina AI...")

    c.execute("DELETE FROM memory_embeddings")
    conn.commit()

    texts = [n["content"] for n in notes]
    vectors = get_embeddings(texts)

    for n, vec in zip(notes, vectors):
        blob = float_list_to_blob(vec)
        c.execute(
            "INSERT OR REPLACE INTO memory_embeddings (note_id, embedding) VALUES (?, ?)",
            (n["id"], blob)
        )
    conn.commit()
    conn.close()
    print(f"Done: {total} notes embedded.")


def semantic_search(query, limit=10):
    """Search by embedding cosine similarity."""
    ensure_embeddings_table()
    conn = get_conn()
    c = conn.cursor()

    embed_count = c.execute("SELECT COUNT(*) FROM memory_embeddings").fetchone()[0]
    if embed_count == 0:
        conn.close()
        return {"results": [], "total": 0, "message": "No embeddings. Run --rebuild first."}

    query_vec = get_embeddings(query)[0]

    rows = c.execute("""
        SELECT e.note_id, e.embedding, n.content, n.category, n.priority, n.tags
        FROM memory_embeddings e
        JOIN memory_notes n ON n.id = e.note_id
    """).fetchall()

    scored = []
    for r in rows:
        vec = blob_to_float_list(r["embedding"])
        sim = cosine_similarity(query_vec, vec)
        scored.append((sim, r))

    scored.sort(key=lambda x: (
        {"high": 0, "medium": 1, "low": 2}.get(x[1]["priority"], 3),
        -x[0]
    ))

    results = []
    for sim, r in scored[:limit]:
        results.append({
            "id": r["note_id"],
            "content": r["content"],
            "category": r["category"],
            "priority": r["priority"],
            "tags": r["tags"].split(",") if r["tags"] else [],
            "similarity": round(sim, 4),
        })

    conn.close()
    return {"results": results, "total": len(results)}


def stats():
    conn = get_conn()
    c = conn.cursor()
    note_count = c.execute("SELECT COUNT(*) FROM memory_notes").fetchone()[0]
    embed_count = c.execute("SELECT COUNT(*) FROM memory_embeddings").fetchone()[0]
    cats = c.execute(
        "SELECT category, COUNT(*) as cnt FROM memory_notes GROUP BY category ORDER BY cnt DESC"
    ).fetchall()

    print(f"Notes:      {note_count}")
    print(f"Embeddings: {embed_count} (Jina AI, 1024-dim)")
    print(f"Categories:")
    for r in cats:
        print(f"  {r['category']}: {r['cnt']}")
    conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == "--rebuild":
        rebuild_embeddings()
    elif sys.argv[1] == "--search":
        query = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
        if not query:
            print("Usage: python3 embedding_service.py --search <query>")
            sys.exit(1)
        result = semantic_search(query, 10)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif sys.argv[1] == "--stats":
        stats()
    else:
        print(f"Unknown flag: {sys.argv[1]}")
        sys.exit(1)
