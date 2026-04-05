# EgeSüt ERP — Agentic Mimari Sunumu
> **Hazırlayan:** MiniMax M2.7 — opencode-dev Baş Mühendisi  
> **Tarih:** 2026-04-04  
> **Versiyon:** 1.0 — HİBRİT STRATEJİ  
> **Statü:** KARAR BEKLENİYOR  

---

# SLIDE 1 — SORUN: NEDEN BU PLAN?

## Mevcut Durum

```
❌ Orchestrator → hayali agent'lara referans veriyor (erp-db-agent, erp-frontend-dev... dosyaları YOK)
❌ erp-implementer → hem DB hem FE yapıyor (tek agent, yavaş)
❌ erp-qa-git → model: Haiku (yetersiz, İ-005 uyarısı)
❌ 4 agent var, 10+ domain uzmanlığı gerekli
❌ Test otomasyonu YOK
❌ Agent multiplicity (paralel çalışma) YOK
```

## Kullanıcı Gerçekleri

| Gerçek | Etki |
|--------|------|
| MiniMax M2.7 sadece | Call-based billing, token limit önemsiz |
| Agent çoğulluğu serbest | Aynı iş birden fazla agent'a verilebilir |
| Paralel çalışma tercih edilir | Hız × maliyet avantajı |
| GitHub Actions → Supabase auto-push | Migration CI/CD zaten var |
| TestSprite MCP mevcut | Ücretsiz test otomasyonu mevcut |

**Sonuç:** Elimizde güçlü altyapı var, sadece organize edilmesi gerekiyor.

---

# SLIDE 2 — SORU 1: NE YAPALIM — CUSTOM MI, HAZIR MI?

## Üç Katmanlı Strateji

```
┌────────────────────────────────────────────────────────────────┐
│  KATMAN 1: DIŞ TEMPLATE (VoltAgent + Plugin)                  │
│  → Hazır, sadece ADAPTASYON gerekli                           │
│  → 5-10 dakikalık iş × 6 agent = ~1 saat                      │
│  → 100× daha hızlı, sıfırdan yazmaktan                        │
│                                                                │
│  KATMAN 2: CUSTOM SKILL (Antigravity + Sıfırdan)              │
│  → EgeSüt domain kuralları (RPC-only, ledger, state machine)  │
│  → Mimariye özgü workflow'lar                                 │
│  → Sıfırdan yazılacak ama çok küçük (20-30 satır / agent)   │
│                                                                │
│  KATMAN 3: MEVCUTTAN GÜÇLENDİR                               │
│  → orchestrator.md, erp-implementer.md → ADAPTE ET            │
│  → Sıfırdan yazma, iyileştir                                  │
└────────────────────────────────────────────────────────────────┘
```

## Karşılaştırma

| Yaklaşım | Zaman | Kalite | EgeSüt Uyumu |
|----------|-------|--------|--------------|
| Sadece custom (tam sıfırdan) | ~40 saat | Orta | ✅ Mükemmel |
| Sadece hazır template | ~2 saat | Düşük | ❌ Domain bilgisi yok |
| **HİBRİT (önerilen)** | **~5 saat** | **Yüksek** | **✅ Mükemmel** |

**Neden hibrit?**
- VoltAgent template'leri mükemmel kalitede (130+ agent, profesyonel olarak yazılmış)
- Domain bilgisi sadece EgeSüt'te var — o kısım custom
- 100× zaman kazanırız, kaliteden ödün vermeyiz

---

# SLIDE 3 — SORU 2: AGENTLARIN TOOLLARI VE SKİLLERİ BELLİ Mİ?

## Evet — Template'lerde Tanımlı

### VoltAgent YAML Header Formatı

```yaml
---
name: backend-developer
description: "Use this agent when building server-side APIs..."
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
---
```

### EgeSüt Adaptasyonunda Eklenenler

| Agent | Base Tools | + EgeSüt Ek Tools |
|-------|-----------|-------------------|
| erp-db-agent | Read, Write, Bash, Glob, Grep | `mcp__supabase__*`, `mcp__supabase__apply_migration` |
| erp-frontend-agent | Read, Write, Edit, Glob, Grep | node --check |
| erp-qa-agent | Read, Grep, Glob, Bash | `mcp__TestSprite__*`, curl, playwright |
| erp-debug-agent | Read, Bash, Glob, Grep | `mcp__supabase__get_logs`, `mcp__supabase__execute_sql` |
| erp-architect | Glob, Grep, Read, Bash | `mcp__supabase__list_tables` |

### Agentın Bileşenleri — Her Zaman Belli

```
Agent Dosyası =
  ├── YAML Header (name, tools, model)
  ├── Base Template (VoltAgent/Plugin'tan)
  │     ├── Genel yetkinlikler
  │     ├── Process/invocation order
  │     └── Quality criteria
  ├── EgeSüt Domain Layer (custom ekleme)
  │     ├── Domain kuralları (13 madde)
  │     ├── RPC-only yazma kuralı
  │     ├── Supabase MCP kullanımı
  │     ├── Türkçe kod stili
  │     ├── Commit formatı
  │     └── Task döngüsü
  └── Raporlama Formatı
        └── task-xxx-done.md standartı
```

---

# SLIDE 4 — SORU 3: MİX YAPABİLİR MİYİZ?

## Evet — Mix Zaten Planlı

### Template Kaynak Matrisi

```
VoltAgent Templates
├── backend-developer.md     ──────────────────→ erp-db-agent
├── frontend-developer.md    ──────────────────→ erp-frontend-agent
├── qa-expert.md            ──────────────────→ erp-qa-agent
├── debugger.md             ──────────────────→ erp-debug-agent
└── multi-agent-coordinator ──────────────────→ orchestrator (güçlendirme)
      │
      └── Agentler arası koordinasyon uzmanlığı

Claude Code Plugin Agents
├── code-architect.md       ──────────────────→ erp-architect
├── code-explorer.md        ──────────────────→ erp-explorer (zaten var)
└── code-reviewer.md        ──────────────────→ erp-qa-agent (quality layer)

Custom Domain Agent'lar (Sıfırdan — Dışarıda Yok)
├── erp-clinical-agent      ──────────────────→ Klinik domain (cases, drugs, diseases)
├── erp-reproduction-agent  ──────────────────→ Üreme domain (tohumlama, gebelik, doğum)
├── erp-stock-agent         ──────────────────→ Stok domain (ledger, kritik eşik)
├── erp-herd-agent          ──────────────────→ Sürü domain (padok, grup, kupe)
└── erp-knowledge-agent     ──────────────────→ Dokümantasyon yönetimi
```

### Mix Formülü

```
HER AGENT =
  VoltAgent/Plugin Template (base, process, tools)
  × EgeSüt Domain Layer (kurallar, RPC pattern, Türkçe)
  + Custom Skill (domain-özel iş akışları)
  + Hookify Koruma (blok/warn mekanizması)
```

### Mix Örneği: erp-db-agent

```
VoltAgent backend-developer.md'DEN AL:
  ├── "You are a senior backend developer specializing in..."
  ├── tools: Read, Write, Edit, Bash, Glob, Grep
  ├── Process: analyze → design → implement → verify
  └── Database architecture patterns

EgeSüt Domain Layer OLARAK EKLE:
  ├── "Sen EgeSüt ERP veritabanı uzmanısın"
  ├── "Sadece RPC ile yazarsın — direkt REST YASAK"
  ├── "Migration idempotent olmalı: DROP IF EXISTS + CREATE OR REPLACE"
  ├── "Supabase MCP kullan: mcp__supabase__apply_migration"
  ├── "Türkçe değişken isimleri kullan"
  └── "Commit formatı: fix/feat/chore: kısa açıklama"

SONUÇ: 15 dakikada hazır agent
```

---

# SLIDE 5 — SORU 4: AGENT EĞİTİMİ NASIL YAPILACAK?

## İki Aşama: Bootstrap + İteratif Öğrenme

### Aşama 1: Bootstrap (İlk Kurulum)

```
⏱️ TOPLAM: ~5 SAAT

SAAT 0-0.5 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  Template'leri topla ve oku
│  → VoltAgent backend-developer.md    (~5 dk)
│  → VoltAgent frontend-developer.md   (~5 dk)
│  → VoltAgent qa-expert.md           (~5 dk)
│  → VoltAgent debugger.md            (~5 dk)
│  → VoltAgent multi-agent-coordinator (~5 dk)
│  → Plugin code-architect.md         (~3 dk)
│  → Plugin code-reviewer.md         (~5 dk)
│  Toplam: ~30 dakika (sadece okuma)
│
SAAT 0.5-2.5 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  6 Agent Adaptasyonu (~20 dk / agent)
│  → Template'i kopyala
│  → YAML header güncelle (name, model)
│  → EgeSüt domain layer yapıştır
│  → Tool listesi güncelle (MCP ekle)
│  → Raporlama formatı ekle
│  → Test: küçük bir görevle doğrula
│
SAAT 2.5-3.0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  5 Custom Domain Agent Oluşturma (~10 dk / agent)
│  → Domain bilgisi + standart format
│  → Tools: Glob, Grep, Read + MCP'ler
│
SAAT 3.0-4.0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  4 Skill Dosyası Oluşturma
│  → erp-onboarding (Antigravity codebase-onboarding'dan)
│  → erp-domain-checker (custom)
│  → erp-migration (VoltAgent backend-developer + Antigravity db-migrations)
│  → erp-parallel-workflow (custom)
│
SAAT 4.0-5.0 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  Hook Konfigürasyonu
│  → Mevcut Hookify kurallarını gözden geçir
│  → Agent'lara referans ver
│  → Yeni hook'ları settings.json'a ekle
│
PİLOT TEST ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│  Gerçek bir görevle test et
│  → "Vaccines IDB store eksik" bug'ı düzeltilsin
│  → Agent davranışını gözle
│  → Prompt'ta düzeltme yap
```

### Aşama 2: İteratif Öğrenme (Sürekli — Görev Döngüsü)

```
HER GÖREV DÖNGÜSÜ:
│
├─ 1. Agent görevi alır
│     → task-xxx.md dosyasını okur
│     → Plan yapar
│     → Adım adım uygular
│
├─ 2. Agent tamamlar
│     → task-xxx-done.md oluşturur
│     → Commit + Push
│
├─ 3. QA agent otomatik tetiklenir
│     → TestSprite smoke test
│     → curl RPC doğrulama
│     → Domain-rule compliance check
│
├─ 4. Sonuç değerlendirilir
│     ├─ GEÇTİ ✅
│     │     → Görev tamam
│     │     → MEMORY.md'ye özet yaz
│     │
│     └─ KALDI ❌
│           → Hata analizi
│           ├─ "Agent domain kuralını bilmiyordu"
│           │     → Domain layer'a YENİ KURAL EKLE
│           │     → Agent prompt'unu GÜNCELLE
│           │
│           ├─ "Agent template'i yanlış kullandı"
│           │     → Template adaptasyonunu DÜZELT
│           │
│           └─ "Yeni bir pattern ortaya çıktı"
│                 → MEMORY.md'ye KAYDET
│                 → Gerekirse yeni skill OLUŞTUR
│
└─ 5. Bir sonraki görev daha iyi
      → Agent "öğrenmiş" oldu
      → MEMORY üzerinden kalıcı hafıza
```

### Agent Memory — Kalıcı Hafıza Sistemi

```
MEMORY.md içeriği (her agent için):

# erp-db-agent Memory
## Domain Uzmanlıkları
- RPC-only yazma kuralı — her zaman uygula
- Migration: DROP önce, ADD sonra (42P13 hatası)
- SECURITY DEFINER zorunlu yeni tablolarda

## Bilinen Hata Kalıpları
- "tohumlama_sonuc_bos 42883 hatası" — p_toh_id tipi uuid olmalı
- "Supabase MCP unauthorized" — apply_migration yetkisi kontrol edilmeli

## Başarılı Workflow'lar
- Büyük migration: önce small test migration → sonra gerçek
- RPC test: önce curl → sonra UI test

## Son Güncelleme
- 2026-04-04: Oluşturuldu (M2.7 Bootstrap)
- [Her görev sonrası güncellenir]
```

---

# SLIDE 6 — ELİMİZDEKİ KAYNAKLAR

## VoltAgent Agents (130+ Agent Template)

| Kategori | Sayı | Kullanılabilir |
|----------|------|---------------|
| 01-core-development | 12 | ✅ backend-dev, frontend-dev |
| 02-language-specialists | 12 | ⚠️ JavaScript uzmanı lazım |
| 03-infrastructure | 7 | ⚠️ GitHub Actions uzmanı lazım |
| 04-quality-security | 15 | ✅ qa-expert, debugger |
| 05-data-ai | 8 | ❌ Gerekmiyor |
| 06-developer-experience | 6 | ⚠️ Onboarding uzmanı lazım |
| 07-specialized-domains | 10 | ❌ Domain-specific değil |
| 08-business-product | 8 | ❌ Gerekmiyor |
| 09-meta-orchestration | 12 | ✅ multi-agent-coordinator |
| 10-research-analysis | 8 | ❌ Gerekmiyor |

**Doğrudan kullanılacak:** 6 template (backend-dev, frontend-dev, qa-expert, debugger, multi-agent-coordinator)

## Claude Code Plugin Agents (Lokal)

```
✅ code-architect.md      — feature-dev/plugin, 35 satır, çok kaliteli
✅ code-explorer.md      — feature-dev/plugin, zaten kullanılıyor
✅ code-reviewer.md      — feature-dev/plugin, 40+ satır, confidence scoring
❌ pr-review-toolkit     — disabled plugin, gerekirse açılabilir
❌ feature-dev           — disabled plugin, agent'lar kullanılabilir
```

## Antigravity Skills (1,344+ Skill)

| Kategori | Sayı | EgeSüt Kullanımı |
|----------|------|-------------------|
| agentic-engineering | ~20 | ✅ Agent oluşturma workflow |
| database-migrations | ~15 | ✅ Migration yazım pattern |
| postgres-patterns | ~20 | ✅ RPC tasarımı |
| mcp-server-patterns | ~10 | ✅ Supabase MCP kullanımı |
| git-workflow | ~10 | ✅ Commit/push workflow |
| codebase-onboarding | ~10 | ✅ erp-onboarding skill |
| continuous-agent-loop | ~10 | ✅ Orchestrator loop önleme |
| verification-loop | ~10 | ✅ QA test döngüsü |
| frontend-patterns | ~20 | ⚠️ Vanilla JS adaptasyon gerekli |
| security-review | ~15 | ⚠️ Gerekirse |
| api-design | ~15 | ⚠️ RPC tasarımı |

## Mevcut Sistem

```
✅ Supabase MCP         — Zaten aktif
✅ GitHub MCP           — Zaten aktif (auth hatası var, ama dosyalar mevcut)
✅ Context7 MCP        — Zaten aktif
✅ Hookify             — 3 hook aktif (block-direct-db-writes, warn-duplicate-fn, warn-critical-files)
✅ GitHub Actions      — 4 workflow var (deploy, migration-telemetry, test-migration-ready, bildirim_check)
✅ TestSprite MCP      — Zaten kurulu, kullanıma hazır
```

---

# SLIDE 7 — ÖNERİLEN 10 AGENTLIK TAKIM

```
┌─────────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (MiniMax M2.7)                                │
│  ────────────────────────────────────────────────────────  │
│  Kaynak: VoltAgent multi-agent-coordinator ADAPTE           │
│  × EgeSüt layer (domain kuralları, task yönetimi)           │
│                                                             │
│  GÖREV: Kullanıcı isteğini parçala → Agent atama kararı     │
│  → Paralel mi, sıralı mı? Koordinasyon kur                 │
│  → Sonuçları birleştir → Raporla                            │
└────────────────────────────┬────────────────────────────────┘
                             │
      ┌──────────────────────┼──────────────────────────────┐
      │                      │                              │
┌─────▼──────────┐  ┌────────▼─────────┐  ┌────────────────▼─────────┐
│ ERP-DB-AGENT    │  │ ERP-FRONTEND-AG  │  │ ERP-QA-AGENT              │
│ Kaynak: VoltAg. │  │ Kaynak: VoltAg.  │  │ Kaynak: VoltAg. qa-expert │
│ backend-dev     │  │ frontend-dev     │  │ + Plugin code-reviewer    │
│                 │  │                  │  │                           │
│ Domain:         │  │ Domain:          │  │ Domain:                    │
│ • Migration     │  │ • js/ui.js       │  │ • TestSprite smoke         │
│ • RPC tasarımı  │  │ • js/forms.js    │  │ • curl RPC test            │
│ • Supabase MCP  │  │ • js/app.js      │  │ • Domain-rule compliance   │
│ • Schema analiz │  │ • index.html     │  │ • node --check             │
│                 │  │                  │  │ • Confidence scoring       │
│ Tools:          │  │ Tools:           │  │                           │
│ • mcp__supabase │  │ Read, Write,     │  │ Tools:                     │
│ • Bash (sql)    │  │ Edit, Glob,      │  │ • mcp__TestSprite          │
│ • Glob, Grep    │  │ Grep, Bash       │  │ • curl (RPC test)          │
│                 │  │                  │  │ • Bash (node)              │
└────────┬────────┘  └────────┬─────────┘  └──────────────┬──────────┘
         │                    │                           │
┌────────▼────────┐  ┌────────▼─────────┐  ┌────────────────▼─────────┐
│ ERP-CLINICAL-AG │  │ ERP-REPRODUC-AG  │  │ ERP-DOMAIN-SPECIALISTS    │
│ CUSTOM          │  │ CUSTOM           │  │                           │
│ (Sıfırdan)      │  │ (Sıfırdan)       │  │ • erp-stock-agent (stok)  │
│                 │  │                  │  │ • erp-herd-agent (sürü)   │
│ Domain:         │  │ Domain:          │  │ • erp-knowledge-agent      │
│ • cases, drugs  │  │ • Tohumlama SM   │  │   (dokümantasyon)         │
│ • treatment_days│ │ • Gebelik/doğum  │  │                           │
│ • İlaç uygulama │  │ • Kızgınlık      │  │ Tools:                     │
│                 │  │                  │  │ • Read, Write, Glob        │
│                 │  │                  │  │ • mcp__supabase (gerekirse)│
└─────────────────┘  └──────────────────┘  └───────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  UTILITY AGENTS (Hepsi MiniMax M2.7)                        │
│  ─────────────────────────────────────────────────────────  │
│                                                             │
│  ERP-DEBUG-AGENT        → VoltAgent debugger ADAPTE         │
│  • Hata analizi (ui_logs, Supabase logs)                    │
│  • Error pattern recognition                                │
│  • Root cause analysis                                      │
│  • Tools: mcp__supabase__get_logs, mcp__supabase__execute_sql │
│                                                             │
│  ERP-ARCHITECT          → Plugin code-architect ADAPTE      │
│  • Schema tasarımı (yeni tablo, FK, index)                 │
│  • RPC contract tasarımı                                    │
│  • Büyük feature blueprint                                  │
│  • Tools: Glob, Grep, Read, mcp__supabase__list_tables    │
│                                                             │
│  ERP-EXPLORER           → Plugin code-explorer (mevcut)     │
│  • Fonksiyon izleme, duplicate tespit                      │
│  • Kod karmaşıklığı analizi                                 │
│  • Tools: Glob, Grep, Read                                  │
└─────────────────────────────────────────────────────────────┘
```

---

# SLIDE 8 — ROL ATAMA MATRİSİ

| Görev | DB | FE | Clinical | Repro | Stock | Herd | Knowledge | QA | Debug | Architect |
|-------|----|----|---------|-------|-------|------|-----------|----|----|----------|
| Yeni migration | 🟦 | | | | 🟦 | | | | | 🟡 |
| RPC ekleme | 🟦 | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | | 🟡 | | 🟡 |
| Klinik UI tamamla | | 🟦 | 🟦 | | | | | 🟦 | | |
| Tohumlama RPC refaktörü | 🟦 | 🟦 | | 🟦 | | | | 🟦 | | |
| UI bug düzeltme | | 🟦 | | | | | | 🟦 | 🟦 | |
| Büyük schema değişikliği | 🟦 | | | | | | | | | 🟦 |
| Hata analizi | 🟡 | 🟡 | | | | | | | 🟦 | |
| Kod keşfi | | 🟡 | | | | | | | 🟡 | 🟡 |
| Dokümantasyon | | | | | | | 🟦 | | | |
| Domain ihlal tespiti | | | | | | | | 🟦 | | |

> 🟦 = **Primary** (bu iş için tasarlandı)  
> 🟡 = **Secondary** (destek, gerekirse)  
> Boş = Bu iş için kullanılmaz

---

# SLIDE 9 — TEST OTOMASYON STRATEJİSİ

## Test Katmanları

| Katman | Araç | Ne Test Edilir | Kim Çalıştırır | Ne Zaman |
|--------|------|----------------|----------------|----------|
| **Syntax** | `node --check` | JS syntax hatası | Hookify (pre-commit) | Commit öncesi otomatik |
| **Smoke** | Playwright (yerel) | UI açılışı, render | qa-agent | Her görev sonu |
| **Backend RPC** | `curl` | RPC çalışıyor mu | qa-agent | Migration sonrası |
| **Integration** | TestSprite MCP | Kullanıcı akışı | qa-agent | Pilot test + PR öncesi |
| **Migration** | test-migration-ready.yml | Migration syntax | GitHub Actions | feature/gwen-arge push |
| **CI/CD** | deploy.yml | GitHub Pages deploy | GitHub Actions | Her push |

## TestSprite Kullanım Akışı

```
qa-agent her görev sonunda:
│
├─ 1. Bootstrap (ilk seferde)
│     mcp__TestSprite__testsprite_bootstrap({
│       projectPath: "/root/egesut-erp1",
│       type: "frontend",
│       testScope: "codebase",
│       localPort: 3000
│     })
│
├─ 2. Test planı oluştur
│     mcp__TestSprite__testsprite_generate_frontend_test_plan({
│       projectPath: "/root/egesut-erp1",
│       needLogin: true
│     })
│
├─ 3. Testleri çalıştır
│     mcp__TestSprite__testsprite_generate_code_and_execute({
│       projectName: "egesut-erp1",
│       projectPath: "/root/egesut-erp1",
│       testIds: [],
│       serverMode: "development",
│       additionalInstruction: "Klinik ve tohumlama akışlarını test et"
│     })
│
└─ 4. Sonuçları raporla
      → task-xxx-done.md'ye test sonuçları
      → Hata varsa → erp-debug-agent'a yönlendir
```

## RPC Doğrulama (Backend Test)

```bash
# Her migration sonrası zorunlu test
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/RPC_ADI" \
  -X POST \
  -H "apikey: ANON_KEY" \
  -H "Authorization: Bearer ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_param1": "deger1"}'

# Beklenen: {"ok": true, ...}
# Hata: {"code": "42883"} → fonksiyon bulunamadı
# Hata: {"code": "42501"} → permission denied (RLS)
```

---

# SLIDE 10 — GİTHUB ACTIONS CI/CD PIPELINE

```
┌─────────────────────────────────────────────────────────────────┐
│  PUSH (herhangi bir branch)                                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
     ┌───────────────┼──────────────────────┐
     │               │                      │
     ▼               ▼                      ▼
┌─────────┐   ┌──────────────┐    ┌───────────────┐
│deploy.yml│   │migration auto│    │bildirim_check │
│          │   │push trigger  │    │               │
│Trigger:  │   │              │    │Trigger:       │
│main/feat │   │Trigger:      │    │Cron (5,8,11,  │
│ure/fix/* │   │supabase/     │    │14,17 saat)   │
│          │   │migrations/** │    │               │
└────┬────┘   └──────┬───────┘    └───────┬───────┘
     │                │                    │
     ▼                ▼                    ▼
GitHub Pages   Supabase CLI      bildirim_log
deploy        migration         creation
              apply

┌─────────────────────────────────────────────────────────────────┐
│  PULL REQUEST (main'e karşı)                                    │
└────────────────────┬────────────────────────────────────────────┘
                     │
     ┌───────────────┼──────────────────────┐
     │               │                      │
     ▼               ▼                      ▼
┌─────────┐   ┌──────────────┐    ┌───────────────┐
│test-     │   │test-         │    │status check   │
│migration │   │sprite-smoke  │    │               │
│ready.yml │   │(yeni!)       │    │               │
│          │   │              │    │               │
└────┬────┘   └──────┬───────┘    └───────────────┘
     │                │                    │
     ▼                ▼                    ▼
Migration     TestSprite        Tüm testler
syntax OK     smoke test        geçmeli
              (yerel veya      (blocking)
              GitHub runner)
```

---

# SLIDE 11 — ZAMAN VE MALİYET PLANI

## Phase 1: Agent Kurulumu (~5 saat)

```
⏱️ SAAT 0-0.5: Template toplama (30 dk)
  → VoltAgent ve plugin template'leri oku
  → Antigravity skill'leri gözden geçir

⏱️ SAAT 0.5-2.5: 6 Agent Adaptasyonu (~20 dk / agent)
  → backend-developer  → erp-db-agent
  → frontend-developer → erp-frontend-agent
  → qa-expert         → erp-qa-agent
  → debugger          → erp-debug-agent
  → multi-agent-coord → orchestrator
  → code-architect    → erp-architect

⏱️ SAAT 2.5-3.5: 5 Custom Domain Agent (~10 dk / agent)
  → erp-clinical-agent
  → erp-reproduction-agent
  → erp-stock-agent
  → erp-herd-agent
  → erp-knowledge-agent

⏱️ SAAT 3.5-4.0: 4 Skill Dosyası
  → erp-onboarding
  → erp-domain-checker
  → erp-migration
  → erp-parallel-workflow

⏱️ SAAT 4.0-5.0: Hook + Konfigürasyon + Pilot Test
  → settings.json güncelle
  → Hookify kurallarını entegre et
  → Küçük bir görevle pilot test
```

## Phase 2: Pilot Görev (~2 saat)

```
🏁 İlk gerçek görev: "Klinik modül frontend tamamlama"
  → db-agent → klinik RPC'leri yazsın
  → frontend-agent → klinik UI yapılandırmasını tamamlasın
  → Paralel çalışsınlar
  → qa-agent → test etsin
  → Raporu değerlendir → prompt'ta düzeltme
```

## Phase 3: Kalan Domain Entegrasyonu (~3 saat)

```
→ erp-reproduction-agent → RPC refaktörü aktif et
→ erp-herd-agent → padok/grup yönetimi
→ erp-stock-agent → kritik eşik iyileştirmesi
→ erp-explorer → codebase analizi
→ erp-knowledge-agent → dokümantasyon güncelleme
```

## Phase 4: CI/CD + Test Entegrasyonu (~2 saat)

```
→ test-sprite-smoke.yml workflow oluştur
→ GitHub Actions → Supabase migration pipeline doğrula
→ Bildirim cron workflow doğrula
→ SonarCloud remediation plan'ı agent'lara dağıt
```

**Toplam tahmini: ~12 saat (1.5 iş günü)**

## Call-Based Billing Maliyet Analizi

| Senaryo | Call Sayısı | Süre | Maliyet |
|---------|-----------|------|---------|
| Tek agent, sıralı | 1 call | 12 saat | Düşük |
| 3 agent paralel | 3 call | 4 saat | Düşük-orta |
| 5 agent paralel | 5 call | 2.5 saat | Orta |

**Önemli:** Call-based billing = paralel agent = call × N ama süre ÷ N  
**Sonuç:** Toplam maliyet paralelle düşer.

---

# SLIDE 12 — KARAR BEKLEYEN SORULAR

## 4 Kritik Karar

| # | Soru | Seçenek A | Seçenek B | Öneri | Karar Kimde? |
|---|------|-----------|-----------|-------|-------------|
| 1 | Kaç agent ile başlayalım? | **6 agent** (adaptasyon, hızlı) | 10 agent (tam plan, 5 saat daha) | **6 + pilot ile başla** | Kullanıcı |
| 2 | Custom agent'ları ne zaman yapalım? | **Hemen** (Phase 1'de) | Pilot sonrası (Phase 2'de) | **Pilot sonrası** | Kullanıcı |
| 3 | TestSprite CI/CD'de kullanılabilir mi? | **Yerel** (geliştirici mak.) | **GitHub Actions** (araştırma gerek) | Yerel ile başla | Kullanıcı |
| 4 | Agent multiplicity (aynı iş 2 agent) | **Her zaman** (maliyet düşük) | **Sadece kritik görevler** | Her zaman | Kullanıcı |

## Risk Haritası

| Risk | Olasılık | Etki | Azaltma |
|------|----------|------|---------|
| Template adaptasyonu yetersiz kalır | Düşük | Orta | İteratif öğrenme döngüsü |
| Paralel write → dosya çakışması | Orta | Yüksek | Orchestrator dosya kilidi + Hookify block |
| TestSprite CI/CD desteklemiyor | Orta | Düşük | Yerel Playwright + curl fallback |
| Agent prompt'u domain bilgisini "unutur" | Orta | Orta | MEMORY.md + domain layer güçlendirme |

---

# SLIDE 13 — ADIM ADIM UYGULAMA PLANI

## Hemen Yapılacaklar (Bu Toplantıdan Sonra)

```
SAYISAL LİSTE:

[ ] Kararları ver
    ├── Kaç agent ile başlayalım? (öneri: 6 + pilot)
    ├── Custom agent zamanı? (öneri: pilot sonrası)
    ├── TestSprite kullanımı? (öneri: yerel)
    └── Agent multiplicity? (öneri: her zaman)

[ ] Adım 1: VoltAgent template'leri topla (~15 dk)
    → /tmp/voltagent/ altına backend-dev, frontend-dev, 
      qa-expert, debugger, multi-agent-coordinator
    → Plugin agent'ları oku: code-architect, code-reviewer

[ ] Adım 2: 6 Agent oluştur (~2 saat)
    → .claude/agents/ altına her agent dosyası
    → Template base + EgeSüt domain layer
    → Tool listesi güncelle

[ ] Adım 3: Orchestrator güncelle (~30 dk)
    → multi-agent-coordinator'dan al, EgeSüt'e adapte et
    → Agent atama karar matrisini entegre et

[ ] Adım 4: Skill dosyaları (~30 dk)
    → .claude/skills/ altına 4 skill

[ ] Adım 5: Hook konfigürasyonu (~30 dk)
    → settings.json güncelle
    → Pre-commit node --check ekle

[ ] Adım 6: Pilot test (~1 saat)
    → Küçük bir görev seç
    → Agent'ları test et
    → Davranışı gözle
    → Prompt düzeltmeleri yap
```

---

# SLIDE 14 — KAYNAK LİSTESİ

## Özet Tablo

```
╔═══════════════════════════════════════════════════════════════════════╗
║  MİMARİ KAYNAKLARI                                                    ║
╠═══════════════════════════════════════════════════════════════════════╣
║                                                                       ║
║  VOLTANT AGENT TEMPLATES (130+)                                       ║
║  GitHub: github.com/VoltAgent/awesome-claude-code-subagents           ║
║  Doğrudan: raw.githubusercontent.com/VoltAgent/awesome-claude-code-  ║
║             subagents/main/categories/                                ║
║                                                                       ║
║  CLAUDE CODE PLUGIN AGENTS (lokal)                                   ║
║  Yol: ~/.claude/plugins/marketplaces/claude-plugins-official/        ║
║        plugins/feature-dev/agents/                                   ║
║  Kullanılabilir: code-architect, code-explorer, code-reviewer        ║
║                                                                       ║
║  ANTIGRAVITY SKILLS (1,344+)                                         ║
║  GitHub: github.com/sickn33/antigravity-awesome-skills               ║
║  npm: npx antigravity-awesome-skills install                         ║
║                                                                       ║
║  MEVCUT SİSTEM (zaten aktif)                                         ║
║  ├── Supabase MCP (mcp__supabase__)                                  ║
║  ├── GitHub MCP (mcp__github__)                                       ║
║  ├── Context7 MCP (mcp__context7__)                                   ║
║  ├── Hookify (3 hook aktif)                                          ║
║  ├── TestSprite MCP (mcp__TestSprite__)                               ║
║  └── GitHub Actions (4 workflow)                                     ║
║                                                                       ║
║  EGEÜT ERP MEVCUT DOSYALAR                                            ║
║  ├── AGENTS.md — Agent kuralları                                      ║
║  ├── ARCHITECTURE.md — Mimari referans                                ║
║  ├── domain-rules.md — 13 kritik kural                               ║
║  ├── rpc-reference.md — Tüm RPC imzaları                             ║
║  ├── .claude/agents/ — Mevcut 4 agent                                ║
║  └── .claude/knowledge/ — Araştırma dosyaları (bu sunum dahil)       ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

# SLIDE 15 — SUNUM DOSYALARI

| Dosya | İçerik | Kim İçin |
|-------|--------|----------|
| `M27_ARCHITECTURE_PLAN.md` | Tam mimari plan (1152 satır) | Detaylı inceleme |
| `HYBRID_ARCHITECTURE_STRATEGY.md` | Template + custom stratejisi (511 satır) | Karar referansı |
| `AGENTIC_ARCHITECTURE_PRESENTATION.md` | **Bu dosya** — sunum formatında | Sunum + karar |
| `AGENTIC_ARCHITECTURE_ANALYSIS.md` | Mevcut durum analizi (433 satır) | Sorun tespiti |
| `EXTERNAL_FRAMEWORKS_RESEARCH.md` | VoltAgent + Antigravity araştırması (212 satır) | Kaynak referans |
| `minimax-platform.md` | MiniMax M2.7 platform bilgisi (229 satır) | Model bilgisi |

---

# SLIDE 16 — SONUÇ

## Tek Cümle

> **Hibrit strateji ile 5 saatlik çalışmayla profesyonel 10 agentlık takım kuruyoruz — VoltAgent template'lerden hız alıyoruz, EgeSüt domain bilgisi ile kaliteyi sağlıyoruz.**

## Sonraki Adım — Senden

```
[ ] Kararları ver (Slide 12)
[ ] "Onayladım, başla" de → Uygulamaya geçiyorum
[ ] Değişiklik iste → Hangi konuda?
```

---

**Sunum hazır. Kararın ne?** 🚀
