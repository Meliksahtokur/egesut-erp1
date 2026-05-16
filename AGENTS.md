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

## İş Akışı

```
Claude/Pi-new → /root/tools-bank/blackboard/specs/<spec>.md yazar
              → event_daemon_v2.sh goose'u spawn eder
              → goose egesut.yaml recipe'si ile çalışır
              → /root/egesut-erp1'de implementasyon yapar
              → commit + push → task_complete
```

## Başlarken

```bash
cd /root/egesut-erp1
git pull origin main
```

Kodu anlamak için önce `semantic_search` kullan — dosya okumayı minimize et.

## Kod Kuralları

- Supabase: `supabase.rpc()` veya fetch API — raw SQL string concatenation YASAK
- Her değişiklik commit + push edilmeli (commit = iş kanıtı)
- Yeni fonksiyon yazmadan önce duplikat kontrolü: `grep -n "fonksiyon" js/*.js`
- Tablo/RPC yazmadan önce şema kontrol: `execute_sql` ile mevcut yapıyı sorgula

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
