# Task-M2.5-002: Klinik Modülü — 3 Eksik RPC

**Durum:** done
**resolved_date:** 2026-05-02
**resolution_note:** All 3 clinical RPCs implemented (migrations 20260403000002/03/04). delete_treatment_day: treatment_day + drug_administrations deleted, stock ledger reversed. update_drug_administration: dose change triggers stock delta. link_drug_to_stock: drugs.stock_item_id updated. Frontend calls exist in ui.js:2270,2321 and forms.js:1083. Node --check passes for all files.
**Tarih:** 2026-04-03
**Branch:** fix/tech-debt
**Öncelik:** Yüksek
**Atanan:** MiniMax M2.5

---

## Bağlam

Klinik modülü UI'ı tamamen yazılmış. DB tarafında 3 RPC eksik — frontend çağırıyor ama fonksiyon yok, hata alıyor.

**Mevcut akış (çalışıyor):**
```
create_case → add_treatment_day → add_drug_administration → remove_drug_administration → close_case
```

**Eksik:**
- `delete_treatment_day` — ui.js çağırıyor, DB'de yok
- `update_drug_administration` — ui.js çağırıyor, DB'de yok
- `link_drug_to_stock` — ui.js çağırıyor, DB'de yok

---

## Mevcut Tablo Yapısı

```sql
cases              (id, animal_id, disease_id, start_date, status, notes)
treatment_days     (id, case_id, day_no, treatment_date)
drug_administrations (id, treatment_day_id, drug_id, dose, unit, route)
stok_hareket       (id, stok_id, miktar, tip, referans_id, ...)  -- ledger, immutable
drugs              (id, name, stock_item_id, default_unit, default_route)
```

**Kural:** `stok_hareket` asla silinmez. Silme/güncelleme işlemlerinde ters kayıt (negatif miktar) ekle.

---

## GÖREV 1 — `delete_treatment_day` RPC

**Frontend çağrısı (ui.js):**
```javascript
await rpc('delete_treatment_day', { p_day_id: dayId });
```

**İş mantığı:**
1. `treatment_day_id = p_day_id` olan tüm `drug_administrations` kayıtlarını bul
2. Her biri için `stok_hareket`'te ters kayıt ekle (kullanılan ilaçları stoka geri yaz)
3. `drug_administrations` kayıtlarını sil
4. `treatment_days` kaydını sil
5. `{"ok": true}` döndür

**Migration dosyası:** `supabase/migrations/20260403000002_delete_treatment_day.sql`

```sql
-- Migration: delete_treatment_day RPC
-- Etkiler: Yeni RPC — tedavi günü + ilaçları sil, stok ledger'ı tersle
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.delete_treatment_day(uuid);

CREATE OR REPLACE FUNCTION public.delete_treatment_day(
  p_day_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin record;
BEGIN
  -- Stok geri yaz (her ilaç uygulaması için ters hareket)
  FOR v_admin IN
    SELECT da.id, da.drug_id, da.dose, da.unit, d.stock_item_id
    FROM drug_administrations da
    JOIN drugs d ON d.id = da.drug_id
    WHERE da.treatment_day_id = p_day_id
      AND d.stock_item_id IS NOT NULL
  LOOP
    INSERT INTO stok_hareket (id, stok_id, miktar, tip, referans_id, notlar)
    VALUES (
      gen_random_uuid(),
      v_admin.stock_item_id::uuid,
      v_admin.dose,           -- pozitif = stoka geri dönüyor
      'iade',
      v_admin.id::text,
      'Tedavi günü silindi — ilaç iadesi'
    );
  END LOOP;

  -- Kayıtları sil (drug_administrations önce, sonra treatment_day)
  DELETE FROM drug_administrations WHERE treatment_day_id = p_day_id;
  DELETE FROM treatment_days WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;
```

**⚠️ Dikkat:** `stok_hareket` tablosunun kolon isimlerini önce kontrol et:
```bash
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/stok_hareket?limit=1" \
  -H "apikey: $(grep 'Anon key' .claude/CREDENTIALS.md | awk '{print $NF}')"
```
Kolon isimleri farklıysa SQL'i güncelle.

---

## GÖREV 2 — `update_drug_administration` RPC

**Frontend çağrısı (ui.js):**
```javascript
await rpc('update_drug_administration', {
  p_admin_id: adminId,
  p_dose: dose,
  p_unit: unit,
  p_route: route
});
```

**İş mantığı:**
1. Mevcut `drug_administrations` kaydını bul
2. Doz değiştiyse: fark kadar `stok_hareket` ekle (artış → negatif, azalış → pozitif)
3. Kaydı güncelle
4. `{"ok": true}` döndür

**Migration dosyası:** `supabase/migrations/20260403000003_update_drug_administration.sql`

```sql
-- Migration: update_drug_administration RPC
-- Etkiler: Yeni RPC — ilaç uygulaması güncelle, stok delta kaydet
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.update_drug_administration(uuid, numeric, text, text);

CREATE OR REPLACE FUNCTION public.update_drug_administration(
  p_admin_id  uuid,
  p_dose      numeric,
  p_unit      text,
  p_route     text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_delta  numeric;
BEGIN
  SELECT da.*, d.stock_item_id
  INTO v_admin
  FROM drug_administrations da
  JOIN drugs d ON d.id = da.drug_id
  WHERE da.id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kayıt bulunamadı');
  END IF;

  -- Doz farkı varsa stok hareketi ekle
  v_delta := p_dose - v_admin.dose;
  IF v_delta <> 0 AND v_admin.stock_item_id IS NOT NULL THEN
    INSERT INTO stok_hareket (id, stok_id, miktar, tip, referans_id, notlar)
    VALUES (
      gen_random_uuid(),
      v_admin.stock_item_id::uuid,
      ABS(v_delta),
      CASE WHEN v_delta > 0 THEN 'kullanim' ELSE 'iade' END,
      p_admin_id::text,
      'İlaç dozu güncellendi'
    );
  END IF;

  UPDATE drug_administrations
  SET dose = p_dose, unit = p_unit, route = p_route
  WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;
```

---

## GÖREV 3 — `link_drug_to_stock` RPC

**Frontend çağrısı (ui.js):**
```javascript
await rpc('link_drug_to_stock', { p_drug_id: drugId, p_stock_item_id: stockId });
```

**İş mantığı:** `drugs` tablosunda `stock_item_id` kolonunu güncelle. Basit update.

**Migration dosyası:** `supabase/migrations/20260403000004_link_drug_to_stock.sql`

```sql
-- Migration: link_drug_to_stock RPC
-- Etkiler: Yeni RPC — ilaçı stok kalemi ile ilişkilendir
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

CREATE OR REPLACE FUNCTION public.link_drug_to_stock(
  p_drug_id       uuid,
  p_stock_item_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE drugs SET stock_item_id = p_stock_item_id::uuid WHERE id = p_drug_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'İlaç bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;
```

---

## GÖREV 4 — Deploy

Her migration için ayrı commit:

```bash
# G1
git add supabase/migrations/20260403000002_delete_treatment_day.sql
git commit -m "feat: delete_treatment_day RPC eklendi"
git push origin fix/tech-debt

# G2
git add supabase/migrations/20260403000003_update_drug_administration.sql
git commit -m "feat: update_drug_administration RPC eklendi"
git push origin fix/tech-debt

# G3
git add supabase/migrations/20260403000004_link_drug_to_stock.sql
git commit -m "feat: link_drug_to_stock RPC eklendi"
git push origin fix/tech-debt
```

GitHub Actions migration'ları otomatik deploy eder.

---

## GÖREV 5 — Doğrulama

Her RPC push sonrası test et:

```bash
ANON=$(grep 'Anon key' .claude/CREDENTIALS.md | awk -F': ' '{print $2}' | tr -d '`')

# delete_treatment_day — var mı kontrol
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/delete_treatment_day" \
  -X POST -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"p_day_id": "00000000-0000-0000-0000-000000000000"}'
# Beklenen: {"ok":false,"error":"..."} — 42883 değil!

# update_drug_administration
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/update_drug_administration" \
  -X POST -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"p_admin_id": "00000000-0000-0000-0000-000000000000", "p_dose": 1, "p_unit": "ml", "p_route": "IV"}'

# link_drug_to_stock
curl -s "https://zqnexqbdfvbhlxzelzju.supabase.co/rest/v1/rpc/link_drug_to_stock" \
  -X POST -H "apikey: $ANON" -H "Content-Type: application/json" \
  -d '{"p_drug_id": "00000000-0000-0000-0000-000000000000", "p_stock_item_id": "test"}'
```

---

## Kabul Kriterleri

- [ ] `delete_treatment_day` migration oluşturuldu ve deploy edildi
- [ ] `update_drug_administration` migration oluşturuldu ve deploy edildi
- [ ] `link_drug_to_stock` migration oluşturuldu ve deploy edildi
- [ ] 3 RPC curl ile test edildi — 42883 hatası yok
- [ ] Her migration için ayrı commit atıldı
- [ ] `task-m2.5-002-done.md` yazıldı (curl çıktıları dahil)

---

## Kritik Uyarılar

- **`main`'e push etme** — sadece `fix/tech-debt`'e push
- **`stok_hareket` silme** — asla silme, ters kayıt ekle
- **Kolon isimlerini doğrula** — migration yazmadan önce mevcut tabloyu curl ile kontrol et
- **JS dosyalarına dokunma** — sadece migration SQL dosyaları
- **Credentials:** `.claude/CREDENTIALS.md` dosyasını oku
