# MiniMax Platform Bilgi Havuzu
> Oluşturuldu: 2026-04-04
> Kaynak: platform.minimax.io/docs
> Güncelleme: https://platform.minimax.io/docs/guides/models-intro

---

## Platform Genel Bakış

**URL:** https://platform.minimax.io/
**CLI Entegrasyonu:** Claude Code, Cursor, VS Code

### Faturalama Modeli (KRİTİK!)
- **Call-based billing** — token başı DEĞİL
- Context window limiti BİR ENTEGRE EDİLMİŞ (sınırsız context gibi düşün)
- Kota yüksek, muhtemelen bitiremeyiz
- "One subscription for all your AI needs"

---

## MiniMax Modelleri

| Model | Tip | Özellik | Kullanım |
|-------|-----|---------|---------|
| **MiniMax-M2.7** | Agentic | Exceptional Tool Use, interleaved thinking | **TERCİH EDİLEN** — her işte kullanılabilir |
| **MiniMax-M2.7-highspeed** | Agentic | Hızlı yanıt, M2.7 yetenekleri | Kritik öncelikli işler |
| MiniMax-M2.5 | General | dengeli | M2.7'den düşük |
| MiniMax-M2.5-highspeed | General | Hızlı, dengeli | Basit sorgular |
| MiniMax-M2.1 | General | Orta | Basit işler |
| MiniMax-M2 | General | Giriş seviye | Minimal görevler |

### M2.7 Agentic Yetenekleri
```
✅ Exceptional Tool Use
✅ Function calling (anthropic uyumlu)
✅ Tool use (Claude Code uyumlu)
✅ Interleaved Thinking Compatible Format
✅ Autonomous task execution
```

---

## Claude Code Entegrasyonu

### settings.json Konfigürasyonu
```json
{
  "model": "MiniMax-M2.7",
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "<MINIMAX_API_KEY>",
    "ANTHROPIC_BASE_URL": "https://api.minimax.io/anthropic"
  }
}
```

### Alternatif Base URL'ler
```
https://api.minimax.io/anthropic     ← CN dışı
https://api.minimaxi.com/anthropic   ← CN içi
```

### Cursor Entegrasyonu
```json
OPENAI_API_KEY: <MINIMAX_API_KEY>
OPENAI_BASE_URL: https://api.minimax.io/anthropic/v1
```

---

## API Reference

### Endpoint
```
POST https://api.minimax.io/anthropic/v1/messages
```

### Header
```
Authorization: Bearer <MINIMAX_API_KEY>
Content-Type: application/application
```

### Body (Anthropic uyumlu)
```json
{
  "model": "MiniMax-M2.7",
  "max_tokens": 8192,
  "messages": [
    {"role": "user", "content": "..."}
  ],
  "tools": [...]
}
```

---

## Function Calling / Tool Use

MiniMax-M2.7, Anthropic uyumlu function calling destekler:

```json
{
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "get_weather",
        "description": "Get weather for a location",
        "parameters": {
          "type": "object",
          "properties": {
            "location": {"type": "string"}
          }
        }
      }
    }
  ]
}
```

### Tool Use Format
```json
{
  "type": "tool_use",
  "name": "bash",
  "input": {"command": "ls -la"}
}
```

---

## MCP (Model Context Protocol) Desteği

MiniMax token plan MCP guide destekler:
- **Kaynak:** https://platform.minimax.io/docs/guides/token-plan-mcp-guide
- Claude Code MCP entegrasyonu ile çalışır
- Tool use = MCP tool çağrısı

---

## AI Coding Tools Entegrasyonu

**Kaynak:** https://platform.minimax.io/docs/guides/text-ai-coding-tools

MiniMax, coding assistant entegrasyonları:
- **Claude Code** — Tam destek
- **Cursor** — OPENAI_API_KEY override ile
- **VS Code** — Via extension

### Claude Code Kurulumu
1. `~/.claude/settings.json` dosyasını düzenle
2. `model: "MiniMax-M2.7"` ayarla
3. `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL` env olarak ekle
4. `claude` komutunu çalıştır

---

## Kullanım Stratejisi

### Model Seçimi
```
M2.7          → Varsayılan, her işte
M2.7-highspeed → Hızlı yanıt gereken işler
M2.5          → Basit, tek round işler (DÜŞÜK öncelik)
M2.1 / M2     → Minimal görevler (NADİR)
```

### Call Optimizasyonu
```
✅ Gereksiz call yapmamak hedef
✅ paralel tool use ile verimlilik
✅ Streaming response kullan
✅ Context reuse (session içinde)
❌ Aynı bilgiyi tekrar sorma
❌ Gereksiz agent spawn (her iş için yeni agent açma)
```

### Maliyet Avantajı
- Call-based = context uzunluğu önemli değil
- M2.7 her işi yapabilir = tek model = basitlik
- Kota yüksek = rahat kullanım

---

## opencode-dev'de Kullanım

Bu projede:
- **Varsayılan model:** MiniMax-M2.7
- **CLI:** Claude Code (MiniMax entegreli)
- **Tool use:** Tüm MCP tool'ları çalışır
- **Maliyet:** Token plan, call-based

### Model Ayarı
```json
// ~/.claude/settings.json
{
  "model": "MiniMax-M2.7",
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "..."
  }
}
```

---

## Referanslar

| Kaynak | URL |
|--------|-----|
| Ana Sayfa | https://platform.minimax.io/ |
| Modeller | https://platform.minimax.io/docs/guides/models-intro |
| API Reference | https://platform.minimax.io/docs/api-reference/text-post |
| Function Call | https://platform.minimax.io/docs/guides/text-m2-function-call |
| AI Coding Tools | https://platform.minimax.io/docs/guides/text-ai-coding-tools |
| Token Plan | https://platform.minimax.io/docs/token-plan/intro |
| MCP Guide | https://platform.minimax.io/docs/guides/token-plan-mcp-guide |

---

## Önemli Notlar

1. **M2.5 planda YOK** — Kullanılamaz
2. **Call-based** — Context sorunu yok, rahatça uzun conversation yap
3. **M2.7 Agentic** — Tool use exceptional, autonomous agent olarak çalışabilir
4. **Claude Code ile entegre** — Normal Claude Code kullanımı, sadece model farklı

---

*Bu dosya MiniMax platformunu anlamak için temel referanstır. Resmi dokümantasyon için platform.minimax.io/docs adresini ziyaret et.*
