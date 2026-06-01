# Tohumlama Ek Uygulama — Stok Entegrasyonu — Plan C

> Topoloji: Hierarchical | 4 task | 0 paralel blok
> Model: deepseek-chat (flash)
> Soru varsa devam etmeden önce sor. DB değişikliklerinde onay bekle.

**Hedef:** Tohumlama sırasında GnRH, PG, vitamin vb. ek uygulamalar stok entegrasyonlu olarak kaydedilir. Her item için `stok_hareket` oluşturulur. Bilgiler `tohumlama.ek_uygulamalar` jsonb kolonuna yazılır.

**Etkilenen dosyalar:**
- Yeni migration: `supabase/migrations/20260526000003_ek_uygulama_stok.sql`
- `supabase/migrations/99999999999999_ground_truth.sql`

**Bağımlılık:** Plan-B tamamlanmış olmalı (tohumlama.case_id mevcut).

---

## Başlamadan Önce

Sırayla oku:
```bash
# 1. tohumlama_kaydet RPC'nin son hali (Plan-B sonrası ground_truth'ta)
grep -n "CREATE FUNCTION.*tohumlama_kaydet\|CREATE.*FUNCTION.*tohumlama_kaydet" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql
# Satır numarasını bul → RPC'nin tamamını oku (yaklaşık 120 satır)

# 2. stok_hareket tablosu yapısı
grep -n "CREATE TABLE.*stok_hareket\|ALTER TABLE.*stok_hareket" \
  /root/egesut-erp1/supabase/migrations/99999999999999_ground_truth.sql | head -5

# 3. stok tablosu (kategori değerleri)
supabase_query({table: "stok", select: "kategori", limit: 20})
# Hangi kategoriler var? GnRH/vitamin hangi kategoride?

# 4. Mevcut stok_hareket örneği (tohumlama_kaydet içindeki)
# tohumlama_kaydet'te zaten sperma stok düşümü var — aynı pattern kullanılacak
```

Sonra planı oku, net olmayan şey varsa sor.

---

## Task 1 — tohumlama.ek_uygulamalar Kolonu

**Uygulama:**
```sql
ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS ek_uygulamalar jsonb DEFAULT '[]'::jsonb;
```

`supabase_migrate({sql: "ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS ek_uygulamalar jsonb DEFAULT '[]'::jsonb;"})` ile deploy et.

**Doğrulama:**
```
supabase_query({table: "tohumlama", select: "id,ek_uygulamalar", limit: 1})
```
→ `ek_uygulamalar: []` dönmeli

---

## Task 2 — tohumlama_kaydet RPC Güncelle

**Okuma:**
`tohumlama_kaydet` RPC'nin tamamını oku (Başlamadan Önce'de bulduğun satır numarasından ~120 satır).

**Uygulama:**

RPC imzasına `p_ek_uygulamalar jsonb DEFAULT '[]'` parametresi ekle. INSERT bloğuna `ek_uygulamalar` kolonu ekle. INSERT'ten sonra stok düşüm döngüsü ekle:

```sql
-- tohumlama_kaydet RPC'ye eklenecek yeni parametre:
-- p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb
-- Örnek item: {"stok_id":"uuid","stok_ad":"GnRH Receptal","tur":"GnRH","doz":2,"birim":"ml","yol":"IM"}

-- DECLARE bloğuna ekle:
--   v_ek      jsonb;
--   v_ek_stok uuid;

-- tohumlama INSERT'ine ek_uygulamalar kolonu ekle:
INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar)
VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme, p_ek_uygulamalar);

-- Sperma stok düşümünden SONRA, ek uygulama stok döngüsü:
IF jsonb_array_length(p_ek_uygulamalar) > 0 THEN
  FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
    IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
      v_ek_stok := (v_ek->>'stok_id')::uuid;
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
      VALUES (
        v_ek_stok,
        'Tohumlama',
        COALESCE((v_ek->>'doz')::numeric, 1),
        'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
        false
      );
    END IF;
  END LOOP;
END IF;
```

Tam RPC'yi yeniden yaz (DROP + CREATE OR REPLACE). `supabase_migrate` ile deploy et.

**Doğrulama:**
Test için stoksuz (stok_id: "") item ile çağır — stok_hareket INSERT atlamalı, tohumlama kaydedilmeli:
```
supabase_rpc({
  function_name: "tohumlama_kaydet",
  params: '{"p_hayvan_id":"...","p_tarih":"2026-05-26","p_sperma":"TEST","p_ek_uygulamalar":[{"stok_id":"","tur":"GnRH","doz":2,"birim":"ml"}]}'
})
```
→ `{"ok": true, ...}` dönmeli

---

## Task 3 — api.js Invalidation Tablosu

**Okuma:**
```bash
grep -n "tohumlama_kaydet" /root/egesut-erp1/js/api.js
```

**Uygulama:**

`api.js`'te `tohumlama_kaydet` invalidation listesine `stok` ve `stok_hareket` ekle (eğer yoksa):

```js
tohumlama_kaydet: ['tohumlama', 'gorev_log', 'hayvanlar', 'stok', 'stok_hareket'],
```

**Syntax kontrolü:**
```bash
node --check /root/egesut-erp1/js/api.js
```

---

## Task 4 — ground_truth.sql Güncelle + Commit

**Uygulama:**

`ground_truth.sql`'de:
- `tohumlama` tablo tanımından sonra `ALTER TABLE` ile `ek_uygulamalar` satırını ekle
- `tohumlama_kaydet` fonksiyonunu yeni versiyon ile değiştir

Migration dosyası: `supabase/migrations/20260526000003_ek_uygulama_stok.sql` — Task 1 + Task 2'deki SQL bloklarını yaz.

**Commit:**
```bash
git add supabase/migrations/20260526000003_ek_uygulama_stok.sql \
        supabase/migrations/99999999999999_ground_truth.sql \
        js/api.js
git commit -m "feat(db): tohumlama ek uygulama stok entegrasyonu — ek_uygulamalar jsonb, stok_hareket döngüsü"
git push origin main
```

---

## Son Task — Pattern Kayıt

```
memory_add({
  content: "Plan-C tamamlandı: tohumlama.ek_uygulamalar jsonb kolonu eklendi, tohumlama_kaydet RPC jsonb array döngüsüyle stok_hareket oluşturuyor. Her item: {stok_id, tur, doz, birim, yol}. stok_id boşsa stok düşümü atlanır.",
  category: "code_change",
  priority: "medium",
  tags: "tohumlama,stok,ek_uygulama,rpc,gnrh"
})
```
