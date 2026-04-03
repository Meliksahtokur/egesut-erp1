# Task-M2.5-001: tohumlama_sonuc_bos Duplicate RPC Temizliği

**Durum:** bekliyor
**Tarih:** 2026-04-03
**Branch:** fix/tech-debt
**Öncelik:** Kritik
**Atanan:** MiniMax M2.5

---

## Problem

`tohumlama_sonuc_bos` fonksiyonu Supabase'de **iki farklı imzayla** tanımlı:

```sql
-- Migration 0327 (eski)
tohumlama_sonuc_bos(p_tohumlama_id text)

-- Migration 0330 (yeni, daha iyi)
tohumlama_sonuc_bos(p_tohumlama_id text, p_notlar text DEFAULT NULL)
```

Frontend sadece `p_tohumlama_id` gönderiyor:
```javascript
// js/forms.js:663
await rpcOptimistic('tohumlama_sonuc_bos', { p_tohumlama_id: _curToh.id }, ...);
```

PostgreSQL hangisi çağrılacağını belirleyemiyor → **error 42883** (undefined_function).

---

## Çözüm

Yeni migration yaz — eski tek parametreli imzayı DROP et, yeni iki parametreli imza kalsın.

`p_notlar DEFAULT NULL` olduğu için frontend değişmeyecek — tek parametre göndermek yeterli.

---

## Yapılacaklar

### Adım 1 — Migration dosyası oluştur

Dosya adı: `supabase/migrations/20260403000001_fix_tohumlama_sonuc_bos_ambiguity.sql`

İçerik:
```sql
-- Migration: tohumlama_sonuc_bos ambiguity fix
-- Sorun: İki farklı imzalı fonksiyon tanımlı, PostgreSQL hangisini çağıracağını bilemiyor
-- Çözüm: Eski tek parametreli imzayı DROP et, yeni imza (DEFAULT NULL ile) kalsın
-- Geri alınabilir: evet — eski migration'dan tek param imzayı yeniden ekle

DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text);

-- Yeni imza zaten migration 0330'dan var, yeniden oluşturmaya gerek yok
-- Doğrulama:
-- SELECT proname, pronargs FROM pg_proc WHERE proname = 'tohumlama_sonuc_bos';
-- 1 satır dönmeli: pronargs = 2
```

### Adım 2 — Migration'ı uygula

```bash
npx supabase db push --project-ref zqnexqbdfvbhlxzelzju
```

Hata verirse Supabase CLI login gerekebilir:
```bash
npx supabase login
```

### Adım 3 — Doğrula

Migration sonrası DB'de tek imza kaldığını doğrula:
```bash
npx supabase db execute --project-ref zqnexqbdfvbhlxzelzju \
  "SELECT proname, pronargs, pg_get_function_arguments(oid) FROM pg_proc WHERE proname = 'tohumlama_sonuc_bos';"
```

Beklenen çıktı: **1 satır**, `pronargs = 2`

### Adım 4 — Commit et

```bash
git add supabase/migrations/20260403000001_fix_tohumlama_sonuc_bos_ambiguity.sql
git commit -m "fix: tohumlama_sonuc_bos duplicate imza temizlendi"
git push origin fix/tech-debt
```

---

## Kabul Kriterleri

- [ ] Migration dosyası oluşturuldu
- [ ] `DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text)` uygulandı
- [ ] DB'de tek imza kaldı (pronargs=2)
- [ ] Frontend değişmedi (test edildi)
- [ ] Commit + push yapıldı

---

## Kritik Uyarılar

- **Migration dosyasına dokunma:** `supabase/migrations/20260327*` ve `20260330*` — sadece yeni migration yaz
- **Frontend'e dokunma:** `js/forms.js` değişmeyecek
- **Migration adlandırma:** `YYYYMMDDHHMMSS_aciklama.sql` formatı — bugünün tarihi ile
- **`node --check` bu görevde gerekmez** — sadece SQL dosyası oluşturulacak

---

## Tamamlandığında

`task-m2.5-001-done.md` dosyası oluştur, şunu yaz:
- Ne yapıldı
- Migration çıktısı
- Doğrulama sonucu
