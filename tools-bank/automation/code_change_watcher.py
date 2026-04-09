#!/usr/bin/env python3
"""
Code Change → Memory + Vector Pipeline
======================================
EgeSüt ERP kodunda değişiklik olduğunda otomatik olarak:
1. Git diff/commit bilgisini çıkar
2. Yeni not oluştur (memory.db)
3. Embedding oluştur (notes_embeddings)
4. Entity extraction (knowledge_graph.db)

Kullanım:
    python3 code_change_watcher.py --daemon      # Arka planda izle
    python3 code_change_watcher.py --once        # Bir kere kontrol et
    python3 code_change_watcher.py --init        # Schema oluştur
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

# DB paths
TOOLSBANK_ROOT = Path("/root/egesut-erp1/tools-bank")
MEMORY_DB = TOOLSBANK_ROOT / "memory/memory.db"
KG_DB = TOOLSBANK_ROOT / "memory/knowledge_graph.db"
REPO_ROOT = Path("/root/egesut-erp1")

# Import services
sys.path.insert(0, str(TOOLSBANK_ROOT))
from memory.embedding_service import EmbeddingService
from memory.knowledge_graph import KnowledgeGraph


def run_cmd(cmd: list, cwd=None) -> tuple[str, str, int]:
    """Run shell command, return stdout, stderr, returncode"""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True,
            cwd=cwd or REPO_ROOT, timeout=30
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "timeout", 1
    except Exception as e:
        return "", str(e), 1


def get_git_changes() -> Optional[dict]:
    """Git'ten son değişiklikleri al"""
    # Check if git repo
    stdout, _, rc = run_cmd(["git", "rev-parse", "--git-dir"])
    if rc != 0:
        return None

    # Last commit info
    commit_msg, _, _ = run_cmd(["git", "log", "-1", "--format=%s"])
    commit_hash, _, _ = run_cmd(["git", "log", "-1", "--format=%H"])
    commit_author, _, _ = run_cmd(["git", "log", "-1", "--format=%an"])
    commit_date, _, _ = run_cmd(["git", "log", "-1", "--format=%ci"])

    # Changed files (staged + unstaged)
    stdout, _, _ = run_cmd(["git", "diff", "--name-only"])
    changed_files = [f for f in stdout.split("\n") if f.strip()]

    # Filter: sadece proje dosyaları
    EXCLUDE_DIRS = {".temp", "node_modules", ".git", "skills", "agents", "mcps", "workflows", "examples", "docs"}
    changed_files = [
        f for f in changed_files
        if not any(f"/{d}/" in f or f.startswith(d) or f.startswith(f"{d}/") for d in EXCLUDE_DIRS)
    ]

    stdout, _, _ = run_cmd(["git", "diff", "--cached", "--name-only"])
    staged_files = [f for f in stdout.split("\n") if f.strip()]

    EXCLUDE_DIRS = {".temp", "node_modules", ".git", "skills", "agents", "mcps", "workflows", "examples", "docs"}
    staged_files = [
        f for f in staged_files
        if not any(f"/{d}/" in f or f.startswith(d) or f.startswith(f"{d}/") for d in EXCLUDE_DIRS)
    ]

    # Diff stats
    diff_stats, _, _ = run_cmd(["git", "diff", "--stat"])
    diff_lines, _, _ = run_cmd(["git", "diff", "--unified=3"])

    return {
        "hash": commit_hash[:8],
        "message": commit_msg,
        "author": commit_author,
        "date": commit_date,
        "changed_files": changed_files,
        "staged_files": staged_files,
        "diff_stats": diff_stats,
        "diff_lines": diff_lines[:2000],  # Limit diff size
    }


def get_code_summary(file_path: str, diff_lines: str) -> str:
    """Değişiklikten anlamlı özet çıkar"""
    filename = os.path.basename(file_path)
    ext = os.path.splitext(filename)[1]

    # Language hint
    lang_map = {".js": "JavaScript", ".py": "Python", ".sql": "SQL", ".md": "Markdown"}
    lang = lang_map.get(ext, ext)

    # Extract function names from diff
    funcs = re.findall(r'(?:function|def|const|let|var)\s+(\w+)', diff_lines)
    funcs = list(set(funcs))[:10]  # Top 10

    # Extract added/removed lines count
    added = len([l for l in diff_lines.split("\n") if l.startswith("+") and not l.startswith("+++")])
    removed = len([l for l in diff_lines.split("\n") if l.startswith("-") and not l.startswith("---")])

    summary = f"[{lang}] {filename}"
    if funcs:
        summary += f" — funcs: {', '.join(funcs)}"
    summary += f" (+{added}/-{removed} lines)"

    return summary


def detect_change_type(file_path: str, diff_lines: str) -> str:
    """Değişiklik türünü tespit et"""
    filename = os.path.basename(file_path)

    if "migration" in file_path.lower() or filename.endswith(".sql"):
        return "migration"
    if any(x in filename for x in ["bug", "fix", "hotfix"]):
        return "bugfix"
    if any(x in file_path for x in ["ureme", "kizginlik", "tohumlama", "gebe"]):
        return "domain_ureme"
    if any(x in file_path for x in ["api", "forms", "state"]):
        return "core_logic"
    if any(x in file_path for x in ["ui", "modal", "render"]):
        return "ui"
    if "test" in file_path.lower() or filename.startswith("test"):
        return "test"
    if filename.endswith(".md"):
        return "docs"
    return "general"


def add_memory_note(
    title: str,
    content: str,
    category: str = "code_change",
    tags: list = None,
    priority: str = "medium"
) -> Optional[int]:
    """memory.db'ye yeni not ekle, embedding oluştur"""
    import sqlite3
    from datetime import datetime

    if tags is None:
        tags = []

    now = datetime.now().isoformat()

    try:
        conn = sqlite3.connect(str(MEMORY_DB))
        cur = conn.cursor()

        # Insert note
        cur.execute("""
            INSERT INTO notes (timestamp, category, content, priority, tags, source, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (now, category, content, priority, json.dumps(tags), "automation", now))

        note_id = cur.lastrowid
        conn.commit()
        conn.close()

        # Generate embedding
        try:
            svc = EmbeddingService(db_path=str(MEMORY_DB))
            svc.connect()
            svc.embed_note(note_id, content)
            svc.close()
        except Exception as e:
            print(f"  ⚠ Embedding error: {e}")

        # Extract entities to knowledge graph
        try:
            kg = KnowledgeGraph(graph_db=str(KG_DB))
            kg.connect()
            kg.extract_entities(content, note_id)
            kg.close()
        except Exception as e:
            print(f"  ⚠ KG extraction error: {e}")

        return note_id

    except Exception as e:
        print(f"  ✗ DB error: {e}")
        return None


def process_changes(changes: dict) -> list:
    """Değişiklikleri işle, not oluştur"""
    if not changes or not changes.get("hash"):
        return []

    note_ids = []
    commit_hash = changes["hash"]
    commit_msg = changes["message"]
    changed_files = changes.get("changed_files", [])

    # Main commit note
    files_str = ", ".join(changed_files[:10])
    if len(changed_files) > 10:
        files_str += f" (+{len(changed_files) - 10} more)"

    content = f"""Git Commit: {commit_hash}
Mesaj: {commit_msg}
Yazar: {changes['author']}
Tarih: {changes['date']}

Değişen dosyalar:
{files_str}

Diff özeti:
{changes['diff_stats']}
"""

    note_id = add_memory_note(
        title=f"commit: {commit_hash} — {commit_msg[:60]}",
        content=content,
        category="code_change",
        tags=["git", "commit", commit_hash, *changed_files[:5]],
        priority="medium"
    )
    if note_id:
        note_ids.append(note_id)

    # Per-file notes for important files
    important_exts = {".js", ".py", ".sql"}
    for f in changed_files:
        ext = os.path.splitext(f)[1]
        if ext not in important_exts:
            continue

        # Get per-file diff
        stdout, _, rc = run_cmd(["git", "diff", "--", f])
        if not stdout or rc != 0:
            continue

        change_type = detect_change_type(f, stdout)
        summary = get_code_summary(f, stdout)

        file_content = f"""Dosya: {f}
Tür: {change_type}
Commit: {commit_hash} — {commit_msg}

Değişiklik:
{stdout[:1500]}
"""

        fid = add_memory_note(
            title=summary,
            content=file_content,
            category=change_type,
            tags=["git", "file", f, change_type],
            priority="high" if change_type in ("migration", "bugfix") else "medium"
        )
        if fid:
            note_ids.append(fid)

    return note_ids


def check_once() -> int:
    """Bir kere kontrol et, değişiklik varsa işle"""
    changes = get_git_changes()
    if not changes:
        print("Not a git repo or no changes")
        return 0

    print(f"Commit: {changes['hash']} — {changes['message']}")
    print(f"Files: {', '.join(changes['changed_files'][:5])}")

    note_ids = process_changes(changes)
    print(f"Created {len(note_ids)} note(s)")
    return len(note_ids)


def run_daemon(poll_interval: int = 30):
    """ Sürekli git değişikliği izle """
    print(f"👁  Code watcher running (poll every {poll_interval}s)")
    print(f"   Repo: {REPO_ROOT}")
    print(f"   Memory DB: {MEMORY_DB}")
    print(f"   KG DB: {KG_DB}")

    last_hash = None

    while True:
        try:
            changes = get_git_changes()
            if changes and changes.get("hash") and changes["hash"] != last_hash:
                if last_hash is not None:  # Skip first run
                    print(f"\n🔔 New commit: {changes['hash']} — {changes['message']}")
                    note_ids = process_changes(changes)
                    print(f"   → {len(note_ids)} note(s) created")
                last_hash = changes["hash"]

        except KeyboardInterrupt:
            print("\n👋 Watcher stopped")
            break
        except Exception as e:
            print(f"  ⚠ Error: {e}")

        time.sleep(poll_interval)


def init_schema():
    """Embedding ve KG tablolarını başlat"""
    print("Initializing schemas...")

    try:
        svc = EmbeddingService(db_path=str(MEMORY_DB))
        svc.connect()
        svc.init_schema()
        print(f"  ✅ Embedding schema ready ({MEMORY_DB})")
        svc.close()
    except Exception as e:
        print(f"  ✗ Embedding init error: {e}")

    try:
        kg = KnowledgeGraph(kg_db_path=str(KG_DB))
        kg.connect()
        kg.init_schema()
        print(f"  ✅ KG schema ready ({KG_DB})")
        kg.close()
    except Exception as e:
        print(f"  ✗ KG init error: {e}")


def main():
    parser = argparse.ArgumentParser(description="Code change → Memory pipeline")
    parser.add_argument("--daemon", action="store_true", help="Run as background watcher")
    parser.add_argument("--once", action="store_true", help="Check once and exit")
    parser.add_argument("--init", action="store_true", help="Initialize schemas")
    parser.add_argument("--poll", type=int, default=30, help="Poll interval in seconds")
    args = parser.parse_args()

    if args.init:
        init_schema()
        return

    if args.daemon:
        run_daemon(args.poll)
    elif args.once:
        check_once()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
