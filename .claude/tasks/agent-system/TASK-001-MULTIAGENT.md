# TASK-001: Multi-Agent Orchestration Sistemi

**Durum:** 🟡 Devam Ediyor (Kilo Code keşfedildi, test edilecek)
**Tarih:** 2026-04-04 (updated from 2026-04-05 checkpoint)
**Öncelik:** 🔴 Kritik

---

## ✅ Çözümlendi: Kilo Code

**Kilo Code çalışıyor!** — code-server içinde sorunsuz çalışıyor:
- 11 `kilo serve` process'i aktif
- Open VSX marketplace'den geliyor (code-server uyumlu)
- MiniMax native destekli
- Orchestrator mode var

**Kullanım:**
1. code-server: http://localhost:8080 (şifre: `22a0ad0fa576b622f04c45c0`)
2. Kilo Code extension'ı aç
3. Settings → Providers → MiniMax → API key gir
4. Orchestrator mode'u test et

---

## 🔴 Kısa Dönem Fix'ler (Bu hafta)

### Sorun: Orchestrator yanıt vermiyor

**Kök Neden:** MiniMax M2.7 ~8sn yanıt veriyor + Claude Code subprocess iletişiminde deadlock/iç içe session çakışması

**Semptomlar:**
- `agent_framework_claude` + MiniMax M2.7: `start()` 30sn+ bekliyor, tamamlanamıyor
- Claude Code CLI subprocess `stream-json` modunda API'ye bağlanamıyor (timeout)
- Direct curl API çalışıyor ✅ (8sn, text geliyor)
- `claude_agent_sdk.query()` çalışıyor ✅ (nested session kontrolü ile)

**Test Edilecek Fix'ler:**

- [ ] `claude_agent_sdk.query()` ile interaktif loop dene — `agent_framework_claude` yerine
- [ ] CLI subprocess `--input-format stream-json` yerine farklı mod denesin
- [ ] Environment variable kontrolü — `ANTHROPIC_BASE_URL` subprocess'e geçiyor mu?
- [ ] Streaming modu devre dışı bırak — `stream=False` zorla
- [ ] Nested session conflict — belki `settings.json` override ile çözülür

**Doğrulama Komutu:**
```bash
unset CLAUDECODE && /opt/agent-framework/.venv/bin/python -c "
import asyncio
from claude_agent_sdk import query, ClaudeAgentOptions
async def t():
    async for msg in query('Selam, kısaca kim olduğunu söyle', 
        options=ClaudeAgentOptions(max_turns=1)):
        print(type(msg).__name__, str(msg)[:100])
asyncio.run(t())
"
```

---

## 🟡 Orta Dönem Hedefler (1-2 ay)

### Mimari Karar: Hangi Yolu Seçeceğiz?

**Seçenek A: `claude_agent_sdk.query()` tabanlı interaktif loop**
- ✅ Zaten çalışıyor (doğrulandı)
- ⚠️ Basit ama etkili
- ⚠️ Subagent spawn için `agents={}` gerekiyor

**Seçenek B: Direct Anthropic SDK + manual tool loop**
- ✅ Full kontrol
- ✅ Arbitrary model (MiniMax dahil)
- ⚠️ Built-in tools yok (file/web/bash)

**Seçenek C: OpenAgents (`oa` CLI)**
- ✅ Zaten kurulu
- ⚠️ MiniMax uyumu net değil

**Seçenek D: Agent Farm fork + MiniMax**
- ✅ Paralel agent yönetimi hazır
- ⚠️ tmux zorunlu

### Altında Yatan Mimari (Hedef)

```
┌──────────────────────────────────────────┐
│  orchestrator.py (senin CLI'n)           │
│                                          │
│  while True:                            │
│    input() → agent.run()               │
│    print(result.final_result)            │
└──────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  Claude Code CLI subprocess             │
│  (bu sunucuda: /opt/.../claude)         │
└──────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  MiniMax M2.7 API                       │
│  https://api.minimax.io/anthropic        │
└──────────────────────────────────────────┘
```

---

## 🟢 Uzun Dönem Hedefler (3+ ay)

### Ana Mimari: Orchestrator + Subagent Sistemi

```
                    SEN (terminal)
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
   [Orchestrator]  [Orchestrator] [Orchestrator]
   (ERP-Analist)  (DB-Schema)    (Code-Review)
         │              │              │
         ▼              ▼              ▼
   MiniMax M2.7    MiniMax M2.7   MiniMax M2.7
```

**Gereksinimler:**
- [ ] Interaktif orchestrator CLI ✅ (ortamda takılıyor)
- [ ] Subagent spawn ✅ (test edildi ama interaktif değil)
- [ ] MCP entegrasyonu (Supabase, GitHub) 🔲
- [ ] Konfigürasyon dosyası (agent-config.json) 🔲
- [ ] Persistent session 🔲
- [ ] Tool'lar arası veri paylaşımı 🔲

### Kullanım Senaryosu (Hedef)

```bash
$ python orchestrator.py

[1] > ERP analiz et
[2] > Supabase migration oluştur
[3] > GitHub issue aç
[4] > Kod incele
[5] > exit
```

---

## 📋 Bu Hafta Yapılacaklar (Fix Adımları)

```
1. claude_agent_sdk.query() ile basit interaktif loop dene
2. Timeout debug — subprocess gerçekten spawn oluyor mu?
3. MiniMax API streaming test et
4. Alternatif: Direct SDK ile minimal agent yaz
5. Sonuc: Çalışan bir interaktif orchestrator scripti
```

---

## 🔍 Debug Notları

### Bugün Test Edilen ve Çalışan:
- ✅ Direct curl → MiniMax API → text + thinking geliyor (8sn)
- ✅ `claude_agent_sdk.query()` → MiniMax (nested session olmadan)
- ✅ `claude_agent_sdk` + `AgentDefinition` → subagent spawn (57sn, non-interactive)

### Çalışmayan:
- ❌ `agent_framework_claude.start()` → 30sn+ bekliyor, timeout
- ❌ Claude Code CLI subprocess `stream-json` → timeout
- ❌ Interaktif loop → cevap yok

### Potansiyel Çözümler:
1. `claude_agent_sdk.query()` interaktif wrapper — en güvenli
2. Direct `anthropic.Anthropic()` + manual loop — full kontrol
3. Claude Code CLI doğrudan spawn, stdin/stdout ile konuş — en düşük seviye

---

## 📊 Context7 Araştırma Sonuçları (2026-04-05)

### ❌ NofX — ARAŞTIRMA HATALI
Paylaşılan araştırmada "NofX" VS Code eklentisi olarak gösteriliyor ama **gerçekte NofX bir crypto trading OS**. Yazılım geliştirme ile alakası yok.

---

### ✅ Kilo Code ⭐⭐⭐⭐⭐ — EN UYGUN

**Context7 ID:** `/websites/kilo_ai`

**MiniMax Entegrasyonu:** ✅ **NATIVE DESTEK!** — MiniMax provider ayarlarında direkt var.

```
Settings → Providers → MiniMax → API Key + Model seçimi
```

**Mimari Özellikleri:**

| Özellik | Durum |
|---------|-------|
| MiniMax M2.5 native | ✅ — Kilo Code ayarlarında direkt |
| Auto Balanced mode | ✅ — `code/build/explore` → Minimax M2.5 |
| Orchestrator mode | ✅ — Koordinatör modu |
| Parallel Mode | ✅ — Git worktree ile izolasyon |
| Agent Manager | ✅ — Merkezi kontrol paneli |
| MCP server desteği | ✅ |
| MiniMax BYOK | ✅ — Kendi API key'inle kullanabilirsin |

**Kilo Code Auto Balanced Mode:**
```
Mode          Model
─────────────────────────
architect   → Kimi K2.5
orchestrator → Kimi K2.5
ask         → Kimi K2.5
plan        → Kimi K2.5
code        → Minimax M2.5 ✅ (SENİN MODELİN!)
build       → Minimax M2.5 ✅
explore     → Minimax M2.5 ✅
```

**Kurulum:**
```bash
# VS Code → Extensions → "Kilo Code" ara → Install
# Settings → MiniMax → API Key yapıştır
```

---

### ✅ Cline ⭐⭐⭐⭐ — İKİNCİ EN İYİ

**Context7 ID:** `/cline/cline`

**MiniMax Entegrasyonu:** ✅ **NATIVE DESTEK!** — MiniMax provider config dosyasında direkt var.

```bash
# Provider olarak "minimax" seç
# API key yapıştır
# Model seç
```

**Mimari Özellikleri:**

| Özellik | Durum |
|---------|-------|
| MiniMax native | ✅ — Direct MiniMax provider |
| Subagent spawning | ✅ — Paralel read-only agent'lar |
| MCP tools | ✅ |
| Parallel worktree | ✅ — CLI ile paralel görevler |
| CLI (npm) | ✅ — `npm install -g cline` |

**Önemli Not:** Cline'ın subagent'ları **read-only**. Dosya düzenleyemezler — sadece okuma, arama, analiz yapabilirler.

**Kullanım:**
```bash
npm install -g cline
cline auth -p minimax -k $MINIMAX_API_KEY -m MiniMax-M2.7
cline "ERP analiz et"
```

---

### 🟡 Roo Code ⭐⭐⭐ — ÜÇÜNCÜ

**Context7 ID:** `/roocodeinc/roo-code`

**MiniMax Entegrasyonu:** ⚠️ Direct yok ama OpenRouter/custom provider üzerinden çalışabilir.

**Mimari Özellikleri:**

| Özellik | Durum |
|---------|-------|
| MiniMax direct | ⚠️ — OpenRouter veya custom provider gerek |
| MCP server | ✅ — `.roo/mcp.json` ile |
| Modes | ✅ — Code, Architect, Ask, Debug, **Orchestrator** |
| YAML workflow | 🔲 — Belgelendi ama detay net değil |

**MCP Config Örneği:**
```json
// .roo/mcp.json
{
  "mcpServers": {
    "github": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"] },
    "postgres": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-postgres"] }
  }
}
```

---

## 🎯 NET KARAR

### En İyi Seçenek: Kilo Code

**Neden:**
1. ✅ MiniMax M2.5 **native destekliyor** (Auto Balanced mode)
2. ✅ Orchestrator mode var
3. ✅ Agent Manager ile merkezi kontrol
4. ✅ Parallel Mode + worktree izolasyonu
5. ✅ MCP server desteği
6. ✅ VS Code içinde çalışıyor — senin sunucuda değil, kendi makinende

**Eksiklik:**
- ⚠️ M2.7 değil M2.5 kullanıyor (ama M2.7 de seçilebilir)
- ⚠️ VS Code gerekli — terminal tabanlı değil

---

### Alternatif: Cline CLI

**Neden:**
1. ✅ MiniMax native destekliyor
2. ✅ CLI ile sunucuda çalışabilir (`npm install -g cline`)
3. ✅ Subagent spawning (paralel agent)

**Eksiklik:**
- ⚠️ Subagent'lar read-only
- ⚠️ VS Code extension değil, CLI daha düşük seviyeli

---

## 🔄 Yeni Mimari Önerisi

```
                        SENİN MAKİNEN (VS Code)
                              │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
   [Kilo Code]        [Cline]            [Roo Code]
   Orchestrator       Subagents          MCP Tools
         │                   │                   │
         ▼                   ▼                   ▼
   MiniMax M2.5       MiniMax M2.7       OpenRouter
   (native)           (native)            / Custom
```

**Önerilen:**
1. **Kilo Code** → VS Code Extension Store'dan kur → Orchestrator olarak kullan
2. **Kilo Code ayarlarında** MiniMax API key → M2.5/M2.7 seç
3. Agent Manager → Paralel görevler başlat

---

## 📋 Yapılacaklar

```
[ ] Kilo Code VS Code Extension kurulumu test et
[ ] MiniMax M2.7 entegrasyonu doğrula
[ ] Orchestrator mode + Agent Manager test et
[ ] MCP server (Supabase/GitHub) bağla
[ ] vs agent_framework_claude kararı — Kilo Code mı yoksa SDK mı?
```

---

## 🔗 Kaynaklar

| Araç | Context7 ID | MiniMax | Orkestrasyon |
|-------|------------|---------|-------------|
| Kilo Code | `/websites/kilo_ai` | ✅ Native | ⭐⭐⭐⭐⭐ |
| Cline | `/cline/cline` | ✅ Native | ⭐⭐⭐⭐ |
| Roo Code | `/roocodeinc/roo-code` | ⚠️ Custom | ⭐⭐⭐ |

