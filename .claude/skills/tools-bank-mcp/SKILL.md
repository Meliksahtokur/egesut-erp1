---
name: tools-bank-mcp
description: Use when you need to use tools-bank MCP tools — supabase_*, semantic_search, knowledge_graph_query, memory_search, goose_*, task_*, file_*. This skill provides trigger rules and usage patterns so you don't rediscover the interface each time.
---

# tools-bank MCP — Kullanım Kılavuzu

> **⚠️ Bu Legion PC'de (2026-07-04) geçerli olmayanlar:**
> - **Goose/goused araçları** (`goose_start`, `goose_status`, `agent_*`, tier/telsiz) — yerel Goose/goused binary'leri kurulu değil.
> - Yol referansları: bu makinede `egesut-erp1` = `/home/melik/egesut-erp1`, `tools-bank` = `/home/melik/tools-bank` (metindeki `/root/...` yerine).
> Aşağıdaki tablo/komutlar tam referans için duruyor; **Goose satırlarını bu makinede kullanma**, `deerflow_*`/`memory_search`/`semantic_search`/`supabase_*`/`file_*`/GitNexus araçları çalışır. **DeerFlow gateway 2026-07-06'da Legion PC'de aktiftir** (`mcp__tools_bank_deerflow_gateway_restart` 6 sn'de kalkar).

## Ne Zaman Hangi Aracı Kullan

| İhtiyaç | Araç | Not |
|---------|------|-----|
| Goose worker başlat | `goose_start(recipe, session_id, params, tier, parent_session_id)` | goused-api :8743 |
| Goose durum sorgula | `goose_status(session_id)` | running/done/crashed/stopped |
| Telsiz'e kaydol | `agent_register(agent_id, capabilities)` | goused-telsiz :8744 |
| Telsiz mesaj gönder | `agent_send(to, from_, message, message_type, priority)` | long-poll kuyruk |
| Telsiz mesaj bekle | `agent_receive(agent_id, timeout)` | timeout=30 default |
| Veritabanı sorgusu (SELECT) | `supabase_query(table, filters, select, limit, order)` | Direkt Supabase REST |
| RPC çağrısı | `supabase_rpc(function_name, params)` | Tüm yazma işlemleri |
| DDL/Migration | `supabase_migrate(sql)` | Management API |
| INSERT/UPDATE/DELETE | `supabase_insert/upsert/delete` | Anon key ile |
| Kodda anlamsal arama | `semantic_search(query, limit)` | pgvector, ~800ms |
| Entity/ilişki sorgulama | `knowledge_graph_query(entity, relation_target?)` | Supabase entity_graph |
| Bellek arama | `memory_search(query, category?, limit?)` | Supabase memory_notes |
| Goose dokümantasyonu | `goose_search(query, limit)` | goose_embeddings |
| Blackboard task | `task_*` (create, get, list, claim, complete, review) | SQLite |
| tools-bank file DB | `file_*` (write, read, list, flush, commit) | SQLite |
| Kodda yapısal (AST) arama | `ast_grep_search(pattern, lang?, path?, max_results?, context_lines?)` | ast-grep, ~50ms, joker: `$$$` |
| GitHub remote kod arama | `github_code_search(query, repo?)` | GitHub API, token gerekli |
| Greptile - PR review listeleme | `list_pull_requests(...)` / `list_merge_requests(...)` | GREPTILE_API_KEY (.mcp.json) |
| Greptile - PR review detay | `get_merge_request(name, remote, defaultBranch, prNumber)` | Repo + PR no |
| Greptile - PR yorumlari | `list_merge_request_comments(...)` / `search_greptile_comments(...)` | Filtreleme destegi |
| Greptile - Review tetikle | `trigger_code_review(name, remote, prNumber)` | Kalici MCP server |
| Greptile - Custom context | `list_custom_context / get_custom_context / search_custom_context` | Organizasyon seviyesi |
| Greptile - Code review | `list_code_reviews / get_code_review` | Headless/PR destegi |
| SonarCloud issue ara | `sonar_issues(project_key?, types?, severities?, tags?, page_size?)` | BUG/CODE_SMELL/VULNERABILITY |
| SonarCloud duplikat dosyalar | `sonar_duplications(project_key?, page_size?)` | En yüksek % önce |
| SonarCloud dosya duplikat blokları | `sonar_file_duplications(file_key)` | `proje:js/ui.js` formatı |
| SonarCloud metrikler | `sonar_measures(project_key?, metrics?)` | LOC, dup%, bug sayısı |
| SonarCloud quality gate | `sonar_quality_gate(project_key?)` | OK/ERROR + fail koşullar |
| SonarCloud security hotspots | `sonar_hotspots(project_key?, status?, page_size?)` | TO_REVIEW/REVIEWED |
| SonarCloud PR kalite durumu | `sonar_pull_requests(project_key?)` | PR'lar + gate status |
| SonarCloud kural detayı | `sonar_rule(rule_key)` | Neden hata, nasıl düzeltilir |
| SonarCloud kaynak kodu | `sonar_source(file_key, from_line?, to_line?)` | Issue satırları işaretli |
| SonarCloud düşük coverage | `sonar_coverage(project_key?, max_coverage?, page_size?)` | Kapsanmayan satırlar |
| SonarCloud issue kapat | `sonar_change_issue_status(issue_key, status, comment?)` | accept/falsepositive/reopen |

### Memory (SQLite FTS5 + Jina AI embedding)
| İhtiyaç | Araç | Not |
|---------|------|-----|
| Not ekle (karar/hata/bilgi kaydet) | `memory_add(content, category?, priority?, tags?)` | SQLite, anında |
| FTS5 arama | `memory_search(query, category?, limit?)` | unicode61 tokenizer |
| Semantik arama | `semantic_search(query, limit?)` | Jina AI (jina-embeddings-v5-text-small, 1024-dim) |
| DB istatistik | `memory_stats()` | Note/embedding sayısı + kategori dağılımı |

### GitNexus (knowledge graph — tools-bank MCP içinde 8 CLI wrapper)
| İhtiyaç | Araç | Not |
|---------|------|-----|
| İndekslenmiş repoları listele | `gitnexus_list_repos()` | npx gitnexus list |
| Execution flow / sembol bağımlılığı keşfi | `gitnexus_query(query, repo?, limit?)` | npx gitnexus query, ~1-3sn |
| Cypher sorgusu | `gitnexus_cypher(query)` | npx gitnexus cypher |
| Sembolün 360° görünümü (callers/callees) | `gitnexus_context(symbol, repo?)` | npx gitnexus context |
| Uncommitted değişikliklerin etkisi | `gitnexus_detect_changes(scope?, base_ref?)` | npx gitnexus detect-changes |
| Blast radius (refactor öncesi) | `gitnexus_impact(target, direction?, depth?, include_tests?)` | npx gitnexus impact |
| Grupları listele | `gitnexus_group_list(name?)` | npx gitnexus group list |
| Contract Registry sync | `gitnexus_group_sync(name, skip_embeddings?, exact_only?)` | npx gitnexus group sync |

**NOT:** `route_map`, `tool_map`, `shape_check`, `api_impact`, `rename` GitNexus MCP-only tool'lardır — CLI wrapper olarak kullanılamaz. Gerekirse `npx gitnexus mcp` ile ayrı MCP sunucusu başlat.

**ÖNEMLİ:** GitNexus index'inin hazır olması gerekir. Yoksa terminalde:
```bash
cd /root/egesut-erp1 && npx gitnexus analyze
```

### ast-grep — Yapısal Kod Arama

`ast_grep_search` ile kodun AST yapısında desen araması yapılır.

| Parametre | Zorunlu | Açıklama | Örnek |
|-----------|---------|----------|-------|
| `pattern` | ✅ | AST pattern (joker: `$$$`, `$NAME`) | `function $$$($$$) { $$$ }` |
| `lang` | ❌ | Programlama dili | `javascript`, `go`, `typescript`, `python`, `rust` |
| `path` | ❌ | Arama yapılacak yol (default: `.`) | `js/`, `supabase/migrations/` |
| `max_results` | ❌ | Maksimum sonuç (default: 20) | `10` |
| `context_lines` | ❌ | Her sonuç için bağlam satırı (default: 0) | `2` |

**2 Aşamalı Protokol (Token Tasarrufu):**

1. **Özet:** `max_results=10` ile çağır, sadece dosya/konum bilgisine bak
2. **Nokta atışı:** İlgili dosyayı `read_file` ile o satır aralığından oku

**Pattern Örnekleri:**
```
JavaScript: function $$$($$$) { $$$ }    → tüm fonksiyon tanımları
JavaScript: await supabase.rpc($$$)      → tüm RPC çağrıları
JavaScript: import $$$ from '$$$'        → tüm import'lar
JavaScript: if ($$$) { $$$ }             → tüm if blokları
Go:         if err != nil { $$$ }        → hata kontrol blokları
Python:     def $$$($$$):                → tüm fonksiyon tanımları
```

**Token Koruma:**
- `--json=compact` kullanılır → sadece konum bilgisi döner, kod içeriğini ham basmaz
- `max_results` aşımında uyarı verir → aramayı daraltman gerekir
- Büyük dosyalarda (300+ satır) önce AST ile hedef bloğu bul, sonra `read_file`

---



## Goose & Telsiz — Agent Sistemi

### Mimari

```
Tier 0 — Claude (orkestratör)
  ↓ goose_start(recipe="goose-ops", tier=1) + agent_send(type="task")
Tier 1 — Goose Orchestrator: goose-ops recipe (max 3 eşzamanlı)
  ↓ native summon — MCP paylaşılıyor (test edildi 2026-05-18)
Tier 2 — Goose Workers: egesut-telsiz recipe (max 3 per orchestrator)
```

### goose_start

```
goose_start(
  recipe="goose-ops",          # recipe adı (GOOSE_RECIPE_PATH'te aranır)
  session_id="goose-ops-A",    # benzersiz ID
  params='{"ops_id":"goose-ops-A"}',  # JSON string
  tier=1,                      # 1=orchestrator, 2=worker, 0=default
  parent_session_id=""         # tier=2 için orchestrator session_id
)
# → {"session_id":"...", "pid":..., "log_path":"/tmp/goose-X.log", "status":"running"}
```

**Slot enforcement (HTTP 429 → sıra bekliyor):**
- tier=1: max 3 eşzamanlı orchestrator
- tier=2: max 3 eşzamanlı worker per parent_session_id

**Log takibi:** `tail -f /tmp/goose-{session_id}.log`

### goused-api Ek Endpointler (HTTP — MCP değil)

```bash
# Cascade kill (orchestrator + tüm children)
curl -X POST http://localhost:8743/goose/stop-tree/{id}

# Heartbeat (orchestrator 30s'de bir çağırmalı — 90s timeout → cascade kill)
curl -X POST http://localhost:8743/goose/heartbeat/{id}

# Commit lock — git race condition önleme (3 worker aynı anda commit yaparsa bozulur)
curl -X POST http://localhost:8743/commit-lock/acquire \
  -H "Content-Type: application/json" -d '{"session_id":"WORKER_ID"}'
# → 200 {"status":"acquired"} | 423 {"error":"locked by X"} → 5s bekle, retry

curl -X POST http://localhost:8743/commit-lock/release \
  -H "Content-Type: application/json" -d '{"session_id":"WORKER_ID"}'
```

### agent_register / agent_send / agent_receive

```
agent_register(agent_id="claude", capabilities='["orchestrate","approve"]')

agent_send(
  to="goose-ops-A",
  from_="claude",
  message="Görev: ...",
  message_type="task",   # task|result|question|answer|approval_req|heartbeat
  priority="high"        # high|normal|low (high → cooldown atlar)
)
# → {"id":"uuid", "status":"queued"}

agent_receive(agent_id="claude", timeout=120)
# mesaj: {"id":..., "from_agent":..., "message":..., "message_type":..., ...}
# timeout: {"message": null, "timeout": true}
```

**Spam koruması:** aynı (from, to, mesaj) 5s içinde → 409 | aynı (from, to) 3s → 429

### Tipik Orkestrasyon Akışı (Claude → Goose-Ops)

```python
# 1. Kayıt
agent_register(agent_id="claude", capabilities='["orchestrate","approve"]')

# 2. Orchestrator spawn
goose_start(recipe="goose-ops", session_id="goose-ops-A",
            params='{"ops_id":"goose-ops-A"}', tier=1)

# 3. Görev ver
agent_send(to="goose-ops-A", from_="claude",
           message="Görev: [ne yapılacak]\nKabul: [kriterler]",
           message_type="task", priority="high")

# 4. Sonuç bekle
result = agent_receive(agent_id="claude", timeout=900)
# → "TAMAMLANDI: abc123 — [özet]"
```

### Commit Lock Kullanımı (Worker — ZORUNLU)

```bash
# Commit öncesi lock al
curl -s -X POST http://localhost:8743/commit-lock/acquire \
  -H "Content-Type: application/json" -d '{"session_id":"WORKER_ID"}'
# 423 gelirse: sleep 5 && retry (max 10 deneme)

git add -A && git commit -m "..." && git push origin main

# Commit sonrası lock bırak
curl -s -X POST http://localhost:8743/commit-lock/release \
  -H "Content-Type: application/json" -d '{"session_id":"WORKER_ID"}'
```

### Recipes (GOOSE_RECIPE_PATH=/root/tools-bank/recipes)

| Recipe | Rol |
|--------|-----|
| `goose-ops` | Tier-1 Orchestrator — analiz+plan+worker yönet+review+exit |
| `egesut-telsiz` | Tier-2 Worker — EgeSüt kod yazar, commit lock kullanır |
| `reviewer` | Bağımsız reviewer — orchestrator kendi işini review ETMEZ |
| `conductor` | Spec dosyası adım adım executor |
| `researcher` | Web araştırma (DuckDuckGo + semantic search) |

### Servis Durumu

```bash
curl -s http://localhost:8742/health  # goused-proxy (deepseek)
curl -s http://localhost:8743/health  # goused-api (process manager)
curl -s http://localhost:8744/health  # goused-telsiz (mesaj kuyruğu)
```

---

## Önemli Parametreler

### supabase_query
- `table`: tablo adı (hayvanlar, gorev_log, stok, tohumlama, memory_notes, entity_graph)
- `filters`: `kolon=eq.deger` formatı (eq, neq, gt, gte, lt, lte, like, in)
- `select`: varsayılan `*`, aggregate desteklemez
- `order`: `kolon.asc` veya `kolon.desc`

### supabase_rpc
- `function_name`: RPC adı (hayvan_ekle, hayvan_guncelle, tohumlama_sonuc_gebe, stok_duzelt)
- `params`: JSON string `{"param1":"deger","param2":123}`

### semantic_search
- `query`: Türkçe veya İngilizce doğal dil sorgusu
- `limit`: varsayılan 5, max 20
- Kaynak: `code_embeddings` (2.437 kod chunk'ı)

### knowledge_graph_query
- `entity`: sembol adı (loadTasks, hayvan_ekle, _katTipMap, gorev_log)
- `relation_target` (opsiyonel): ilişki hedefi
- Kaynak: `entity_graph` (14 entity)

### memory_search
- `query`: arama sorgusu
- `category` (opsiyonel): critical_rules, rpc_reference, domain_rules, tech_stack
- `limit`: varsayılan 5
- Kaynak: `memory_notes` (local SQLite, not sayısı `memory_stats()` ile görülür)

### memory_add
- `content`: not içeriği (zorunlu)
- `category`: kategoriler — `critical_rules`, `rpc_reference`, `domain_rules`, `code_change`, `tech_stack`, `general`
- `priority`: öncelik — `high`, `medium` (default), `low`
- `tags`: virgülle ayrılmış etiketler (örn: `"rpc,hayvan,kritik"`)

### semantic_search
- `query`: doğal dil sorgusu
- `limit`: max sonuç (default 5)

- **NOT:** Jina AI (jina-embeddings-v5-text-small), 1024-dim, ~200ms/call

### memory_stats
- Parametre yok — note/embedding sayısı + kategori dağılımı

### gitnexus_list_repos
- Parametre yok — tüm indekslenmiş repoları listeler

### gitnexus_query
- `query`: doğal dil veya keyword (örn: `"tohumlama sonuc işleme"`, `"loadTasks execution flow"`)
- `repo`: repo adı (tek repo varsa gerekmez)
- `limit`: max sonuç sayısı (default 10)

### gitnexus_cypher
- `query`: Cypher sorgusu (örn: `MATCH (f:Function) RETURN f.name LIMIT 5`)
- `repo`: repo adı (opsiyonel)

### gitnexus_context
- `symbol`: sembol adı (örn: `hayvan_ekle`, `rpcOptimistic`, `_katTipMap`)
- `repo`: repo adı (opsiyonel)

### gitnexus_detect_changes
- `scope`: kapsam — `unstaged` (default), `staged`, `all`, `compare`
- `base_ref`: compare modunda karşılaştırma branch'i (örn: `main`)
- `repo`: repo adı (opsiyonel)

### gitnexus_impact
- `target`: değiştirmeyi düşündüğün sembol
- `direction`: yön — `upstream` (kullananlar, default), `downstream` (çağırdıkları)
- `depth`: ilişki derinliği (default 3)
- `include_tests`: test dosyalarını dahil et (default false)
- `repo`: repo adı (opsiyonel)

### gitnexus_group_list
- `name`: grup adı (opsiyonel, boşsa tüm gruplar)

### gitnexus_group_sync
- `name`: grup adı (zorunlu)
- `skip_embeddings`: embedding atla (default false)
- `exact_only`: sadece exact match (default false)

## Örnek Kullanımlar

### Veritabanı sorgusu
```
supabase_query({table: "gorev_log", filters: "kaynak=eq.MANUEL", limit: 10})
```

### RPC çağrısı
```
supabase_rpc({function_name: "buzagi_sutten_kesme_kontrol", params: "{}"})
```

### Kod arama
```
semantic_search({query: "görev tag filtresi muayene tedavi", limit: 5})
```

### Entity sorgulama
```
knowledge_graph_query({entity: "loadTasks"})
```

### Not ekle (kararlar/hatalar/bilgiler)
```
memory_add({content: "tohumlama_sonuc_bos RPC 42883 hatası — DB'de fonksiyon yok", category: "code_change", priority: "high", tags: "bug,rpc,tohumlama"})
```

### Bellek arama
```
memory_search({query: "kritik kural supabase rpc", category: "critical_rules"})
```

### Semantik arama
```
semantic_search({query: "tohumlama sonuc işleme akışı"})
```

### Memory istatistik
```
memory_stats()
```

### Repoları listele
```
gitnexus_list_repos()
```

### GitNexus sorgulama
```
gitnexus_query({query: "tohumlama sonuc işleme akışı", limit: 5})
```

### Cypher sorgusu
```
gitnexus_cypher({query: "MATCH (f:Function) RETURN f.name LIMIT 5"})
```

### Sembol bağlamı
```
gitnexus_context({symbol: "loadTasks"})
```

### Değişiklik etkisi
```
gitnexus_detect_changes({scope: "unstaged"})
```

### Etki analizi
```
gitnexus_impact({target: "rpcOptimistic", depth: 2})
```

### Migration
```
supabase_migrate({sql: "CREATE TABLE ..."})
```

---

## DeerFlow — Web Araştırması

DeerFlow sadece **web araştırması** ve **harici kaynak analizi** için kullanılır. Kod yazma, dosya değiştirme, implementasyon yapamaz.

### Araçlar

| İhtiyaç | Araç | Not |
|---------|------|-----|
| Tek seferlik araştırma | `deerflow_research(query, mode?)` | Stateless, her çağrı yeni thread |
| Stateful sohbet — yeni | `deerflow_chat(message)` → thread_id sakla | Context korunur |
| Stateful sohbet — devam | `deerflow_chat(message, thread_id="...")` | Aynı thread |
| Gateway sağlık kontrolü | `deerflow_health()` | `200 healthy` beklenir |
| Gateway restart | `deerflow_gateway_restart()` | DOWN ise çağır |
| Agent listesi | `deerflow_agents()` | Varsayılan: `lead_agent` |
| Thread listesi | `deerflow_threads(limit=10)` | Geçmiş thread_id'leri |
| Model listesi | `deerflow_list_models()` | **minimax-m3 (MiniMax-M3)** — DeepSeek DEĞİL (2026-07-06 doğrulandı) |
| Skill listesi | `deerflow_list_skills()` | 22 yüklü DeerFlow skill'i (claude-to-deerflow, deep-research, vb.) |
| Memory özeti | `deerflow_memory("status")` | DeerFlow kendi memory'si (rijit şema) |
| Memory'e yaz | `deerflow_memory("add", content="...", category="...")` | Sadece izin verilen kategoriler (aşağıda "Memory Schema") |

### Mod Seçimi

| Mod | Plan | Sub-agent | Not |
|-----|------|-----------|-----|
| `flash` | ✗ | ✗ | Thinking kapalı, hızlı (5-15 sn) |
| **`standard` (default)** | ✗ | ✗ | Thinking açık, tek kaynaklı analiz (20-60 sn) |
| `pro` | ✓ | ✗ | Planlı + TodoMiddleware (1-3 dk) |
| `ultra` | ✓ | ✓ | Sub-agent'lı derin rapor, max 3 concurrent (3-15+ dk) |

**Default = `standard`** (kod, `tools-bank/mcp_server/server.py:1979` → `mode: str = "standard"`).
SKILL.md'nin eski sürümlerinde "default flash" yazıyordu — bu **yanlış**. Parametre YAZILMAZSA `standard` çalışır (thinking=True, plan=False, subagent=False).
Mod seçimi kodu 3 Boolean bayrağa açılır: `thinking_enabled`, `is_plan_mode`, `subagent_enabled`.

Hepsi izinsiz kullanılabilir (Legion PC donanım yeterli, 2026-07-04 sonrası politika).

```python
# DOĞRU — default standard (parametre yazma)
deerflow_research(query="...")

# AÇIKÇA KULLANICI ONAYI İLE — pro/ultra
deerflow_research(query="...", mode="pro")
deerflow_research(query="...", mode="ultra")

# YANLIŞ — kullanıcı onayı olmadan pro/ultra
deerflow_research(query="X nedir?", mode="ultra")  # Tek-sorgu için overkill

### Gateway DOWN ise

```python
# 1. Kontrol
deerflow_health()  # → ❌

# 2. Restart (tools-bank üzerinden)
deerflow_gateway_restart()  # max 60sn bekler

# 3. Tekrar kontrol
deerflow_health()  # → ✅ devam et
```

Manuel başlatma (restart tool çalışmazsa):
```bash
cd /root/deer-flow/backend && PYTHONPATH=. nohup uv run uvicorn app.gateway.app:app \
  --host 0.0.0.0 --port 8001 --log-level warning \
  > /root/deer-flow/logs/gateway.log 2>&1 &
```

### Thread & Recursion Bilinen Sorunlar (ÇOK ÖNEMLİ)

v2.0 main'de hâlâ **release-blocking** 5 issue:

| Issue # | Problem | Etki |
|---|---|---|
| [#3107](https://github.com/bytedance/deer-flow/issues/3107) | v2.0-m1-rc1 release-blocking bugs | ultra/user workflow testing |
| [#2569](https://github.com/bytedance/deer-flow/issues/2569) | Infinite `web_search ↔ web_fetch` döngüsü, `LoopDetectionMiddleware` atlatıyor | Thread sonsuz döngü |
| [#1987](https://github.com/bytedance/deer-flow/issues/1987) | `LoopDetectionMiddleware` cross-file `read_file` loop'larını kaçırıyor | `GraphRecursionError` |
| [#1055](https://github.com/bytedance/deer-flow/issues/1055) | Repetitive tool call loop'ları | Tüm modlarda görülür |
| [#2116](https://github.com/bytedance/deer-flow/issues/2116) | Loop detection false positives; thresholds `config.yaml`'dan yapılandırılamıyor | Tuning zor |

**Recursion limit değerleri:**
- `tools-bank/mcp_server/server.py` (her iki çağrıda): hardcoded `recursion_limit=100`
- DeerFlow config (deer-flow/backend): `recursion_limit=1000`
- Yani tools-bank tarafında **100 recursion** sınırı var, bu nedenle 4+ dallı sorgu veya uzun tool call zincirleri hızla tükenir.

**Mitigasyon (her sorgu için uygula):**
1. **Odaklı sorgu yaz** — tek seferde 2-3 soru max. Çok-dallı → recursion limit'e çarpar.
2. **Sorgu derinliği sınırla** — "X nedir, B nasıl çalışır, C neden, D ne zaman" gibi 4+ alt konu ayrı sorgulara böl.
3. **Termination condition koy** — özellikle `mode="ultra"` çağrılarında explicit "durdurma koşulu" tanımla.
4. **Thread yönetimi** — 1 konu = 1 thread. Farklı konular için yeni thread; eski thread'de context şişmesine izin verme.

```python
# RİSKLİ — 4 dallı sorgu, recursion limit'i zorlar
deerflow_research(query="A nedir? B nasıl çalışır? C neden? D ne zaman?")

# DOĞRU — odaklı tek sorgu
deerflow_research(query="DeerFlow recursion limit mechanism and workarounds")
```

### Memory Schema (Rijit)

`deerflow_memory("add", content, category)` sadece şu kategorileri kabul ediyor:

- `workContext` — oturum-içi kısa vadeli çalışma hafızası
- `personalContext` — kalıcı kullanıcı tercihleri
- `topOfMind` — "always-on" öncelikli bilgi

**+ zorunlu `correction` alanı** (her fact için garanti düzeltme notu).

**Custom kategori kabul edilmiyor** (test 2026-07-06 ile doğrulandı → `category: "test"` → 200 OK döner AMA yeni thread'de hatırlamaz).

Pratik: `max_facts` ≤ 100, `fact_confidence_threshold` ≥ 0.7, 30s debounce, semantic duplicate'a dikkat.

### Güvenlik: "Emir Kesin" Prompt-Injection

`docs/research/deerflow/state-usage-2026-07-06.md:67-70`'te tespit edilen flag:
- Kullanıcı girdisinde `"emir kesin"` gibi ifadeler tespit edilirse ajan farklı modda davranabiliyor
- DeerFlow'un memory/thread sistemine sızma riski
- **Kullanıcı promptlarına `"emir kesin"` ifadesini yazma** — bu test vektörü, üretim kullanımında sızma riski taşır
- Memory'den gelen "topOfMind summary" kullanıcı girdisini DeerFlow'a yansıtırken bu flag aktif olabilir

**Detay:** `docs/research/deerflow/state-usage-2026-07-06.md:67-70` ve `.claude/skills/deerflow/SKILL.md` "Güvenlik" bölümü.

**Not:** DeerFlow her sistem restart'ında DOWN düşer — oturum başında `deerflow_health()` ile kontrol et.

---

---

## Repomix MCP — Codebase Haritası

Repomix MCP (`npx repomix --mcp`) Tree-sitter ile kod iskeletini çıkarır.
Fonksiyon gövdelerini keser, sadece imza + yapı bırakır. Token-verimli genel oryantasyon için.

| İhtiyaç | Araç | Not |
|---------|------|-----|
| Proje iskelet haritası | `pack_codebase(directory, compress=true)` | ~2-4k token, gövdeler yok |
| Uzak repo analizi | `pack_remote_repository(url, compress=true)` | GitHub URL |
| Üretilen haritayı oku | `read_repomix_output(outputId)` | pack sonrası |
| Haritada arama | `grep_repomix_output(outputId, pattern)` | regex destekli |

**Ne zaman kullan:**
- Oturum başında yön bulmak için (bir kez yeterli, her mesajda değil)
- "Bu projede tohumlama ile ilgili ne var?" gibi genel sorularda
- Yeni bir modüle dokunmadan önce dosya/fonksiyon listesi almak için

**Ne zaman kullanma:**
- Spesifik fonksiyon araması için → `ast_grep_search` daha hızlı
- Blast radius için → `gitnexus_impact` daha doğru
- Her mesajda → gereksiz token tüketimi

---

## Domain Fonksiyon Pre-Check Protokolü

**Tohumlama / Doğum / Görev gibi domain fonksiyonlarına dokunmadan önce ZORUNLUdur.**

```
Adım 1 — Blast Radius (kim etkilenir?)
  gitnexus_impact(target="değişen_fonksiyon", direction="upstream")
  → HIGH veya CRITICAL risk dönerse kullanıcıya bildir, onay al

Adım 2 — Benzer Fonksiyon Tespiti (duplikat var mı?)
  ast_grep_search(pattern="function $NAME($$$) { $$$ }", lang="javascript", path="js/")
  → Aynı domain'de benzer isimli fonksiyonları listele
  → Örnekler: toh*, insem*, dogum*, gorev*, submitToh*, submitBirth*

Adım 3 — Mevcut SonarCloud Bulguları (bu alanda duplikat kayıtlı mı?)
  Bash: curl -s "https://sonarcloud.io/api/issues/search?componentKeys=Meliksahtokur_egesut-erp1\
        &resolved=false&types=CODE_SMELL&tags=clones&severities=MAJOR,CRITICAL,BLOCKER" \
        -H "Authorization: Bearer $SONAR_TOKEN" | python3 -m json.tool
  → Sadece duplikat issue'ları (tag=clones) çek, MINOR/INFO atla
```

**Kural:** Adım 1 HIGH/CRITICAL dönerse implementasyona geçme — önce kullanıcıya göster.

---

## Önemli Uyarılar

1. `supabase_migrate` Management API kullanır — DDL için güvenli
2. Anon key ile yazma işlemleri RLS'ye takılabilir → `supabase_migrate` ile RLS policy ekle
3. `entity_graph` tablosuna anon key SELECT için RLS policy gerekli
4. `knowledge_graph_query` Supabase'deki `entity_graph` tablosunu sorgular
5. **Memory sistemi local SQLite kullanır** — `memory_search`, `memory_add`, `memory_stats` local DB'ye gider. Supabase fallback var ama boş.
6. `semantic_search` / `memory_add` Jina AI (jina-embeddings-v5-text-small) kullanır — 1024-dim, ~200ms/call. API key: `jina_a9b0ff962ff94ee98f9d7f8d4f7feee9_-qMCCMAbTSnJHf6m7vOaCGbloC0` (kod içinde default, env `JINA_API_KEY` ile override edilebilir).
7. **GitNexus araçları CLI wrapper'dır** — MCP'den çağrılınca `npx gitnexus <komut>` çalıştırır. Index zaten varsa ~1-3sn döner.
8. Index yoksa `"Run 'npx gitnexus analyze' first"` uyarısı döner — terminalde bir kere `npx gitnexus analyze` çalıştır yeter.
9. `gitnexus_impact` dönen sonuçlar approximate'dir — mutlaka verify et.
10. **`memory_add` / `vec_notes` / `vec_goose` INSERT yaparken MUTLAKA `_get_db()` kullan.** `sqlite3.connect(MEMORY_DB)` ile açılan bağlantıda `vec0` extension yüklü olmaz → `no such module: vec0` hatası → `embedded: false`. Düzeltme için bkz `memory_search({query: "_get_db fix"})`.

## Session Sonu Notları (2026-06-23)

### Çağrı Formatı — Doğrulanan Gerçekler
- `mcp__tools_bank_*` direct call: **ÇALIŞIYOR** (3 not bu oturumda başarıyla eklendi: `1a9453cb`, `15b0877a`, `28da20f7`)
- `mcp__tools_bank_*` bash içinden direct: **ÇALIŞIYOR** (search_tool_bm25 ile keşfedildi)
- `mcp({tool: ..., args: ...})` proxy mode: tool listesinde **YOK** (doğru)
- **Bash içinde `mcp({...})` syntax**: HATA — "pi-natives:command: syntax error at end of input" döner. Proxy mode sadece **harness tool call** olarak çalışır, bash subshell içinde değil.
- `tools_bank_*` (prefix'siz) veya `mcp__tools-bank__*` (tire ile): **YOK**
- MiniMax-M3 harness'inde toplam tool sayısı: **67** (46 tools-bank + 12 gitnexus + 9 ddg/notebooklm/local)
- `search_tool_bm25` ile tool discovery: `mcp__tools_bank_memory_add` → yeni tool oturum boyunca aktif kalır

### mcp_watchdog / master_daemon — DEACTIVATED (2026-06-23)
- `/etc/profile.d/start_daemons.sh` indirildi — sadece açıklayıcı yorum kaldı (192 byte)
- Syntax hatası (yarım yorum refactor: `if` yorum içinde ama gövde + `fi` açıkta) düzeltildi
- İzlenen süreçler (MCP server, goused :8742/:8743/:8744, skillopt-session-watch) artık kendi supervisor'larında — watchdog no-op
- memory: ID `15b0877a` (critical_rules, high)

### Profile.d refactor kuralı
Bir `if ... then ... fi` bloğunu devre dışı bırakmak için SADECE `if` satırını yorum satırına almak yetmez — gövde ve `fi` de yorum içinde kalmalı. memory: ID `28da20f7` (critical_rules, medium)
