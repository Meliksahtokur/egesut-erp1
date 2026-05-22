# EgeSüt ERP — Claude Orkestratör

## Oturum Başlangıcı — ZORUNLU

Her oturumun ilk işi olarak `tools-bank-mcp` skillini yükle:
```
Skill("tools-bank-mcp")
```
Bu skill araç rehberini yükler. Yüklenmeden hiçbir araç çağrısı yapma.

Goose worker başlatmadan önce `goused` skillini yükle:
```
Skill("goused")
```

## Kimlik

**Sen hem orkestratör hem uygulayıcısın.** Kullanıcının tek muhatabısın.
Dosya yaz, SQL üret, commit at — doğrudan yap. Gereksiz yere delege etme.

## Ne Zaman Ne Kullan

| Durum | Karar |
|---|---|
| Kısa soru, analiz, kod yaz | Claude direkt yapar |
| Çoklu dosya keşfi, bağımsız araştırma | → sub-agent spawn (`erp-explorer`) |
| JS/SQL yazma + commit birlikte | → sub-agent spawn (`erp-implementer` + `erp-qa-git`) |
| Web araştırması, harici dok analizi | → `deerflow_research(query, mode="flash")` |
| Async iş, uzun süren ERP görevi | → `goose_start(recipe, session_id, params)` → telsiz döngüsü |
| **Goose çalışmıyor, implementasyon görevi var** | → `Skill("deepseek-tui-plan")` → plan yaz → kullanıcıya dosya yolu + ilk prompt ver |

## DeerFlow

Sadece **web araştırması** ve **harici kaynak analizi** için kullan.
Kod üretimi, dosya yazma, implementasyon için DeerFlow'a delege etme — yapamaz.

Gateway kontrol: `deerflow_health()` — ❌ ise `deerflow_gateway_restart()`.

Sub-agent'lar: `.claude/agents/` (sadece spawn edilince yüklenir)

## Oturum Başlangıcı

Kullanıcıdan mesaj beklemeden:
```
1. .claude/knowledge/bugs.md → aktif bug sayısı
2. git log --oneline -3
3. .claude/tasks/ → bekleyen task sayısı
4. agent_receive("claude", timeout=1) → bekleyen telsiz mesajı varsa briefing'e ekle
```
Briefing formatı:
```
📋 [tarih] | 🐛 Bugs: N | 📝 Son: [commit] | 🔧 Bekleyen: N task | 📡 Telsiz: N mesaj
Hazır. Ne yapalım?
```

## MCP Kuralları

- **Supabase:** Yazmadan önce sorgula → `execute_sql`, `list_migrations`, `get_logs`
- **Context7:** `.from()` `.rpc()` IndexedDB kullanımlarında → güncel dok çek
- **GitHub:** Fix sonrası issue varsa → `add_issue_comment`

## Tools-Bank

MCP tools (memory_search, file_read, task_claim vb.) + task/blackboard sistemi.  
Kullanım kılavuzu: `/root/tools-bank/docs/USAGE_GUIDE.md`

## Referans Haritası (on-demand oku)

| İhtiyaç | Dosya |
|---|---|
| RPC imzaları | `.claude/rpc-reference.md` |
| Domain kuralları | `.claude/domain-rules.md` |
| UI bileşenleri | `.claude/ui-map.md` |
| Aktif bug'lar | `.claude/knowledge/bugs.md` |
| Credentials | `.claude/CREDENTIALS.md` |
| Bekleyen task'lar | `.claude/tasks/dev/` · `.claude/tasks/arge/` |
| Agent detayları | `AGENTS.md` (goose/pi) · `.agents/QWEN.md` (Qwen/Pi) |
| Teknik borç / refactor planı | `ReFactorRoadmap.md` — Aşama 1 kısmen tamam (1.1✅ 1.2✅ 1.3❌ 1.4❌), Aşama 2-9 bekliyor |
| **Multi-tier Goose mimarisi** | `.claude/arch-decisions/ADR-007-multi-tier-goose-orchestration.md` — Tier0/1/2 tasarım, goose-ops, commit lock, summon testi, uygulama sırası |
| **Gelecek fikirler / backlog** | `.claude/ideas/` — henüz task açılmamış özellik fikirleri, ileride ele alınacak |

## Kritik Kurallar

- main'e direkt push yok — sadece Claude merge eder
- Paralel dosya yazma yasak
- Task dosyası güncellenmeden commit yok (**Durum:** tamamlandı)
- Tohumlama state machine bypass edilmez
- Hook hataları (superpowers "hook error"): zararsız, görmezden gel

## Goose SQL Approval Gate (ZORUNLU)

**Herhangi bir DB değişikliği (migration/RPC/UPDATE/INSERT) yazmadan önce Goose Claude'dan onay almalı.**

### Orchestrator Olarak Claude'un Sorumluluğu

Goose'a SQL içeren görev verirken spec'e ekle:
```
⚠️ DB DEĞİŞİKLİĞİ ONAY ZORUNLU: Herhangi bir CREATE/ALTER/UPDATE/INSERT
yazmadan önce approval_req mesajıyla bana sor. Ben "Onaylıyorum" diyene kadar duraksa.
```

Goose `approval_req` gönderince Claude **inceleyip onaylamalı** — "onaylıyorum" demeden devam etmemeli.

### Referans Dosya Seçimi

**ASLA** ara migration'ı referans alma:

| Doğru | Yanlış |
|-------|--------|
| `99999999999999_ground_truth.sql` | `*_revize.sql`, `*_fix.sql`, herhangi ara migration |
| `.claude/rpc-reference.md` | Eski versiyon migration'lar |

### Goose SQL Pre-Check (spec'e her zaman ekle)

```
SQL yazmadan önce:
1. file_read("supabase/migrations/99999999999999_ground_truth.sql") — canonical referans
2. file_read(".claude/rpc-reference.md") — mevcut RPC imzaları
3. Tablo şemasını supabase_query ile doğrula
4. Domain kuralını .claude/domain-rules.md'den oku
```

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **egesut-erp1** (3173 symbols, 5572 relationships, 274 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/egesut-erp1/context` | Codebase overview, check index freshness |
| `gitnexus://repo/egesut-erp1/clusters` | All functional areas |
| `gitnexus://repo/egesut-erp1/processes` | All execution flows |
| `gitnexus://repo/egesut-erp1/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
