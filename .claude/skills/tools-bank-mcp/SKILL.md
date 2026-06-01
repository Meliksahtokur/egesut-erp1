---
name: tools-bank-mcp
description: Use when you need to use tools-bank MCP tools — supabase_*, semantic_search, knowledge_graph_query, memory_search, goose_*, task_*, file_*. This skill provides trigger rules and usage patterns so you don't rediscover the interface each time.
---

# tools-bank MCP — Kullanım Kılavuzu

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

### memory_search
- `query`: arama sorgusu (FTS5 — unicode61 tokenizer)
- `category`: opsiyonel kategori filtresi
- `limit`: max sonuç (default 10)

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
| Model listesi | `deerflow_list_models()` | deepseek-v4-flash / deepseek-v4-pro |
| Skill listesi | `deerflow_list_skills()` | Yüklü DeerFlow skill'leri |
| Memory özeti | `deerflow_memory("status")` | DeerFlow kendi memory'si |
| Memory'e yaz | `deerflow_memory("add", content="...", category="workContext")` | — |

### ⚠️ Model / Mod Kuralı (ZORUNLU)

| Mod | Model | İzin |
|-----|-------|------|
| `flash` | deepseek-v4-flash | ✅ Varsayılan — izinsiz kullanılır |
| `standard` | deepseek-v4-flash | ✅ Kullanıcı onayı ile |
| `pro` | deepseek-v4-pro | ❌ İzinsiz KULLANMA — kullanıcı onayı zorunlu |
| `ultra` | deepseek-v4-pro + sub-agent | ❌ İzinsiz KULLANMA — kullanıcı onayı zorunlu |

- Default (parametre verilmezse) → `flash` modu çalışır
- `standard` mod gerekiyorsa kullanıcıya bildir ve onay al
- `pro` / `ultra` → **deepseek-v4-pro** modeli demektir, her ikisi de izinsiz yasak

```python
# DOĞRU — varsayılan flash
deerflow_research(query="...")

# DOĞRU — kullanıcı onaylıyorsa
deerflow_research(query="...", mode="standard")

# YANLIŞ — izinsiz v4-pro
deerflow_research(query="...", mode="pro")
deerflow_research(query="...", mode="ultra")
```

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

**Not:** DeerFlow her sistem restart'ında DOWN düşer — oturum başında `deerflow_health()` ile kontrol et.

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
