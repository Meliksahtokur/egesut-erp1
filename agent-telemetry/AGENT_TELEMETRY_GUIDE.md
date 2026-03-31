# 🎯 Agent Telemetry & DB Monitoring — Quick Start

## 📊 Sistem Özeti

**Amaç:** Coder Agent'ın kullanıcı testlerini gerçek zamanlı izlemesi ve DB değişiklikleri ile karşılaştırması.

---

## 🏗️ Mimari

```
┌─────────────────────────────────────────────────────────────┐
│  Browser (Tablet/PC)                                        │
│  http://localhost:8080                                      │
│  - tracker.js (auto session tracking)                       │
│  - window.agentTestSession (otomatik başlar/biter)          │
└─────────────────────┬───────────────────────────────────────┘
                      │ WebSocket
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  Telemetry Server (port 3002)                               │
│  - agent-telemetry/server.js                                │
│  - events.jsonl (browser event log)                         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  Agent Event Reader                                         │
│  - agent-telemetry/agent-event-reader.js                    │
│  - readAgentEvents() — incremental okuma                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────────────────────┐
│  Supabase MCP Tools                                         │
│  - get_db_telemetry(startTime, endTime)                     │
│  - verify_transaction_integrity(tip, refId)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Başlangıç

### 1. Server'ları Başlat

```bash
# EgeSüt HTTP Server
cd /root/egesut-erp1
python3 -m http.server 8080 --bind 0.0.0.0

# Telemetry WebSocket Server
cd /root/egesut-erp1/agent-telemetry
node server.js
```

**Port'lar:**
- EgeSüt: `http://localhost:8080`
- Telemetry: `ws://localhost:3002` (dinamik, 3002-3006 arası bulur)

### 2. Browser'da Test Et

**Tablet/PC:**
```
http://localhost:8080
```

**Otomatik Session Tracking:**
- Sayfa açılınca → Session otomatik başlar ✅
- Sayfa kapanınca → Session otomatik biter ✅
- Konsol gerekmez!

### 3. Agent Okur

**Browser Event'leri:**
```javascript
import { readAgentEvents } from './agent-telemetry/agent-event-reader.js';

const events = readAgentEvents();
// events.hasNew, events.summary, events.context
```

**DB Telemetry (MCP):**
```javascript
// Session timestamp'lerini al
const ts = window.agentTestSession.getTimestamps();

// DB değişikliklerini çek
const dbEvents = await mcp__gwen-supabase__get_db_telemetry(
  ts.startTime,
  ts.endTime
);

// Transaction integrity check
const integrity = await mcp__gwen-supabase__verify_transaction_integrity(
  "TOHUMLAMA",  // İşlem tipi
  "ref_id_123"  // Referans ID
);
```

---

## 📁 Dosya Yapısı

```
agent-telemetry/
├── server.js                 # WebSocket server (port 3002)
├── tracker.js                # Browser inject (auto session)
├── agent-event-reader.js     # Incremental okuma
├── events.jsonl              # Browser event log
├── .agent-state.json         # Session state
└── README.md

gwen-mcp-servers/supabase/
└── index.js                  # get_db_telemetry, verify_transaction_integrity

/root/.qwen/agents/
└── gwen.md                   # Agent instructions (DB telemetry ZORUNLU)
```

---

## 🔧 MCP Tools

### get_db_telemetry

**Parametreler:**
- `startTime` (ZORUNLU): ISO timestamp
- `endTime` (Opsiyonel): ISO timestamp (varsayılan: şimdi)
- `tables` (Opsiyonel): Tablo listesi

**Örnek:**
```javascript
get_db_telemetry("2026-03-31T10:00:00Z", "2026-03-31T10:15:00Z")
```

**Output:**
```
📊 DB Telemetry (Son Session)

⏱️ Süre: 900000ms (15dk)

📋 Özet:
  - islem_log: 12 kayıt
  - stok_hareket: 3 değişiklik
  - gorev_log: 5 görev
  - hayvanlar: 2 güncelleme
```

### verify_transaction_integrity

**Parametreler:**
- `transactionType` (ZORUNLU): "TOHUMLAMA", "DOGUM_KAYDI", "ILAC_EKLE"
- `refId` (ZORUNLU): Referans ID (hayvan_id, tohumlama_id, vs.)
- `expectedActions` (Opsiyonel): ["stok_dus", "gorev_olustur"]

**Örnek:**
```javascript
verify_transaction_integrity("TOHUMLAMA", "abc123", ["stok_dus"])
```

**Output:**
```
🔍 Transaction Integrity Check

İşlem: TOHUMLAMA
Ref ID: abc123
Durum: ❌ KRİTİK HATA

📊 Kontroller:
  - islem_log: ❌ (0 kayıt)
  - stok_hareket: ❌ (0)
  - gorev_log: ⏭️ (0 görev)
  - hayvan_durum: ❌ (Bekliyor)

❌ Sorunlar:
  - [critical] İşlem log'u bulunamadı
```

---

## 🚨 Discrepancy Detection

**Agent Workflow:**

1. **Browser Event'leri Oku:**
   ```javascript
   const browserEvents = readAgentEvents();
   ```

2. **DB Telemetry Çağır:**
   ```javascript
   const dbEvents = get_db_telemetry(start, end);
   ```

3. **Kıyasla:**

| UI Diyor Ki | DB Gösteriyor Ki | Sorun | Aksiyon |
|-------------|------------------|-------|---------|
| "Başarılı" | islem_log yok | ❌ KRİTİK | Rapor + Onay → Fix |
| "Stok düştü" | stok_hareket yok | ❌ KRİTİK | Rapor + Onay → Fix |
| "Görev oluştu" | gorev_log yok | ⚠️ YÜKSEK | Rapor + Onay → Fix |
| "Tohumlandı" | durum != "Tohumlandı" | ⚠️ YÜKSEK | Rapor + Onay → Fix |
| "Toast yanlış" | DB temiz | ✅ KÜÇÜK | Direkt düzelt |

---

## 🧪 Test Senaryosu

**1. Session Başlat (Otomatik):**
```javascript
// Sayfa açılınca otomatik başlar
window.agentTestSession.start(); // Otomatik
```

**2. Test Et:**
- Tohumlama formunu aç
- Doldur, kaydet
- Console'da "✅ Telemetry connected" gör

**3. Session Bitir (Otomatik):**
```javascript
// Sayfa kapanınca otomatik biter
window.agentTestSession.end(); // Otomatik
```

**4. Agent Okur:**
```bash
# Browser event'leri
tail -f /root/egesut-erp1/agent-telemetry/events.jsonl

# Agent reader
cd /root/egesut-erp1/agent-telemetry
npm run read
```

---

## ⚠️ Sorun Giderme

### "Event gelmiyor"

**Kontrol:**
```bash
# Server çalışıyor mu?
pgrep -af "node.*server.js"

# Port dinleniyor mu?
ss -tlnp | grep 3002

# Tracker inject edilmiş mi?
grep "tracker.js" index.html
```

**Çözüm:**
```bash
# Server restart
cd /root/egesut-erp1/agent-telemetry
pkill -f "node.*server.js"
node server.js
```

### "RPC çalışmıyor"

**Kontrol:**
```bash
# CDC publication var mı?
# Supabase Dashboard SQL Editor'da çalıştır:
SELECT pubname FROM pg_publication WHERE pubname = 'gwen_db_watch';
```

**Migration:**
```sql
BEGIN;
  DROP PUBLICATION IF EXISTS gwen_db_watch;
  CREATE PUBLICATION gwen_db_watch FOR TABLE 
    public.islem_log, 
    public.stok_hareket, 
    public.gorev_log,
    public.hayvanlar;
COMMIT;
```

### "Agent DB telemetry okumuyor"

**Instruction:** `/root/.qwen/agents/gwen.md` içinde:
- Test sonrası DB kontrolü ZORUNLU
- Browser ↔ DB kıyaslama
- Discrepancy handling

---

## 📋 Checklist

Her test sonrası:

```
[ ] Server'lar çalışıyor (8080, 3002)
[ ] Browser event'leri kaydediliyor (events.jsonl)
[ ] Session timestamp'leri var (.agent-state.json)
[ ] Agent readAgentEvents() çağırıyor
[ ] get_db_telemetry() çağrılıyor
[ ] verify_transaction_integrity() çalışıyor
[ ] Discrepancy raporu oluşturuluyor
```

---

## 🎯 Sonraki Adımlar

1. ✅ Server'ları başlat
2. ✅ Browser'da test et
3. ✅ Agent okur → DB telemetry
4. ✅ Discrepancy → Rapor + Fix

---

**Hazır! Sorun yaşarsan bu README'yi oku.** 🚀
