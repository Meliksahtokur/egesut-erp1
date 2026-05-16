---
name: tools-bank-mcp
description: Use when you need to use tools-bank MCP tools — supabase_*, semantic_search, knowledge_graph_query, memory_search, goose_*, task_*, file_*. This skill provides trigger rules and usage patterns so you don't rediscover the interface each time.
---

# tools-bank MCP — Kullanım Kılavuzu

## Ne Zaman Hangi Aracı Kullan

| İhtiyaç | Araç | Not |
|---------|------|-----|
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
| Blast radius (refactor öncesi) | `gitnexus_impact(target, direction?, depth?, includeTests?)` | npx gitnexus impact |
| Grupları listele | `gitnexus_group_list(name?)` | npx gitnexus group list |
| Contract Registry sync | `gitnexus_group_sync(name, skipEmbeddings?, exactOnly?)` | npx gitnexus group sync |

**NOT:** `route_map`, `tool_map`, `shape_check`, `api_impact`, `rename` GitNexus MCP-only tool'lardır — CLI wrapper olarak kullanılamaz. Gerekirse `npx gitnexus mcp` ile ayrı MCP sunucusu başlat.

**ÖNEMLİ:** GitNexus index'inin hazır olması gerekir. Yoksa terminalde:
```bash
cd /root/egesut-erp1 && npx gitnexus analyze
```

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
- `includeTests`: test dosyalarını dahil et (default false)
- `repo`: repo adı (opsiyonel)

### gitnexus_group_list
- `name`: grup adı (opsiyonel, boşsa tüm gruplar)

### gitnexus_group_sync
- `name`: grup adı (zorunlu)
- `skipEmbeddings`: embedding atla (default false)
- `exactOnly`: sadece exact match (default false)

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
