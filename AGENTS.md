# EgeSüt ERP — Agent Context

## Kimlik

Bu dosyayı okuyan agent'a göre rol farklıdır:

| Agent | Rol | Ne yapar |
|---|---|---|
| **Pi-new** | Orkestratör (Claude'un alternatifi) | Analiz eder, spec/task yazar, delege eder — kod yazmaz |
| **Goose** | Worker | Spec'i çalıştırır, kodu yazar, commit atar |

**Pi-new iseniz:** Spec yazın, `tools-bank/AGENTS.md`'deki workflow'u izleyin. Kodu kendiniz yazmayın.  
**Goose iseniz:** Aşağıdaki kuralları izleyin.

---

## Goose Worker

- **Çalışma dizini:** `/root/egesut-erp1`
- **Branch:** `main` (direkt push, branch yok)
- **Orkestratör:** Claude Code veya Pi-new (`/root/tools-bank` üzerinden task yazar)

## Stack

```
Frontend:  Vanilla JS (js/api.js, js/app.js, js/ui.js, js/forms.js, js/state.js, js/config.js)
Backend:   Supabase REST API (PostgreSQL + RPC)
Hosting:   GitHub Pages (index.html)
CI/Test:   Playwright E2E — GitHub Actions'da otomatik çalışır (local'de çalıştırma)
```

## İş Akışı (ACP — Güncel)

```
Claude → goose_start(recipe="egesut-telsiz", session_id="w-001", params='{"agent_id":"w-001"}')
       → Goose: agent_register + agent_receive(timeout=60) [bekler]
       → Claude: agent_send(to="w-001", message="görev detayı")
       → Goose: görevi alır → implementasyon → commit + push → agent_send(to="claude", "TAMAMLANDI")
       → Claude: agent_receive("claude") → sonucu alır
```

**Eski akış (artık kullanılmıyor):** `event_daemon_v2.sh` subprocess spawn → PRoot ENOSYS crash nedeniyle devre dışı.

## Goose Olarak Başlarken

```bash
# Telsizden gelen görevi al (recipe zaten çağırır — bu sadece bilgi)
# ACP parametreleri recipe'den otomatik gelir: agent_id, cwd

cd /root/egesut-erp1
git pull origin main
```

Kodu anlamak için önce `semantic_search` kullan — dosya okumayı minimize et.


## Kod Kuralları

- Supabase: `supabase.rpc()` veya fetch API — raw SQL string concatenation YASAK
- Her değişiklik commit + push edilmeli (commit = iş kanıtı)
- Yeni fonksiyon yazmadan önce duplikat kontrolü: `grep -n "fonksiyon" js/*.js`
- Tablo/RPC yazmadan önce şema kontrol: `execute_sql` ile mevcut yapıyı sorgula

## SQL / RPC Pre-Check (ZORUNLU — Bu Adımları Atla)

**Her SQL veya RPC yazmadan önce sırayla:**

1. **Canonical referans oku** (ara migration'lar YASAK — kırık olabilir):
   ```bash
   file_read("supabase/migrations/99999999999999_ground_truth.sql")
   file_read(".claude/rpc-reference.md")
   ```
   `*_revize.sql`, `*_fix.sql` gibi ara dosyalar YANLIŞ referanstır.

2. **Tablo şemasını doğrula:**
   ```sql
   SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'TABLO';
   ```

3. **Domain kuralını oku:**
   ```bash
   file_read(".claude/domain-rules.md")
   ```

4. **ID tiplerine dikkat:**
   - `text` id: `hayvanlar`, `stok`, `hekimler`, `tohumlama`, **`gorev_log`**
   - `uuid` id: `stok_hareket`, `padoklar`, `vaccines`, `islem_log`
   - `gorev_log.id` = text ama UUID string saklar → INSERT: `gen_random_uuid()::text` veya `gen_random_uuid()` (implicit cast)
   - WHERE karşılaştırma: `WHERE id = p_gorev_id` (text=text, cast GEREKMİYOR)
   - uuid kolona INSERT: `gen_random_uuid()` kullan (`::text` YAPMA)

## DB Değişikliği — Approval Gate (ZORUNLU)

Herhangi bir `CREATE/ALTER/UPDATE/INSERT/DELETE` yazmadan önce orchestrator/kullanıcıya sor:

```
"ONAY GEREKLİ: [ne yapılacak]
Etkilenecek tablolar: [...]
Risk: [veri kaybı var mı?]
SQL taslağı: [sql]"
```

"Onaylıyorum" mesajını alana kadar hiçbir DB yazma yapma.

## Deploy Süreci

- Migration dosyası repoda olması = canlıda çalışıyor DEĞİL
- `supabase_migrate` MCP aracıyla ayrıca deploy et
- GitHub Pages sadece JS günceller, Supabase SQL'i göndermez

## Yasaklar

- `main` dışında branch — YASAK
- CLAUDE.md veya AGENTS.md değiştirme — YASAK (Claude günceller)
- node_modules düzenleme — YASAK
- Raw SQL string birleştirme — YASAK (SQL injection)
- `npx playwright test` local çalıştırma — YASAK (PRoot'ta CPU krizi yapar, CI'da otomatik çalışır)

## Tools-Bank MCP (Memory + GitNexus)

`/root/egesut-erp1/tools-bank/tools-bank-mcp-server.py` üzerinden **13 tool** sunulur:

### Memory (SQLite FTS5 + local ONNX embedding)
- `memory_add(content, category?, priority?, tags?)` — not ekle (karar/hata/bilgi kaydet)
- `memory_search(query, category?, limit?)` — FTS5 full-text arama
- `semantic_search(query, limit?)` — Jina AI embeddings (1024-dim, ~200ms)
- `memory_stats()` — DB istatistik (note/embedding sayısı)

Her oturum **sonunda kritik kararları/hataları** `memory_add` ile kaydet.
Yeni oturum **başında** `memory_search` ile ilgili geçmiş notları getir.
Embedding yenileme: `python3 tools-bank/memory/embedding_service.py --rebuild`

### GitNexus (knowledge graph)
- `gitnexus_list_repos()` — indekslenmiş repolar
- `gitnexus_query(query, repo?, limit?)` — execution flow keşfi
- `gitnexus_context(symbol, repo?)` — 360° sembol görünümü
- `gitnexus_impact(target, direction?, depth?)` — blast radius
- `gitnexus_cypher(query)` — Cypher sorgusu
- `gitnexus_detect_changes(scope?, base_ref?)` — değişiklik etkisi
- `gitnexus_group_list(name?)` / `gitnexus_group_sync(name)` — grup yönetimi

Detaylı kullanım: `.claude/skills/tools-bank-mcp/SKILL.md`
Memory güncelleme: `load_skill("memory-update")` — oturum sonu kayıt workflow'u

## Key Dosyalar

| Dosya | İçerik |
|-------|--------|
| `js/api.js` | Supabase API çağrıları, pullTables, IDB sync |
| `js/app.js` | Ana uygulama mantığı, init |
| `js/ui.js` | UI render fonksiyonları, modal'lar |
| `js/forms.js` | Form işlemleri, RPC çağrıları |
| `js/state.js` | Global state (AppState, getState/setState) |
| `js/config.js` | Sabit listeler (HEKIMLER, GRUP_PADOK vb.) |
| `index.html` | Tek sayfa HTML |
| `supabase/migrations/` | DB migration dosyaları |
| `tools-bank/tools-bank-mcp-server.py` | MCP sunucusu (13 tool: memory + gitnexus) |
| `tools-bank/memory/` | SQLite FTS5 DB + ONNX embedding model |
| `.claude/skills/tools-bank-mcp/SKILL.md` | tools-bank MCP kullanım kılavuzu |
| `ReFactorRoadmap.md` | Teknik borç planı — Aşama 1 kısmen tamam (1.3 helpers/modal, 1.4 autocomplete bekliyor) |

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
