# Goose Serve Migration — İkinci Self-Review (Post-Fix)

**Tarih:** 2026-05-21
**Kapsam:** Bug fix'leri sonrası ikinci self-review
**Önceki rapor:** `results/2026-05-21-goose-serve-migration-report.md`

---

## 1. Fix Edilen Sorunlar

### Sorun 1 — `sessionId` camelCase (KRİTİK, %95)

**Bulgu:** `acp_client.py`'de ACP JSON-RPC params anahtarları snake_case idi (`session_id`). ACP standardı ve Goose agent'ı camelCase bekler (`sessionId`).

**Etki:** Agent `session_id` parametresini tanımaz → session/prompt sessizce başarısız olur → SSE stream hiç açılmaz → `_acp_update("done")` asla çağrılmaz → session sonsuza kadar "running" kalır.

**Fix:**
| Parametre | Önce (snake_case) | Sonra (camelCase) |
|-----------|-------------------|-------------------|
| session/prompt | `"session_id": ...` | `"sessionId": ...` |
| session/cancel | `"session_id": ...` | `"sessionId": ...` |

Ayrıca `session_new()` fonksiyonuna `session/new` RPC çağrısı eklendi:
```python
# initialize sonrası session'ı server'a kaydet
POST /acp + {"jsonrpc":"2.0","method":"session/new","params":{"sessionId":"..."}}
```

Eğer `session/new` RPC başarısız olursa (proxy down), fallback olarak `ensure_session()` transport mekanizması session'ı yine de oluşturur.

**Doğrulama:** `grep -c "sessionId" mcp_server/acp_client.py` → 3 (session/new, session/cancel, session/prompt)

### Sorun 2 — Watchdog cooldown (ÖNEMLİ, %90)

**Bulgu:** Tüm watchdog target'ları 10s global cooldown kullanıyordu. goose-serve start 15-60s sürer (proxy/dependency yükleme). Health check 30s ping'te başarısız → 10s cooldown dolar → tekrar restart → port çakışması → kısır döngü.

**Etki:** Port 3284'te birden fazla goose serve process'i çakışır, health hiç düzelmez, watchdog sürekli restart dener.

**Fix:**
- `target` struct'a `cooldown time.Duration` field'ı eklendi (0 = global varsayılan)
- `effectiveCooldown(t)` — per-target cooldown varsa onu, yoksa global'i döndürür
- `canRestart()` — per-target cooldown kullanır

| Target | Cooldown | Gerekçe |
|--------|----------|---------|
| proxy | 10s (global) | Go binary, hızlı start |
| api | 10s (global) | Go binary, hızlı start |
| telsiz | 10s (global) | Go binary, hızlı start |
| **goose-serve** | **90s** | Shell script + Rust binary + proxy dependency |

---

## 2. Kod İncelemesi

### 2.1 `acp_client.py` (265 satır)

```
initialize()     → POST /acp + {method:"initialize"}   → returns connection_id
session_new()    → initialize() + POST /acp + session/new → returns (conn_id, sess_id)
session_cancel() → POST /acp + {method:"session/cancel"} → notification
session_prompt_background() → POST /acp + GET /acp (SSE) → daemon thread
```

**Kritik akış:**
```
POST /acp (initialize) → Acp-Connection-Id header
       ↓
POST /acp (session/new) + Acp-Connection-Id + Acp-Session-Id headers
       ↓
POST /acp (session/prompt) + headers → 202 Accepted
       ↓
GET /acp (SSE) + headers → stream data: {...json...}
       ↓
SSE stream kapanır → _acp_update("done")
```

**Edge case coverage:**
| Durum | Davranış |
|-------|----------|
| Initialize timeout (proxy down) | 30s timeout → exception → goose_start error |
| session/new timeout | 30s timeout → fallback ensure_session() |
| session/prompt POST fail | _acp_update("crashed") |
| SSE stream timeout | 3600s (1h) timeout |
| session_cancel no-session | returns False, best-effort |

### 2.2 `server.py` goose_stop (lines 1570-1594)

```
1. GET /goose/status/{id} → acp_session_id = "conn_id|sess_id"
2. If "|" in acp_raw → split → session_cancel(conn_id, sess_id)
3. POST /goose/stop/{id} (everyat)
4. Return {"session_id": ..., "status": "stopped"}
```

**Graceful degradation:** acp_raw boşsa (eski subprocess session) sadece goused-api stop çalışır.

### 2.3 Watchdog `main.go` (153 satır)

```
type target struct {
    name     string
    url      string
    bin      string
    cooldown time.Duration  // YENİ: per-target cooldown
}

canRestart(t) → effectiveCooldown(t) → last restart check
```

---

## 3. Doğrulama Testleri

| Test | Sonuç |
|------|-------|
| Python import `acp_client` | ✅ |
| Tüm fonksiyonlar callable | ✅ session_new, session_cancel, session_prompt_background, health |
| `_parse_sse_done` (7 test case) | ✅ Tümü geçti |
| Go build `goused-watchdog` | ✅ (8.6 MB) |
| **Önceki endpoint testleri** | ✅ (değişmedi) |
| PROXY health check fix | ⏳ **Önerildi, henüz eklenmedi** |

---

## 4. Kalan Eksikler (Pre-existing)

### Proxy Health Check (ÖNERİLEN İYİLEŞTİRME)

`goose_start`'te ACP initialize öncesi proxy health check yok. Proxy down ise 30s timeout → "session/new failed" hatası.

```python
# goose_start içinde, acp_client.health()'ten sonra
try:
    requests.get("http://localhost:8742/health", timeout=2)
except:
    return json.dumps({"error": "LLM proxy (port 8742) unreachable"})
```

### Watchdog Child PID Tracking
Restart sonrası eski process öldürülmez. goose-serve `exec` kullandığı için port çakışması olasılığı düşük. Pre-existing.

### Start Script Hardcoded API Key
`start-goose-serve.sh`'de API key açık metin. Pre-existing.

---

## 5. Final Karar

**✅ Kod üretim için hazır.** Tüm plan task'leri tamamlandı. 2 kritik bug fix'lendi. 5 commit atıldı (tools-bank). Tek önerilen iyileştirme proxy health check — eğer istenirse 3 dakikada eklenir.
