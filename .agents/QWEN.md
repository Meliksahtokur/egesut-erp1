# EgeSüt ERP — Gwen Agent Ortak Taban

Bu dosya tüm Gwen sub-agent'larının okuduğu ortak kurallardır.

## Dil Kuralı

**ANADİL: TÜRKÇE** — kullanıcıyla her zaman Türkçe konuş.
Kod değişken adları, API/RPC isimleri İngilizce kalabilir. UI metinleri Türkçe.

## Kimlik & Worktree

| Session | Path | Branch | Git Kimliği |
|---|---|---|---|
| dev | `/root/qwen-dev` | `gwen/dev` | `Gwen [Dev]` |
| arge | `/root/qwen-arge` | `gwen/arge` | `Gwen [Arge]` |
| claude (dokunma) | `/root/egesut-erp1-main` | `main` | — |

**Branch değiştirme YASAK. main'e dokunma YASAK. Diğer worktree'lere müdahale YASAK.**

## Credentials & Backend

**Supabase:**
- Project ref: `zqnexqbdfvbhlxzelzju`
- URL: `https://zqnexqbdfvbhlxzelzju.supabase.co`
- Anon key + diğer bilgiler: `.claude/CREDENTIALS.md` (worktree'nde mevcut)

**GitHub:**
- Repo: `Meliksahtokur/egesut-erp1`
- Auth: `~/.netrc` — push otomatik çalışır

**MCP Sunucuları (Gwen'e özel):**
- `gwen-supabase` — execute_sql, get_table_schema, get_db_telemetry
- `gwen-context7` — fetch_docs
- `gwen-github` — get_repo_info, create_pull_request

## ⚠️ 4 Demir Kural

### Kural 1: Task İzolasyonu
- `gwen/dev` → SADECE `.claude/tasks/dev/`
- `gwen/arge` → SADECE `.claude/tasks/arge/`

### Kural 2: Otonom Workflow (sıra değişmez)
```
1. .claude/tasks/{session}/ACTIVE.md yaz
2. Task uygula
3. node --check js/*.js (dev için)
4. Task dosyasını güncelle: **Durum:** tamamlandı
5. task-XXX-done.md yaz
6. git add + git commit + git push
7. BLACKBOARD güncelle + ACTIVE.md sil
```

### Kural 3: Context7 Zorunlu
`.from()` `.rpc()` `.select()` `.insert()` IndexedDB kullanmadan önce → context7'den güncel doküman çek.

### Kural 4: Yazma Kuralları
- Direkt REST write YASAK → sadece `supabase.rpc()` kullan
- Paralel dosya yazma YASAK
- Task dosyası güncellenmeden commit YASAK

## Referans Haritası (on-demand oku)

| İhtiyaç | Dosya |
|---|---|
| RPC imzaları | `.claude/rpc-reference.md` |
| Domain kuralları | `.claude/domain-rules.md` |
| UI bileşenleri | `.claude/ui-map.md` |
| Credentials | `.claude/CREDENTIALS.md` |

## Hata Çözme

Bir sorunla max 4-5 kere uğraş. Çözemezsen kullanıcıya detaylı hata raporu ver, dur.
