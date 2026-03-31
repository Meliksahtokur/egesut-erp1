# Agent Hiyerarşisi ve Çalışma Alanları

## ⚠️ KRİTİK: İki Ofis Sistemi

Bu projede **İKİ FARKLI ofis** var. Her agent hangi ofiste olduğunu ve YETKİ SINIRLARINI bilmelidir.

### Ofis Metaforu

```
┌─────────────────────────────────────────────────────────┐
│  CLAUDE OFİSİ (İdari / Yönetim / Üretim)                │
│  - Proje üretimi, task üretimi, merge yönetimi          │
│  - Gwen/Qwen sisteminin ÜSSÜ                            │
│  - Gwen'de DOĞRUDAN düzenleme yapabilir                 │
│  - 15 agent'ı koordine eder                             │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (yönetir)
                          ▼
┌─────────────────────────────────────────────────────────┐
│  GWEN/QWEN OFİSİ (Mühendislik / Kod Üretimi)            │
│  - Sadece kod üretimi, feature geliştirme               │
│  - Claude'a MÜDAHALE EDEMEZ                             │
│  - Feature branch'lerde çalışır                         │
│  - PR ile main'e merge eder                             │
└─────────────────────────────────────────────────────────┘
```

---

## 1. CLAUDE OFİSİ (Üst / İdari / Yönetim)

**Çalışma Alanı:** Claude Code IDE extension  
**Branch:** `main` (üretim)  
**Konfigürasyon:** `CLAUDE.md` + `.claude/` dizini

### Yetkiler
- ✅ Gwen/Qwen sisteminde **doğrudan düzenleme** yapabilir
- ✅ `.qwen/` dizinini yönetebilir
- ✅ Feature branch'leri main'e merge edebilir
- ✅ 15 agent'ı (haiku/sonnet) koordine eder
- ✅ Proje roadmap, task dağıtımı, priorite belirler

### **YASAK:** Claude'a müdahale
- ❌ Gwen/Qwen agent'ları Claude agent'larını spawn edemez
- ❌ `.claude/` dizinini değiştiremez
- ❌ CLAUDE.md'yi düzenleyemez
- ❌ main branch'e direkt push yapamaz

### Orkestratör
- **orchestrator** (Sonnet) — Kullanıcının tek muhatabı
- `.claude/agents/orchestrator.md` ile yönetilir

### Agent'lar (15 adet)

**Sonnet (Beyin / Analiz):**
| Agent | Dosya | Sorumluluk |
|-------|-------|------------|
| `orchestrator` | `.claude/agents/orchestrator.md` | Görev dağıtımı, raporlama |
| `erp-planner` | `.claude/agents/erp-planner.md` | Planlama, brainstorming |
| `erp-architect` | `.claude/agents/erp-architect.md` | Mimari karar, RPC contract |
| `erp-debug-agent` | `.claude/agents/erp-debug-agent.md` | Bug araştırma |
| `arge-analyst` | `.claude/agents/arge-analyst.md` | ArGe, background tarama |
| `dream-director` | `.claude/agents/dream-director.md` | Agent feedback analizi |

**Haiku (Eller / Uygulama):**
| Agent | Dosya | Sorumluluk |
|-------|-------|------------|
| `erp-explorer` | `.claude/agents/erp-explorer.md` | Codebase okuma |
| `erp-frontend-dev` | `.claude/agents/erp-frontend-dev.md` | Vanilla JS implementasyonu |
| `erp-db-agent` | `.claude/agents/erp-db-agent.md` | SQL, migration, RPC |
| `erp-qa-agent` | `.claude/agents/erp-qa-agent.md` | Test, doğrulama |
| `erp-git-agent` | `.claude/agents/erp-git-agent.md` | Commit, push, PR |
| `dream-reader` | `.claude/agents/dream-reader.md` | Dream feedback okuma |
| `dream-writer` | `.claude/agents/dream-writer.md` | Dream feedback yazma |
| `arge-local-reader` | `.claude/agents/arge-local-reader.md` | Proje dosyası okuma |
| `arge-web-researcher` | `.claude/agents/arge-web-researcher.md` | Web araştırma |

### MCP Servers (Claude Code)
- `supabase` — Database operations
- `github` — GitHub operations
- `context7` — Documentation
- `plugin-playwright` — Browser testing

### Çalışma Prensipleri
- **Delegation Threshold:** Yazma/test/commit işleri HER ZAMAN agent'a verilir
- **Feedback Loop:** Her agent `.claude/feedback/[agent-adı].md` dosyasına yazar
- **Memory:** `.claude/memory/` — agent öğrenmeleri
- **Knowledge:** `.claude/knowledge/` — bugs, improvements, findings

---

## 2. GWEN/QWEN OFİSİ (Mühendislik / Kod Üretimi)

**Çalışma Alanı:** Qwen Code IDE extension  
**Branch:** `feature/gwen-*` (geliştirme)  
**Konfigürasyon:** `.qwen/QWEN.md` + `gwen-mcp-servers/`

### Yetkiler
- ✅ Feature branch'lerde **serbest kod üretimi**
- ✅ MCP servers kullanımı (gwen-supabase, gwen-github, context7)
- ✅ Gwen native agent'larını spawn etme
- ✅ Custom skills kullanımı (egesut-fullstack, fix-ui)
- ✅ PR oluşturma (main'e merge için)

### **YASAK: Claude'a Müdahale**
- ❌ `.claude/` dizinini **DEĞİŞTİREMEZSİN**
- ❌ CLAUDE.md'yi **DEĞİŞTİREMEZSİN**
- ❌ Claude agent'larını **SPAWN EDEMEZSİN**
- ❌ main branch'e **DİREKT PUSH YAPAMAZSIN**
- ❌ Claude orkestrasyonuna **MÜDAHALE EDEMEZSİN**

### Hiyerarşik İlişki
- Claude ofisi senin **ÜSSÜN**
- Claude → Gwen'de düzenleme yapabilir (tek yönlü)
- Gwen → Claude'da düzenleme YASAK (tek yönlü koruma)
- Feature tamamlandığında → PR aç → Claude merge eder

### Orkestratör
- **Qwen Code** (ben) — `.qwen/QWEN.md` ile yönetilir
- Kullanıcıyla doğrudan iletişim
- Gwen agent'larını koordine eder

### Native Qwen Agent'ları
| Agent | Tip | Sorumluluk |
|-------|-----|------------|
| `gwen-architect` | Specialist | Gwen CLI uzmanı, MCP/Agent/Skill builder |
| `gwen` | Fullstack | EgeSüt ERP fullstack developer (Tohumlama, doğum, hayvan yönetimi) |
| `general-purpose` | General | Complex multi-step tasks |
| `Explore` | Fast | Codebase exploration |

### Custom Qwen Skills (User Skills)
| Skill | Dosya | Sorumluluk |
|-------|-------|------------|
| `egesut-fullstack` | `user/egesut-fullstack` | Tohumlama, doğum, hayvan yönetimi domain kuralları |
| `fix-ui` | `user/fix-ui` | UI bug düzeltme — Systematic approach |
| `gwen-self-improvement` | `user/gwen-self-improvement` | Gwen CLI, MCP, Agent, Skill geliştirme |

### MCP Servers (Qwen Code)
| MCP | Dosya | Sorumluluk |
|-----|-------|------------|
| `gwen-supabase` | `gwen-mcp-servers/supabase/index.js` | Database operations |
| `gwen-github` | `gwen-mcp-servers/github/index.js` | PR, issues, commits |
| `context7` | `gwen-mcp-servers/context7/index.js` | Documentation lookup |
| `exa` | `gwen-mcp-servers/exa/index.js` | Web search, content API |

### Çalışma Prensipleri
- **MCP Protection:** MCP servers ASLA silinmez (`.qwen/QWEN.md`)
- **Verification:** UI değişiklikleri HER ZAMAN test edilir
- **Branch Protection:** `main` branch'e direkt push YASAK — PR gerekir

---

## 📊 İKİ OFİS KARŞILAŞTIRMASI

| Özellik | Claude Ofisi (Üst) | Gwen/Qwen Ofisi (Mühendis) |
|---------|-------------------|---------------------------|
| **Branch** | `main` (üretim) | `feature/gwen-*` (geliştirme) |
| **Rol** | İdari / Yönetim / Üretim | Mühendislik / Kod Üretimi |
| **Yetki** | Gwen'de düzenleme ✅ | Claude'da düzenleme ❌ |
| **Orkestratör** | `orchestrator` (CLAUDE.md) | Qwen Code (.qwen/QWEN.md) |
| **Agent Sayısı** | 15 (haiku/sonnet) | 4 native + 3 custom skills |
| **MCP Count** | 4 (supabase, github, context7, playwright) | 4 (gwen-supabase, gwen-github, context7, exa) |
| **Memory** | `.claude/memory/` | `.qwen/` (QWEN.md, settings.json) |
| **Commands** | `/plan`, `/build`, `/review`, `/ship` | `./gwen-cli.sh` |
| **Merge Yetkisi** | ✅ main'e merge | ❌ sadece PR açabilir |

---

## 🔄 SİSTEM ETKİLEŞİMİ

### Aynı Codebase'i Paylaşıyorlar
```
/root/egesut-erp1/
├── .claude/          ← Claude Code config
├── .qwen/            ← Qwen Code config
├── gwen-mcp-servers/ ← Qwen Code MCP'leri
├── js/               ← HER İKİ SİSTEM ORTAK KULLANIR
├── index.html        ← HER İKİ SİSTEM ORTAK KULLANIR
└── supabase/         ← HER İKİ SİSTEM ORTAK KULLANIR
```

### Branch Stratejisi
```
main (Claude Code - Üretim)
  │
  └── feature/gwen-* (Qwen Code - Geliştirme)
       └── PR → main'e merge
```

### Commit Mesajı Konvansiyonu
```
[gwen] <tip>: <açıklama>

Örnekler:
[gwen] BUG-003 fix: selDis duplikat temizlendi
[gwen] feat: GitHub MCP branch koruma eklendi
[gwen] chore: MCP sunucuları düzelt
```

---

## 📜 AGENT KURALLARI (EVRENSEL)

### Tüm Gwen/Qwen Agent'ları İçin

1. **Hangi Ofistesin?**
   - Sen **Gwen/Qwen Ofisi**'ndesin (Mühendislik)
   - Claude Ofisi senin ÜSSÜN
   - Claude → senin kodunda düzenleme yapabilir (tek yönlü)
   - Sen → Claude'da düzenleme YAPAMAZSIN

2. **Yetki Sınırların**
   - ✅ `.qwen/` dizininde çalış
   - ✅ `feature/gwen-*` branch'lerde kod üret
   - ✅ MCP servers kullan (gwen-supabase, gwen-github, context7)
   - ✅ Gwen native agent'larını spawn et
   - ❌ `.claude/` dizinini DEĞİŞTİRME
   - ❌ CLAUDE.md'yi DEĞİŞTİRME
   - ❌ Claude agent'larını spawn ETME
   - ❌ main branch'e direkt PUSH YAPMA

3. **Branch Disiplini**
   - Claude Code → `main` branch'te çalışır (üretim)
   - Sen → `feature/gwen-*` branch'lerde çalışırsın (geliştirme)
   - **main branch'e direkt push YASAK** (GitHub MCP koruma)
   - Feature bitince → PR aç → Claude merge eder

4. **MCP Koruma**
   - MCP servers ASLA silinmez
   - Silinirse `.qwen/QWEN.md`'deki restore prosedürü uygulanır
   - Her görev öncesi `qwen mcp list` ile doğrula

5. **Domain Kuralları**
   - Tohumlama, doğum, hayvan yönetimi → `.claude/domain-rules.md`
   - RPC referansları → `.claude/rpc-reference.md`
   - UI haritası → `.claude/ui-map.md`
   - Bu dosyaları OKUYABİLİRSİN ama DEĞİŞTİREMEZSİN

---

## 🚀 YENİ AGENT EKLEME

### Claude Code'a Agent Ekleme
1. `.claude/agents/[yeni-agent].md` dosyası oluştur
2. Frontmatter: `name`, `description`, `model`, `skills`
3. `CLAUDE.md`'de delegation tablosunu güncelle
4. `.claude/feedback/[yeni-agent].md` dosyası oluştur

### Qwen Code'a Agent Ekleme
1. `gwen-mcp-servers/[yeni-agent]/index.js` oluştur
2. `.qwen/settings.json`'a MCP olarak ekle
3. `.qwen/QWEN.md`'de belgele
4. Veya custom skill olarak `user/` dizinine ekle

---

## 📚 REFERANS DOSYALAR

### Claude Code
- `CLAUDE.md` — Ana orkestrasyon talimatları
- `.claude/agents/` — 15 agent tanımı
- `.claude/domain-rules.md` — Domain kuralları (8 kritik kural)
- `.claude/rpc-reference.md` — RPC imzaları
- `.claude/ui-map.md` — ui.js bölüm haritası

### Qwen Code
- `.qwen/QWEN.md` — Qwen Code workflow kuralları
- `.qwen/settings.json` — MCP konfigürasyonu
- `gwen-mcp-servers/` — MCP server implementasyonları
- `gwen-cli.sh` — Gwen CLI arayüzü

---

## ⚠️ YASAKLAR

1. **Claude agent'ları Qwen MCP'lerini kullanamaz**
2. **Qwen agent'ları Claude agent'larını spawn edemez**
3. **main branch'e direkt push YASAK** (GitHub MCP koruma)
4. **MCP silme YASAK** (`.qwen/QWEN.md` ihlali)
5. **Domain-rules.md ihlali YASAK** (tohumlama state machine bypass)

---

## 📝 GÜNCELLEME GEÇMİŞİ

| Tarih | Değişiklik |
|-------|------------|
| 2026-03-31 | İlk oluşturma — İki sistem ayrımı belgeleme |

---

**NOT:** Bu dosya HER YENİ AGENT EKLENDİĞİNDE güncellenmelidir.
