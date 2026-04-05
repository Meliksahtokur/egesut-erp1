# Agentic Mimari Analizi — EgeSüt ERP
> Araştırma tarihi: 2026-04-04
> Araştırmacı: Claude Code (me)
> Kapsam: Mevcut agentic yapı + dış framework analizi

---

## 1. PROJE ÖZETİ

### 1.1 Nedir?
EgeSüt ERP — 130+ hayvanlık süt çiftliğinin operasyonel yönetim sistemi.

### 1.2 Teknik Stack
| Katman | Teknoloji |
|--------|-----------|
| Frontend | Vanilla JS PWA, tek `index.html`, build yok |
| Backend | Supabase (PostgreSQL) + RPC |
| Cache | IndexedDB (`egesut_v9`, DB_VER=6) |
| Deploy | GitHub Pages |
| Migration | GitHub Actions → Supabase CLI |

**Dosya yapısı:**
```
js/api.js    (396 satır) — Supabase client, RPC wrapper, IDB sync
js/app.js    (766 satır) — Init, routing, global state
js/ui.js    (3083 satır) — Tüm render fonksiyonları (TEK DOSYA!)
js/forms.js  (958 satır) — Form submit, RPC çağrıları
js/config.js   (68 satır) — GRUP_PADOK mapping
js/state.js    (84 satır) — getState/setState
```

**Mevcut satır sayısı:** ~5.355 satır Vanilla JS

### 1.3 Domain Modülleri
| # | Modül | Durum |
|---|-------|-------|
| 1 | Sürü (Hayvan kaydı, grup/padok) | ✅ Tamamlandı |
| 2 | Klinik (Vaka sistemi) | 🟡 DB hazır, frontend devam |
| 3 | Stok (İlaç/malzeme, ledger) | ✅ Tamamlandı |
| 4 | Üreme (Tohumlama, gebelik, doğum) | 🟡 Çalışıyor, RPC refaktörü bekliyor |
| 5 | Görev (Otomatik görev üretimi) | ✅ Tamamlandı |

### 1.4 MVP Dışı (Sonraki Aşama)
- Muhasebe / gelir-gider
- Süt verim kaydı
- Raporlama ekranı
- Mobil native app
- Çoklu kullanıcı / rol yönetimi

---

## 2. MEVCUT AGENTIC YAPI

### 2.1 İKİ PARALEL SİSTEM

```
┌─────────────────────────────────────────────────────────┐
│  CLAUDE CODE (Bu proje - /root/opencode-dev)            │
│  Branch: main / fix/tech-debt                           │
│  Config: CLAUDE.md + .claude/agents/                   │
│  MCP: Supabase, Context7, GitHub                         │
│  Orkestratör: orchestrator (Sonnet)                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  QWEN CODE (Ayrı proje - /root/egesut-erp1)            │
│  Branch: feature/gwen-* / feature/gwen-arge             │
│  Config: .qwen/ + gwen-cli.sh                          │
│  Orkestratör: gwen-dev / gwen-arge (Qwen)              │
│  MCP: gwen-supabase, gwen-github, context7               │
└─────────────────────────────────────────────────────────┘
```

**Kritik:** Bu iki sistem AYNI codebase üzerinde çalışıyor (`/root/egesut-erp1/`).
Claude `main`'de, Qwen feature branch'lerde.

### 2.2 Claude Code Agent'ları (`.claude/agents/`)

| Agent | Model | Görev | Durum |
|-------|-------|-------|-------|
| `orchestrator` | Sonnet | Planlama, delegasyon | ⚠️ Tanımlı ama referansları tutarsız |
| `erp-implementer` | Sonnet | Fullstack kodlama (DB + FE) | ✅ Çalışıyor |
| `erp-qa-git` | Haiku | Syntax kontrol + commit/push | ⚠️ Model yetersiz (İ-005) |
| `erp-explorer` | Haiku | Kod keşfi, okuma | ✅ Temel çalışıyor |

### 2.3 Orchestrator'ın Bildiği Ama Olmayan Agent'lar

`orchestrator.md` şu agent'ları spawn etmeyi planlıyor ama dosyaları YOK:

```
❌ erp-db-agent      → SQL, migration, RPC tasarımı
❌ erp-frontend-dev  → ui.js, forms.js vanilla JS
❌ erp-planner        → Yeni özellik planı, brainstorming
❌ erp-architect      → RPC/schema contract, mimari karar
❌ erp-debug-agent   → Bug araştırma, pasif tarama
❌ arge-analyst      → ArGe analizi, web araştırma
❌ dream-director     → Agent feedback örüntüleri
```

### 2.4 Qwen/Claude Karışıklığı

`orchestrator.md`'de şöyle diyor:
> "Skill'lerin önerdiği generic agent isimleri (code-explorer, code-architect, code-reviewer) **bu projede YOKTUR**"

Ama `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/feature-dev/agents/` şunlar var:
```
code-architect.md    → feature-dev plugininden
code-explorer.md     → feature-dev plugininden
code-reviewer.md     → feature-dev plugininden
```

Ve bu agent'lar orchestrator tarafından spawn ediliyor olabilir, ama projeye ÖZEL değiller.

### 2.5 Hookify Hook'ları (`.claude/hookify.*.local.md`)

| Hook | Event | Action | Koruma |
|------|-------|--------|--------|
| `block-direct-db-writes` | file | block | `db.from(...).insert/update` → kritik tablolara yazmayı engeller |
| `warn-duplicate-functions` | file | warn | Yeni fonksiyon → duplicate kontrol hatırlatması |
| `warn-critical-files` | file | warn | sw.js, config.js, state.js, domain-rules.md değişikliği uyarısı |

**Değerlendirme:** Hookify plugin yapısı GÜÇLÜ. Block/warn/ask mekanizması çok etkili.
İlk satırlarda tanımlanan `.local.md` dosyaları proje düzeyinde.

### 2.6 Superpowers Skill'leri (Aktif)

| Skill | Kullanım |
|--------|--------|
| `dispatching-parallel-agents` | Çoklu dosya keşfi, paralel okuma |
| `brainstorming` | Yeni özellik tasarımı |
| `systematic-debugging` | Bug araştırma |
| `commit-push-pr` | Commit + PR workflow |

---

## 3. BİLİNEN SORUNLAR

### 3.1 Kritik Teknik Borç

| # | Sorun | Önem | Durum |
|---|-------|------|-------|
| 1 | Tohumlama: 3 write path, sadece 1'i RPC üzerinden | 🔴 Kritik | Bekliyor |
| 2 | `_origConsoleError` duplicate tanım (app.js) | 🔴 Kritik | MiniMax M2.5 Task-2 |
| 3 | vaccines IDB store eksik | 🔴 Kritik | MiniMax M2.5 Task-1 |
| 4 | tohumlama_sonuc_bos 42883 hatası | 🔴 Kritik | MiniMax M2.5 Task-3 |
| 5 | Offline kuyruk REST bypass | 🟡 Yüksek | MiniMax M2.5 Task-4 |
| 6 | state.js benimseme eksik | 🟡 Orta | Organik geçiş |
| 7 | Migration 013-014 drift | 🟠 Orta | Bekliyor |

### 3.2 Agentic Mimari Sorunları

| # | Sorun | Etki |
|---|-------|------|
| 1 | Orchestrator tanımsız agent'lara referans veriyor | Haiku agent belirsizlikle karşılaşabilir |
| 2 | `erp-qa-git` model=haiku, Playwright karmaşık senaryo için yetersiz | İ-005 bekliyor |
| 3 | `erp-implementer` tek agent'ta DB+FE yapıyor, iki farklı uzmanlık alanı | İnce uzmanlaşma gerekli |
| 4 | Qwen plugin agent'ları (feature-dev, pr-review-toolkit) projeye özel değil | Generik, domain bilgisi yok |
| 5 | Domain-spesifik agent yok (üreme uzmanı, klinik uzmanı, stok uzmanı) | Genel agent'lar domain hatası yapabilir |
| 6 | SonarCloud remediation planı aktif — yüksek hacimli refaktör geliyor | Agent'ların bu planı bilmesi gerekiyor |

### 3.3 Delegasyon Karışıklığı

`AGENTS.md` diyor:
```
Bilgi gerekiyor      → erp-explorer (haiku)
Kod yazılacak        → erp-frontend-dev (haiku)
```

Ama `erp-frontend-dev` dosyası YOK. Bu yüzden `erp-implementer` kullanılıyor ama o da Sonnet model — haiku yeterli işler için aşırı güçlü.

### 3.4 Session Başlangıcı Briefing Tutarsızlığı

`CLAUDE.md` oturum başında şunları yap diyor:
```
1. .claude/knowledge/bugs.md → aktif bug sayısı
2. .claude/knowledge/improvement-proposals.md → bekleyen öneri sayısı
3. git log --oneline -3 → son commitler
```

Ama `orchestrator.md` da aynı şeyi söylüyor. **İKİ KERE tanımlı** — tutarsızlık riski.

---

## 4. DIŞ FRAMEWORK ARAŞTIRMASI

### 4.1 Araştırılan Kaynaklar

| Kaynak | Stars | Kapsam |
|--------|-------|--------|
| `sickn33/antigravity-awesome-skills` | 136K ⭐ | 1,344+ agentic skill |
| `hesreallyhim/awesome-claude-code` | 36K ⭐ | Skills, hooks, agents, plugins |
| `affaan-m/everything-claude-code` | 30K ⭐ | Agent harness, skills, memory, security |
| `VoltAgent/awesome-claude-code-subagents` | — | 130+ Claude Code subagent |
| `VoltAgent/awesome-agent-skills` | 14K ⭐ | 1,060+ official+community skills |
| `alirezareadi/claude-skills` | 9K ⭐ | 220+ skills (engineering, marketing) |

### 4.2 VoltAgent Claude Code Subagents Kategorileri

```
01-core-development/
  ├── api-designer.md
  ├── backend-developer.md
  ├── design-bridge.md
  ├── electron-pro.md
  ├── frontend-developer.md
  ├── fullstack-developer.md
  ├── graphql-architect.md
  ├── microservices-architect.md
  ├── mobile-developer.md
  ├── ui-designer.md
  └── websocket-engineer.md

04-quality-security/
  ├── accessibility-tester.md
  ├── ad-security-reviewer.md
  ├── ai-writing-auditor.md
  ├── architect-reviewer.md
  ├── chaos-engineer.md
  ├── code-reviewer.md
  ├── compliance-auditor.md
  ├── debugger.md
  ├── error-detective.md
  ├── penetration-tester.md
  ├── performance-engineer.md
  ├── qa-expert.md
  ├── security-auditor.md
  └── test-automator.md

09-meta-orchestration/
  ├── agent-installer.md
  ├── agent-organizer.md
  ├── context-manager.md
  ├── error-coordinator.md
  ├── it-ops-orchestrator.md
  ├── knowledge-synthesizer.md
  ├── multi-agent-coordinator.md
  ├── performance-monitor.md
  ├── task-distributor.md
  └── workflow-orchestrator.md

10-research-analysis/
  ├── competitive-analyst.md
  ├── data-researcher.md
  ├── market-researcher.md
  ├── project-idea-validator.md
  ├── research-analyst.md
  ├── scientific-literature-researcher.md
  ├── search-specialist.md
  └── trend-analyst.md
```

### 4.3 Öğrenilen Dersler

#### VoltAgent `backend-developer.md` Yapısı:
```yaml
---
name: backend-developer
description: "Use when building server-side APIs..."
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
---

You are a senior backend developer...
When invoked:
1. Query context manager for existing API architecture
2. Review current backend patterns and service dependencies
3. Analyze performance requirements and security constraints
4. Begin implementation following established backend standards
```

**Öğrenilen:** Agent invoke sırasında ilk adım olarak "context manager'a sor" — proje içi bilgiye öncelik veriyor.

#### VoltAgent `fullstack-developer.md`:
Ayrı fullstack-developer agent var. EgeSüt'te `erp-implementer` bu rolü üstleniyor ama domain-knowledge ile zenginleştirilmemiş.

#### Antigravity Skill Kategorileri:
| Kategori | Örnek |
|----------|-------|
| `agentic-engineering` | Agent harness, orchestrator pattern |
| `database-migrations` | Migration workflow, rollback |
| `mcp-server-patterns` | MCP server geliştirme |
| `postgres-patterns` | PostgreSQL best practices |
| `git-workflow` | Git workflow automation |
| `codebase-onboarding` | Yeni projeye agent adaptasyonu |
| `continuous-learning` | Agent memory, feedback loop |
| `verification-loop` | Doğrulama döngüleri |
| `tdd-workflow` | Test-driven development |

### 4.4 Supabase Official Skill (Beklenen Yapı)

Supabase MCP zaten aktif. Resmi Supabase skill-Agent bu MCP ile entegre çalışır. Şu anda aktif Supabase MCP:
- `execute_sql` — schema okuma, migration
- `list_migrations` — migration geçmişi
- `get_advisors` — güvenlik/performans
- `get_logs` — hata ayıklama
- `apply_migration` — ⚠️ UnauthorizedException, `execute_sql` kullanılıyor

---

## 5. MCP ANALİZİ

### 5.1 Aktif MCP'ler

| MCP | Amaç | Kullanım Sıklığı |
|-----|------|-----------------|
| **Supabase** | DB işlemleri, migration | Çok yüksek |
| **Context7** | Supabase JS + Web API dokümanı | Orta |
| **GitHub** | PR, issue, commit | Orta |
| **Hookify** | Write/Edit guard'ları | Yüksek |
| **Superpowers** | dispatching-parallel-agents, brainstorming, systematic-debugging | Düşük-orta |
| **Commit-commands** | commit-push-pr workflow | Orta |

### 5.2 Kullanılmayan Ama Mevcut MCP'ler

| MCP | Durum | Neden |
|-----|-------|-------|
| `agent-sdk-dev` | ❌ Disabled | Agent SDK geliştirme |
| `code-simplifier` | ❌ Disabled | Kod sadeleştirme |
| `feature-dev` | ❌ Disabled | Feature geliştirme |
| `pr-review-toolkit` | ❌ Disabled | PR review |
| `hookify` | ✅ Enabled | Write protection |
| `sentry` | ❌ Disabled | Hata izleme |
| `test-sprite` | ❌ Disabled | Test üretimi |
| `context7` | ✅ Enabled | Doküman |

### 5.3 Eksik MCP Fırsatları

| MCP | Öneri | Öncelik |
|-----|-------|---------|
| **TestSprite** | Frontend test üretimi | Orta |
| **Context7** | Daha aktif kullanım (Supabase JS her zaman çekilmeli) | Yüksek |
| **Hookify** | daha fazla kural eklenebilir | Orta |

---

## 6. AGENT-PLUGIN UYUŞMAZLIKLARI

### 6.1 Etkin Olmayan Ama Potansiyel Plugin'ler

| Plugin | Disabled Neden | Faydası |
|--------|---------------|---------|
| `pr-review-toolkit` | Kullanılmıyor | PR review, code review agent'ları |
| `feature-dev` | Kullanılmıyor | Feature geliştirme workflow |
| `code-simplifier` | Kullanılmıyor | Kod sadeleştirme |
| `test-sprite` | Kullanılmıyor | Test üretimi |
| `sentry` | Kullanılmıyor | Production hata izleme |

### 6.2 Agent Name Collision

```
.claude/agents/          → erp-explorer.md, erp-implementer.md (PROJE)
~/.claude/plugins/.../feature-dev/agents/ → code-architect.md, code-reviewer.md (GENERİK)
~/.claude/plugins/.../pr-review-toolkit/ → code-reviewer.md, code-simplifier.md (GENERİK)
```

**Sorun:** Aynı isimli agent'lar farklı kaynaklarda. Proje-dışı agent'lar domain-bilgisiz çalışır.

---

## 7. GÜVENLİK VE YANLIŞ KULLANIM RİSKLERİ

### 7.1 Domain Kurallarını Aşma Riski

En kritik 3 kural:
1. **Sadece RPC ile yaz** — agent'lar bunu bilmeli
2. **Parallel yazma yasak** — aynı dosyaya iki agent yazamaz
3. **State machine ihlali yok** — tohumlama durumları

### 7.2 Mevcut Koruma

- `hookify: block-direct-db-writes` → `db.from(...).insert/update` → otomatik block
- `hookify: warn-duplicate-functions` → yeni fonksiyon → uyarı
- `hookify: warn-critical-files` → kritik dosya → uyarı

### 7.3 Eksik Koruma

| Risk | Mevcut Durum | Öneri |
|------|-------------|-------|
| RPC guard bypass (tohumlama) | Hook yok | Ek kural ekle |
| Backend validasyon bypass | Hookify yok | Ek kural ekle |
| Domain kuralı ihlali | Agent instruction'da var, enforcement yok | Agent instruction güçlendir |
| Yanlış migration order | Manuel kontrol | Migration sıralama kuralı |

---

## 8. SONARCSLOUD REMEDIATION PLANI BAĞLAMI

`SONARCLOUD_REMEDIATION_PLAN.md` ~40KB dosya — birçok kritik refaktör içeriyor:

| Öncelik | Konu | Agent Etkisi |
|---------|------|-------------|
| 🔴 Kritik | Tohumlama write-path refaktörü (3→1) | Agent buna öncelik vermeli |
| 🔴 Kritik | RPC-only write convention | Hookify kuralları güçlendirilmeli |
| 🟡 Orta | State machine consistency | Domain agent'ı bilmeli |
| 🟡 Orta | Offline queue → RPC geçişi | Agent domain-bilgili olmalı |

**Bu plan agentic yapıyı DOĞRUDAN etkiliyor.** Agent'ların bu planı okuması ve referans alması gerekiyor.

---

## 9. TOPLAM DEĞERLENDİRME

### Güçlü Yönler
✅ İki paralel sistem (Claude + Qwen) — ücretsiz iş gücü kullanımı  
✅ Hookify plugin — koruyucu hook sistemi çalışıyor  
✅ Domain-knowledge içeren agent tanımları (erp-implementer, erp-explorer)  
✅ RPC-only kuralı — tutarlı veri erişimi  
✅ Bug/issue tracking dosyaları mevcut  

### Zayıf Yönler  
⚠️ Orchestrator tanımsız agent'lara referans veriyor (erp-db-agent vs erp-implementer karışıklığı)  
⚠️ Tek agent'a çok yük (erp-implementer hem DB hem FE yapıyor)  
⚠️ Domain-spesifik agent eksikliği (klinik, üreme, stok uzmanı yok)  
⚠️ Generik plugin agent'ları domain-bilgisiz (code-reviewer vs erp-qa-git karışıklığı)  
⚠️ SonarCloud remediation planı agent tarafından takip edilmiyor  
⚠️ Feedback/learning döngüsü zayıf  

### Fırsatlar
🚀 VoltAgent/Antigravity framework'leri — hazır agent template'leri  
🚀 TestSprite — frontend test üretimi  
🚀 Hookify genişletme — daha fazla koruyucu kural  
🚀 Superpowers skill'leri — parallelism, brainstorming  
🚀 SonarCloud remediation planı — agent'lar için net hedef  

### Tehditler
🔴 Domain dışı agent'lar kritik iş kurallarını ihlal edebilir  
🔴 Paralel agent'lar aynı dosyaya yazabilir  
🔴 Haiku model karmaşık senaryolarda yetersiz  
🔴 Orchestrator karar yorgunluğu — çok fazla seçenek, net karar yok  

---

*Dosya devam ediyor → `AGENTIC_ARCHITECTURE_PROPOSAL.md`*
