# opencode.ai Kurulumu — 2026-04-04

> Bugün öğrenilen kritik bilgiler

---

## 🏆 opencode.ai Nedir?

**İKİ farklı proje var:**

| Proje | URL | Tip |
|-------|-----|-----|
| **opencode.ai** (anomaly.co) | opencode.ai | Açık kaynak CLI + Web arayüzü |
| **Claude Code** | claude.ai/code | Cloud-based CLI |

**Mevcut `claude` CLI aslında opencode.ai formatını kullanıyor!**
- `opencode.json` = `~/.claude.json` ile aynı yapı
- Provider konfigürasyonu birebir aynı

---

## ✅ MiniMax M2.7 Kurulumu (opencode CLI)

### Config dosyası: `~/.opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "minimax": {
      "npm": "@ai-sdk/anthropic",
      "options": {
        "baseURL": "https://api.minimax.io/anthropic/v1",
        "apiKey": "sk-cp-4ErelSlnFkyo49Uc8H8RRZXr..."
      },
      "models": {
        "MiniMax-M2.7": {
          "name": "MiniMax-M2.7"
        }
      }
    }
  },
  "model": "minimax/MiniMax-M2.7",
  "mcp": {
    "supabase": {
      "command": "npx",
      "args": ["mcp-server-supabase", "--access-token", "sbp_35765ff5bc0c01ff126dd66a5ca8d8521e0c796d"]
    },
    "github": {
      "command": "npx",
      "args": ["mcp-server-github"]
    },
    "testsprite": {
      "command": "npx",
      "args": ["@testsprite/testsprite-mcp@latest"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

### ⚠️ MODEL NOTLARI

```
DOĞRU: minimax/MiniMax-M2.7      ← NORMAL model
YANLIŞ: minimax/MiniMax-M2.7-highspeed  ← HIZLI model (farklı)
```

**opencode models minimax** ile kontrol et:
```
minimax/MiniMax-M2
minimax/MiniMax-M2.1
minimax/MiniMax-M2.5
minimax/MiniMax-M2.5-highspeed
minimax/MiniMax-M2.7              ← KULLAN
minimax/MiniMax-M2.7-highspeed    ← HIZLI, normal değil
```

---

## 🚀 Web Arayüzünü Başlatma

```bash
# Kurulum
npm i -g opencode-ai@latest

# Config'i ~/.opencode.json'a koy (yukarıdaki gibi)

# Web arayüzünü başlat
opencode web --hostname 0.0.0.0 --port 3000

# Çıktı:
# Local access:       http://localhost:3000
# Network access:     http://192.168.1.156:3000
```

**Tablet tarayıcısında:** `http://192.168.1.156:3000` aç

---

## ⚠️ Önemli Uyarılar

1. **Şifre ayarlanmamış:** `OPENCODE_SERVER_PASSWORD` set edilmedi. Sadece güvenli ağda kullan.
2. **API Key config'te:** `~/.opencode.json` API key açık içeriyor — paylaşma.
3. **MCP'ler config'te:** `opencode mcp list` çalışmıyor, config dosyasından okunuyor.

---

## MCP Config Syntax (opencode.ai)

opencode Claude Code'dan FARKLI config formatı kullanıyor:

```json
"mcp": {
  "server-name": {
    "command": "npx",
    "args": ["mcp-server-supabase", "--access-token", "sbp_..."]
  }
}
```

---

## Diğer Araç Karşılaştırması

### Droid (Factory AI)
- Agent sistemi: ✅ Markdown tabanlı
- MCP: ✅ Interaktif
- Güvenlik: ✅ Droid Shield
- MiniMax: ✅ BYOK custom model
- Skor: **8.05/10** (EgeSüt için en yüksek)

### Goose (Block)
- Agent sistemi: ✅ YAML Recipe
- MCP: ✅ Extensions
- Güvenlik: ❌ Zayıf
- Topluluk: ✅ 27K stars
- Skor: **6.70/10**

### Crush (Charm)
- Agent sistemi: ❌ Yok (tek agent)
- MCP: ✅
- LSP: ✅ (Go, TS, Nix)
- Güvenlik: ❌ Zayıf
- Skor: **6.15/10**

**Karar:** Şu an opencode.ai kullanılıyor — tablet uyumlu, self-hosted web arayüzü.

---

## MiniMax OpenAI-Compatible Endpoint

```
Standart OpenAI SDK:  https://api.minimax.io/v1
Claude Code workaround: https://api.minimax.io/anthropic/v1
```

**opencode.ai** `https://api.minimax.io/anthropic/v1` kullanıyor ✅
**opencode CLI** config'teki baseURL'e göre çalışır.

---

*Son güncelleme: 2026-04-04*

---

## ⚠️ ÖNEMLİ: opencode CLI vs Claude Code Hız Farkı

### Sebep
MiniMax, Claude Code ile **resmi ortaklık** yapıyor. Bu:
- Özel API routing
- Coding Plan altyapısı
- `minimax-coding-plan-mcp` özel MCP

opencode CLI standart API kullandığı için bu optimizasyonlara erişemiyor.

### Sonuç
opencode CLI + MiniMax = YAVAŞ (~7sn latency + inference)
Claude Code + MiniMax = HIZLI (aynı API ama optimizasyonlu)

### Çözümler
1. **SSH ile Claude Code** — uzaktaki makinede Claude Code çalıştır, tablet terminale stream et
2. **opencode CLI'ı kabul et** — yavaş ama tablet tarayıcısında çalışır
3. **Claude Code tablet için** — Claude Code'u tablet terminalden kullan (web arayüzü değil, CLI)

### Not
Aynı API'ye istek atıyoruz (~7sn), fark Claude Code'un altyapı optimizasyonlarından geliyor.

