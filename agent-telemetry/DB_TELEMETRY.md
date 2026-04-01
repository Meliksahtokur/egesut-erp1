# Agent DB Telemetry — Flight Recorder

Coder Agent için real-time DB gözlem ve transaction integrity sistemi.

---

## 🎯 Özellikler

### 1. Session-Based Tracking
- Test başlangıç/bitiş timestamp
- Browser + DB event'leri senkronize
- 15dk test de olsa tüm değişiklikler

### 2. DB Telemetry
- `get_db_telemetry(startTime, endTime)` — Session bazlı DB değişiklikleri
- Kritik tablolar: `islem_log`, `stok_hareket`, `gorev_log`, `hayvanlar`
- Özet + detay output

### 3. Transaction Integrity Check
- `verify_transaction_integrity(tip, refId)` — Bütünlük kontrolü
- Trigger'lar çalıştı mı?
- Stok ledger doğru mu?
- Görevler oluştu mu?

### 4. Discrepancy Detection
- UI "başarılı" diyor ama DB'de kayıt yok → KRİTİK
- Stok düşmedi → KRİTİK
- Toast mesajı yanlış → KÜÇÜK (direkt düzelt)

---

## 🚀 Kurulum

### 1. CDC Publication Oluştur

**GitHub Actions (Otomatik):**
- Workflow: `.github/workflows/supabase-migration-telemetry.yml`
- Push'ta otomatik çalışır
- Secrets gerekli: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`

**Manuel (Alternatif):**
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

### 2. MCP Server Restart

```bash
cd /root/egesut-erp1/gwen-mcp-servers/supabase
# Eski process'i durdur
pkill -f "node.*supabase"
# Yeniden başlat
node index.js
```

### 3. Browser Telemetry

`index.html` zaten inject edilmiş:
```html
<script src="agent-telemetry/tracker.js"></script>
```

---

## 📖 Kullanım

### Test Session

```javascript
// 1. Test başlangıç
window.agentTestSession.start();
// Console: "🎯 Test session started: 2026-03-31T08:00:00.000Z"

// 2. Test et (browser'da manuel)
// - Tohumlama formunu aç
// - Doldur, kaydet
// - Console log'ları kontrol et

// 3. Test bitiş
window.agentTestSession.end();
// Console: "🏁 Test session ended: 2026-03-31T08:15:00.000Z Duration: 900000ms"

// 4. Timestamp'leri al
const ts = window.agentTestSession.getTimestamps();
// { startTime: "...", endTime: "..." }
```

### Agent Workflow

```javascript
// 1. Browser event'leri oku
import { readAgentEvents } from './agent-telemetry/agent-event-reader.js';

const browserEvents = readAgentEvents();
// browserEvents.testSession.startTime, .endTime

// 2. DB telemetry çağır (MCP)
const dbTelemetry = await mcp__gwen-supabase__get_db_telemetry(
  browserEvents.testSession.startTime,
  browserEvents.testSession.endTime
);

// 3. Integrity check
const integrity = await mcp__gwen-supabase__verify_transaction_integrity(
  "TOHUMLAMA",
  hayvan_id
);

// 4. Kıyasla
if (integrity.hasIssues) {
  // KRİTİK → Rapor + Onay iste
  // KÜÇÜK → Direkt düzelt
}
```

---

## 📊 Output Örnekleri

### get_db_telemetry Output

```
📊 DB Telemetry (Son Session)

⏱️ Süre: 900000ms (15dk)

📋 Özet:
  - islem_log: 12 kayıt
  - stok_hareket: 3 değişiklik
  - gorev_log: 5 görev
  - hayvanlar: 2 güncelleme

🔍 Detaylar için 'details' alanına bak.

💡 İpucu: "verify_transaction_integrity" ile bütünlük kontrolü yap.
```

### verify_transaction_integrity Output

```
🔍 Transaction Integrity Check

İşlem: TOHUMLAMA
Ref ID: abc123
Durum: ❌ KRİTİK HATA

📊 Kontroller:
  - islem_log: ❌ (0 kayıt)
  - stok_hareket: ⏭️ (0)
  - gorev_log: ⏭️ (0 görev)
  - hayvan_durum: ❌ (Bekliyor)

❌ Sorunlar:
  - [critical] İşlem log'u bulunamadı (ref_id: abc123)

🚨 KRİTİK HATA: Fix öncesi bu sorunlar çözülmeli!
```

---

## 🛠️ MCP Tools

### get_db_telemetry

```javascript
{
  startTime: "2026-03-31T08:00:00.000Z", // ZORUNLU
  endTime: "2026-03-31T08:15:00.000Z",   // Opsiyonel (şimdi)
  tables: ["islem_log", "stok_hareket"]  // Opsiyonel
}
```

### verify_transaction_integrity

```javascript
{
  transactionType: "TOHUMLAMA",  // ZORUNLU
  refId: "abc123",              // ZORUNLU
  expectedActions: ["stok_dus", "gorev_olustur"] // Opsiyonel
}
```

---

## 🚨 Discrepancy Matrix

| UI Diyor Ki | DB Gösteriyor Ki | Sorun | Aksiyon |
|-------------|------------------|-------|---------|
| "Başarılı" | islem_log yok | ❌ KRİTİK | Rapor + Onay → Fix |
| "Stok düştü" | stok_hareket yok | ❌ KRİTİK | Rapor + Onay → Fix |
| "Görev oluştu" | gorev_log yok | ⚠️ YÜKSEK | Rapor + Onay → Fix |
| "Tohumlandı" | durum != "Tohumlandı" | ⚠️ YÜKSEK | Rapor + Onay → Fix |
| "Toast yanlış" | DB temiz | ✅ KÜÇÜK | Direkt düzelt |

---

## 📁 Dosya Yapısı

```
agent-telemetry/
├── server.js                 # WebSocket relay
├── tracker.js                # Browser inject (session tracking)
├── agent-event-reader.js     # Incremental okuma + DB telemetry
├── events.jsonl              # Browser event log
└── .agent-state.json         # Session state

gwen-mcp-servers/supabase/
└── index.js                  # get_db_telemetry, verify_transaction_integrity

.github/workflows/
└── supabase-migration-telemetry.yml  # CDC publication

supabase/migrations/
└── 20260331000001_agent_db_telemetry.sql
```

---

## ⚠️ Sorun Giderme

### "GitHub Actions çalışmıyor"

**Sebep:** Secrets eksik
**Çözüm:**
1. GitHub → Settings → Secrets and variables → Actions
2. Ekle: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`
3. Workflow'u manuel tetikle

### "Publication oluşturulamadı"

**Manuel SQL:**
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

### "Test session timestamp yok"

**Kontrol:**
```javascript
console.log(window.agentTestSession);
// undefined ise tracker.js inject edilmemiş
```

**Çözüm:**
```html
<script src="agent-telemetry/tracker.js"></script>
<!-- index.html son satır -->
```

---

## 🎯 Sonraki Adımlar

1. ✅ CDC Publication oluştur (GitHub Actions veya manuel)
2. ✅ MCP server restart
3. ✅ Test session başlat
4. ✅ Agent DB telemetry oku
5. ✅ Discrepancy detection test et

---

**Hazır! Sorun yaşarsan README'yi oku.**
