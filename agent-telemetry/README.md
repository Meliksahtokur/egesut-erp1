# Agent Telemetry Pipeline

Browser'daki kullanıcı işlemlerini real-time olarak AI Agent'a aktaran sistem.

---

## 🎯 Özellikler

### ✅ Incremental Okuma
- Agent her seferinde **SADECE YENİ event'leri** okur
- Context dolmaz, full log okunmaz
- State tracking (hangi satırda kaldık)

### ✅ Real-Time Tracking
- Click, submit, fetch, error otomatik track
- WebSocket ile anlık iletim
- Session-based grouping

### ✅ Özet Çıktı
- Son işlemler (max 5)
- API çağrıları (max 3)
- Hatalar (tümü)
- Context-friendly format

---

## 🚀 Kullanım

### 1. Server'ı Başlat

```bash
cd /root/egesut-erp1/agent-telemetry
npm start
```

**Output:**
```
📡 Telemetry WebSocket Server started on ws://localhost:3003
🌐 Browser UI: http://localhost:3003/test
📄 Test UI: http://localhost:13003/test
```

### 2. EgeSüt'ü Aç

```bash
cd /root/egesut-erp1
python3 -m http.server 8080
```

**Browser:** http://localhost:8080

### 3. Agent Event'leri Oku

**Node.js ile:**
```bash
npm run read
```

**Programmatic:**
```javascript
import { readAgentEvents } from './agent-telemetry/agent-event-reader.js';

const result = readAgentEvents();

if (result.hasNew) {
  console.log('Yeni aktivite:', result.summary);
  console.log('Context:', result.context);
  console.log('Event sayısı:', result.count);
} else {
  console.log('Yeni aktivite yok');
}
```

---

## 📊 Çıktı Örneği

### `npm run read` Output:

```
=== AGENT EVENT READER ===

Yeni event var mı: true
Event sayısı: 10

📊 ÖZET:
Son işlem: click "Kaydet" • 3 API çağrı başarılı

📝 CONTEXT:

📋 Son İşlemler:
  [08:13:07] CLICK 115
  [08:13:09] CLICK svg
  [08:13:10] CLICK İlaç, sperma, sarf malzeme
  [08:13:11] CLICK 📋 Tüm Hareketler
  [08:13:13] CLICK 📋 Tüm Stok Hareketleri

🌐 API Çağrıları:
  [08:13:02] POST rpc/rpc/add_drug_administration → 200 (360ms)
  [08:13:02] GET rpc/drug_classes → 200 (231ms)
  [08:13:03] GET rpc/treatment_timeline → 200 (196ms)

========================
```

---

## 📁 Dosya Yapısı

```
agent-telemetry/
├── package.json              # Dependencies + exports
├── server.js                 # WebSocket relay (dinamik port)
├── tracker.js                # Browser inject (auto-discover)
├── agent-analyzer.js         # Real-time listener (opsiyonel)
├── agent-event-reader.js     # ✅ Incremental okuma (YENİ!)
├── events.jsonl              # Event log (JSONL)
├── .agent-state.json         # State tracking (hangi satırda kaldık)
├── .port                     # Aktif port
└── README.md
```

---

## 🔧 Agent Entegrasyonu

### Gwen Agent için:

```javascript
// Agent task başında oku
import { readAgentEvents } from '../agent-telemetry/agent-event-reader.js';

const events = readAgentEvents();

if (events.hasNew) {
  // Kullanıcı test etmiş, sonuçları kullan
  console.log('Kullanıcı şunları yaptı:', events.summary);
  console.log('Detay:', events.context);
  
  // Test PASS mi?
  const hasErrors = events.errors.length > 0;
  if (hasErrors) {
    // Hata düzelt
  } else {
    // Task tamamlandı
  }
}
```

---

## 📊 Event Tipleri

| Tip | Payload | Örnek |
|-----|---------|-------|
| `click` | tagName, id, className, text, selector | `BUTTON#tohumlamaKaydet` |
| `submit` | action, id, method | `FORM#tohumlamaForm` |
| `fetch` | url, method, status, duration | `POST /rpc/add_drug → 200 (360ms)` |
| `xhr` | url, method, status, duration | `GET /hayvanlar → 200 (45ms)` |
| `error` | message, source, lineno | `ReferenceError: x is not defined` |
| `console_*` | args | `["Test log", "123"]` |

---

## ⚙️ Ayarlar

### Tracker.js (Browser)

```javascript
// Otomatik port bulur (3002-3006 dener)
const TELEMETRY_PORTS = [3002, 3003, 3004, 3005, 3006];

// Throttle (ms)
const THROTTLE_MS = 200;
```

### Agent Reader (Node.js)

```javascript
// Son N event oku
const lines = readLastNLines(LOG_FILE, 200);

// State dosyası
.agent-state.json // lastLine, lastReadTime
```

---

## 🛡️ Güvenlik

- Sadece localhost
- External bağlantı YOK
- .gitignore: `.port`, `events.jsonl`, `.agent-state.json`
- Production'da tracker.js'i kaldır

---

## 🧪 Test

```bash
# Terminal 1: Server
cd agent-telemetry
npm start

# Terminal 2: EgeSüt
cd /root/egesut-erp1
python3 -m http.server 8080

# Terminal 3: Event oku
cd agent-telemetry
npm run read
```

---

## 📝 State Management

### `.agent-state.json`:

```json
{
  "lastLine": 156,
  "lastReadTime": "2026-03-31T08:13:00.000Z",
  "lastSession": "session-1774944730815-p76nr"
}
```

**Ne Zaman Güncellenir:**
- `readAgentEvents()` çağrıldığında
- Son okunan timestamp kaydedilir
- Sonraki okuma sadece daha yeni event'leri getirir

---

## ⚠️ Sorun Giderme

### "Yeni event yok" diyor ama browser'da test yaptım

- Tracker.js inject edildi mi? (F12 → Sources)
- Console'da "✅ Telemetry connected" var mı?
- Server çalışıyor mu? (`lsof -i :3003`)

### "Context çok uzun"

- `readLastNLines(LOG_FILE, 200)` → `50`'ye düşür
- `summarizeEvents()` max action/API sayısını azalt

### "Port çakışması"

- Server otomatik boş port bulur
- `.port` dosyasını sil, restart et

---

## 🎯 Sonraki Adımlar

1. ✅ Sistem hazır
2. ✅ Incremental okuma çalışıyor
3. 📊 Agent entegrasyonu yap
4. 🧪 Real test senaryoları

---

**Hazır! Sorun yaşarsan README'yi oku.**
