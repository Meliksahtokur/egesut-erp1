# AI CLI Aracı Karşılaştırması — 2026-04-04

> Bugün yapılan araştırma ve testlere dayalı

---

## Kriterler

- Browser/Web UI var mı?
- Docker gerekli mi?
- Ücretsiz mi / Maliyet?
- MiniMax M2.7 çalışıyor mu?
- Tool use / MCP destekliyor mu?
- Tablet uyumlu mu?

---

## Araçlar Karşılaştırması

| Araç | Browser UI | Docker | Ücret | M2.7 | Tool/MCP | Tablet | Not |
|-------|-----------|--------|-------|------|----------|--------|-----|
| **Claude Code CLI** | ❌ | ❌ | Ücretsiz | ✅ | ✅ | ⚠️ Terminal | **KULLANILAN** |
| **opencode (anomaly.co)** | ✅ | ❌ | Ücretsiz | ⚠️ SDK sıkıntısı | ⚠️ | ✅ | Çalışıyor ama model kısıtlı |
| **Droid (Factory AI)** | ⚠️ Cloud only | ❌ | **ÜCRETLİ** | ✅ BYOK | ✅ | ❌ Terminal | Bedava değil |
| **OpenClaw** | ✅ | ❌ | Ücretsiz | ✅ | ✅ | ✅ | Config çok karmaşık |
| **AnythingLLM** | ✅ | ✅ **Gerekli** | Ücretsiz | ✅ | ✅ | ✅ | Docker şart |
| **Goose** | ❌ | ❌ | Ücretsiz | ✅ env var | ✅ | ❌ Terminal | CLI only |
| **Crush** | ❌ | ❌ | Açık kaynak | ✅ | ✅ | ❌ Terminal | Agent sistemi yok |
| **code-server + Cline** | ✅ VS Code | Tercih | Ücretsiz | ✅ | ✅ | ✅ | Kurulum gerekli |

---

## Sonuç: Ne Kullanılıyor

### ✅ Claude Code CLI (Şu an)
- Tablet terminalden kullanılıyor
- MiniMax M2.7 full özellikle çalışıyor
- Tool use, MCP, agent spawn hepsi çalışıyor
- Ücretsiz

### ✅ opencode (browser UI)
- `opencode web --hostname 0.0.0.0 --port 3000`
- `http://192.168.1.156:3000` — tablet tarayıcısında açılır
- Config: `~/.opencode.json`
- Sorun: @ai-sdk/anthropic SDK'sı MiniMax'i düzgün yansıtmıyor — "lobotomized" hisseder

---

## opencode Config (Mevcut)

```json
// ~/.opencode.json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "minimax": {
      "npm": "@ai-sdk/anthropic",
      "options": {
        "baseURL": "https://api.minimax.io/anthropic/v1",
        "apiKey": "sk-cp-..."
      },
      "models": {
        "MiniMax-M2.7": { "name": "MiniMax-M2.7" }
      }
    }
  },
  "model": "minimax/MiniMax-M2.7",
  "mcp": {
    "supabase": { "command": "npx", "args": ["mcp-server-supabase", "--access-token", "sbp_..."] },
    "github": { "command": "npx", "args": ["mcp-server-github"] }
  }
}
```

---

## MCP Durumu (Claude Code)

**Kaldırılanlar:**
- `ccm` ❌ — native --agents yeterli
- `chat` ❌ — multi-agent room gerekmiyor
- `context7-mcp` ❌ — duplicate

**Kalanlar:**
- `plugin:context7:context7` ✅ — Dokümantasyon
- `github` ✅ — GitHub işlemleri
- `TestSprite` ✅ — Test
- `supabase` ✅ — Veritabanı

---

## TTAL vs Custom MCP Karşılaştırması

| Kriter | TTAL (Skills) | Custom MCP | Ağırlık |
|---------|---------------|------------|---------|
| Startup time | 10 | 4 | 15% |
| Kurulum | 9 | 5 | 10% |
| Bakım | 9 | 3 | 15% |
| Güvenlik | 8 | 6 | 10% |
| Funksiyonel derinlik | 4 | 9 | 20% |
| Hata yönetimi | 5 | 8 | 10% |

**Skor:** TTAL 7.30/10 | Custom MCP 6.05/10

**Karar:** Hibrit — built-in tool = TTAL, dış API = MCP

---

## MiniMax API Endpoint'leri

```
Standart OpenAI SDK:  https://api.minimax.io/v1
Claude Code workaround: https://api.minimax.io/anthropic/v1
opencode CLI:          https://api.minimax.io/anthropic/v1 (@ai-sdk/anthropic)
```

**Not:** Claude Code + MiniMax resmi ortaklık = özel routing/infrastruktur
opencode CLI aynı API'ye gidiyor ama optimizasyon yok → yavaş/hissettiriyor

---

## Öneriler

1. **Ciddi işler için:** Claude Code CLI (terminal)
2. **Basit/hızlı işler için:** opencode browser UI (ama model kısıtlı)
3. **VS Code isteyenler:** code-server + Cline (kurulum gerekli)

---

*Son güncelleme: 2026-04-04*
