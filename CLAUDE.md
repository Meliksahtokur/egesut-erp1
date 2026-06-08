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
| Çoklu dosya keşfi, bağımsız araştırma | → `mcp__deepseek__deepseek_chat` ile DeepSeek'e delege et |
| JS/SQL yazma + commit birlikte | → `mcp__deepseek__deepseek_chat` ile DeepSeek'e delege et |
| Web araştırması, harici dok analizi | → `deerflow_research(query, mode="flash")` |
| Async iş, uzun süren ERP görevi | → `goose_start(recipe, session_id, params)` → telsiz döngüsü |
| **Goose çalışmıyor, implementasyon görevi var** | → `mcp__deepseek__deepseek_chat` ile DeepSeek'e delege et |

## DeepSeek Subagent Kuralları (ZORUNLU)

- **Subagent görevi için MUTLAKA `mcp__deepseek__deepseek_chat` kullan** — Claude Agent tool'u (erp-explorer, erp-implementer vb.) subagent olarak spawn etme, aynı model = gereksiz maliyet.
- **Model parametresi ASLA belirtme** — default `deepseek-chat` (v4-flash) kullanılır. Kullanıcı açıkça söylemedikçe `deepseek-reasoner` veya başka model geçme.
- DeepSeek'e dosya okuma/yazma yetkisi yok — önce Claude okur, içeriği prompt'a ekler, DeepSeek analiz/üretim yapar, Claude sonucu uygular.

## DeerFlow

Sadece **web araştırması** ve **harici kaynak analizi** için kullan.
Kod üretimi, dosya yazma, implementasyon için DeerFlow'a delege etme — yapamaz.

Gateway kontrol: `deerflow_health()` — ❌ ise `deerflow_gateway_restart()`.

**Model kuralı:** `deerflow_research` çağrısında `mode` parametresi ASLA belirtme — default `flash` (deepseek-v4-flash) kullanılır. Kullanıcı açıkça söylemedikçe `standard`, `pro`, `ultra` veya başka mod geçme.

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

## Tools-Bank

MCP tools (memory_search, file_read, task_claim vb.) + task/blackboard sistemi.  
Kullanım kılavuzu: `/root/tools-bank/docs/USAGE_GUIDE.md`

### ast-grep (Yapısal Kod Arama)

`ast_grep_search(pattern, lang?, path?, max_results?, context_lines?)` — kod AST'sinde desen araması.

**2 Aşamalı Protokol:**
1. `max_results=10` ile özet çek → hangi dosya/satırda match var gör
2. İlgili bloğu `read_file` ile o satır aralığından oku

Joker: `$$$` (herhangi node), `$NAME` (değişken yakalama).
Pattern + lang zorunlu. Detaylar: `AGENTS.md` > ast-grep Yapısal Arama Protokolü

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
| **İlaç Sınıflandırma Faz 2** | Kalan iş: `stok.kategori` string→UUID FK, `drugs` DROP, drug_products kategori propagasyonu. Spec: `docs/superpowers/specs/2026-05-30-ilac-siniflandirma-refactor.md` §Faz 2 |
| **Kırık RPC'ler** | `update_drug_administration` ve `remove_drug_administration` — ground_truth'ta da kırık, düzeltilmeli. Bkz. `.claude/tasks/dev/task-042` |
| **Scroll reset (BUG-010)** | Tanımlar paneli kronik scroll sorunu — 3 deneme başarısız. `_keepScroll` utility mevcut. Detay: `.claude/knowledge/bugs.md` |

## Vanilla JS UI Kuralları

`ui.js` içindeki `innerHTML = template literal` pattern kullanılıyor. Sorunsuz çalışması için:

**Accordion / show-hide:** `display:none` / `display:block` toggle — her zaman ilk tercih.
`max-height` transition mobilde `overflow:hidden` parent içinde render etmeyebilir.
`<details>/<summary>` mobile Safari'de buton onclick'ini yutabilir, modal scroll kaymasına neden olur. **Yasak.**

**openAttr mantığı (default açık/kapalı):**
```js
// Sadece aktif vakada, sadece ilk aksiyon bekleyen öğe açık
const firstActive = aktif ? items.find(d => !d.done && !d.locked) : null;
const isOpen = aktif && item === firstActive;
```
Kapalı vaka veya done/locked öğeler → her zaman kapalı başlar.

**Yeni UI bölümü yazarken:**
1. Önce edge case'leri listele (kapalı/aktif/done/locked kombinasyonları)
2. Büyük template → küçük helper fonksiyonlara böl (`_buildDayHeader`, `_buildDrugList` vb.)
3. Gerekirse önce statik HTML prototip yaz, sonra template'e çevir

## Kritik Kurallar

- Paralel dosya yazma yasak
- Plan/task/spec dosyaları tamamlanınca done olarak işaretle
- Tohumlama state machine bypass edilmez
- Hook hataları (superpowers "hook error"): zararsız, görmezden gel
- **İş bitince commit + push**: Bir görev tamamlandığında otomatik olarak commit oluştur ve `git push origin main` yap. Kullanıcıdan onay bekleme.

## DB Değişikliği Öncesi (ZORUNLU)

**Bulk UPDATE/DELETE/DROP** → önce taslağı göster, onay al, sonra uygula.
Rutin DDL (ADD COLUMN, CREATE FUNCTION, CREATE INDEX) → doğrudan uygula.

**Referans dosya seçimi — ASLA ara migration kullanma:**

| Doğru | Yanlış |
|-------|--------|
| `99999999999999_ground_truth.sql` | `*_revize.sql`, `*_fix.sql`, herhangi ara migration |
| `.claude/rpc-reference.md` | Eski versiyon migration'lar |

**SQL yazmadan önce oku:**
1. `supabase/migrations/99999999999999_ground_truth.sql` — canonical referans
2. `.claude/rpc-reference.md` — mevcut RPC imzaları
3. `.claude/domain-rules.md` — domain kuralı

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **egesut-erp1** (6099 symbols, 8969 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

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
