# Dış Framework Araştırması — Agentic Mimari
> Araştırma tarihi: 2026-04-04

---

## Kaynaklar

| Kaynak | URL | Stars |
|--------|-----|-------|
| Antigravity Awesome Skills | github.com/sickn33/antigravity-awesome-skills | 136K |
| Awesome Claude Code | github.com/hesreallyhim/awesome-claude-code | 36K |
| Everything Claude Code | github.com/affaan-m/everything-claude-code | 30K |
| VoltAgent Claude Code Subagents | github.com/VoltAgent/awesome-claude-code-subagents | — |
| VoltAgent Awesome Agent Skills | github.com/VoltAgent/awesome-agent-skills | 14K |
| Claude Skills (Alireza) | github.com/alirezareadi/claude-skills | 9K |

---

## VoltAgent Claude Code Subagents — 10 Kategori

### 01-core-development (12 agent)
- `api-designer.md` — REST/GraphQL API design
- `backend-developer.md` — Node.js, Python, Go backend
- `design-bridge.md` — Design system → code bridge
- `electron-pro.md` — Electron desktop
- `frontend-developer.md` — React/Vue/Svelte
- `fullstack-developer.md` — Full-stack genel
- `graphql-architect.md` — GraphQL schema
- `microservices-architect.md` — Microservice mimarisi
- `mobile-developer.md` — React Native, Flutter
- `ui-designer.md` — UI/UX design
- `websocket-engineer.md` — WebSocket real-time

### 02-language-specialists
- Rust, Go, Python, TypeScript, JavaScript, Java, C++, C#, PHP, Ruby, Dart

### 03-infrastructure
- AWS, GCP, Azure, Kubernetes, Docker, Terraform, CI/CD

### 04-quality-security (15 agent)
- `accessibility-tester.md`
- `ad-security-reviewer.md`
- `ai-writing-auditor.md`
- `architect-reviewer.md`
- `chaos-engineer.md`
- `code-reviewer.md`
- `compliance-auditor.md`
- `debugger.md`
- `error-detective.md`
- `penetration-tester.md`
- `performance-engineer.md`
- `powershell-security-hardening.md`
- `qa-expert.md`
- `security-auditor.md`
- `test-automator.md`

### 05-data-ai
- ML engineering, data pipeline, RAG, LLM integration

### 06-developer-experience
- Onboarding, documentation, tooling

### 07-specialized-domains
- Healthcare, finance, legal, education

### 08-business-product
- Product management, growth, analytics

### 09-meta-orchestration (12 agent)
- `agent-installer.md`
- `agent-organizer.md`
- `context-manager.md`
- `error-coordinator.md`
- `it-ops-orchestrator.md`
- `knowledge-synthesizer.md`
- `multi-agent-coordinator.md`
- `performance-monitor.md`
- `task-distributor.md`
- `workflow-orchestrator.md`

### 10-research-analysis (8 agent)
- `competitive-analyst.md`
- `data-researcher.md`
- `market-researcher.md`
- `project-idea-validator.md`
- `research-analyst.md`
- `scientific-literature-researcher.md`
- `search-specialist.md`
- `trend-analyst.md`

---

## Antigravity Awesome Skills — Skill Kategorileri

Toplam: 1,344+ skills. İlgili olanlar:

| Kategori | Skill Sayısı | EgeSüt İlgisi |
|----------|-------------|---------------|
| `agentic-engineering` | ~20 | 🔴 Çok yüksek |
| `database-migrations` | ~15 | 🔴 Çok yüksek |
| `postgres-patterns` | ~20 | 🔴 Çok yüksek |
| `mcp-server-patterns` | ~10 | 🟡 Orta |
| `git-workflow` | ~10 | 🟡 Orta |
| `codebase-onboarding` | ~10 | 🔴 Çok yüksek |
| `continuous-learning` | ~10 | 🟡 Orta |
| `verification-loop` | ~10 | 🟡 Orta |
| `tdd-workflow` | ~10 | 🟢 Düşük |
| `deployment-patterns` | ~20 | 🟢 Düşük |
| `security-review` | ~15 | 🟡 Orta |
| `frontend-patterns` | ~20 | 🟡 Orta |
| `api-design` | ~15 | 🟡 Orta |

---

## Agent Template Format Karşılaştırması

### VoltAgent Format
```yaml
---
name: backend-developer
description: "Use when building server-side APIs..."
tools: Read, Write, Edit, Bash, Glob, Grep
model: sonnet
---

You are a senior backend developer...
When invoked:
1. Query context manager
2. Review current patterns
3. Analyze requirements
4. Begin implementation
```

### EgeSüt Mevcut Format
```yaml
---
name: erp-implementer
description: EgeSüt ERP Fullstack Geliştiricisi...
model: sonnet
---

Sen EgeSüt ERP'nin Fullstack uygulayıcısısın...
## ZORUNLU ARAÇ KULLANIMI
## KURUMSAL HAFIZA
## KOD STANDARTLARI
## ESCALATION
```

**Fark:** VoltAgent → trigger-first, invocation order. EgeSüt → rule-first, enforcement.

**Öneri:** VoltAgent formatını adaptasyon + EgeSüt domain-knowledge ile zenginleştirme.

---

## Everything Claude Code (affaan-m) — Katkılar

Bu repo'nun sundukları:

1. **Skills** — Claude Code'a özel skill dosyaları
2. **Instincts** — Agent davranış constraint'leri
3. **Memory optimization** — Kontekst budget yönetimi
4. **Continuous learning** — Agent self-improvement
5. **Security scanning** — Code security audit
6. **Research-first development** — Araştırma → implementasyon

**İlgili Skills:**
- `agentic-engineering/` — Agent harness construction
- `continuous-agent-loop/` — Infinite agent loop prevention
- `context-budget/` — Context window optimization
- `safety-guard/` — Agent safety mechanisms
- `repo-scan/` — Codebase analysis

---

## Supabase Official Skills

Supabase MCP zaten aktif. Supabase'in resmi skill-agent'ları olmalı:
- Supabase skill-agent → `github.com/supabase/skill-agents` (API rate limit)

**Mevcut Supabase MCP Tool'ları:**
- `execute_sql` — Sorgu çalıştırma
- `apply_migration` — ⚠️ Unauthorized
- `list_tables` — Tablo listesi
- `list_migrations` — Migration geçmişi
- `get_advisors` — Güvenlik/performans
- `get_logs` — Hata logları

---

## Sonuç: EgeSüt ERP İçin Öneriler

### Alınacak (Doğrudan Kullanılabilir)
1. `backend-developer.md` template → `erp-db-agent` için temel
2. `frontend-developer.md` template → `erp-frontend-agent` için temel
3. `code-reviewer.md` → `erp-qa-agent` için template
4. `debugger.md` → `erp-debug-agent` için template
5. `workflow-orchestrator.md` → orchestrator güçlendirme

### Adaptasyon Gerekli
1. Domain-knowledge injection — Türkçe değişkenler, RPC pattern
2. Supabase MCP integration — agent'ta MCP kullanımı açıkça belirtilmeli
3. SonarCloud remediation planı — agent instruction'larına entegre edilmeli
4. Hookify rule reference — agent'lar hangi hook'ların koruduğunu bilmeli

### Yapılmamalı
1. Genel "code-explorer" kullanmak — domain-specific `erp-explorer` daha iyi
2. Hazır bundle almak — domain-bilgisiz olur
3. Çok fazla agent oluşturmak — 7 agent yeterli (mevcut + 3 yeni)

---

*Dosya tamamlandı.*
