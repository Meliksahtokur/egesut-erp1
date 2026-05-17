---
name: goused
description: Use when orchestrating Goose workers, sending/receiving agent messages via telsiz, managing goused binaries (proxy/api/telsiz/watchdog), or coordinating multi-agent workflows. Trigger on: goose_start, goose_status, agent_register, agent_send, agent_receive, telsiz, goused, "goose worker başlat", "agent mesaj gönder/bekle", "direktif gönder", "sonuç bekle". Also use when checking if goused binaries are running or need restart.
---

# goused — Kullanım Kılavuzu

Tam dokümantasyon: `/root/tools-bank/docs/USAGE_GUIDE.md` § 8

## Binary'ler

| Binary | Port | Sorumluluk |
|---|---|---|
| goused-proxy | 8742 | DeepSeek API proxy — `thinking:disabled` inject |
| goused-api | 8743 | Goose process manager |
| goused-telsiz | 8744 | Agent mesaj kuyruğu (long-poll SQLite) |
| goused-watchdog | — | 30s health ping, otomatik restart |

### Durum Kontrolü

```bash
curl -s http://localhost:8742/health
curl -s http://localhost:8743/health
curl -s http://localhost:8744/health
```

### Başlatma (hepsi down ise)

```bash
nohup /root/tools-bank/bin/goused-proxy   >> /tmp/goused-proxy.log   2>&1 &
nohup /root/tools-bank/bin/goused-api     >> /tmp/goused-api.log     2>&1 &
nohup /root/tools-bank/bin/goused-telsiz  >> /tmp/goused-telsiz.log  2>&1 &
nohup /root/tools-bank/bin/goused-watchdog >> /tmp/goused-watchdog.log 2>&1 &
```

---

## MCP Tool'ları

### Goose Process Manager (:8743)

```
goose_start(recipe, session_id, params="{}")
  Goose worker başlatır. params JSON string.
  → {"session_id":"...", "pid":..., "log_path":"/tmp/goose-X.log", "status":"running"}

goose_status(session_id)
  → {"status": "running|done|crashed|stopped", "pid":..., ...}
```

**Log takibi:** `tail -f /tmp/goose-{session_id}.log`

### Telsiz — Mesaj Kuyruğu (:8744)

```
agent_register(agent_id, capabilities)
  capabilities: JSON string → '["implement","sql","review"]'
  → {"agent_id":"...", "status":"registered"}

agent_send(to, from_, message, message_type="task", priority="normal", reply_to="")
  message_type: task|result|question|answer|approval_req|broadcast|heartbeat
  priority: high|normal|low  (high → cooldown atlar)
  → {"id":"uuid", "status":"queued"}

agent_receive(agent_id, timeout=30)
  Long-poll: timeout süresi boyunca mesaj bekler.
  Mesaj: {"id":..., "from_agent":..., "message":..., "message_type":..., "read":1, ...}
  Timeout: {"message": null, "timeout": true}
```

---

## Tipik Akışlar

### 1. Goose Worker Orkestrasyon

```python
# Worker başlat
goose_start(recipe="egesut-telsiz", session_id="task-001",
            params='{"agent_id":"erp-worker-1"}')

# Direktif gönder
agent_send(to="erp-worker-1", from_="claude",
           message="hayvan formunu güncelle — spec: ...",
           message_type="task")

# Sonuç bekle (worker agent_send(type=result) ile cevap verir)
result = agent_receive(agent_id="claude", timeout=120)
# → {"message": "TAMAMLANDI: a3b4c5d — hayvan_guncelle RPC eklendi"}

# Session durumu
goose_status(session_id="task-001")
```

### 2. Orkestratör olarak Claude

```python
# Kendini kaydet
agent_register(agent_id="claude", capabilities='["orchestrate","review","plan"]')

# Alt agent'a görev ver
agent_send(to="erp-worker-1", from_="claude",
           message="görev açıklaması", message_type="task")

# Yanıt bekle
msg = agent_receive(agent_id="claude", timeout=60)
if msg["timeout"]:
    # Agent cevap vermedi — goose_status ile kontrol et
```

### 3. Soru-Cevap (question/answer)

```python
# Soru sor
agent_send(to="erp-worker-1", from_="claude",
           message="Bu RPC'yi idempotent yapalım mı?",
           message_type="question")

# Cevap bekle
answer = agent_receive(agent_id="claude", timeout=30)
# reply_to ile thread takibi yapılabilir
```

---

## Spam Önleme

| Kural | Limit |
|---|---|
| Dedup | Aynı (from, to, mesaj) 5s içinde → 409 |
| Cooldown | Aynı (from, to) 3s içinde → 429 (high atlar) |
| Rate limit | task:10/dk, question:20/dk, heartbeat:3/dk |

**TTL (saniye):** task:86400 · result:604800 · question/answer:3600 · heartbeat:300

---

## Hata Durumu

goused down ise tüm tool'lar:
```json
{"error": "goused-api unavailable: ..."}
```
MCP crash yapmaz. Health check yap, gerekirse binary'yi başlat.
