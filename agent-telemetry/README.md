# Agent Telemetry Pipeline

Browser'daki kullanıcı işlemlerini real-time olarak AI Agent'a aktaran sistem.

---

## 🎯 Ne İşe Yarar?

Sen browser'da test yaparken, agent senin her işlemini görebilir:

- 🖱️ **Click** - Hangi butona/form'a tıklandın
- 📝 **Submit** - Hangi form submit edildi
- 🌐 **Fetch/XHR** - Hangi API çağrıları yapıldı
- ❌ **Error** - Hangi hatalar oluştu
- 📋 **Console** - Console log'ları

---

## 🚀 Kullanım

### 1. WebSocket Server'ı Başlat

```bash
cd /root/egesut-erp1/agent-telemetry
npm start
```

**Output:**
```
📡 Telemetry WebSocket Server started on ws://localhost:3002
```

### 2. Agent Analyzer'ı Başlat (Opsiyonel)

```bash
npm run agent
```

**Output:**
```
🤖 Agent Analyzer starting...
✅ Connected to telemetry server
🎧 Listening for browser events...
```

### 3. Browser'da Test Et

`index.html`'i aç ve normal şekilde test yap.

Tracker otomatik olarak:
- Her tıklamayı
- Her form submit'i
- Her API çağrısını
- Her hatayı

loglar ve WebSocket server'a gönderir.

---

## 📊 Event Örnekleri

### Click Event
```json
{
  "type": "click",
  "payload": {
    "tagName": "BUTTON",
    "id": "tohumlamaKaydet",
    "className": "btn btn-primary",
    "text": "Kaydet...",
    "selector": "#tohumlamaKaydet"
  },
  "timestamp": "2026-03-31T12:30:45.123Z"
}
```

### Submit Event
```json
{
  "type": "submit",
  "payload": {
    "action": "javascript:void(0)",
    "id": "tohumlamaForm",
    "method": "POST"
  },
  "timestamp": "2026-03-31T12:30:46.456Z"
}
```

### Fetch Event
```json
{
  "type": "fetch",
  "payload": {
    "url": "https://abc123.supabase.co/rest/v1/tohumlama",
    "method": "POST",
    "status": 201,
    "duration": 145
  },
  "timestamp": "2026-03-31T12:30:46.789Z"
}
```

---

## 📁 Dosya Yapısı

```
agent-telemetry/
├── package.json          # Dependencies
├── server.js             # WebSocket relay (port 3002)
├── agent-analyzer.js     # AI listener (opsiyonel)
├── tracker.js            # Browser inject script
├── events.jsonl          # Event log (JSONL format)
└── README.md             # Bu dosya
```

---

## 🔧 Ayarlar

### tracker.js İçinde

```javascript
const WS_URL = 'ws://localhost:3002';  // WebSocket URL
const THROTTLE_MS = 200;               // Event throttle (ms)
const MAX_TEXT_LENGTH = 50;            // Text truncation
```

---

## 🛡️ Güvenlik

- Sadece localhost'ta çalışır
- External bağlantı YOK
- events.jsonl sadece local dosya
- Production'da tracker.js'i kaldır

---

## 🧪 Test

```bash
# Terminal 1: Server
cd agent-telemetry
npm start

# Terminal 2: Analyzer (opsiyonel)
npm run agent

# Browser: index.html'i aç
# Test yap, console'da event loglarını gör
```

---

## 📝 Agent Nasıl Okur?

Agent `events.jsonl` dosyasını okur:

```javascript
// Her satır bir JSON event
const events = readFileSync('events.jsonl', 'utf-8')
  .trim()
  .split('\n')
  .map(line => JSON.parse(line));

// Son 10 event
const recent = events.slice(-10);
```

---

## ⚠️ Sorun Giderme

### "WebSocket connected ama event gelmiyor"

- Tracker.js inject edildi mi? (F12 → Network → WS kontrol et)
- Port 3002 açık mı? (lsof -i :3002)

### "Events.jsonl boş"

- Server.js çalışıyor mu?
- Browser'da console'da "✅ Telemetry connected" var mı?

### "Çok fazla event, spam oluyor"

- THROTTLE_MS değerini artır (200 → 500)
- Click event'lerini kapat (tracker.js'de yorum yap)

---

## 🎯 Sonraki Adımlar

1. ✅ Sistem hazır
2. 🧪 Test et
3. 📊 Agent okuma entegrasyonu yap

---

**Hazır! Sorun yaşarsan README'yi oku.**
