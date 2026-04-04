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

## Migration Protokolü (ZORUNLU — sıra değiştirilemez)

### 1. Yazmadan önce — DB'yi sorgula

```bash
ANON_KEY=$(grep -A5 'Anon key' .claude/CREDENTIALS.md | grep -oP 'eyJ[A-Za-z0-9._-]+')

curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/FUNC_ADI" \
  -X POST -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{}'
# {"code":"42883"} → fonksiyon yok → CREATE yaz
# Başka sonuç → fonksiyon VAR → DROP + CREATE yaz
```

Veya `gwen-supabase` MCP ile:
```
execute_sql: SELECT proname, pg_get_function_arguments(oid) FROM pg_proc WHERE proname = 'func_adi';
```

### 2. Migration kuralı — CREATE OR REPLACE YASAK

```sql
-- ✅ DOĞRU — her zaman böyle yaz
DROP FUNCTION IF EXISTS public.func_adi(uuid, text);
CREATE FUNCTION public.func_adi(...) RETURNS jsonb ...

-- ❌ YANLIŞ — 42P13 hatasına yol açar
CREATE OR REPLACE FUNCTION public.func_adi(...) ...
```

Overload belirsizse hepsini temizle:
```sql
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure FROM pg_proc
           WHERE proname = 'func_adi' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.oid::regprocedure; END LOOP;
END $$;
```

### 3. Push sonrası — GitHub Actions kontrol et

```bash
sleep 15
gh run list --limit 3
gh run watch        # tamamlanana kadar bekle
gh run view --log-failed  # hata varsa
```

**Actions başarısız olursa — önce kendin dene (max 5 deneme):**

```
Deneme 1: gh run view --log-failed → hatayı oku → SQL düzelt → yeni migration → push
Deneme 2-4: Farklı yaklaşım dene, DB'yi yeniden sorgula
Deneme 5: Son deneme
```

5 denemede çözülmezse:
1. `git revert HEAD` — migration'ı geri al
2. `.claude/tasks/BLOCKED-migration-[func_adi].md` yaz (hata + 5 deneme özeti)
3. Push et → Claude görecek, **merge yapma, bekle**

### 4. Doğrula — fonksiyon çalışıyor mu?

```bash
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/FUNC_ADI" \
  -X POST -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{}'
# {"code":"42883"} → HATA, hâlâ yok
# Başka → ✅ fonksiyon aktif
```

## Hata Çözme

Bir sorunla max 4-5 kere uğraş. Çözemezsen kullanıcıya detaylı hata raporu ver, dur.
