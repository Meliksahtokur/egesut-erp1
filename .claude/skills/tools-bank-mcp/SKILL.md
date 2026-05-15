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
- Kaynak: `memory_notes` (21 kayıt)

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

### Bellek arama
```
memory_search({query: "kritik kural supabase rpc", category: "critical_rules"})
```

### Migration
```
supabase_migrate({sql: "CREATE TABLE ..."})
```

## Önemli Uyarılar

1. `supabase_migrate` Management API kullanır — DDL için güvenli
2. Anon key ile yazma işlemleri RLS'ye takılabilir → `supabase_migrate` ile RLS policy ekle
3. `memory_notes` ve `entity_graph` tablolarına anon key INSERT/SELECT için RLS policy gerekli
4. `knowledge_graph_query` Supabase'deki `entity_graph` tablosunu sorgular
5. `memory_search` Supabase'deki `memory_notes` tablosunu sorgular
6. `semantic_search` doğrudan Supabase pgvector kullanır (en hızlı)
