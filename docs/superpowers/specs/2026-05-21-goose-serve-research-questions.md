# Goose Serve / ACP — Araştırma Soruları ve Cevapları

**Amaç:** goused-api'nin exec.Cmd spawn modelini `goose serve` ACP daemon'una geçirmek için
gerekli bilgileri topla.

**Kaynaklar:** Gemini + Grok + GPT araştırması (2026-05-21)  
**Referans docs:** goose-docs.ai, github.com/block/goose, agentcommunicationprotocol.dev

---

## ⚠️ En Kritik Bulgular (Önce Oku)

1. **goose serve API'si mature/documented değil** — production-grade entegrasyon için source code inspection şart (axum/warp router, session state manager, extension loading lifecycle)
2. **Session persistence yok** — `goose serve` restart olursa session history kaybolur. goused-api'nin SQLite session tablosu hala gerekli.
3. **REST endpoint yok** — Geleneksel `POST /sessions/{id}/messages` değil, JSON-RPC 2.0 method çağrısı. Tek endpoint üzerinden.
4. **Env var → daemon startup'ta inject** — Per-session env injection documented değil. `DEERFLOW_ADMIN_EMAIL=... goose serve` ile başlatmak gerekiyor.
5. **Recipe → system prompt** — Serve modunda recipe YAML doğrudan desteklenmiyor, system prompt / initial message'a map etmek gerekiyor.

---

## Bölüm 1 — goose serve vs goose acp Farkı

**Bilinen:**
- `goose serve` → HTTP + WebSocket server, port 3284, network daemon
- `goose acp` → stdio transport (başka bir ACP orchestrator'ın Goose'u subprocess embed ettiği durum)
- Her ikisi de ACP protokolünü implement ediyor, transport farklı

### S1: ACP feature farkı

**CEVAP:** Her ikisi de aynı JSON-RPC 2.0 tabanlı ACP core'u implement eder. Fark sadece transport:

| | `goose acp` | `goose serve` |
|---|---|---|
| Transport | stdio + JSON-RPC | HTTP + WebSocket/SSE |
| Kullanım | Editor/IDE embedding (Zed, JetBrains) | External client, daemon, otomasyon |
| Session persistence | Yok | Yok |
| Session lifecycle | Client-managed | Client-managed |

Session lifecycle, tool calls, streaming davranışı aynı (ACP spec'e bağlı).

### S2: Multi-session desteği

**CEVAP:** Evet, `goose serve` eşzamanlı birden fazla session destekliyor. ACP architecture concurrent session mantığı üzerine kurulu. Explicit hard limit yok (Rust/Tokio tabanlı, resource ile sınırlı).

### S3: HTTP endpoint listesi

**CEVAP:** Geleneksel REST yok. Tüm iletişim JSON-RPC 2.0, tek endpoint üzerinden method çağrısı:

```
POST /  (veya /acp)  ← tek endpoint, body'de JSON-RPC method

Methods:
  session/new     → Yeni session aç (session_id döner)
  session/load    → Mevcut session'ı history ile yükle
  session/prompt  → Mesaj gönder (system prompt veya user message)
  session/cancel  → Devam eden prompt/tool işlemini iptal et (notification)
```

**Dikkat:** Resmi endpoint dokümantasyonu zayıf. Source inspection gerekiyor:
- `crates/goose-acp/` router definitions
- axum/warp route handler'ları

### S4: Streaming modeli

**CEVAP:** SSE (Server-Sent Events) veya WebSocket. Long-polling kullanılmıyor.

Server → Client event tipleri:
- `AgentMessageChunk` — metin akışı
- `ToolCall` — tool başladı
- `ToolCallUpdate` — tool durum güncellemesi

goused-api'deki long-poll modeli SSE/WS subscription'a dönüşecek.

---

## Bölüm 2 — Process ve Session Yönetimi

### S5: Max concurrent session

**CEVAP:** Belgelenmiş hard limit yok. Rust/Tokio mimarisi yüksek concurrency için tasarlanmış. Pratik limit: MCP tool call yoğunluğu (özellikle bash/file subprocess açıyorsa).

### S6: Tool call context (working directory)

**CEVAP:** ⚠️ **Kritik risk.** Tool call'lar (file_write, bash vb.) daemon'un başlatıldığı cwd ve env'de çalışıyor. Subprocess spawn'daki process-level izolasyon yok.

**Sonuç:** Cross-session contamination riski var. Session bazlı cwd isolation, goused-api katmanında implement edilmeli.

### S7: Session crash davranışı

**CEVAP:** Daemon modeli → session-level isolation hedefleniyor. Goose reposunda SIGCHLD race condition ve subprocess zombie fix'leri yapılmış (son sürümlerde). Ana process ayakta kalmalı.

**Tahmin:** Tokio worker thread paniklemesi genel olarak server'ı öldürmez — ama test edilmeli.

### S8: Restart sonrası session

**CEVAP:** ⚠️ **Kritik.** ACP docs açık: "sessions are not persisted between client restarts." Restart sonrası session history kaybolur.

**Sonuç:** goused-api'nin SQLite `goose_sessions` tablosu silinmemeli. Session metadata (recipe, params, session_id) goused'da tutulacak. Resume için `session/load` kullanılabilir ama history external'da saklanmalı.

---

## Bölüm 3 — MCP ve Extension Konfigürasyonu

### S9: MCP loading

**CEVAP:** `goose serve` global config'i okur:
- `~/.config/goose/config.yaml` otomatik yükleniyor
- `--with-builtin developer,memory` flag'i de çalışıyor

**Env var aktarımı:** Per-session env injection documented değil. Doğru yaklaşım:
```bash
DEERFLOW_ADMIN_EMAIL=admin@example.com \
DEERFLOW_ADMIN_PASSWORD=DeerFlow2026! \
JINA_API_KEY=... \
goose serve --port 3284
```
→ Daemon startup env'i tüm session'lara inherit oluyor.

**tools-bank ve duckduckgo MCP:** config.yaml'daki tanım serve modunda da çalışmalı. Test edilmeli.

### S10: Recipe desteği

**CEVAP:** Serve modunda recipe YAML doğrudan desteklenmiyor. Mapping:

```yaml
# CLI (goose run)
recipe:
  instructions: "hayvanı güncelle..."
  params: {task_id: "001"}
```

```json
// ACP (goose serve) karşılığı
{
  "method": "session/prompt",
  "params": {
    "role": "system",
    "content": "hayvanı güncelle... task_id: 001"
  }
}
```

goused-api, recipe YAML'ı parse edip system prompt'a çeviren bir katman eklenmeli.

### S11: --with-builtin flag

**CEVAP:** Goose'un kendi internal tool'larını aktive etmek için (developer, computercontroller, memory vb.). External MCP'ler (tools-bank) config.yaml üzerinden yüklendiğinde bu flag'e gerek yok veya çakışmayı önlemek için bazıları devre dışı bırakılabilir.

---

## Bölüm 4 — Authentication ve Güvenlik

### S12: Auth gereksinimi

**CEVAP:** Localhost'ta default "no-op" — token gerektirmiyor. Aynı makinedeki Go/Python client doğrudan istek atabilir. (v1.34+ credential yönetimi ACP'ye eklenmeye başlanmış ama lokal entegrasyonda bloklayıcı değil.)

### S13: CORS

**CEVAP:** Browser kullanılmadığı için (Go/Python client) CORS önemsiz.

---

## Bölüm 5 — Pratik Entegrasyon (goused-api → ACP Mapping)

### S14: goose_start → ACP mapping

```
goused-api             ACP equivalent
─────────────────────────────────────
goose_start(           session/new  →  session_id
  recipe,            + session/prompt (system prompt = recipe instructions)
  session_id,          session_id = ACP session_id (goused saklar)
  params             + params → prompt context'e gömülür
)
```

### S15: goose_status → ACP

**CEVAP:** Polling endpoint yok. İki seçenek:
1. **SSE/WS listener** — session boyunca bağlantı açık, event'leri dinle
2. **goused-api internal state** — gelen event'leri SQLite'a yaz, `goose_status` oradan okusun

Öneri: goused-api persistent bir goroutine ile SSE dinler, status'u kendi DB'sine yazar.

### S16: Force stop

**CEVAP:** `session/cancel` JSON-RPC notification'ı. Mevcut prompt/tool işlemini keser. DELETE REST endpoint yok.

Cascade kill için: `session/cancel` + gerekirse `goose serve` process'ine SIGTERM.

### S17: Benzer projeler

**CEVAP:** Ecosystem immature — public örnek çok az. Zed/JetBrains entegrasyonları var ama onlar stdio (goose acp). goose serve üzerinde custom client örneği neredeyse yok.

**Sonuç:** Source code okumak en güvenilir yol.

---

## Bölüm 6 — Python/Go Doğrudan HTTP Client Yaklaşımı

### S18: Mümkün mü?

**CEVAP:** Mimarisi olarak mümkün ve önerilen yön. Ancak:

- ACP spec evolving (experimental)
- `goose serve` HTTP surface documented değil → source inspection şart
- Doğrudan reverse-engineering kırılgan olabilir (API değişirse)

**Önerilen yaklaşım:**
```
tools-bank MCP server (Python)
  ├── goose_session_start(recipe, params) → JSON-RPC session/new + session/prompt
  ├── goose_session_send(session_id, message) → JSON-RPC session/prompt
  └── goose_session_status(session_id) → goused SQLite'tan (SSE listener goroutine)
```

Go'da mevcut goused-api'yi yeniden yazmak yerine Python MCP tool'larına eklemek daha hızlı.

---

## Mimari Karşılaştırma (Özet)

```
MEVCUT (kırık)
Claude → goused MCP → goused-api (Go) → exec.Cmd → goose run → Tokio CRASH

HEDEF
Claude → goused MCP → tools-bank Python → HTTP JSON-RPC → goose serve (daemon, persistent)
                     └── goused-api (Go, sadece commit lock + telsiz + tier slots)
```

**Korunacaklar:** commit lock, goused-telsiz, heartbeat watchdog, tier slot enforcement  
**Değişecek:** goose spawn → ACP HTTP session

---

## Sonraki Adımlar

1. `goose --version` kontrol et (v1.30+ serve desteği daha güçlü)
2. `crates/goose-acp/src/` source'unu oku — router, endpoint, session manager
3. `goose serve` başlat, curl ile `session/new` test et
4. tools-bank MCP'ye `goose_session_*` tool'ları ekle (Python, ~100 satır)
5. goused-api'ye SSE listener goroutine ekle (status tracking)
6. goused watchdog'a `goose serve` process'i ekle (restart on crash)
