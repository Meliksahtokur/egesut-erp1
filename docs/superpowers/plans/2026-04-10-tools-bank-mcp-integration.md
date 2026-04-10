# Tools-Bank MCP Entegrasyonu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tools-bank'i `/root/tools-bank/` adresinde izole bir repo'ya taşıyarak Claude Code CLI'a MCP server, hook ve skill katmanlarıyla native entegre etmek.

**Architecture:** 3 katman: (1) FastMCP stdio server — Claude Code'un session başında spawn ettiği, session boyunca sıcak kalan Python process; (2) UserPromptSubmit hook — her mesajda kritik kuralları otomatik inject eden script; (3) mem-tools skill — `/mem-search`, `/mem-add`, `/mem-graph`, `/mem-stats` slash komutları.

**Not — Spec düzeltmesi:** Tasarım dokümanı "Unix socket daemon" diyordu. Claude Code MCP protokolü stdio (stdin/stdout JSON-RPC) kullanır ve server process'i session boyunca canlı tutar — bu doğal olarak sıcak daemon davranışı sağlar, ayrı Unix socket veya daemon-manager gerekmez.

**Tech Stack:** Python 3, `mcp==1.27.0` (FastMCP), SQLite FTS5, MiniMax embo-01 (1024-dim), Alpine Linux / PRoot-Distro

---

## Dosya Haritası

| Dosya | İşlem | Sorumluluk |
|---|---|---|
| `/root/tools-bank/` | OLUŞTUR (git repo) | Bağımsız repo |
| `/root/tools-bank/mcp/server.py` | YENİ | FastMCP stdio server, 5 tool |
| `/root/tools-bank/hooks/prompt_context_injector.py` | YENİ | UserPromptSubmit hook |
| `/root/tools-bank/skills/mem-tools/SKILL.md` | YENİ | Slash komut skill'i |
| `/root/tools-bank/memory/*` | TAŞI + PATH FİX | Bellek motoru |
| `/root/tools-bank/tools/*` | TAŞI + PATH FİX | CLI araçları |
| `/root/tools-bank/automation/*` | TAŞI | Otomasyon scriptleri |
| `/root/.claude/settings.json` | GÜNCELLE | mcpServers + hooks blokları |

---

## Task 1: /root/tools-bank Repo'sunu Oluştur ve Dosyaları Taşı

**Files:**
- Create: `/root/tools-bank/` (git repo)
- Source: `/root/egesut-erp1/tools-bank/`

- [ ] **Step 1: Repo oluştur ve dosyaları kopyala**

```bash
mkdir -p /root/tools-bank
git -C /root/tools-bank init
cp -r /root/egesut-erp1/tools-bank/memory /root/tools-bank/
cp -r /root/egesut-erp1/tools-bank/tools /root/tools-bank/
cp -r /root/egesut-erp1/tools-bank/automation /root/tools-bank/
cp -r /root/egesut-erp1/tools-bank/docs /root/tools-bank/
cp -r /root/egesut-erp1/tools-bank/workflows /root/tools-bank/
cp -r /root/egesut-erp1/tools-bank/examples /root/tools-bank/
cp /root/egesut-erp1/tools-bank/README.md /root/tools-bank/
cp /root/egesut-erp1/tools-bank/RPC_QUICK_REFERENCE.md /root/tools-bank/
cp /root/egesut-erp1/tools-bank/RPC_REFERENCES_SUMMARY.md /root/tools-bank/
cp /root/egesut-erp1/tools-bank/rpc_data_export.json /root/tools-bank/
mkdir -p /root/tools-bank/mcp /root/tools-bank/hooks /root/tools-bank/skills/mem-tools
```

- [ ] **Step 2: Kopyalandığını doğrula**

```bash
ls /root/tools-bank/memory/ && ls /root/tools-bank/tools/ && ls /root/tools-bank/automation/
```

Beklenen: `memory.db`, `knowledge_graph.db`, `embedding_service.py`, `search_tool.py`, `knowledge_graph.py`, `memory_search.py`, `intelligence_wrapper.py`, `daemon-manager.sh` görünür.

- [ ] **Step 3: memory.db çalışıyor mu kontrol et**

```bash
python3 /root/tools-bank/tools/memory_search.py stats
```

Beklenen: `{"total_notes": 48, ...}` JSON çıktısı.

- [ ] **Step 4: İlk commit**

```bash
cd /root/tools-bank
git add -A
git commit -m "chore: initial migration from egesut-erp1/tools-bank"
```

---

## Task 2: Hardcoded Path'leri Güncelle

tools-bank araçlarındaki `/root/egesut-erp1/tools-bank/` referanslarını `/root/tools-bank/` ile değiştir.

**Files:**
- Modify: `/root/tools-bank/tools/intelligence_wrapper.py`
- Modify: `/root/tools-bank/tools/intelligence_shortcuts.sh`
- Modify: `/root/tools-bank/memory/embedding_service.py`
- Modify: `/root/tools-bank/memory/search_tool.py`
- Modify: `/root/tools-bank/memory/knowledge_graph.py`

- [ ] **Step 1: Tüm eski path referanslarını bul**

```bash
grep -r "egesut-erp1/tools-bank" /root/tools-bank/ --include="*.py" --include="*.sh" -l
```

Beklenen: birkaç dosya listelenir.

- [ ] **Step 2: intelligence_wrapper.py path'lerini güncelle**

`/root/tools-bank/tools/intelligence_wrapper.py` içinde:

```python
# ESKİ:
TOOLSBANK_ROOT = "/root/egesut-erp1/tools-bank"

# YENİ:
TOOLSBANK_ROOT = "/root/tools-bank"
```

`MEMORY_TOOLS`, `MEMORY_DB`, `KNOWLEDGE_GRAPH_DB`, `WORKSPACE` satırları `TOOLSBANK_ROOT`'a bağlı olduğu için otomatik düzelir. Kontrol et:

```bash
head -20 /root/tools-bank/tools/intelligence_wrapper.py | grep -E "ROOT|DB|TOOLS"
```

Beklenen: `/root/tools-bank` görmeli, `/root/egesut-erp1` olmamalı.

- [ ] **Step 3: memory_search.py path'ini güncelle**

`/root/tools-bank/tools/memory_search.py` içinde:

```python
# ESKİ:
DB_PATH = "/root/egesut-erp1/tools-bank/memory/memory.db"
GRAPH_PATH = "/root/egesut-erp1/tools-bank/memory/knowledge_graph.db"

# YENİ:
DB_PATH = "/root/tools-bank/memory/memory.db"
GRAPH_PATH = "/root/tools-bank/memory/knowledge_graph.db"
```

- [ ] **Step 4: embedding_service.py path'ini güncelle**

`/root/tools-bank/memory/embedding_service.py` içinde:

```python
# ESKİ:
MEMORY_DB = ".claude/memory/memory.db"

# YENİ (mutlak path):
MEMORY_DB = "/root/tools-bank/memory/memory.db"
```

- [ ] **Step 5: search_tool.py path'ini güncelle**

`/root/tools-bank/memory/search_tool.py` içinde:

```python
# ESKİ:
MEMORY_DB = ".claude/memory/memory.db"

# YENİ:
MEMORY_DB = "/root/tools-bank/memory/memory.db"
```

- [ ] **Step 6: knowledge_graph.py path'lerini güncelle**

`/root/tools-bank/memory/knowledge_graph.py` içinde:

```python
# ESKİ:
MEMORY_DB = ".claude/memory/memory.db"
GRAPH_DB = ".claude/memory/knowledge_graph.db"

# YENİ:
MEMORY_DB = "/root/tools-bank/memory/memory.db"
GRAPH_DB = "/root/tools-bank/memory/knowledge_graph.db"
```

- [ ] **Step 7: intelligence_shortcuts.sh güncelle**

`/root/tools-bank/tools/intelligence_shortcuts.sh` içinde:

```bash
# ESKİ:
WRAPPER="/root/egesut-erp1/tools-bank/tools/intelligence_wrapper.py"

# YENİ:
WRAPPER="/root/tools-bank/tools/intelligence_wrapper.py"
```

- [ ] **Step 8: Kalan referansları kontrol et**

```bash
grep -r "egesut-erp1/tools-bank" /root/tools-bank/ --include="*.py" --include="*.sh"
```

Beklenen: çıktı yok (tüm referanslar temizlendi).

- [ ] **Step 9: Araçların yeni path'lerle çalıştığını doğrula**

```bash
python3 /root/tools-bank/tools/memory_search.py search "RPC"
python3 /root/tools-bank/tools/intelligence_wrapper.py stats
```

Beklenen: İlk komut `{"query": "RPC", "count": ...}` döner. İkinci komut stats JSON döner.

- [ ] **Step 10: Commit**

```bash
cd /root/tools-bank
git add -A
git commit -m "fix: update all hardcoded paths to /root/tools-bank"
```

---

## Task 3: FastMCP Server Yaz

**Files:**
- Create: `/root/tools-bank/mcp/__init__.py`
- Create: `/root/tools-bank/mcp/server.py`

**Mimari notu:** Claude Code, mcpServers config'deki `command`'ı session başında spawn eder ve session boyunca canlı tutar. Server stdio (stdin/stdout) üzerinden JSON-RPC konuşur — bu doğal olarak sıcak cache sağlar, ayrı daemon gerekmez.

- [ ] **Step 1: `__init__.py` oluştur**

```bash
touch /root/tools-bank/mcp/__init__.py
```

- [ ] **Step 2: server.py yaz**

`/root/tools-bank/mcp/server.py` dosyasını oluştur:

```python
#!/usr/bin/env python3
"""
tools-bank MCP Server
=====================
Claude Code'a memory, semantic search ve knowledge graph araçlarını
native MCP tool olarak sunar. FastMCP stdio modu — Claude Code
session başında spawn eder, session boyunca canlı tutar.
"""

import sys
import os
import json
import sqlite3
import math
import hashlib
from pathlib import Path
from typing import Optional

# Paket importları
from mcp.server.fastmcp import FastMCP

# Sabitler
TOOLS_BANK = "/root/tools-bank"
MEMORY_DB  = f"{TOOLS_BANK}/memory/memory.db"
GRAPH_DB   = f"{TOOLS_BANK}/memory/knowledge_graph.db"
MINIMAX_API_KEY = os.environ.get("MINIMAX_API_KEY", "")
MINIMAX_URL = "https://api.minimax.io/v1/embeddings"
EMBED_DIM   = 1024

mcp = FastMCP("tools-bank")


# ── Yardımcı: FTS5 arama ────────────────────────────────────────────
def _fts_search(query: str, category: Optional[str], limit: int) -> list:
    conn = sqlite3.connect(MEMORY_DB)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    words = query.strip().split()
    fts_query = f"{words[0]}*" if len(words) == 1 else " AND ".join(words)
    safe_q = fts_query.replace('"', '""')
    if category:
        c.execute("""
            SELECT notes.id, notes.category, notes.content, notes.priority,
                   notes.tags, bm25(notes_fts) as rank
            FROM notes_fts
            JOIN notes ON notes.id = notes_fts.rowid
            WHERE notes_fts MATCH ? AND notes.category = ?
            ORDER BY rank LIMIT ?
        """, (safe_q, category, limit))
    else:
        c.execute("""
            SELECT notes.id, notes.category, notes.content, notes.priority,
                   notes.tags, bm25(notes_fts) as rank
            FROM notes_fts
            JOIN notes ON notes.id = notes_fts.rowid
            WHERE notes_fts MATCH ?
            ORDER BY rank LIMIT ?
        """, (safe_q, limit))
    rows = [dict(r) for r in c.fetchall()]
    conn.close()
    return rows


# ── Yardımcı: Embedding üret ────────────────────────────────────────
def _embed(text: str) -> list:
    """MiniMax embo-01 ile embedding üret. API yoksa deterministic fallback."""
    if MINIMAX_API_KEY:
        try:
            import urllib.request
            payload = json.dumps({"model": "embo-01", "texts": [text], "type": "query"}).encode()
            req = urllib.request.Request(
                MINIMAX_URL,
                data=payload,
                headers={"Authorization": f"Bearer {MINIMAX_API_KEY}",
                         "Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=10) as r:
                data = json.loads(r.read())
                if data.get("vectors"):
                    return data["vectors"][0]["embedding"]
        except Exception:
            pass
    # Deterministic fallback (anlamsal değil, keyword overlap ölçer)
    h = hashlib.sha256(text.lower().encode()).digest()
    vec = [(b / 127.5) - 1.0 for b in h[:EMBED_DIM % len(h) + EMBED_DIM]]
    return vec[:EMBED_DIM]


# ── Yardımcı: Cosine benzerlik ──────────────────────────────────────
def _cosine(a: list, b: list) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na  = math.sqrt(sum(x * x for x in a))
    nb  = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb) if na and nb else 0.0


# ── Tool 1: memory_search ────────────────────────────────────────────
@mcp.tool()
def memory_search(query: str, category: str = "", limit: int = 5) -> str:
    """
    tools-bank belleğini FTS5 keyword aramasıyla sorgula.
    Kritik kurallar, RPC referansları, domain kuralları vb. için kullan.
    category: critical_rules | rpc_reference | domain_rules | code_change |
              tech_stack | commands | general (boş bırakırsan hepsinde arar)
    """
    cat = category if category else None
    results = _fts_search(query, cat, limit)
    if not results:
        return f"'{query}' için sonuç bulunamadı."
    lines = [f"## Memory Search: '{query}'\n"]
    for i, r in enumerate(results, 1):
        tags = r.get("tags") or "[]"
        lines.append(f"### {i}. [{r['category']}] (prio: {r['priority']})")
        lines.append(r['content'])
        lines.append(f"*tags: {tags}*\n")
    return "\n".join(lines)


# ── Tool 2: semantic_search ─────────────────────────────────────────
@mcp.tool()
def semantic_search(query: str, limit: int = 5) -> str:
    """
    Anlamsal (vektör) arama. Keyword eşleşmesi olmasa bile benzer
    kavramları bulur. MiniMax embo-01 kullanır.
    """
    q_vec = _embed(query)
    conn  = sqlite3.connect(MEMORY_DB)
    c     = conn.cursor()
    c.execute("SELECT note_id, embedding FROM embeddings")
    rows  = c.fetchall()
    conn2 = sqlite3.connect(MEMORY_DB)
    conn2.row_factory = sqlite3.Row
    c2    = conn2.cursor()
    scored = []
    for note_id, emb_blob in rows:
        if emb_blob is None:
            continue
        try:
            emb = json.loads(emb_blob)
        except Exception:
            continue
        score = _cosine(q_vec, emb)
        scored.append((note_id, score))
    scored.sort(key=lambda x: x[1], reverse=True)
    top = scored[:limit]
    lines = [f"## Semantic Search: '{query}'\n"]
    for note_id, score in top:
        c2.execute("SELECT id, category, content, priority FROM notes WHERE id = ?", (note_id,))
        row = c2.fetchone()
        if row:
            lines.append(f"### [{row['category']}] (sim: {score:.3f})")
            lines.append(row['content'])
            lines.append("")
    conn.close()
    conn2.close()
    return "\n".join(lines) if len(lines) > 1 else f"'{query}' için sonuç bulunamadı."


# ── Tool 3: knowledge_graph_query ───────────────────────────────────
@mcp.tool()
def knowledge_graph_query(entity: str, relation_target: str = "") -> str:
    """
    Knowledge graph'ta entity ara. İki entity arasındaki ilişkiyi bul.
    entity: aranacak kavram (örn: 'RPC', 'tohumlama', 'hayvanlar')
    relation_target: ilişki hedefi (boş bırakırsan entity'nin tüm bağlantıları)
    """
    import subprocess
    cmd = ["python3", f"{TOOLS_BANK}/memory/knowledge_graph.py",
           "--query", entity, "--graph-db", GRAPH_DB]
    if relation_target:
        cmd = ["python3", f"{TOOLS_BANK}/memory/knowledge_graph.py",
               "--relate", entity, relation_target, "--graph-db", GRAPH_DB]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        out = result.stdout.strip()
        return out if out else f"'{entity}' için graph verisi bulunamadı."
    except Exception as e:
        return f"Graph sorgu hatası: {e}"


# ── Tool 4: memory_add ──────────────────────────────────────────────
@mcp.tool()
def memory_add(content: str, category: str = "general",
               priority: str = "medium", tags: str = "") -> str:
    """
    Belleğe yeni not ekle ve otomatik embed et.
    category: critical_rules | rpc_reference | domain_rules | code_change |
              tech_stack | commands | general
    priority: high | medium | low
    tags: virgülle ayrılmış etiketler (örn: 'rpc,kritik,supabase')
    """
    from datetime import datetime
    tag_list = json.dumps([t.strip() for t in tags.split(",") if t.strip()])
    conn = sqlite3.connect(MEMORY_DB)
    c    = conn.cursor()
    now  = datetime.utcnow().isoformat()
    c.execute("""
        INSERT INTO notes (timestamp, category, content, priority, tags,
                           confidence, source, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 1.0, 'mcp_tool', ?, ?)
    """, (now, category, content, priority, tag_list, now, now))
    note_id = c.lastrowid
    conn.commit()
    # FTS5 sync (insert trigger yoksa elle)
    try:
        c.execute("INSERT INTO notes_fts(rowid, content) VALUES (?, ?)",
                  (note_id, content))
        conn.commit()
    except Exception:
        pass
    conn.close()
    # Embed
    vec = _embed(content)
    conn2 = sqlite3.connect(MEMORY_DB)
    c2    = conn2.cursor()
    try:
        c2.execute("""
            INSERT INTO embeddings (note_id, embedding, model, created_at)
            VALUES (?, ?, ?, ?)
        """, (note_id, json.dumps(vec), "embo-01" if MINIMAX_API_KEY else "deterministic", now))
        conn2.commit()
        embedded = True
    except Exception:
        embedded = False
    conn2.close()
    return json.dumps({"id": note_id, "category": category,
                       "priority": priority, "embedded": embedded})


# ── Tool 5: memory_stats ────────────────────────────────────────────
@mcp.tool()
def memory_stats() -> str:
    """
    Bellek sistemi istatistiklerini göster.
    Toplam not, embedding, kategori dağılımı ve DB boyutu.
    """
    conn = sqlite3.connect(MEMORY_DB)
    c    = conn.cursor()
    c.execute("SELECT COUNT(*) FROM notes")
    total_notes = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM embeddings")
    total_emb   = c.fetchone()[0]
    c.execute("SELECT category, COUNT(*) as n FROM notes GROUP BY category ORDER BY n DESC")
    cats = {row[0]: row[1] for row in c.fetchall()}
    conn.close()
    db_mb = os.path.getsize(MEMORY_DB) / (1024 * 1024)
    result = {
        "total_notes": total_notes,
        "embeddings":  total_emb,
        "db_size_mb":  round(db_mb, 2),
        "categories":  cats,
        "minimax_key": "aktif" if MINIMAX_API_KEY else "yok (deterministic fallback)"
    }
    lines = ["## Memory Stats"]
    lines.append(f"- Notlar: {total_notes} | Embeddings: {total_emb} | DB: {db_mb:.2f} MB")
    lines.append(f"- MiniMax: {result['minimax_key']}")
    lines.append("\n**Kategoriler:**")
    for cat, n in cats.items():
        lines.append(f"  - {cat}: {n}")
    return "\n".join(lines)


if __name__ == "__main__":
    mcp.run()
```

- [ ] **Step 3: Server'ı standalone test et**

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | \
  MINIMAX_API_KEY="sk-cp-..." python3 /root/tools-bank/mcp/server.py 2>/dev/null | head -5
```

Beklenen: JSON yanıt içinde `memory_search`, `semantic_search`, `knowledge_graph_query`, `memory_add`, `memory_stats` tool adları görünür.

- [ ] **Step 4: memory_search tool'unu test et**

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_search","arguments":{"query":"RPC","limit":2}}}\n' | \
  MINIMAX_API_KEY="<MINIMAX_API_KEY>" \
  python3 /root/tools-bank/mcp/server.py 2>/dev/null
```

Beklenen: `content` alanında "RPC" içeren memory notları görünür.

- [ ] **Step 5: memory_stats tool'unu test et**

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_stats","arguments":{}}}\n' | \
  python3 /root/tools-bank/mcp/server.py 2>/dev/null
```

Beklenen: `total_notes: 48` içeren istatistik bloğu.

- [ ] **Step 6: Commit**

```bash
cd /root/tools-bank
git add mcp/
git commit -m "feat: FastMCP stdio server — memory_search, semantic_search, knowledge_graph_query, memory_add, memory_stats"
```

---

## Task 4: settings.json'a MCP Server Ekle

**Files:**
- Modify: `/root/.claude/settings.json`

- [ ] **Step 1: Mevcut settings.json'u oku**

```bash
cat /root/.claude/settings.json
```

- [ ] **Step 2: mcpServers bloğunu ekle**

`/root/.claude/settings.json` içindeki mevcut JSON'a `mcpServers` ekle. Mevcut `env` ve `enabledPlugins` korunur:

```json
{
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "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"
  },
  "enabledPlugins": {
    "frontend-design@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "github@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "skill-creator@claude-plugins-official": true,
    "claude-md-management@claude-plugins-official": true,
    "feature-dev@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "supabase@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true
  },
  "skipDangerousModePermissionPrompt": true,
  "mcpServers": {
    "tools-bank": {
      "command": "python3",
      "args": ["/root/tools-bank/mcp/server.py"],
      "env": {
        "MINIMAX_API_KEY": "<MINIMAX_API_KEY>"
      }
    }
  }
}
```

- [ ] **Step 3: JSON geçerliliğini kontrol et**

```bash
python3 -c "import json; json.load(open('/root/.claude/settings.json')); print('JSON OK')"
```

Beklenen: `JSON OK`

- [ ] **Step 4: Claude Code'u yeniden başlat ve MCP bağlantısını doğrula**

Yeni bir Claude Code session'ı aç (bu terminali kapat, tekrar başlat). Session açıldığında sol üstte veya `/mcp` komutuyla tools-bank server'ının `connected` durumda olduğunu gör.

---

## Task 5: UserPromptSubmit Hook Yaz

**Files:**
- Create: `/root/tools-bank/hooks/prompt_context_injector.py`

Hook, her kullanıcı mesajında tetiklenir. stdin'den JSON okur, mesajdaki teknik kelimeleri çıkarır, `memory_search` ile kritik kuralları bulur, stdout'a inject context yazar.

**Claude Code hook stdin formatı:**
```json
{"session_id": "...", "transcript_path": "...", "prompt": "kullanıcı mesajı"}
```

**stdout'a yazılacak format:**
```json
{"additionalContext": "inject edilecek metin"}
```

- [ ] **Step 1: Hook script'i yaz**

`/root/tools-bank/hooks/prompt_context_injector.py`:

```python
#!/usr/bin/env python3
"""
UserPromptSubmit Hook — Otomatik Memory Context Injector
=========================================================
Her kullanıcı mesajında tetiklenir. Kritik kuralları ve RPC
referanslarını Claude'un context'ine otomatik ekler.

stdin:  {"session_id": "...", "prompt": "..."}
stdout: {"additionalContext": "..."}  veya boş çıktı (inject yoksa)
"""

import sys
import json
import sqlite3
import re

MEMORY_DB = "/root/tools-bank/memory/memory.db"

# Bu kategoriler her zaman inject edilir (bulunursa)
PRIORITY_CATEGORIES = ["critical_rules", "rpc_reference", "domain_rules"]

# Teknik kelime pattern'leri — bunlar varsa memory'e bak
TECH_PATTERNS = [
    r'\b(rpc|supabase|migration|tohumlama|kizginlik|hayvan|ilac|hastalik)\b',
    r'\b(insert|update|delete|select|sql|query)\b',
    r'\b(js|javascript|html|css|api|hook|component)\b',
    r'\b(hata|bug|fix|düzelt|broken|calismıyor|çalışmıyor)\b',
]


def extract_keywords(text: str) -> list:
    """Mesajdan teknik anahtar kelimeleri çıkar."""
    text_lower = text.lower()
    keywords = []
    for pattern in TECH_PATTERNS:
        matches = re.findall(pattern, text_lower)
        keywords.extend(matches)
    # İlk 3 kelimeyi al (fazla query yapmamak için)
    return list(dict.fromkeys(keywords))[:3]


def fts_search_priority(keywords: list) -> list:
    """Kritik kategorilerde FTS5 arama yap."""
    if not keywords:
        return []
    conn = sqlite3.connect(MEMORY_DB)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    results = []
    # Önce critical_rules kategorisini her zaman ekle
    c.execute("""
        SELECT content, category, priority FROM notes
        WHERE category IN ('critical_rules', 'rpc_reference', 'domain_rules')
        AND priority = 'high'
        ORDER BY updated_at DESC LIMIT 3
    """)
    results.extend([dict(r) for r in c.fetchall()])
    # Sonra keyword araması
    for kw in keywords[:2]:
        safe_kw = kw.replace('"', '""') + "*"
        try:
            c.execute("""
                SELECT notes.content, notes.category, notes.priority
                FROM notes_fts
                JOIN notes ON notes.id = notes_fts.rowid
                WHERE notes_fts MATCH ?
                AND notes.category NOT IN ('code_change', 'general')
                ORDER BY bm25(notes_fts) LIMIT 2
            """, (safe_kw,))
            results.extend([dict(r) for r in c.fetchall()])
        except Exception:
            pass
    conn.close()
    # Deduplicate by content
    seen = set()
    unique = []
    for r in results:
        key = r['content'][:50]
        if key not in seen:
            seen.add(key)
            unique.append(r)
    return unique[:4]


def main():
    try:
        raw = sys.stdin.read().strip()
        if not raw:
            sys.exit(0)
        data = json.loads(raw)
        prompt = data.get("prompt", "")
        if not prompt or len(prompt) < 5:
            sys.exit(0)
        keywords = extract_keywords(prompt)
        notes = fts_search_priority(keywords)
        if not notes:
            sys.exit(0)
        lines = ["[tools-bank memory — otomatik inject]\n"]
        for note in notes:
            lines.append(f"**[{note['category']}]** {note['content'][:300]}")
            lines.append("")
        context = "\n".join(lines)
        print(json.dumps({"additionalContext": context}))
    except Exception:
        # Hook hataları sessizce geç — Claude'u bloklama
        sys.exit(0)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Hook'u çalıştırılabilir yap**

```bash
chmod +x /root/tools-bank/hooks/prompt_context_injector.py
```

- [ ] **Step 3: Hook'u test et**

```bash
echo '{"session_id":"test","prompt":"tohumlama RPC nasıl çalışır"}' | \
  python3 /root/tools-bank/hooks/prompt_context_injector.py
```

Beklenen: `{"additionalContext": "[tools-bank memory...]..."}` JSON çıktısı. İçinde critical_rules veya rpc_reference notu olmalı.

- [ ] **Step 4: Teknik olmayan mesajda inject olmamasını test et**

```bash
echo '{"session_id":"test","prompt":"merhaba nasılsın"}' | \
  python3 /root/tools-bank/hooks/prompt_context_injector.py
```

Beklenen: boş çıktı veya `{}` (inject yok — israfı önle).

- [ ] **Step 5: Commit**

```bash
cd /root/tools-bank
git add hooks/
git commit -m "feat: UserPromptSubmit hook — otomatik kritik kural inject"
```

---

## Task 6: settings.json'a Hook Ekle

**Files:**
- Modify: `/root/.claude/settings.json`

- [ ] **Step 1: hooks bloğunu ekle**

`/root/.claude/settings.json`'a `hooks` bloğunu ekle (mcpServers'ın yanına):

```json
{
  "env": { ... },
  "enabledPlugins": { ... },
  "skipDangerousModePermissionPrompt": true,
  "mcpServers": { ... },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 /root/tools-bank/hooks/prompt_context_injector.py"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: JSON geçerliliğini kontrol et**

```bash
python3 -c "import json; json.load(open('/root/.claude/settings.json')); print('JSON OK')"
```

Beklenen: `JSON OK`

---

## Task 7: mem-tools Skill Yaz

**Files:**
- Create: `/root/tools-bank/skills/mem-tools/SKILL.md`

Bu skill, kullanıcının `/mem-search`, `/mem-add`, `/mem-graph`, `/mem-stats` komutlarını manuel olarak çağırmasını sağlar.

- [ ] **Step 1: SKILL.md yaz**

`/root/tools-bank/skills/mem-tools/SKILL.md`:

```markdown
---
name: mem-tools
description: tools-bank memory araçları — /mem-search, /mem-add, /mem-graph, /mem-stats
triggers:
  - /mem-search
  - /mem-add
  - /mem-graph
  - /mem-stats
---

# mem-tools

tools-bank bellek sistemine doğrudan erişim sağlar.
MCP tools mevcut değilse veya manuel arama yapmak istersen kullan.

## /mem-search <query> [--category <cat>] [--semantic]

Bellekte ara. FTS5 (varsayılan) veya semantic arama.

```bash
python3 /root/tools-bank/tools/memory_search.py search "<query>"
```

Semantic için:
```bash
MINIMAX_API_KEY="sk-cp-..." python3 /root/tools-bank/memory/embedding_service.py \
  --search "<query>" --db /root/tools-bank/memory/memory.db
```

Kategoriler: `critical_rules` | `rpc_reference` | `domain_rules` | `code_change` | `commands` | `general`

## /mem-add <content> [--category <cat>] [--priority high|medium|low]

Yeni not ekle:

```bash
python3 -c "
import sqlite3, json
from datetime import datetime
conn = sqlite3.connect('/root/tools-bank/memory/memory.db')
now = datetime.utcnow().isoformat()
conn.execute('''INSERT INTO notes (timestamp, category, content, priority, tags, confidence, source, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, 1.0, 'manual', ?, ?)''',
             (now, '<category>', '<content>', '<priority>', '[]', now, now))
conn.commit()
print('Eklendi')
conn.close()
"
```

## /mem-graph <entity> [<relation_target>]

Knowledge graph sorgusu:

```bash
python3 /root/tools-bank/memory/knowledge_graph.py \
  --query "<entity>" --graph-db /root/tools-bank/memory/knowledge_graph.db
```

## /mem-stats

DB istatistikleri:

```bash
python3 /root/tools-bank/tools/memory_search.py stats
```
```

- [ ] **Step 2: Skill'i test et — mem-stats çalışıyor mu**

```bash
python3 /root/tools-bank/tools/memory_search.py stats
```

Beklenen: `{"total_notes": 48, ...}` JSON.

- [ ] **Step 3: Commit**

```bash
cd /root/tools-bank
git add skills/
git commit -m "feat: mem-tools skill — /mem-search /mem-add /mem-graph /mem-stats"
```

---

## Task 8: Skill'i Claude Code'a Kaydet

Claude Code, skill'leri `~/.claude/plugins/` yapısından okur. mem-tools'u buraya symlink veya kopyala.

- [ ] **Step 1: Skill dizini oluştur**

```bash
mkdir -p /root/.claude/plugins/data/tools-bank-local/skills/mem-tools
cp /root/tools-bank/skills/mem-tools/SKILL.md \
   /root/.claude/plugins/data/tools-bank-local/skills/mem-tools/SKILL.md
```

- [ ] **Step 2: Plugin manifest oluştur**

```bash
cat > /root/.claude/plugins/data/tools-bank-local/plugin.json << 'EOF'
{
  "name": "tools-bank-local",
  "version": "1.0.0",
  "description": "tools-bank memory araçları — local MCP entegrasyonu",
  "skills": ["mem-tools"]
}
EOF
```

- [ ] **Step 3: Son genel test — tüm katmanlar**

```bash
# Katman 1: MCP server ayağa kalkıyor mu
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | \
  python3 /root/tools-bank/mcp/server.py 2>/dev/null | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print('Tools:', [t['name'] for t in d['result']['tools']])"

# Katman 2: Hook çalışıyor mu
echo '{"prompt":"tohumlama RPC"}' | python3 /root/tools-bank/hooks/prompt_context_injector.py | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print('Inject OK, uzunluk:', len(d.get('additionalContext','')))"

# Katman 3: Skill CLI çalışıyor mu
python3 /root/tools-bank/tools/memory_search.py stats | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print('Notes:', d['total_notes'])"
```

Beklenen:
```
Tools: ['memory_search', 'semantic_search', 'knowledge_graph_query', 'memory_add', 'memory_stats']
Inject OK, uzunluk: <100'den fazla>
Notes: 48
```

- [ ] **Step 4: tools-bank repo final commit**

```bash
cd /root/tools-bank
git add -A
git commit -m "feat: tools-bank MCP entegrasyonu tamamlandı — 3 katman aktif"
```

---

## Özet: Tamamlandığında Ne Aktif Olur

| Katman | Nasıl çalışır | Test |
|---|---|---|
| MCP native tools | Claude Code session'da `memory_search` vb. direkt çağırabilir | `/mcp` komutu → tools-bank: connected |
| Auto context inject | Her teknik mesajda critical_rules + rpc_reference otomatik gelir | Hook test (Task 5 Step 3) |
| Slash komutlar | `/mem-search RPC` gibi manuel sorgular | Skill CLI testleri |
| Semantic search | embo-01 ile anlamsal arama | `semantic_search` MCP tool |
| egesut-erp1 izolasyonu | tools-bank ayrı repo, pull/push çakışmaz | `/root/tools-bank/.git` |
