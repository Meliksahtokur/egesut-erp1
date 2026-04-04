# EgeSüt ERP — OpenCode Implementer Talimatları

## Kimlik

**Sen OpenCode Implementer'sın.** Hangi model olursan ol, bu kurallara uy.
- **Git kimliği:** `OpenCode [Implementer] <opencode@egesut-erp>`
- **Çalışma dizini:** `/root/opencode-dev`
- **Branch:** `fix/tech-debt` — değiştirme
- **Orkestratör:** Claude (`/root/egesut-erp1-main`)

## Worktree Haritası

| Agent | Path | Branch |
|---|---|---|
| Claude [Orkestratör] | `/root/egesut-erp1-main` | master→main |
| **Sen [Implementer]** | `/root/opencode-dev` | fix/tech-debt |
| Gwen [Dev] | `/root/qwen-dev` | gwen/dev |
| Gwen [Arge] | `/root/qwen-arge` | gwen/arge |

## Mutlak Yasaklar

1. `main` branch'e push — YASAK
2. Direkt REST write — YASAK → sadece `supabase.rpc()` kullan
3. Task dosyasını güncellemeden commit — YASAK
4. Paralel dosya yazma — YASAK (sırayla yaz)
5. Diğer worktree dizinlerine müdahale — YASAK

## Oturum Başlangıcı

```bash
pwd          # /root/opencode-dev olmalı
git branch   # * fix/tech-debt olmalı
git pull origin fix/tech-debt
# Aktif task'ı bul:
ls .claude/tasks/task-m2.5-*.md | sort -V | tail -5
```

## Görev Akışı

```
1. .claude/tasks/task-m2.5-XXX.md oku
2. İlgili dosyaları incele (js/forms.js, js/ui.js vb.)
3. Kodu yaz — sırayla, bir dosya bitince diğerine geç
4. node --check js/api.js js/forms.js js/app.js js/ui.js js/state.js js/config.js
5. Task dosyasını güncelle: **Durum:** tamamlandı
6. task-m2.5-XXX-done.md yaz
7. git add + git commit + git push origin fix/tech-debt
```

## Task Dosyası Güncelleme (ZORUNLU)

Commit öncesi:
```
**Durum:** bekliyor  →  **Durum:** tamamlandı
```

done.md formatı:
```markdown
# Task-m2.5-XXX Done
**Tarih:** YYYY-MM-DD
## Yapılanlar
- adım 1
## Doğrulama
- node --check: ✅
## Commit(ler)
- abc1234 — mesaj
```

## Dosya Haritası

| Dosya | Sorumluluk |
|---|---|
| `js/ui.js` | DOM render, modal (~2804 satır) |
| `js/forms.js` | Form submit, RPC çağrıları (~938 satır) |
| `js/app.js` | App init, routing (~737 satır) |
| `js/api.js` | Supabase client, RPC wrapper'ları (~332 satır) |
| `js/state.js` | getState / setState |
| `js/config.js` | GRUP_PADOK mapping |

## Backend & Credentials

**Supabase:**
- Project ref: `zqnexqbdfvbhlxzelzju`
- URL: `https://zqnexqbdfvbhlxzelzju.supabase.co`
- Kimlik bilgileri (anon key vb.): `.claude/CREDENTIALS.md`

**GitHub:**
- Repo: `Meliksahtokur/egesut-erp1`
- Auth: `~/.netrc` (otomatik)

## RPC Kuralı

```javascript
// ✅ DOĞRU
await rpc('hayvan_ekle', { p_kupe_no: '...', ... });

// ❌ YASAK — direkt REST
await db.from('hayvanlar').insert({ ... });
```

Tam RPC imzaları: `.claude/rpc-reference.md`

## Referans Haritası (on-demand)

| İhtiyaç | Dosya |
|---|---|
| RPC imzaları | `.claude/rpc-reference.md` |
| Domain kuralları | `.claude/domain-rules.md` |
| UI bileşenleri | `.claude/ui-map.md` |
| Credentials | `.claude/CREDENTIALS.md` |

## Migration Protokolü (ZORUNLU — sıra değiştirilemez)

### Adım 1 — Mevcut fonksiyonu sorgula (yazmadan önce)

```bash
ANON_KEY=$(grep -A5 'Anon key' .claude/CREDENTIALS.md | grep -oP 'eyJ[A-Za-z0-9._-]+')

# Fonksiyon DB'de var mı? İmzası ne?
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/FUNC_ADI" \
  -X POST \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}' | head -c 200
# {"code":"42883"} → yok, CREATE yaz
# Başka hata → var, DROP + CREATE yaz
```

### Adım 2 — Migration yaz

**KURAL: `CREATE OR REPLACE` YASAK — her zaman `DROP + CREATE`:**

```sql
-- ✅ DOĞRU
DROP FUNCTION IF EXISTS public.func_adi(uuid, text);
CREATE FUNCTION public.func_adi(...) ...

-- ❌ YANLIŞ — 42P13 hatasına yol açar
CREATE OR REPLACE FUNCTION public.func_adi(...) ...
```

Birden fazla overload olabilirse hepsini temizle:
```sql
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure FROM pg_proc
           WHERE proname = 'func_adi' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.oid::regprocedure; END LOOP;
END $$;
```

### Adım 3 — Push sonrası Actions kontrolü (ZORUNLU)

```bash
# Push'tan sonra bekle ve kontrol et
sleep 10
gh run list --limit 3

# Durumu izle (tamamlanana kadar)
gh run watch

# Hata varsa log'a bak
gh run view --log-failed
```

### Adım 4 — Fonksiyon doğrula

```bash
# Fonksiyon oluştu mu?
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/FUNC_ADI" \
  -X POST \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"yanlis_param": "test"}'
# {"code":"42883"} → HATA, fonksiyon hâlâ yok
# {"code":"42P13"} veya başka → ✅ fonksiyon var (parametre hatası beklenir)
```

**Actions başarısız olursa → Claude'a rapor ver, merge yapma.**

## Commit Formatı

```
fix: kısa açıklama
feat: kısa açıklama
chore: kısa açıklama
```
