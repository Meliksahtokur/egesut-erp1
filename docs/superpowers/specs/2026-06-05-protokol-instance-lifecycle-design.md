# Protokol Instance + Lifecycle Cancel Guarantee

**Tarih:** 2026-06-05  
**Durum:** APPROVED ✅ — Tüm 12 adım uygulandı + canlıda test edildi (2026-06-06, commit fe4c926)  
**Scope:** DB schema + RPC güncelleme + filtrasyon fix  
**Backup notu:** Implement öncesi Supabase DB snapshot alınacak (tools-bank MCP ile)

---

## Problem

`gorev_log` hem task storage hem workflow state görevi görüyor — ama workflow tracking'i yarım yapıyor:

1. **Lifecycle cancel garantisi yok** — `cikis_yap` RPC DB'de mevcut değil; Ölü/Satıldı hayvanlar için pending task temizliği çalışmıyor
2. **Protokol durumu sorgulanamıyor** — "Bu doğum protokolü tamamlandı mı?" sorusu gorev_log aggregate'i gerektiriyor
3. **`kaynak` alanı enforce edilmiyor** — `GEBELIK_KONTROL`, `TOHUMLAMA_HAZIRLIK`, `VETERINER_KONTROL`, `PADOK_DEGISIM`, `TEDAVI_GUN` görevleri kaynak=NULL, hiçbir protokole bağlı değil
4. **Buzağı görevleri anne'nin ID'si altında** — `DOGUM-{anne_id}` kaynağı hem anne hem buzağı görevlerini grupluyor; buzağı çıkışı anne protokolünü etkiliyor

---

## Çözüm: Yaklaşım C (Tam Entegrasyon)

`protokol_instance` tablosu + `gorev_log.protokol_instance_id` UUID FK. Loose coupling değil, sıkı bağlantı. Her görev kendi protokolünü biliyor.

---

## Veri Modeli

### 1. `protokol_instance` tablosu

```sql
CREATE TABLE public.protokol_instance (
  id            uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
  hayvan_id     text    NOT NULL REFERENCES public.hayvanlar(id) ON DELETE CASCADE,
  tip           text    NOT NULL,    -- üst kategori: UREME | BAKIM | SAGLIK
  alttip        text    NOT NULL,    -- alt kategori: aşağıda listelendi
  kaynak_ref    text    NOT NULL,    -- gorev_log.kaynak ile eşleşen değer
  baslangic     date    NOT NULL,
  durum         text    NOT NULL DEFAULT 'aktif',  -- aktif | tamamlandi | iptal
  kapandi_at    timestamptz,
  kapandi_sebep text,               -- DOGUM | OLUM | SATIS | MANUEL | TAMAMLANDI
  created_at    timestamptz DEFAULT now(),
  CONSTRAINT protokol_instance_kaynak_unique UNIQUE (kaynak_ref)
);

CREATE INDEX idx_pi_hayvan_durum ON protokol_instance(hayvan_id, durum);
CREATE INDEX idx_pi_tip_alttip   ON protokol_instance(tip, alttip);
```

### 2. `gorev_log.protokol_instance_id` FK

```sql
ALTER TABLE public.gorev_log
  ADD COLUMN protokol_instance_id uuid
  REFERENCES public.protokol_instance(id) ON DELETE SET NULL;

CREATE INDEX idx_gorev_protokol ON gorev_log(protokol_instance_id)
  WHERE protokol_instance_id IS NOT NULL;
```

`ON DELETE SET NULL`: instance silinirse görevler korunur, FK NULL olur.

---

## Tip / Alttip Taxonomy

```
UREME
  ├─ KIZGINLIK     kizginlik_log event → instance (dashboard: 🩺 Muayene)
  ├─ TOHUMLAMA     TOHUMLAMA_HAZIRLIK + GEBELIK_KONTROL
  ├─ GEBELIK       ILERI_GEBE + ILERI_GEBE_ASI (Rota 1.doz, 2.doz düve)
  └─ DOGUM         ILAC + DIGER/kızgınlık-takip (anne protokolü)

BAKIM
  ├─ BUZAGI        BUZAGI_BAKIM (buzağının ayrı instance'ı)
  ├─ BESLEME       BESLEME (anyonik)
  ├─ PADOK         PADOK_DEGISIM
  └─ SUTTEN_KESME  SUTTEN_KESME

SAGLIK
  ├─ TEDAVI        TEDAVI_GUN
  ├─ ASI           ASI_RAPEL (genel sürü aşısı — ileri gebe aşısından ayrı)
  └─ MUAYENE       VETERINER_KONTROL
```

**Protokolsüz (NULL FK):** `kaynak='MANUEL'` — kullanıcı tarafından elle eklenen görevler

### gorev_tipi → Dashboard → protokol_instance eşleşmesi

| gorev_tipi | Dashboard filtresi | tip / alttip |
|---|---|---|
| ASI_RAPEL, ASI_HATIRLATMA | 💉 Aşı | SAGLIK / ASI |
| ILERI_GEBE_ASI | 💉 Aşı | UREME / GEBELIK |
| ILERI_GEBE (Ademin, E Vit) | 💊 Takviye | UREME / GEBELIK |
| ILAC (doğum protokolü) | 💊 Takviye | UREME / DOGUM |
| TOHUMLAMA_HAZIRLIK | 💊 Takviye | UREME / TOHUMLAMA |
| VETERINER_KONTROL | 🩺 Muayene | SAGLIK / MUAYENE |
| GEBELIK_KONTROL | 🩺 Muayene | UREME / TOHUMLAMA |
| KIZGINLIK görevi | 🩺 Muayene | UREME / KIZGINLIK |
| TEDAVI_GUN | 🚑 Tedavi | SAGLIK / TEDAVI |
| BUZAGI_BAKIM | 🐄 Bakım | BAKIM / BUZAGI |
| BESLEME | 🐄 Bakım | BAKIM / BESLEME |
| PADOK_DEGISIM | 🐄 Bakım | BAKIM / PADOK |
| SUTTEN_KESME | 🐄 Bakım | BAKIM / SUTTEN_KESME |
| MANUEL, MUAYENE, TEDAVI | 📋 Diğer | NULL |
| DIGER (kızgınlık takip) | 📋 Diğer | UREME / DOGUM |

---

## Lifecycle Cancel Guarantee

### `_protokol_kapat` helper (yeni internal function)

```sql
CREATE OR REPLACE FUNCTION public._protokol_kapat(
  p_kaynak_ref  text,
  p_sebep       text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
  SET iptal = true
  WHERE kaynak = p_kaynak_ref
    AND tamamlandi = false
    AND iptal = false;

  UPDATE public.protokol_instance
  SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = p_sebep
  WHERE kaynak_ref = p_kaynak_ref
    AND durum = 'aktif';
END;
$$;
```

### `cikis_yap` (sıfırdan — DB'de mevcut değil)

Frontend `submitCikis` parametreleri: `p_hayvan_id`, `p_cikis_tipi`, `p_cikis_tarihi`, `p_cikis_sebebi`, `p_satis_fiyati`

```sql
CREATE OR REPLACE FUNCTION public.cikis_yap(
  p_hayvan_id    text,
  p_cikis_tipi   text,           -- 'olum' | 'satis'
  p_cikis_tarihi date   DEFAULT (NOW() AT TIME ZONE 'Europe/Istanbul')::date,
  p_cikis_sebebi text   DEFAULT NULL,
  p_satis_fiyati numeric DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_durum_yeni text;
BEGIN
  IF p_cikis_tipi = 'olum' THEN v_durum_yeni := 'Ölü';
  ELSIF p_cikis_tipi = 'satis' THEN v_durum_yeni := 'Satıldı';
  ELSE RAISE EXCEPTION 'Geçersiz çıkış tipi: %', p_cikis_tipi;
  END IF;

  UPDATE public.hayvanlar
  SET durum        = v_durum_yeni,
      cikis_tipi   = p_cikis_tipi,
      cikis_tarihi = p_cikis_tarihi,
      cikis_sebebi = p_cikis_sebebi,
      satis_fiyati = CASE WHEN p_cikis_tipi = 'satis' THEN p_satis_fiyati ELSE satis_fiyati END
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif hayvan bulunamadı');
  END IF;

  -- TÜM pending görevleri iptal et (kaynak ne olursa)
  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false;

  -- TÜM aktif protokol instance'larını kapat
  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = upper(p_cikis_tipi)
  WHERE hayvan_id = p_hayvan_id
    AND durum = 'aktif';

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.cikis_yap(text,text,date,text,numeric) TO anon, authenticated;
```

---

## Güncellenecek RPC'ler

Her RPC artık `protokol_instance` satırı açıp `protokol_instance_id`'yi görevlere yazacak.

### 1. `dogum_kaydet` — İKİ instance

```sql
-- İçinde:
-- Instance 1: Anne protokolü
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (p_anne_id, 'UREME', 'DOGUM', 'DOGUM-' || p_anne_id, p_tarih)
RETURNING id INTO v_anne_inst_id;

-- Instance 2: Buzağı bakım protokolü  
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (v_buzagi_id, 'BAKIM', 'BUZAGI', 'BUZAGI-' || v_buzagi_id, p_tarih)
RETURNING id INTO v_buzagi_inst_id;

-- Tüm anne görevlerinde: protokol_instance_id = v_anne_inst_id
-- Tüm buzağı görevlerinde: protokol_instance_id = v_buzagi_inst_id
```

**Kaynak değişimi:** Buzağı görevleri artık `kaynak='DOGUM-{anne_id}'` değil, `kaynak='BUZAGI-{buzagi_id}'` kullanacak.

### 2. `tohumlama_kaydet` — UREME/TOHUMLAMA instance

```sql
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (p_hayvan_id, 'UREME', 'TOHUMLAMA', 'TOH-' || v_toh_id::text, p_tarih)
RETURNING id INTO v_inst_id;

-- GEBELIK_KONTROL + TOHUMLAMA_HAZIRLIK görevlerine: protokol_instance_id = v_inst_id
-- kaynak = 'TOH-' || v_toh_id::text
```

### 3. `tohumlama_tekrar_kaydet` — Mevcut instance güncelle

Tekrar tohumlamada mevcut `TOH-{id}` instance'ı `aktif` kalmaya devam eder, eski gebelik kontrol görevleri iptal edilir (zaten yapılıyor), yeni görevler aynı instance'a bağlanır.

### 4. `fn_gebe_gorev_yarat` trigger + `ileri_gebe_gorev_kontrol` RPC — UREME/GEBELIK instance

```sql
-- tohumlama sonuc='Gebe' olduğunda (kaynak_ref hayvan bazlı):
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (NEW.hayvan_id, 'UREME', 'GEBELIK', 'ILERI_GEBE-' || NEW.hayvan_id, CURRENT_DATE)
ON CONFLICT (kaynak_ref) DO UPDATE SET durum='aktif'  -- yeniden gebelik durumunda reset
RETURNING id INTO v_inst_id;

-- ILERI_GEBE + ILERI_GEBE_ASI görevlerine: protokol_instance_id = v_inst_id
```

**Önemli:** `ON CONFLICT DO NOTHING RETURNING` standart SQL'de çalışmaz; `DO UPDATE SET durum='aktif'` veya conflict sonrası ayrı `SELECT id INTO v_inst_id FROM protokol_instance WHERE kaynak_ref=...` kullanılmalı — implement sırasında netleştirilecek.

**Not:** Mevcut `kaynak='ILERI_GEBE'` tüm hayvanlar için aynı string → `'ILERI_GEBE-' || hayvan_id` olarak değiştirilmeli. Migration 4'te backfill ile eski satırlar güncellenir.

### 5. `besleme_gorev_olustur` — BAKIM/BESLEME instance

```sql
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (p_hayvan_id, 'BAKIM', 'BESLEME', 'BESLEME-' || p_hayvan_id, p_baslangic)
ON CONFLICT (kaynak_ref) DO NOTHING
RETURNING id INTO v_inst_id;
```

### 6. `tedavi_baslat` / case açma — SAGLIK/TEDAVI instance

```sql
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (p_hayvan_id, 'SAGLIK', 'TEDAVI', 'TEDAVI-' || v_vaka_id::text, p_tarih)
RETURNING id INTO v_inst_id;
```

### 7. ASI_RAPEL oluşturma — SAGLIK/ASI instance

```sql
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (p_hayvan_id, 'SAGLIK', 'ASI', 'ASI_RAPEL-' || p_hayvan_id || '-' || p_tarih::text, p_tarih);
```

**Not:** Aşı rapel oluşturma mekanizması (`vaccination_schedule` tablosu + ilgili RPC) implement sırasında incelenecek. Aynı hayvana aynı tarihte iki rapel çakışmaması için `kaynak_ref`'e tarih eklendi.

### 8. PADOK_DEGISIM — BAKIM/PADOK instance

```sql
INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic)
VALUES (p_hayvan_id, 'BAKIM', 'PADOK', 'PADOK-' || p_hayvan_id || '-' || p_tarih::text, p_tarih);
```

**Not:** Padok değişimi mekanizması (frontend direkt REST mi, RPC mi?) implement sırasında incelenecek. DB'de `hayvan_padok_degistir` RPC bulunamadı.

---

## Backfill Migration

Mevcut 400+ gorev_log satırı için:

### Adım 1: `protokol_instance` backfill — kaynak'tan türet

```sql
-- DOGUM protokolleri
INSERT INTO protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
SELECT DISTINCT
  gl.hayvan_id,
  'UREME', 'DOGUM',
  gl.kaynak,
  MIN(gl.hedef_tarih) OVER (PARTITION BY gl.kaynak),
  CASE
    WHEN EXISTS (SELECT 1 FROM gorev_log g2
      WHERE g2.kaynak = gl.kaynak AND g2.tamamlandi=false AND g2.iptal=false)
    THEN 'aktif' ELSE 'tamamlandi'
  END
FROM gorev_log gl
WHERE gl.kaynak LIKE 'DOGUM-%' AND gl.hayvan_id IS NOT NULL
ON CONFLICT (kaynak_ref) DO NOTHING;

-- BUZAGI (mevcut DOGUM-* altındaki buzağı görevleri kaynak değiştirilecek)
-- Bu migration'da kaynak='BUZAGI-{buzagi_id}' olarak güncellenir

-- ILERI_GEBE → tek kaynak, hayvan başına ayrılmalı
-- Backfill sırasında 'ILERI_GEBE' → 'ILERI_GEBE-{hayvan_id}' dönüşümü

-- BESLEME_OTOMATIK → 'BESLEME-{hayvan_id}'
-- ASI_RAPEL → 'ASI_RAPEL-{hayvan_id}'
-- TEDAVI-{id} → olduğu gibi
```

### Adım 2: `gorev_log.protokol_instance_id` backfill

```sql
UPDATE gorev_log gl
SET protokol_instance_id = pi.id
FROM protokol_instance pi
WHERE gl.kaynak = pi.kaynak_ref
  AND gl.protokol_instance_id IS NULL;
```

### NULL kaynak görevler (VETERINER_KONTROL, GEBELIK_KONTROL, TOHUMLAMA_HAZIRLIK vb.)

Aktif olanlar için hayvan + tarih eşleşmesinden kaynak türetilmeye çalışılır:
- `GEBELIK_KONTROL` → ilgili hayvanın aktif `UREME/TOHUMLAMA` instance'ına bağla
- `TOHUMLAMA_HAZIRLIK` → aynı
- `VETERINER_KONTROL` → SAGLIK/MUAYENE instance oluştur, her hayvan için ayrı
- `TEDAVI_GUN` → `SAGLIK/TEDAVI` instance'ına bağla
- `PADOK_DEGISIM` → BAKIM/PADOK instance oluştur

---

## Dashboard Filtrasyon Fix

`js/ui.js` satır 48-55 — `_katTipMap` güncellemesi:

```javascript
// ÖNCE:
const _katTipMap={
  asi:['ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE'],
  muayene:['MUAYENE'],
  tedavi:['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN'],
  bakim:['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME'],
  diger:null
};

// SONRA:
const _katTipMap={
  asi:    ['ILERI_GEBE_ASI','ASI_HATIRLATMA','ASI_RAPEL'],
  vitamin:['ILERI_GEBE','TOHUMLAMA_HAZIRLIK','ILAC'],
  muayene:['MUAYENE','GEBELIK_KONTROL','VETERINER_KONTROL'],
  tedavi: ['TEDAVI','ILAC_UYGULAMA','TEDAVI_GUN'],
  bakim:  ['SUTTEN_KESME','PADOK_DEGISIM','DOGUM_TAKIP','BESLEME','BUZAGI_BAKIM'],
  diger:  null
};
```

**Etki:** `GEBELIK_KONTROL` + `VETERINER_KONTROL` 📋 Diğer'den 🩺 Muayene'ye; `TOHUMLAMA_HAZIRLIK` + `ILAC` 📋 Diğer'den 💊 Takviye'ye; `BUZAGI_BAKIM` 📋 Diğer'den 🐄 Bakım'a geçer.

---

## Implement Sırası

> Implement öncesi: Supabase DB snapshot (tools-bank `supabase_migrate` ile `pg_dump` veya manual backup)

1. ✅ **Migration 1** — `protokol_instance` tablosu + index → `20260605000003_protokol_instance_schema.sql`
2. ✅ **Migration 2** — `gorev_log.protokol_instance_id` FK kolonu → `20260605000003_protokol_instance_schema.sql`
3. ✅ **Migration 3** — `_protokol_kapat` helper + `cikis_yap` RPC (sıfırdan) → `20260605000004_cikis_yap_rpc.sql`
4. ✅ **Migration 4** — Kaynak string'leri standardize et (`ILERI_GEBE` → `ILERI_GEBE-{id}`, `BESLEME_OTOMATIK` → `BESLEME-{id}` vb.) → `20260605000005_kaynak_backfill.sql`
5. ✅ **Migration 5** — Backfill: `protokol_instance` satırlarını mevcut `kaynak`'tan türet → `20260605000005_kaynak_backfill.sql`
6. ✅ **Migration 6** — Backfill: `gorev_log.protokol_instance_id` doldur → `20260605000005_kaynak_backfill.sql`
7. ✅ **Migration 7** — `dogum_kaydet` güncelle (2 instance, buzağı kaynak değişimi) → `20260605000006_dogum_kaydet_update.sql`
8. ✅ **Migration 8** — `tohumlama_kaydet` güncelle (TOHUMLAMA instance) → `20260605000007_tohumlama_kaydet_update.sql`
9. ✅ **Migration 9** — `fn_gebe_gorev_yarat` trigger + `ileri_gebe_gorev_kontrol` güncelle (GEBELIK instance) → `20260605000008_gebe_trigger_update.sql`
10. ✅ **Migration 10** — `gebelik_protokol_kontrol` + `besleme_tamam` güncelle (BAKIM/BESLEME instance) → `20260605000009_besleme_protokol_instance.sql`
11. ✅ **Migration 11** — `ground_truth.sql` güncellemesi (tüm yeni fonksiyonlar eklendi)
12. ✅ **Frontend** — `_katTipMap` güncellendi + `api.js` TABLES'a `protokol_instance` eklendi

---

## Risk ve Mitigasyon

| Risk | Önlem |
|---|---|
| Backfill sırasında kaynak eşleşmesi tutarsız | Conservative: şüpheliyse NULL bırak, sonra manuel fix |
| `ILERI_GEBE` → `ILERI_GEBE-{id}` rename'i trigger'da tutarsızlık | Önce trigger güncelle, sonra backfill |
| `dogum_kaydet` buzağı kaynak değişimi eski veriyle çelişirse | Backfill migration 4'ten önce çalıştırılmaz |
| `cikis_yap` mevcut `submitCikis` param isimleriyle eşleşmeli | Spec'te param isimleri frontend ile uyumlu yazıldı |

---

## Açık Kalan (Sonraki Adım)

- **`protokol_instance.durum` otomatik güncellemesi:** Tüm görevler tamamlandığında instance `tamamlandi`'ya geçmeli. Trigger veya RPC sonunda kontrol — bu spec'e dahil değil, ayrı iş.
- **Dashboard protokol durumu görünümü:** Hayvan kartında "Aktif protokoller" göstergesi — bu spec'e dahil değil.
- **`kizginlik_log` → UREME/KIZGINLIK instance:** Kızgınlık kaydedilince instance açılıp tohumlama ile bağlantı kurulması — ayrı iş.
