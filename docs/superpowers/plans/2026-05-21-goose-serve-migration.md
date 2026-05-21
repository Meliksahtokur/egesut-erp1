# Goose Serve Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `goose_start` MCP tool'unu `exec.Cmd` spawn modelinden `goose serve` ACP HTTP daemon modeline geçir — Tokio crash'ini ortadan kaldır.

**Architecture:** `goose serve --port 3284` kalıcı daemon olarak çalışır (terminal modeli gibi). `goose_start` artık `goose run` subprocess spawn etmez; ACP JSON-RPC ile `goose serve`'e session açar ve recipe'yi system prompt olarak gönderir. Arka planda SSE listener statüsü goused-api SQLite'a yazar, `goose_status` oradan okur.

**Tech Stack:** Python 3 (mcp_server/server.py, yeni acp_client.py) · Go (goused-api, goused-watchdog) · Goose v1.31.1 ACP JSON-RPC · SSE streaming · SQLite

**Değişmeyenler:** commit lock · goused-telsiz · heartbeat watchdog · tier slots · agent_send/receive

---

## Dosya Haritası

| Dosya | İşlem | Ne Yapıyor |
|---|---|---|
| `/root/tools-bank/scripts/start-goose-serve.sh` | CREATE | env var'larla goose serve başlatır |
| `/root/tools-bank/cmd/goused-watchdog/main.go` | MODIFY | goose serve health target ekle |
| `/root/tools-bank/mcp_server/acp_client.py` | CREATE | ACP JSON-RPC client (session/new, session/prompt, session/cancel) |
| `/root/tools-bank/internal/api/session.go` | MODIFY | acp_session_id kolonu + ACP session kayıt metotları |
| `/root/tools-bank/internal/api/handler.go` | MODIFY | /goose/acp-register + /goose/acp-update endpoint'leri |
| `/root/tools-bank/mcp_server/server.py` | MODIFY | goose_start → ACP, goose_stop ekle |

---

## Task 1: goose serve Endpoint Keşfi

> Bu task araştırma. Sonuçları Task 3'e yaz. Kod değişikliği yok.

**Files:** hiç

- [ ] **Step 1: goose serve'i test ortamında başlat**

```bash
GOOSE_PROVIDER=openai \
GOOSE_MODEL=deepseek-v4-flash \
OPENAI_HOST=http://localhost:8742 \
OPENAI_API_KEY=sk-7634e7a3d2d44b97997475cc313a4bb0 \
GOOSE_DISABLE_KEYRING=1 \
goose serve --port 3284 &
sleep 3
```

- [ ] **Step 2: Health endpoint'i bul**

```bash
curl -s http://localhost:3284/health
curl -s http://localhost:3284/
curl -s http://localhost:3284/status
```

Hangi URL 200 dönüyor? Sonucu not al — Task 2'de watchdog için lazım.

- [ ] **Step 3: session/new endpoint'ini test et**

```bash
# ACP JSON-RPC — tek endpoint testi
curl -s -X POST http://localhost:3284 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"session/new","params":{},"id":1}'

# Alternatif path'ler
curl -s -X POST http://localhost:3284/api \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"session/new","params":{},"id":1}'

curl -s -X POST http://localhost:3284/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"session/new","params":{},"id":1}'
```

Hangi URL çalışıyor? Response body'yi tam kopyala.

- [ ] **Step 4: session/prompt test et (SSE)**

Bir önceki adımda gelen `session_id`'yi kullan:

```bash
SESSION_ID="<önceki adımdan gelen id>"

curl -s -X POST http://localhost:3284 \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"session/prompt\",\"params\":{\"session_id\":\"$SESSION_ID\",\"message\":\"Say hi in one word\"},\"id\":2}" \
  --no-buffer | head -20
```

SSE event formatını not al (data: satırlarının içeriği).

- [ ] **Step 5: Goose serve'i durdur ve sonuçları belgele**

```bash
pkill -f "goose serve"
```

**Task 3 için dolduracak bilgiler:**
- Health URL: `_____________`
- ACP endpoint (POST path): `_____________`
- session/new response format: `_____________`
- session/prompt SSE event format: `_____________`
- "done" eventi nasıl anlıyoruz: `_____________`

---

## Task 2: goose serve Startup Script + Watchdog

**Files:**
- Create: `/root/tools-bank/scripts/start-goose-serve.sh`
- Modify: `/root/tools-bank/cmd/goused-watchdog/main.go`

- [ ] **Step 1: Startup script oluştur**

```bash
cat > /root/tools-bank/scripts/start-goose-serve.sh << 'EOF'
#!/usr/bin/env bash
# goose serve — env var'larla başlat (Tokio crash fix)
# goused-watchdog tarafından çağrılır

export HOME=/root
export GOOSE_PROVIDER=openai
export GOOSE_MODEL=deepseek-v4-flash
export OPENAI_HOST=http://localhost:8742
export OPENAI_API_KEY=sk-7634e7a3d2d44b97997475cc313a4bb0
export GOOSE_DISABLE_KEYRING=1
export GOOSE_RECIPE_PATH=/root/tools-bank/recipes
export GOOSE_MOIM_MESSAGE_FILE=/root/agent-os-docs/dokumanlar/AGENT_OS_TOM.md
export JINA_API_KEY=jina_a9b0ff962ff94ee98f9d7f8d4f7feee9_-qMCCMAbTSnJHf6m7vOaCGbloC0

exec goose serve --port 3284
EOF
chmod +x /root/tools-bank/scripts/start-goose-serve.sh
```

- [ ] **Step 2: Script'i test et**

```bash
/root/tools-bank/scripts/start-goose-serve.sh &
sleep 3
curl -s http://localhost:3284/health  # Task 1'den bulunan health URL'i kullan
pkill -f "goose serve"
```

Çıktı: 200 OK veya `{"status":"ok"}` benzeri bir şey olmalı.

- [ ] **Step 3: goused-watchdog'a goose serve ekle**

`/root/tools-bank/cmd/goused-watchdog/main.go` dosyasını aç.
`targets` slice'ına goose serve'i ekle. **Task 1'de bulunan health URL'ini kullan.**

```go
// Mevcut:
var targets = []target{
	{"proxy", "http://localhost:8742/health", "/root/tools-bank/bin/goused-proxy"},
	{"api", "http://localhost:8743/health", "/root/tools-bank/bin/goused-api"},
	{"telsiz", "http://localhost:8744/health", "/root/tools-bank/bin/goused-telsiz"},
}

// Değiştir (goose-serve satırını ekle):
var targets = []target{
	{"proxy", "http://localhost:8742/health", "/root/tools-bank/bin/goused-proxy"},
	{"api", "http://localhost:8743/health", "/root/tools-bank/bin/goused-api"},
	{"telsiz", "http://localhost:8744/health", "/root/tools-bank/bin/goused-telsiz"},
	{"goose-serve", "http://localhost:3284/health", "/root/tools-bank/scripts/start-goose-serve.sh"},
}
```

> **Not:** Health URL'i Task 1'de bulunan gerçek URL'e göre ayarla. Eğer `/health` yoksa `/status` veya `/` kullan.

- [ ] **Step 4: Watchdog'u rebuild et**

```bash
cd /root/tools-bank
go build -o bin/goused-watchdog ./cmd/goused-watchdog/
echo "Build: $?"
```

Çıktı: `Build: 0`

- [ ] **Step 5: Commit**

```bash
cd /root/tools-bank
git add scripts/start-goose-serve.sh cmd/goused-watchdog/main.go bin/goused-watchdog
git commit -m "feat: goose serve startup script + watchdog target"
```

---

## Task 3: ACP Client (acp_client.py)

> Task 1'in sonuçlarına göre endpoint URL ve format'ı ayarla.

**Files:**
- Create: `/root/tools-bank/mcp_server/acp_client.py`

- [ ] **Step 1: acp_client.py oluştur**

```python
# /root/tools-bank/mcp_server/acp_client.py
"""
Goose ACP JSON-RPC client.
goose serve --port 3284 ile iletişim kurar.

Task 1'den bulunan endpoint'lere göre GOOSE_SERVE_ENDPOINT ve
sağlık URL'ini ayarla.
"""
import json
import threading
import requests

GOOSE_SERVE_URL = "http://localhost:3284"
# Task 1'de hangi path çalıştıysa buraya yaz: "/" veya "/api" vb.
GOOSE_ACP_ENDPOINT = "http://localhost:3284"
GOUSED_API = "http://localhost:8743"

_rpc_id = 0
_rpc_lock = threading.Lock()


def _next_id() -> int:
    global _rpc_id
    with _rpc_lock:
        _rpc_id += 1
        return _rpc_id


def _rpc(method: str, params: dict, timeout: int = 10) -> dict:
    """Synchronous JSON-RPC call. Returns result dict or raises."""
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": _next_id(),
    }
    r = requests.post(GOOSE_ACP_ENDPOINT, json=payload,
                      headers={"Content-Type": "application/json"}, timeout=timeout)
    r.raise_for_status()
    body = r.json()
    if "error" in body:
        raise RuntimeError(f"ACP error: {body['error']}")
    return body.get("result", {})


def session_new() -> str:
    """Yeni ACP session aç. ACP session_id döner."""
    result = _rpc("session/new", {})
    # Task 1'den gelen response format'ına göre key adını ayarla
    return result.get("session_id") or result.get("id") or result.get("sessionId")


def session_cancel(acp_session_id: str) -> bool:
    """Session'ı iptal et (notification — fire-and-forget)."""
    try:
        payload = {
            "jsonrpc": "2.0",
            "method": "session/cancel",
            "params": {"session_id": acp_session_id},
            # Notification: id yok
        }
        requests.post(GOOSE_ACP_ENDPOINT, json=payload,
                      headers={"Content-Type": "application/json"}, timeout=5)
        return True
    except Exception:
        return False


def _parse_sse_done(line: bytes) -> bool:
    """SSE event'inin 'done' sinyali olup olmadığını kontrol et.
    Task 1'den öğrenilen event format'ına göre güncelle."""
    if not line.startswith(b"data:"):
        return False
    raw = line[5:].strip()
    if raw == b"[DONE]":
        return True
    try:
        evt = json.loads(raw)
        # Task 1'den öğrenilen 'done' field'ını kontrol et
        # Muhtemel: evt.get("type") == "done" veya evt.get("done") == True
        return evt.get("type") in ("done", "finish", "end") or evt.get("done") is True
    except Exception:
        return False


def session_prompt_background(
    goused_session_id: str,
    acp_session_id: str,
    instructions: str,
):
    """
    session/prompt'u arka planda gönderir, SSE yanıtı okur.
    Bitince goused-api'yi /goose/acp-update ile günceller.
    """
    def _run():
        payload = {
            "jsonrpc": "2.0",
            "method": "session/prompt",
            "params": {
                "session_id": acp_session_id,
                "message": instructions,
            },
            "id": _next_id(),
        }
        try:
            r = requests.post(
                GOOSE_ACP_ENDPOINT,
                json=payload,
                headers={
                    "Content-Type": "application/json",
                    "Accept": "text/event-stream",
                },
                stream=True,
                timeout=3600,  # max 1 saat
            )
            r.raise_for_status()

            for line in r.iter_lines():
                if _parse_sse_done(line):
                    _acp_update(goused_session_id, "done")
                    return

            # Stream bitti ama 'done' gelmediyse done say
            _acp_update(goused_session_id, "done")

        except Exception as e:
            _acp_update(goused_session_id, "crashed", str(e))

    threading.Thread(target=_run, daemon=True).start()


def _acp_update(session_id: str, status: str, error: str = ""):
    """goused-api /goose/acp-update endpoint'ine status gönder."""
    try:
        requests.post(
            f"{GOUSED_API}/goose/acp-update",
            json={"session_id": session_id, "status": status, "error": error},
            timeout=5,
        )
    except Exception:
        pass  # goused-api down olsa bile crash etme


def health() -> bool:
    """goose serve ayakta mı?"""
    try:
        r = requests.get(f"{GOOSE_SERVE_URL}/health", timeout=3)
        return r.status_code == 200
    except Exception:
        return False
```

- [ ] **Step 2: Import test et (syntax check)**

```bash
cd /root/tools-bank
python3 -c "import mcp_server.acp_client; print('OK')" 2>&1 || \
python3 -c "
import sys; sys.path.insert(0, 'mcp_server')
import acp_client; print('OK')
"
```

Çıktı: `OK`

- [ ] **Step 3: goose serve başlat ve session_new test et**

```bash
/root/tools-bank/scripts/start-goose-serve.sh >> /tmp/goose-serve.log 2>&1 &
sleep 4

python3 - << 'EOF'
import sys; sys.path.insert(0, '/root/tools-bank/mcp_server')
import acp_client
print("Health:", acp_client.health())
sid = acp_client.session_new()
print("ACP session_id:", sid)
EOF
```

Çıktı: `Health: True` ve bir session_id string.

> Eğer `session_new()` farklı bir key ile dönüyorsa (`id`, `sessionId` vb.),
> `acp_client.py`'daki `session_new()` return satırını güncelle.

- [ ] **Step 4: goose serve durdur**

```bash
pkill -f "goose serve" || true
```

- [ ] **Step 5: Commit**

```bash
cd /root/tools-bank
git add mcp_server/acp_client.py
git commit -m "feat: ACP JSON-RPC client for goose serve"
```

---

## Task 4: goused-api ACP Session Tracking

**Files:**
- Modify: `/root/tools-bank/internal/api/session.go` (acp_session_id kolonu + AcpRegister/AcpUpdate)
- Modify: `/root/tools-bank/internal/api/handler.go` (2 yeni endpoint)

- [ ] **Step 1: session.go — acp_session_id migration ekle**

`NewSessionStore` içindeki migration loop'una yeni kolon ekle (satır 77-83 civarı):

```go
// Mevcut loop:
for _, col := range []string{
    "ALTER TABLE goose_sessions ADD COLUMN tier INTEGER DEFAULT 0",
    "ALTER TABLE goose_sessions ADD COLUMN parent_session_id TEXT",
    "ALTER TABLE goose_sessions ADD COLUMN last_heartbeat TEXT",
} {
    db.Exec(col)
}

// Değiştir:
for _, col := range []string{
    "ALTER TABLE goose_sessions ADD COLUMN tier INTEGER DEFAULT 0",
    "ALTER TABLE goose_sessions ADD COLUMN parent_session_id TEXT",
    "ALTER TABLE goose_sessions ADD COLUMN last_heartbeat TEXT",
    "ALTER TABLE goose_sessions ADD COLUMN acp_session_id TEXT",
} {
    db.Exec(col)
}
```

- [ ] **Step 2: session.go — AcpRegister ve AcpUpdate metotları ekle**

`session.go` dosyasının sonuna (isAlive fonksiyonundan sonra) ekle:

```go
// AcpRegister creates a session record for an ACP-mode session (no PID).
// Called when goose_start uses goose serve instead of subprocess spawn.
func (s *SessionStore) AcpRegister(sessionID, recipe, params, acpSessionID string, tier int, parentSessionID string) error {
    _, err := s.db.Exec(
        `INSERT OR IGNORE INTO goose_sessions
         (id, recipe, pid, status, started_at, log_path, params, tier, parent_session_id, acp_session_id)
         VALUES (?, ?, 0, 'running', datetime('now'), '', ?, ?, ?, ?)`,
        sessionID, recipe, params, tier, parentSessionID, acpSessionID,
    )
    return err
}

// AcpUpdate updates the status of an ACP session from SSE listener.
func (s *SessionStore) AcpUpdate(sessionID, status string) error {
    return s.UpdateStatus(sessionID, status)
}
```

- [ ] **Step 3: handler.go — 2 yeni endpoint ekle**

`handler.go` dosyasına yeni handler fonksiyonları ekle (releaseCommitLock'tan sonra):

```go
func (h *Handler) acpRegister(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    var req struct {
        SessionID       string `json:"session_id"`
        Recipe          string `json:"recipe"`
        Params          string `json:"params"`
        AcpSessionID    string `json:"acp_session_id"`
        Tier            int    `json:"tier"`
        ParentSessionID string `json:"parent_session_id"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.SessionID == "" {
        http.Error(w, "session_id required", http.StatusBadRequest)
        return
    }
    if req.Params == "" {
        req.Params = "{}"
    }
    if err := h.store.AcpRegister(req.SessionID, req.Recipe, req.Params, req.AcpSessionID, req.Tier, req.ParentSessionID); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    json.NewEncoder(w).Encode(map[string]string{"status": "registered"})
}

func (h *Handler) acpUpdate(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    var req struct {
        SessionID string `json:"session_id"`
        Status    string `json:"status"`
        Error     string `json:"error"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.SessionID == "" || req.Status == "" {
        http.Error(w, "session_id and status required", http.StatusBadRequest)
        return
    }
    if req.Status != "running" && req.Status != "done" && req.Status != "crashed" && req.Status != "stopped" {
        http.Error(w, "invalid status", http.StatusBadRequest)
        return
    }
    if err := h.store.AcpUpdate(req.SessionID, req.Status); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    if req.Error != "" {
        log.Printf("[api] ACP session %s error: %s", req.SessionID, req.Error)
    }
    json.NewEncoder(w).Encode(map[string]string{"status": "updated"})
}
```

- [ ] **Step 4: handler.go — RegisterWithRecovery'ye 2 yeni route ekle**

`RegisterWithRecovery` içindeki route slice'ına ekle:

```go
// Mevcut son 2 satır:
{"POST /goose/stop-tree/{id}", h.stopTree},
{"POST /goose/heartbeat/{id}", h.heartbeat},

// Değiştir (2 satır ekle):
{"POST /goose/stop-tree/{id}", h.stopTree},
{"POST /goose/heartbeat/{id}", h.heartbeat},
{"POST /goose/acp-register", h.acpRegister},
{"POST /goose/acp-update", h.acpUpdate},
```

- [ ] **Step 5: goused-api'yi rebuild et**

```bash
cd /root/tools-bank
go build -o bin/goused-api ./cmd/goused-api/
echo "Build: $?"
```

Çıktı: `Build: 0`

- [ ] **Step 6: Rebuild binary'yi test et**

```bash
# Kısa test: binary başlıyor mu?
/root/tools-bank/bin/goused-api &
sleep 2
curl -s http://localhost:8743/health
kill %1 2>/dev/null || true
```

Çıktı: `{"status":"ok"}`

- [ ] **Step 7: Commit**

```bash
cd /root/tools-bank
git add internal/api/session.go internal/api/handler.go bin/goused-api
git commit -m "feat: goused-api ACP session tracking (acp-register, acp-update endpoints)"
```

---

## Task 5: server.py — goose_start Rewrite + goose_stop Ekle

**Files:**
- Modify: `/root/tools-bank/mcp_server/server.py` (satır 1475-1497 civarı)

- [ ] **Step 1: Recipe YAML parser helper ekle**

`server.py`'ye import bölümünün altına (diğer import'ların yanına) ekle.
Dosyanın başındaki import satırlarını bul ve `yaml` import'u ekle:

```python
import yaml  # recipe YAML parse için
```

Ardından `GOUSED_API` sabiti tanımlandıktan sonra helper fonksiyon ekle:

```python
def _load_recipe_instructions(recipe: str, params_dict: dict) -> str:
    """
    Recipe YAML'ından instructions'ı yükler.
    Params değerlerini {param_name} placeholder'larına yerleştirir.
    """
    import os, yaml
    recipe_path = f"/root/tools-bank/recipes/{recipe}.yaml"
    if not os.path.exists(recipe_path):
        return f"Recipe bulunamadı: {recipe}"
    with open(recipe_path) as f:
        data = yaml.safe_load(f)
    instructions = data.get("instructions", "")
    # {agent_id} gibi placeholder'ları gerçek değerlerle doldur
    for k, v in params_dict.items():
        instructions = instructions.replace("{" + k + "}", str(v))
    return instructions
```

- [ ] **Step 2: yaml paketi kontrol et**

```bash
python3 -c "import yaml; print('ok')"
```

Çıktı: `ok`. Eğer hata alırsan: `pip3 install pyyaml`

- [ ] **Step 3: goose_start'ı ACP modeline geçir**

`server.py`'deki mevcut `goose_start` fonksiyonunu bul (satır ~1481):

```python
# ESKİ (SİL):
@mcp.tool()
def goose_start(recipe: str, session_id: str, params: str = "{}") -> str:
    """Goose worker başlat"""
    try:
        return json.dumps(requests.post(f"{GOUSED_API}/goose/start",
            json={"recipe": recipe, "session_id": session_id, "params": json.loads(params)},
            timeout=5).json())
    except Exception as e:
        return json.dumps({"error": f"goused-api unavailable: {e}"})
```

YENİ kod ile değiştir:

```python
@mcp.tool()
def goose_start(recipe: str, session_id: str, params: str = "{}",
                tier: int = 1, parent_session_id: str = "") -> str:
    """
    Goose worker başlat — goose serve ACP modu (Tokio crash yok).
    recipe: /root/tools-bank/recipes/ altındaki YAML dosyasının adı (uzantısız)
    session_id: benzersiz tanımlayıcı (örn: 'task-fix-001')
    params: JSON string (örn: '{"agent_id":"worker-1"}')
    """
    import sys as _sys
    _sys.path.insert(0, '/root/tools-bank/mcp_server')
    import acp_client

    try:
        params_dict = json.loads(params) if params else {}
    except Exception:
        params_dict = {}

    # 1. goose serve sağlık kontrolü
    if not acp_client.health():
        return json.dumps({"error": "goose serve unavailable — start with: /root/tools-bank/scripts/start-goose-serve.sh"})

    # 2. ACP session aç
    try:
        acp_session_id = acp_client.session_new()
    except Exception as e:
        return json.dumps({"error": f"session/new failed: {e}"})

    if not acp_session_id:
        return json.dumps({"error": "session/new returned empty session_id"})

    # 3. goused-api'ye kaydet (status tracking için)
    try:
        requests.post(f"{GOUSED_API}/goose/acp-register", json={
            "session_id": session_id,
            "recipe": recipe,
            "params": params,
            "acp_session_id": acp_session_id,
            "tier": tier,
            "parent_session_id": parent_session_id,
        }, timeout=5)
    except Exception as e:
        return json.dumps({"error": f"goused-api unavailable: {e}"})

    # 4. Recipe instructions yükle ve arka planda gönder
    instructions = _load_recipe_instructions(recipe, params_dict)
    acp_client.session_prompt_background(session_id, acp_session_id, instructions)

    return json.dumps({
        "session_id": session_id,
        "acp_session_id": acp_session_id,
        "status": "running",
        "mode": "acp",
    })
```

- [ ] **Step 4: goose_stop ekle (session/cancel)**

`goose_status` fonksiyonundan sonra yeni `goose_stop` ekle:

```python
@mcp.tool()
def goose_stop(session_id: str) -> str:
    """
    Goose session'ı durdur — ACP session/cancel + goused-api stop.
    """
    import sys as _sys
    _sys.path.insert(0, '/root/tools-bank/mcp_server')
    import acp_client

    # ACP session_id'yi goused-api'den al
    try:
        sess = requests.get(f"{GOUSED_API}/goose/status/{session_id}", timeout=5).json()
        acp_session_id = sess.get("acp_session_id", "")
        if acp_session_id:
            acp_client.session_cancel(acp_session_id)
    except Exception:
        pass  # best effort

    # goused-api'de de durdur
    try:
        requests.post(f"{GOUSED_API}/goose/stop/{session_id}", timeout=5)
    except Exception:
        pass

    return json.dumps({"session_id": session_id, "status": "stopped"})
```

- [ ] **Step 5: Session struct'ına acp_session_id ekle (goused-api JSON response)**

`session.go`'daki `Session` struct'ına yeni field ekle (satır ~20):

```go
// Mevcut Son:
type Session struct {
    ID              string  `json:"id"`
    Recipe          string  `json:"recipe"`
    PID             int     `json:"pid"`
    Status          string  `json:"status"`
    StartedAt       string  `json:"started_at"`
    EndedAt         *string `json:"ended_at,omitempty"`
    LogPath         string  `json:"log_path"`
    Params          string  `json:"params"`
    Tier            int     `json:"tier"`
    ParentSessionID string  `json:"parent_session_id,omitempty"`
    LastHeartbeat   *string `json:"last_heartbeat,omitempty"`
}

// Değiştir (AcpSessionID ekle):
type Session struct {
    ID              string  `json:"id"`
    Recipe          string  `json:"recipe"`
    PID             int     `json:"pid"`
    Status          string  `json:"status"`
    StartedAt       string  `json:"started_at"`
    EndedAt         *string `json:"ended_at,omitempty"`
    LogPath         string  `json:"log_path"`
    Params          string  `json:"params"`
    Tier            int     `json:"tier"`
    ParentSessionID string  `json:"parent_session_id,omitempty"`
    LastHeartbeat   *string `json:"last_heartbeat,omitempty"`
    AcpSessionID    string  `json:"acp_session_id,omitempty"`
}
```

`Get` ve `List` metodlarında `acp_session_id`'yi Scan'e ekle:

`Get` metodunda (satır ~150), SELECT sorgusuna ve Scan'a ekle:

```go
// SELECT sorgusunu güncelle:
row := s.db.QueryRow(
    `SELECT id, recipe, pid, status, started_at, ended_at, log_path, params, tier, parent_session_id, last_heartbeat, COALESCE(acp_session_id,'')
     FROM goose_sessions WHERE id = ?`, id,
)

// Scan'e ekle (var acpSessionID string ekle):
var acpSessionID string
err := row.Scan(&sess.ID, &sess.Recipe, &sess.PID, &sess.Status,
    &sess.StartedAt, &endedAt, &sess.LogPath, &sess.Params,
    &sess.Tier, &parentSessionID, &lastHeartbeat, &acpSessionID)
// Scan'den sonra:
sess.AcpSessionID = acpSessionID
```

`List` metodunda da aynı şekilde SELECT ve Scan'i güncelle.

- [ ] **Step 6: goused-api rebuild**

```bash
cd /root/tools-bank
go build -o bin/goused-api ./cmd/goused-api/
echo "Build: $?"
```

Çıktı: `Build: 0`

- [ ] **Step 7: Commit**

```bash
cd /root/tools-bank
git add mcp_server/server.py internal/api/session.go bin/goused-api
git commit -m "feat: goose_start → ACP mode, goose_stop eklendi, acp_session_id tracking"
```

---

## Task 6: Entegrasyon Testi + Deploy

**Files:** hiç (test + deploy)

- [ ] **Step 1: Tüm servisleri başlat**

```bash
# Önce mevcut servisleri durdur
pkill -f "goused-api" || true
pkill -f "goose serve" || true
sleep 2

# goose serve başlat
/root/tools-bank/scripts/start-goose-serve.sh >> /tmp/goose-serve.log 2>&1 &
sleep 4

# goused-api başlat
nohup /root/tools-bank/bin/goused-api >> /tmp/goused-api.log 2>&1 &
sleep 2
```

- [ ] **Step 2: Servis sağlık kontrolü**

```bash
curl -s http://localhost:8743/health && echo " goused-api OK"
curl -s http://localhost:3284/health && echo " goose-serve OK"  # Task 1'den health URL
```

Her ikisi de OK dönmeli.

- [ ] **Step 3: goose_start entegrasyon testi**

```bash
python3 - << 'EOF'
import sys; sys.path.insert(0, '/root/tools-bank/mcp_server')
import json, requests

# goused MCP tool'unu simüle et
import server
result = server.goose_start(
    recipe="health_check",
    session_id="test-acp-001",
    params="{}"
)
print("goose_start:", result)

import time; time.sleep(5)

result2 = server.goose_status(session_id="test-acp-001")
print("goose_status:", result2)
EOF
```

Beklenen:
```
goose_start: {"session_id": "test-acp-001", "acp_session_id": "...", "status": "running", "mode": "acp"}
goose_status: {"id": "test-acp-001", "status": "running", ...}
```

- [ ] **Step 4: 30 saniye bekle, status done mu?**

```bash
sleep 30
python3 -c "
import sys; sys.path.insert(0, '/root/tools-bank/mcp_server')
import server
print(server.goose_status('test-acp-001'))
"
```

Beklenen: `"status": "done"` (health_check recipe hızlı biter)

- [ ] **Step 5: /tmp/goose-serve.log kontrol et**

```bash
tail -30 /tmp/goose-serve.log
```

**Tokio crash satırı olmamalı:**
```
thread 'tokio-rt-worker' panicked  ← BU OLMAMALI
```

- [ ] **Step 6: Watchdog restart et**

```bash
pkill -f "goused-watchdog" || true
sleep 1
nohup /root/tools-bank/bin/goused-watchdog >> /tmp/goused-watchdog.log 2>&1 &
echo "Watchdog başlatıldı"
```

- [ ] **Step 7: Final commit**

```bash
cd /root/tools-bank
git add bin/goused-watchdog
git commit -m "chore: goused binaries rebuild with ACP support"

cd /root/egesut-erp1
git add docs/
git commit -m "docs: goose serve migration plan tamamlandı"
```

---

## Sorun Giderme

**goose serve sağlık URL'i bulunamıyorsa:**
```bash
# goose serve'in hangi port/path'te dinlediğini gör
curl -v http://localhost:3284/ 2>&1 | head -30
```

**session/new endpoint farklı path'teyse:**
`acp_client.py`'de `GOOSE_ACP_ENDPOINT`'i düzenle.

**SSE "done" eventi farklı formattaysa:**
`acp_client.py`'deki `_parse_sse_done` fonksiyonunu güncelle.

**yaml import hatası:**
```bash
pip3 install pyyaml
```

**goused-api go build hatası (acp_session_id scan column sayısı uyuşmazsa):**
`Get` ve `List` metotlarındaki Scan çağrılarında column sayısını kontrol et.
