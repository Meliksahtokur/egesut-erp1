#!/usr/bin/env python3
"""
Memory search tool — FTS5 + category filter + priority boost.
Usage:
  python3 search_tool.py --query "rpc hayvan" [--category rpc_reference] [--limit 10] [--json]
  python3 search_tool.py --add --content "not icerigi" [--category general] [--priority high] [--tags "rpc,kritik"]
"""

import sqlite3
import argparse
import json
import os
import sys

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory.db")


def search(query, category=None, limit=10, json_output=False, include_obsolete=False):
    """FTS5 search with optional category filter, priority boost, and obsolete filter."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    # Check if DB has data
    count = c.execute("SELECT COUNT(*) FROM memory_notes").fetchone()[0]
    if count == 0:
        conn.close()
        msg = json.dumps({"results": [], "total": 0, "message": "Memory DB is empty. Add notes first."})
        if json_output:
            print(msg)
        else:
            print("Memory DB is empty. Add notes first.")
        return

    # FTS5 search — escape FTS special chars
    safe_query = query.replace('"', '""')
    fts_query = f'"{safe_query}"'

    sql = """
        SELECT n.id, n.content, n.category, n.priority, n.tags, n.source, n.created_at,
               rank as relevance
        FROM memory_notes_fts
        JOIN memory_notes n ON n.id = memory_notes_fts.rowid
        WHERE memory_notes_fts MATCH ?
    """
    params = [fts_query]

    if not include_obsolete:
        sql += " AND n.obsolete = 0"

    if category:
        sql += " AND n.category = ?"
        params.append(category)

    sql += " ORDER BY CASE n.priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END, rank LIMIT ?"
    params.append(limit)

    try:
        rows = c.execute(sql, params).fetchall()
    except sqlite3.OperationalError as e:
        # FTS5 syntax error — fallback to LIKE
        like_q = f"%{query}%"
        sql_like = """
            SELECT n.id, n.content, n.category, n.priority, n.tags, n.source, n.created_at,
                   0.5 as relevance
            FROM memory_notes n
            WHERE n.content LIKE ?
        """
        like_params = [like_q]
        if not include_obsolete:
            sql_like += " AND n.obsolete = 0"
        if category:
            sql_like += " AND n.category = ?"
            like_params.append(category)
        sql_like += " ORDER BY CASE n.priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END LIMIT ?"
        like_params.append(limit)
        rows = c.execute(sql_like, like_params).fetchall()

    results = []
    for r in rows:
        results.append({
            "id": r["id"],
            "content": r["content"],
            "category": r["category"],
            "priority": r["priority"],
            "tags": r["tags"].split(",") if r["tags"] else [],
            "source": r["source"],
            "created_at": r["created_at"],
            "relevance": round(r["relevance"], 4),
        })

    conn.close()

    output = {"results": results, "total": len(results)}
    if json_output:
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        if not results:
            print(f"No results for '{query}'.")
            return
        print(f"Found {len(results)} result(s) for '{query}':\n")
        for r in results:
            prio = {"high": "🔴", "medium": "🟡", "low": "⚪"}.get(r["priority"], "⚪")
            preview = r["content"][:150] + "..." if len(r["content"]) > 150 else r["content"]
            src = r.get("source", "?")
            dt = r.get("created_at", "?")
            print(f"  [{r['id']}] {prio} {r['category']} (src:{src}, {dt[:10]})")
            print(f"       {preview}")
            print()


def add_note(content, category="general", priority="medium", tags="", source="manual"):
    """Add a new note to memory + auto-embed via Jina AI."""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute(
        "INSERT INTO memory_notes (content, category, priority, tags, source) VALUES (?, ?, ?, ?, ?)",
        (content, category, priority, tags, source)
    )
    note_id = c.lastrowid
    conn.commit()

    # Auto-embed via Jina AI
    try:
        _auto_embed(conn, note_id, content)
    except Exception as e:
        # Log but don't fail — FTS5 still works without embedding
        print(f"  Warning: embedding failed: {e}", file=sys.stderr)

    conn.close()
    return note_id


def _auto_embed(conn, note_id, content):
    """Create embedding for a single note via Jina AI."""
    import urllib.request, json, struct

    payload = json.dumps({
        "model": "jina-embeddings-v3",
        "task": "retrieval.query",
        "normalized": True,
        "input": [content]
    }).encode("utf-8")

    req = urllib.request.Request(
        "https://api.jina.ai/v1/embeddings",
        data=payload,
        headers={
            "Authorization": "Bearer jina_a9b0ff962ff94ee98f9d7f8d4f7feee9_-qMCCMAbTSnJHf6m7vOaCGbloC0",
            "Content-Type": "application/json",
            "User-Agent": "curl/8.0",
        },
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        vec = data["data"][0]["embedding"]

    blob = struct.pack(f"<{len(vec)}d", *vec)
    c = conn.cursor()
    c.execute(
        "INSERT OR REPLACE INTO memory_embeddings (note_id, embedding) VALUES (?, ?)",
        (note_id, blob)
    )
    conn.commit()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Tools-Bank Memory Search")
    parser.add_argument("--query", "-q", help="Search query")
    parser.add_argument("--category", "-c", help="Category filter")
    parser.add_argument("--limit", "-l", type=int, default=10, help="Max results")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument("--include-obsolete", action="store_true", help="Include obsolete notes (hidden by default)")
    parser.add_argument("--add", action="store_true", help="Add a new note")
    parser.add_argument("--content", help="Note content (for --add)")
    parser.add_argument("--priority", choices=["high", "medium", "low"], default="medium", help="Priority")
    parser.add_argument("--tags", default="", help="Comma-separated tags")
    parser.add_argument("--source", default="manual", help="Source identifier")
    parser.add_argument("--db", help="Override DB path")

    args = parser.parse_args()
    if args.db:
        DB_PATH = args.db

    if args.add:
        if not args.content:
            print("Error: --content required with --add")
            sys.exit(1)
        note_id = add_note(args.content, args.category or "general", args.priority, args.tags, args.source)
        print(json.dumps({"id": note_id, "status": "created"}))
    elif args.query:
        search(args.query, args.category, args.limit, args.json, args.include_obsolete)
    else:
        parser.print_help()
