# Agent Hiyerarşisi ve Çalışma Alanları

## ⚠️ KRİTİK: Yeni Orkestrasyon Sistemi

Bu projede **YENİ MİMARİ** çalışıyor. Claude tek orkestratördür, Qwen'leri spawn eder.

### Yeni Hiyerarşi

```
┌─────────────────────────────────────────────────────────┐
│  CLAUDE (Tek Orkestratör / Yönetim / Üretim)            │
│  - Proje üretimi, task yönetimi, merge yetkisi          │
│  - Qwen spawn edebilir (gwen-dev, gwen-arge)            │
│  - 2 Qwen tipini koordine eder                          │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (spawn eder)
          ┌───────────────┴───────────────┐
          │                               │
          ▼                               ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│  gwen-dev                │  │  gwen-arge               │
│  (ERP Geliştirme)        │  │  (AR-GE Geliştirme)      │
│  - Tohumlama, doğum      │  │  - Skills, agents, MCP   │
│  - UI bug fix            │  │  - Workflow iyileştirme  │
│  - Feature branch        │  │  - Feature/gwen-arge     │
│  - Sadece ERP dev        │  │  - Sadece AR-GE          │
│  - Arge işi YASAK        │  │  - ERP dev YASAK         │
└──────────────────────────┘  └──────────────────────────┘
```

### Sub-Orchestrator Kuralı (DEĞİŞTİRİLEMEZ)

**Claude:**
- ✅ Qwen spawn edebilir (gwen-dev, gwen-arge)
- ✅ Task dağıtabilir
- ✅ Merge yapabilir

**Qwen (gwen-dev veya gwen-arge):**
- ❌ **Başka Qwen spawn EDEMEZ** — sub-orchestrator YASAK
- ✅ Native subagent kullanabilir (gwen-architect, gwen, general-purpose, Explore)
- ✅ Subagent'ları **runner** olarak kullanır (aynı ekranda)

### Runner Subagent Kuralı

**Runner = Subagent (aynı ekran, ayrı proses)**

| Özellik | Açıklama |
|---------|----------|
| **Spawn** | Qwen → native subagent (gwen-architect, gwen, general-purpose, Explore) |
| **Execution** | Aynı ekranda çalışır, ayrı terminal değil |
| **Paralellik** | Birden fazla subagent aynı anda çalışabilir |
| **Dosya Çakışması** | **Aynı dosyaya paralel yazma YASAK** — çakışma önlenir |

**Paralel Okuma:**
```
✅ gwen-architect → dosya1.md oku
✅ gwen → dosya2.md oku
```

**Paralel Yazma (farklı dosyalar):**
```
✅ gwen-architect → .qwen/QWEN.md güncelle
✅ gwen → .qwen/skills/yeni/SKILL.md oluştur
```

**Paralel Yazma (aynı dosya — YASAK):**
```
❌ gwen-architect → .qwen/QWEN.md düzenle
❌ gwen → .qwen/QWEN.md düzenle  ← ÇAKIŞMA!
```

---

## 1. CLAUDE (Orkestratör)

**Çalışma Alanı:** Claude Code IDE extension
**Branch:** `main` (üretim)
**Konfigürasyon:** `CLAUDE.md` + `.claude/` dizini

### Yetkiler
- ✅ Qwen spawn edebilir (gwen-dev, gwen-arge)
- ✅ Task dağıtabilir
- ✅ Feature branch'leri main'e merge edebilir
- ✅ `.qwen/` dizinini yönetebilir

### **YASAK:**
- ❌ Qwen agent'ları Claude agent'larını spawn edemez
- ❌ `.claude/` dizinini değiştiremez (Qwen)
- ❌ main branch'e direkt push yapamaz (Qwen)

### Orkestratör
- **Claude** — `CLAUDE.md` ile yönetilir
- Kullanıcının tek muhatabı
- Qwen'leri koordine eder

---

## 2. gwen-dev (ERP Geliştirme)

**Çalışma Alanı:** Qwen Code IDE extension
**Branch:** `feature/gwen-*` (geliştirme)
**Session Tipi:** `dev`

### Yetkiler
- ✅ Feature branch'lerde **serbest kod üretimi**
- ✅ MCP servers kullanımı (gwen-supabase, gwen-github, context7)
- ✅ Native subagent'ları spawn etme (runner olarak)
- ✅ Custom skills kullanımı (egesut-fullstack, fix-ui)
- ✅ PR oluşturma (main'e merge için)

### **YASAK:**
- ❌ **Arge işleri YASAK** — skill/agent/MCP geliştirme yok
- ❌ `.qwen/` dizininde değişiklik YASAK
- ❌ session-rules ihlali YASAK

### Subagent'lar (Runner)
| Agent | Tip | Sorumluluk |
|-------|-----|------------|
| `gwen-architect` | Specialist | Gwen CLI uzmanı, MCP/Agent/Skill builder |
| `gwen` | Fullstack | EgeSüt ERP fullstack developer |
| `general-purpose` | General | Complex multi-step tasks |
| `Explore` | Fast | Codebase exploration |

### Custom Skills (Dev Session)
| Skill | Dosya | Sorumluluk |
|-------|-------|------------|
| `egesut-fullstack` | `user/egesut-fullstack` | Tohumlama, doğum, hayvan yönetimi domain kuralları |
| `fix-ui` | `user/fix-ui` | UI bug düzeltme — Systematic approach |
| `session-rules` | `user/session-rules` | Dev/arge session kuralları |

### MCP Servers
| MCP | Dosya | Sorumluluk |
|-----|-------|------------|
| `gwen-supabase` | `gwen-mcp-servers/supabase/index.js` | Database operations |
| `gwen-github` | `gwen-mcp-servers/github/index.js` | PR, issues, commits |
| `context7` | `gwen-mcp-servers/context7/index.js` | Documentation lookup |

---

## 3. gwen-arge (AR-GE Geliştirme)

**Çalışma Alanı:** Qwen Code IDE extension
**Branch:** `feature/gwen-arge` (geliştirme)
**Session Tipi:** `arge`

### Yetkiler
- ✅ Qwen skills geliştirme (egesut-fullstack, fix-ui, gwen-self-improvement)
- ✅ Yeni agent/skill/MCP oluşturma
- ✅ Workflow iyileştirme
- ✅ `.qwen/` dizininde değişiklik
- ✅ Native subagent'ları spawn etme (runner olarak)

### **YASAK:**
- ❌ **ERP geliştirme YASAK** — tohumlama, doğum, hayvan yönetimi yok
- ❌ `js/` dizininde değişiklik YASAK
- ❌ Domain koduna müdahale YASAK
- ❌ session-rules ihlali YASAK

### Subagent'lar (Runner)
| Agent | Tip | Sorumluluk |
|-------|-----|------------|
| `gwen-architect` | Specialist | Gwen CLI uzmanı, MCP/Agent/Skill builder |
| `gwen` | Fullstack | EgeSüt ERP fullstack developer |
| `general-purpose` | General | Complex multi-step tasks |
| `Explore` | Fast | Codebase exploration |

### Custom Skills (Arge Session)
| Skill | Dosya | Sorumluluk |
|-------|-------|------------|
| `gwen-self-improvement` | `user/gwen-self-improvement` | Gwen CLI, MCP, Agent, Skill geliştirme |
| `session-rules` | `user/session-rules` | Dev/arge session kuralları |

### MCP Servers
| MCP | Dosya | Sorumluluk |
|-----|-------|------------|
| `gwen-supabase` | `gwen-mcp-servers/supabase/index.js` | Database operations |
| `gwen-github` | `gwen-mcp-servers/github/index.js` | PR, issues, commits |
| `context7` | `gwen-mcp-servers/context7/index.js` | Documentation lookup |

---

## 📊 HİYERARŞİ KARŞILAŞTIRMASI

| Özellik | Claude (Orkestratör) | gwen-dev | gwen-arge |
|---------|---------------------|----------|-----------|
| **Branch** | `main` | `feature/gwen-*` | `feature/gwen-arge` |
| **Rol** | Orkestratör | ERP Geliştirme | AR-GE Geliştirme |
| **Spawn** | Qwen ✅ | Subagent (runner) ✅ | Subagent (runner) ✅ |
| **Sub-orchestrator** | N/A | ❌ YASAK | ❌ YASAK |
| **ERP Dev** | ✅ | ✅ | ❌ YASAK |
| **AR-GE** | ✅ | ❌ YASAK | ✅ |
| **.qwen/ Değişiklik** | ✅ | ❌ YASAK | ✅ |
| **js/ Değişiklik** | ✅ | ✅ | ❌ YASAK |
| **Session Kilidi** | N/A | dev | arge |

---

## 🔄 SİSTEM ETKİLEŞİMİ

### Aynı Codebase'i Paylaşıyorlar
```
/root/egesut-erp1/
├── .claude/          ← Claude config
├── .qwen/            ← Qwen config (gwen-arge değiştirir)
├── gwen-mcp-servers/ ← Qwen MCP'leri
├── js/               ← gwen-dev değiştirir
├── index.html        ← Ortak
└── supabase/         ← Ortak
```

### Branch Stratejisi
```
main (Claude - Üretim)
  │
  ├── feature/gwen-* (gwen-dev - ERP)
  │    └── PR → main'e merge
  │
  └── feature/gwen-arge (gwen-arge - ARGE)
       └── PR → main'e merge
```

### Commit Mesajı Konvansiyonu
```
DONE: [tip]: [açıklama]

Örnekler:
DONE: dev: Tohumlama formu tarih validasyonu eklendi
DONE: arge: session-rules skill'i oluşturuldu
DONE: dev: UI bug — modal kapanma sorunu fix edildi
```

---

## 📜 EVRENSEL KURALLAR

### Tüm Agent'lar İçin

1. **Session Tipi Kilidi**
   - Session başında belirlenir (dev/arge)
   - Session boyunca **değişmez**
   - İhlal YASAK

2. **Sub-orchestrator Yasağı**
   - Qwen → başka Qwen spawn EDEMEZ
   - Sadece native subagent (runner olarak)
   - Aynı dosyaya paralel yazma YASAK

3. **Branch Disiplini**
   - gwen-dev → `feature/gwen-*`
   - gwen-arge → `feature/gwen-arge`
   - main → direkt push YASAK (PR gerekir)

4. **MCP Koruma**
   - MCP servers ASLA silinmez
   - Her görev öncesi `qwen mcp list` ile doğrula
   - Silinirse `.qwen/QWEN.md` restore prosedürü

5. **DONE: Commit Zorunluluğu**
   - Her commit mesajı `DONE:` ile başlar
   - Session tipi belirtilir (dev/arge)
   - Task bitince commit

---

## 🚀 YENİ AGENT/SKILL EKLEME

### gwen-dev'e Skill Ekleme (YASAK)
- ❌ gwen-dev session'ında skill/agent/MCP geliştirme YASAK
- ✅ Sadece mevcut skills kullanılır

### gwen-arge'a Skill Ekleme
1. `feature/gwen-arge` branch'inde çalış
2. `/root/.qwen/skills/[yeni-skill]/SKILL.md` oluştur
3. `.qwen/QWEN.md`'de belgele
4. Test et
5. `DONE: arge — [skill adı] eklendi` commit

### Yeni Agent Ekleme
1. `feature/gwen-arge` branch'inde çalış
2. `/root/.qwen/agents/[yeni-agent].md` oluştur
3. `.qwen/QWEN.md`'de belgele
4. Test et
5. `DONE: arge — [agent adı] eklendi` commit

---

## ⚠️ YASAKLAR

1. **Qwen → Qwen spawn YASAK** (sub-orchestrator yasağı)
2. **Aynı dosyaya paralel yazma YASAK** (çakışma)
3. **Session tipi ihlali YASAK** (dev/arge kilidi)
4. **main branch'e direkt push YASAK** (PR gerekir)
5. **MCP silme YASAK** (`.qwen/QWEN.md` ihlali)
6. **gwen-dev → AR-GE YASAK** (skill/agent/MCP geliştirme)
7. **gwen-arge → ERP dev YASAK** (tohumlama, doğum, hayvan)

---

## 📚 REFERANS DOSYALAR

### Qwen Code
- `.qwen/QWEN.md` — Qwen Code workflow kuralları, session tipi
- `.qwen/AGENT_HIERARCHY.md` — Bu dosya — hiyerarşi, sub-orchestrator
- `.qwen/settings.json` — MCP konfigürasyonu
- `gwen-cli.sh` — Gwen CLI arayüzü

### Claude Code
- `CLAUDE.md` — Ana orkestrasyon talimatları
- `.claude/agents/` — Claude agent'ları

---

## 📝 GÜNCELLEME GEÇMİŞİ

| Tarih | Değişiklik |
|-------|------------|
| 2026-04-01 | Yeni mimari — Claude orkestratör, gwen-dev/gwen-arge ayrımı |
| 2026-04-01 | Sub-orchestrator yasağı, runner subagent kuralı eklendi |

---

**NOT:** Bu dosya HER YENİ AGENT/SKILL EKLENDİĞİNDE güncellenmelidir.
