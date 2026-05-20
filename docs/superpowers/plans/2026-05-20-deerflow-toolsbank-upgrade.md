# DeerFlow MCP Genişletme + Global Tools-Bank Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tools-bank MCP server'a 6 yeni DeerFlow aracı ekle, global tools-bank-mcp skill yaz ve symlink ile her dizinden erişilebilir kıl.

**Architecture:** Tüm değişiklikler `/root/tools-bank/mcp_server/server.py` DeerFlow bölümüne eklenir. Skill canonical olarak `/root/tools-bank/skills/tools-bank/SKILL.md`'de yaşar, `/root/.claude/skills/tools-bank/SKILL.md` symlink'i global erişim sağlar.

**Tech Stack:** Python 3, FastMCP, requests (SSE streaming), subprocess (gateway restart), DeerFlow REST API (http://localhost:8001)

---

## Gerçek API Endpoint Referansı

| İşlem | Endpoint | Method | Not |
|-------|----------|--------|-----|
| Thread oluştur | `/api/threads` | POST + CSRF | `{}` body |
| Thread listele | `/api/threads/search` | POST + CSRF | `{"limit": N}` |
| Thread'e mesaj gönder | `/api/threads/{id}/runs/stream` | POST + CSRF | SSE stream |
| Assistant listele | `/api/assistants/search` | POST + CSRF | `{}` body |
| Memory oku | `/api/memory/status` | GET | Auth yeterli |
| Memory yaz | `/api/memory/facts` | POST + CSRF | `{"content": "...", "category": "..."}` |

CSRF token: `_deerflow_session.cookies.get("csrf_token", "")` → `X-CSRF-Token` header

---

## Dosya Haritası

| Dosya | Değişiklik |
|-------|-----------|
| `/root/tools-bank/mcp_server/server.py` | DeerFlow bölümü genişletilir (satır ~1678-1890) |
| `/root/tools-bank/skills/tools-bank/SKILL.md` | Yeni dosya oluşturulur |
| `/root/.claude/skills/tools-bank/SKILL.md` | Symlink oluşturulur |
| `/root/.claude/CLAUDE.md` | `tools-bank-mcp` referansı eklenir |
| `/root/tools-bank/skills/mem-tools/SKILL.md` | Silinir |

---

## Task 1: Güvenlik Düzeltmesi + deerflow_research'e agent_id

**Files:**
- Modify: `/root/tools-bank/mcp_server/server.py:1682` (default password)
- Modify: `/root/tools-bank/mcp_server/server.py` (deerflow_research fonksiyonu)

- [ ] **Step 1: Default password'u kaldır**

`server.py:1682` satırını değiştir:
```python
# ÖNCE
DEERFLOW_ADMIN_PASSWORD = os.environ.get("DEERFLOW_ADMIN_PASSWORD", "DeerFlow2026!")

# SONRA
DEERFLOW_ADMIN_PASSWORD = os.environ.get("DEERFLOW_ADMIN_PASSWORD", "")
```

- [ ] **Step 2: deerflow_research'e agent_id ekle**

`deerflow_research` fonksiyon imzasını ve payload'ını güncelle:
```python
@mcp.tool()
def deerflow_research(query: str, mode: str = "standard", agent_id: str = "lead_agent") -> str:
    """DeerFlow'a araştırma görevi gönderir ve sonucu döndürür.
    
    Args:
        query: Araştırma sorusu veya görev tanımı
        mode: Çalışma modu — flash (hızlı), standard, pro (planlı), ultra (sub-agent'lı)
        agent_id: Hedef agent (varsayılan: lead_agent). deerflow_agents() ile listelenir.
    """
```

Payload içindeki `"assistant_id": "lead_agent"` satırını değiştir:
```python
        payload = {
            "assistant_id": agent_id,   # "lead_agent" → agent_id
            ...
        }
```

- [ ] **Step 3: MCP server'ı yeniden başlat ve test et**

```bash
pkill -f "mcp_server/server.py" 2>/dev/null; sleep 1
python3 /root/tools-bank/mcp_server/server.py --stdio &
sleep 2 && echo "OK"
```

Ardından Claude Code'da `deerflow_research("test", agent_id="lead_agent")` çağır — öncekiyle aynı çalışmalı.

- [ ] **Step 4: tools-bank repo'sunda commit**

```bash
cd /root/tools-bank
git add mcp_server/server.py
git commit -m "fix: deerflow default password kaldırıldı, deerflow_research'e agent_id eklendi"
```

---

## Task 2: deerflow_gateway_restart() Aracı

**Files:**
- Modify: `/root/tools-bank/mcp_server/server.py` — DeerFlow bölümünün sonuna ekle (if __name__ bloğundan önce)

- [ ] **Step 1: import subprocess kontrolü**

`server.py` başında `import subprocess` var mı kontrol et:
```bash
grep "^import subprocess" /root/tools-bank/mcp_server/server.py
```
Yoksa `import os` satırının altına ekle: `import subprocess`

- [ ] **Step 2: deerflow_gateway_restart fonksiyonunu ekle**

`server.py`'de `if __name__ == "__main__":` bloğunun hemen üstüne ekle:

```python
@mcp.tool()
def deerflow_gateway_restart() -> str:
    """DeerFlow Gateway'i başlatır veya yeniden başlatır. Agent'lar gateway düşünce bunu çağırır."""
    import time
    import subprocess

    DEER_FLOW_BACKEND = os.path.expanduser("~/deer-flow/backend")
    GATEWAY_LOG = os.path.expanduser("~/deer-flow/logs/gateway.log")

    # Zaten çalışıyorsa erken dön
    try:
        r = requests.get(f"{DEERFLOW_GATEWAY}/health", timeout=3)
        if r.status_code == 200:
            return "✅ Gateway zaten çalışıyor — restart gerekmedi."
    except Exception:
        pass

    # Eski process temizle
    subprocess.run(["pkill", "-f", "uvicorn app.gateway.app"], capture_output=True)
    time.sleep(1)

    # Log dosyasını sıfırla
    os.makedirs(os.path.dirname(GATEWAY_LOG), exist_ok=True)
    with open(GATEWAY_LOG, "w") as f:
        f.write("")

    # uvicorn başlat
    env = os.environ.copy()
    pyenv_root = os.path.expanduser("~/.pyenv")
    if os.path.isdir(f"{pyenv_root}/bin"):
        env["PATH"] = f"{pyenv_root}/bin:{pyenv_root}/shims:{env.get('PATH', '')}"
        env["PYENV_ROOT"] = pyenv_root
    env["UV_LINK_MODE"] = "copy"

    try:
        with open(GATEWAY_LOG, "a") as log_f:
            subprocess.Popen(
                ["uv", "run", "uvicorn", "app.gateway.app:app",
                 "--host", "0.0.0.0", "--port", "8001", "--log-level", "warning"],
                cwd=DEER_FLOW_BACKEND,
                env=env,
                stdout=log_f,
                stderr=log_f,
            )
    except FileNotFoundError:
        return "❌ 'uv' komutu bulunamadı. pyenv/PATH sorununu kontrol et."

    # Max 60sn health bekle
    start = time.time()
    while time.time() - start < 60:
        time.sleep(2)
        try:
            r = requests.get(f"{DEERFLOW_GATEWAY}/health", timeout=3)
            if r.status_code == 200:
                elapsed = round(time.time() - start)
                return f"✅ Gateway başlatıldı ({elapsed}sn)"
        except Exception:
            pass

    # Başlatılamadı — log son 10 satırını döndür
    try:
        with open(GATEWAY_LOG) as f:
            lines = f.readlines()
        log_tail = "".join(lines[-10:])
    except Exception:
        log_tail = "(log okunamadı)"
    return f"❌ Gateway 60sn içinde başlatılamadı.\nLog:\n{log_tail}"
```

- [ ] **Step 3: Manuel test**

MCP server'ı yeniden başlat:
```bash
pkill -f "mcp_server/server.py" 2>/dev/null; sleep 1
```

Claude Code'da tool'u çağır:
- Gateway çalışıyorken: `deerflow_gateway_restart()` → `"✅ Gateway zaten çalışıyor"` döndürmeli
- Gateway durdurulup çağırılınca: `"✅ Gateway başlatıldı (Xs)"` döndürmeli

- [ ] **Step 4: Commit**

```bash
cd /root/tools-bank
git add mcp_server/server.py
git commit -m "feat: deerflow_gateway_restart — agent'lar gateway'i kaldırabilir"
```

---

## Task 3: deerflow_agents() + deerflow_threads() Araçları

**Files:**
- Modify: `/root/tools-bank/mcp_server/server.py`

- [ ] **Step 1: deerflow_agents fonksiyonunu ekle**

`deerflow_gateway_restart` fonksiyonunun üstüne ekle:

```python
@mcp.tool()
def deerflow_agents() -> str:
    """DeerFlow'daki mevcut agent'ları listeler. Dönen assistant_id değerleri deerflow_chat/deerflow_research'e agent_id olarak geçilebilir."""
    try:
        r = _df_post("/api/assistants/search", json_data={}, timeout=5)
        if r.status_code == 200:
            agents = r.json() if isinstance(r.json(), list) else r.json().get("assistants", [])
            if not agents:
                return "Hiç agent bulunamadı."
            lines = ["**DeerFlow Agent'ları:**"]
            for a in agents:
                aid = a.get("assistant_id", a.get("name", "?"))
                desc = a.get("description", "")
                lines.append(f"  - `{aid}` — {desc}")
            return "\n".join(lines)
        return f"API hatası: {r.status_code} {r.text[:200]}"
    except requests.ConnectionError:
        return "❌ DeerFlow Gateway'e bağlanılamıyor. deerflow_gateway_restart() çağır."
    except Exception as e:
        return f"❌ Hata: {e}"


@mcp.tool()
def deerflow_threads(limit: int = 10) -> str:
    """Son N DeerFlow thread'ini listeler. thread_id değerleri deerflow_chat'e geçilebilir."""
    try:
        r = _df_post("/api/threads/search", json_data={"limit": limit}, timeout=5)
        if r.status_code == 200:
            threads = r.json() if isinstance(r.json(), list) else []
            if not threads:
                return "Hiç thread bulunamadı."
            lines = ["**DeerFlow Thread'leri:**"]
            for t in threads:
                tid = t.get("thread_id", "?")
                status = t.get("status", "?")
                updated = (t.get("updated_at") or "")[:16]
                title = t.get("values", {}).get("title", "—")
                lines.append(f"  - `{tid}` [{status}] {updated} — {title}")
            return "\n".join(lines)
        return f"API hatası: {r.status_code} {r.text[:200]}"
    except requests.ConnectionError:
        return "❌ DeerFlow Gateway'e bağlanılamıyor. deerflow_gateway_restart() çağır."
    except Exception as e:
        return f"❌ Hata: {e}"
```

- [ ] **Step 2: Manuel test**

Claude Code'da:
```
deerflow_agents()    → lead_agent listede görünmeli
deerflow_threads(5)  → mevcut thread'ler listelenmeli
```

- [ ] **Step 3: Commit**

```bash
cd /root/tools-bank
git add mcp_server/server.py
git commit -m "feat: deerflow_agents + deerflow_threads araçları eklendi"
```

---

## Task 4: deerflow_chat() Aracı

**Files:**
- Modify: `/root/tools-bank/mcp_server/server.py`

- [ ] **Step 1: deerflow_chat fonksiyonunu ekle**

`deerflow_threads` fonksiyonunun altına ekle:

```python
@mcp.tool()
def deerflow_chat(message: str, thread_id: str = "", agent_id: str = "lead_agent") -> str:
    """DeerFlow ile stateful konuşma. thread_id verilmezse yeni thread açar.
    
    Args:
        message: Gönderilecek mesaj
        thread_id: Devam edilecek thread (boşsa yeni thread açılır)
        agent_id: Hedef agent (varsayılan: lead_agent)
    
    Returns:
        JSON string: {"thread_id": "...", "response": "..."}
    """
    try:
        # Thread yoksa oluştur
        if not thread_id:
            thr = _df_post("/api/threads", json_data={}, timeout=10)
            if thr.status_code != 200:
                return json.dumps({"error": f"Thread oluşturulamadı: {thr.status_code} {thr.text[:200]}"})
            thread_id = thr.json().get("thread_id", "")
            if not thread_id:
                return json.dumps({"error": f"Thread ID alınamadı: {thr.text[:200]}"})

        # Run başlat (SSE streaming)
        payload = {
            "assistant_id": agent_id,
            "input": {
                "messages": [{
                    "type": "human",
                    "content": [{"type": "text", "text": message}]
                }]
            },
            "stream_mode": ["values"],
            "config": {"recursion_limit": 100, "configurable": {
                "thinking_enabled": True,
                "is_plan_mode": False,
                "subagent_enabled": False,
            }}
        }

        r = _df_post(
            f"/api/threads/{thread_id}/runs/stream",
            json_data=payload,
            timeout=300,
            stream=True
        )

        if r.status_code != 200:
            return json.dumps({"error": f"Run başlatılamadı: {r.status_code} {r.text[:200]}"})

        # SSE stream'i oku — research ile aynı mekanizma
        last_content = ""
        current_event = ""
        for line in r.iter_lines():
            if not line:
                current_event = ""
                continue
            decoded = line.decode("utf-8")
            if decoded.startswith("event: "):
                current_event = decoded[7:].strip()
            elif decoded.startswith("data: ") and current_event == "values":
                try:
                    data = json.loads(decoded[6:])
                    msgs = data.get("messages", [])
                    for msg in msgs:
                        if msg.get("type") == "ai" and msg.get("content"):
                            content = msg["content"]
                            if isinstance(content, list):
                                text_parts = [c.get("text", "") for c in content if c.get("type") == "text"]
                                content = "\n".join(text_parts)
                            if content:
                                last_content = content
                except json.JSONDecodeError:
                    continue

        if last_content:
            return json.dumps({"thread_id": thread_id, "response": last_content})
        return json.dumps({"thread_id": thread_id, "response": "⚠️ Yanıt boş döndü."})

    except requests.ConnectionError:
        return json.dumps({"error": "❌ DeerFlow Gateway'e bağlanılamıyor. deerflow_gateway_restart() çağır."})
    except Exception as e:
        return json.dumps({"error": f"❌ Hata: {e}"})
```

- [ ] **Step 2: Stateless kullanım testi**

Claude Code'da:
```
result = deerflow_chat("Merhaba, kim olduğunu kısaca anlat")
```
→ `thread_id` ve `response` içeren JSON dönmeli.

- [ ] **Step 3: Stateful kullanım testi**

Dönen `thread_id`'yi alıp ikinci mesaj gönder:
```
result2 = deerflow_chat("Az önce ne dedim?", thread_id="<önceki thread_id>")
```
→ Önceki mesajı hatırlamalı.

- [ ] **Step 4: Commit**

```bash
cd /root/tools-bank
git add mcp_server/server.py
git commit -m "feat: deerflow_chat — stateful konuşma aracı"
```

---

## Task 5: deerflow_memory() Aracı

**Files:**
- Modify: `/root/tools-bank/mcp_server/server.py`

- [ ] **Step 1: deerflow_memory fonksiyonunu ekle**

`deerflow_chat` fonksiyonunun altına ekle:

```python
@mcp.tool()
def deerflow_memory(action: str, query: str = "", content: str = "", category: str = "") -> str:
    """DeerFlow'un memory sistemine eriş.
    
    Args:
        action: "status" (özet), "list" (tüm veri), "add" (yeni fact ekle)
        query: (şu an kullanılmıyor, ileride arama için)
        content: action="add" için fact içeriği
        category: action="add" için kategori (workContext, personalContext, topOfMind)
    """
    try:
        if action in ("status", "list"):
            r = _df_get("/api/memory/status", timeout=5)
            if r.status_code == 200:
                data = r.json()
                if action == "status":
                    # Özet ver
                    config = data.get("config", {})
                    mem_data = data.get("data", {})
                    user = mem_data.get("user", {})
                    lines = ["**DeerFlow Memory Durumu:**"]
                    lines.append(f"  Enabled: {config.get('enabled')}, Max facts: {config.get('max_facts')}")
                    for key, val in user.items():
                        summary = val.get("summary", "") if isinstance(val, dict) else str(val)
                        if summary:
                            lines.append(f"  [{key}]: {summary[:100]}")
                    return "\n".join(lines) if len(lines) > 1 else "Memory boş veya özet yok."
                else:
                    # Ham veriyi döndür
                    return json.dumps(data, ensure_ascii=False, indent=2)[:2000]
            return f"Memory status alınamadı: {r.status_code}"

        elif action == "add":
            if not content:
                return "❌ action='add' için content gerekli."
            payload = {"content": content}
            if category:
                payload["category"] = category
            r = _df_post("/api/memory/facts", json_data=payload, timeout=5)
            if r.status_code in (200, 201):
                return "✅ Memory'e eklendi."
            return f"❌ Eklenemedi: {r.status_code} {r.text[:200]}"

        else:
            return f"❌ Geçersiz action: '{action}'. Geçerli: status, list, add"

    except requests.ConnectionError:
        return "❌ DeerFlow Gateway'e bağlanılamıyor. deerflow_gateway_restart() çağır."
    except Exception as e:
        return f"❌ Hata: {e}"
```

- [ ] **Step 2: Test**

```
deerflow_memory("status")   → memory özeti
deerflow_memory("list")     → ham JSON
deerflow_memory("add", content="Test fact", category="workContext")  → ✅
```

- [ ] **Step 3: Commit**

```bash
cd /root/tools-bank
git add mcp_server/server.py
git commit -m "feat: deerflow_memory — status/list/add işlemleri"
```

---

## Task 6: Global Tools-Bank Skill

**Files:**
- Create: `/root/tools-bank/skills/tools-bank/SKILL.md`
- Create (symlink): `/root/.claude/skills/tools-bank/SKILL.md`
- Modify: `/root/.claude/CLAUDE.md`
- Delete: `/root/tools-bank/skills/mem-tools/SKILL.md`

- [ ] **Step 1: Skill dosyasını yaz**

`/root/tools-bank/skills/tools-bank/SKILL.md` oluştur:

```markdown
---
name: tools-bank-mcp
description: |
  tools-bank MCP araç rehberi — memory, DeerFlow araştırma/sohbet, agent telsiz, supabase.
  Trigger: "tools-bank", "memory ara", "deerflow", "araştır", "araştırma yap",
  "deepseek tui", "gateway", "thread aç", "agent listele".
version: 2.0.0
---

# Tools-Bank MCP Araç Rehberi

tools-bank MCP server her Claude/DeepSeek TUI oturumunda aktif gelir.
Bu skill araçları doğru kullanmak için rehberdir.

---

## Karar Tablosu

| İhtiyaç | Araç |
|---------|------|
| Kısa araştırma | `deerflow_research(query, mode="flash")` |
| Derin araştırma | `deerflow_research(query, mode="pro")` |
| Stateful sohbet | `deerflow_chat(message)` → thread_id sakla → tekrar `deerflow_chat(msg, thread_id)` |
| Hangi agent'lar var? | `deerflow_agents()` |
| Geçmiş thread'ler | `deerflow_threads(limit=10)` |
| Gateway kontrolü | `deerflow_health()` |
| Gateway düştü | `deerflow_gateway_restart()` → ardından `deerflow_health()` |
| Memory oku | `deerflow_memory("status")` |
| Memory yaz | `deerflow_memory("add", content="...", category="workContext")` |
| tools-bank memory ara | `memory_search(query)` veya `semantic_search(query)` |
| tools-bank'a not ekle | `memory_add(content, category, priority)` |
| tools-bank stats | `memory_stats()` |
| Agent'a mesaj | `agent_send(to, message)` |
| Agent'tan mesaj al | `agent_receive(agent_id, timeout=30)` |

---

## DeerFlow Araçları

### deerflow_health()
Gateway ayakta mı kontrol eder. Her DeerFlow işlemi öncesi opsiyonel ön kontrol.

### deerflow_gateway_restart()
Gateway düştüğünde agent'lar bunu çağırır. TUI açmaz, sadece uvicorn başlatır.
Akış:
```
deerflow_health() → ❌  →  deerflow_gateway_restart()  →  deerflow_health() → ✅
```
Hala ❌ ise kullanıcıyı bildir.

### deerflow_research(query, mode, agent_id)
Stateless tek seferlik araştırma. Her çağrıda yeni thread açar.

| mode | Açıklama |
|------|----------|
| flash | Hızlı, plansız |
| standard | Düşünen, plansız (varsayılan) |
| pro | Planlı araştırma |
| ultra | Sub-agent'lı derin araştırma |

`agent_id` varsayılan `"lead_agent"` — `deerflow_agents()` ile diğerleri listelenir.

### deerflow_chat(message, thread_id, agent_id)
Stateful konuşma. `thread_id` boşsa yeni thread, doluysa devam eder.
Her zaman `{"thread_id": "...", "response": "..."}` JSON döndürür.
`thread_id`'yi sakla → bir sonraki çağrıda geç → context korunur.

### deerflow_threads(limit)
`POST /api/threads/search` — son N thread: id, status, başlık.

### deerflow_agents()
`POST /api/assistants/search` — mevcut agent'lar. Dönen `assistant_id` değerleri `agent_id` parametresi olarak kullanılır.

### deerflow_memory(action, content, category)
DeerFlow'un kendi memory'si.
- `"status"` → özet görünüm
- `"list"` → ham JSON
- `"add"` → yeni fact ekle (category: workContext | personalContext | topOfMind)

### deerflow_list_models() / deerflow_list_skills()
Yapılandırılmış LLM ve yüklü skill listesi.

---

## tools-bank Memory Araçları

tools-bank'ın kendi SQLite memory sistemi — DeerFlow'dan bağımsız.

| Araç | Kullanım |
|------|---------|
| `memory_search(query, category, limit)` | FTS5 keyword arama |
| `semantic_search(query, limit)` | Vektör tabanlı anlam arama |
| `memory_add(content, category, priority, tags)` | Not ekle |
| `memory_stats()` | İstatistik + sağlık |

Kategoriler: `critical_rules` · `rpc_reference` · `domain_rules` · `code_change` · `tech_stack` · `commands` · `general`

---

## Agent Telsiz

```python
agent_send(to="goose-worker-1", message="görev tamamlandı")
agent_receive(agent_id="claude", timeout=30)  # 30sn bekle
```

---

## Supabase Araçları

Canonical referans: `supabase/migrations/99999999999999_ground_truth.sql`
RPC imzaları: `.claude/rpc-reference.md`

Araçlar: `supabase_query`, `supabase_rpc`, `supabase_insert`, `supabase_upsert`, `supabase_delete`, `supabase_migrate`

---

## CLI Fallback (MCP yoksa)

```bash
# memory_search fallback
python3 /root/tools-bank/tools/memory_search.py search "<query>"

# semantic_search fallback  
python3 /root/tools-bank/memory/embedding_service.py --search "<query>" \
  --db /root/tools-bank/memory/memory.db

# memory stats
python3 /root/tools-bank/tools/memory_search.py stats

# gateway restart
~/deer-flow/scripts/tui+ --status
```
```

- [ ] **Step 2: Symlink oluştur**

```bash
mkdir -p /root/.claude/skills/tools-bank
ln -sf /root/tools-bank/skills/tools-bank/SKILL.md \
        /root/.claude/skills/tools-bank/SKILL.md
ls -la /root/.claude/skills/tools-bank/SKILL.md
```
→ Symlink çalışıyor olmalı, dosyayı göstermeli.

- [ ] **Step 3: Global CLAUDE.md güncelle**

`/root/.claude/CLAUDE.md` dosyasına ekle:
```markdown
# tools-bank-mcp
@/root/.claude/skills/tools-bank/SKILL.md
```

- [ ] **Step 4: Eski mem-tools skill'i sil**

```bash
rm /root/tools-bank/skills/mem-tools/SKILL.md
rmdir /root/tools-bank/skills/mem-tools 2>/dev/null || true
```

- [ ] **Step 5: Commit (tools-bank repo)**

```bash
cd /root/tools-bank
git add skills/tools-bank/SKILL.md
git rm skills/mem-tools/SKILL.md
git commit -m "feat: global tools-bank-mcp skill — mem-tools yerine geçti"
```

---

## Task 7: MCP Server Yeniden Başlat + Tüm Araçları Test Et

- [ ] **Step 1: MCP server'ı yeniden başlat**

MCP server'ı restart etmek için Claude Code oturumunu yeniden başlatmak gerekir (stdio mod). Kullanıcıya bildir: "MCP server'ı yenilemek için Claude Code oturumunu yeniden başlat."

- [ ] **Step 2: Başarı kriterlerini kontrol et**

```
deerflow_gateway_restart()        → "✅ Gateway zaten çalışıyor"
deerflow_agents()                 → lead_agent listede
deerflow_threads(3)               → thread listesi
deerflow_chat("Merhaba")          → {"thread_id": "...", "response": "..."}
deerflow_chat("Ne dedim?", thread_id="<önceki>")  → context hatırlıyor
deerflow_research("test", agent_id="lead_agent")  → yanıt döner
deerflow_memory("status")         → memory özeti
```

- [ ] **Step 3: Global skill erişim testi**

```bash
ls -la /root/.claude/skills/tools-bank/SKILL.md   # symlink mevcut
cat /root/.claude/CLAUDE.md | grep tools-bank      # referans var
```

Farklı dizinden Claude açıp `tools-bank-mcp` skill'ini çağır — yüklenmeli.

- [ ] **Step 4: Final commit (egesut-erp1)**

```bash
cd /root/egesut-erp1
git add docs/
git commit -m "docs: DeerFlow MCP + global tools-bank skill plan tamamlandı"
```
