# Saat Bazlı Tedavi Görev Sistemi (BUG-059 Çözümü)

**Tarih:** 2026-06-10
**Önem:** 🟡 Orta (operasyonel verimlilik + reçete değişimi reaktivitesi)
**Durum:** 📋 Spec yazıldı, review bekliyor
**Bildirim kaynağı:** Brainstorming oturumu (2026-06-10)
**İlgili bug:** BUG-059 (Tedavi günü alt seans — beklemede, tasarım gerekli)

## 🎯 Amaç

Bugün eczacı bir tedavi gününe **sadece 1 seans + 1 saat** girebiliyor. Gerçek hayatta bir hayvana günde 3-10 arası farklı saatlerde ilaç uygulanması gerekebiliyor. Bu spec:

1. **N seanslı tedavi günü** modelini tanımlar (her seans saat + ilaç + doz + yol)
2. **Reçete değişikliği reaktif yansır** — henüz açılmamış günler güncellenebilir
3. **Her seans ayrı done/iptal** — detaylı audit + "7/10 tamamlandı" rozeti
4. **Geriye uyumluluk korunur** — mevcut 4 aktif vaka etkilenmez

## 🧠 Brainstorming Çıktıları (7 Karar)

| # | Karar |
|---|---|
| 1 | **Gerçek zamanlı zincir mimarisi** — reçete değişikliği reaktif yansır |
| 2 | **Saat temelli, serbest N seans** — şablon YOK, max N (örn. 10) |
| 3 | **Her seans ayrı done** — detaylı audit + rozet |
| 4 | **Geriye uyumluluk: C** — yeni tablo + eski tek-seans davranışı korunur |
| 5 | **drug_admin tek doğruluk kaynağı** — görev sentetik |
| 6 | **A+B hibrit modal** — mevcut modal korunur + accordion seans listesi |
| 7 | **C** — plan görünümü sadece vaka modalında (görev sekmesi sade) |

## 🏗️ Mimari Genel Bakış

Mevcut sistem (tek seans, gün başına 1 satır):
```
treatment_days (1 satır/gün) → drug_administrations (N ilaç) → gorev_log (1 TEDAVI_GUN görevi)
```

Yeni sistem (N seans, geriye uyumluluk):
```
treatment_days (1 satır/gün, seans_sayisi=1..N)
├── treatment_day_uygulamalar (N seans, saat+ilaç+doz+yol)   ← YENİ
│   ├── drug_administrations (her seansın 1+ ilacı, FK)
│   ├── gorev_log (N TEDAVI_SEANS görevi, seans_admin_id bağlı)
│   └── stok_hareket (N ledger, seans referansı ile)
└── gorev_log (1 TEDAVI_GUN ana görev, lock kontrolü için)
```

**Uyumluluk katmanı:**
- `seans_sayisi=1` (eski davranış) → `treatment_day_uygulamalar` boş, eski akış çalışır
- `seans_sayisi>=2` (yeni davranış) → alt tablo dolu, zincir mantığı devrede
- Mevcut 4 vaka (140, 5, 7, 9) → hiçbiri etkilenmez

## 📊 Veri Akışı

### Yeni Tedavi Açılışı
```
Eczacı "5 gün × günde 3 seans: 08:00, 16:00, 24:00" girer
   ↓
add_treatment_day_with_sessions(case_id, "2026-06-11", [
  {planned_time:"08:00", stok_id:"ABC", dose:20, unit:"ml", route:"IM"},
  {planned_time:"16:00", stok_id:"DEF", dose:5,  unit:"ml", route:"IM"},
  {planned_time:"24:00", stok_id:"ABC", dose:20, unit:"ml", route:"IM"}
])
   ↓
INSERT treatment_days (day_no=1, seans_sayisi=3)
INSERT treatment_day_uygulamalar × 3 (planned_time 08/16/24)
INSERT drug_administrations × 3 (her seans için)
INSERT stok_hareket × 3 (otomatik trigger, ledger)
INSERT gorev_log × 4 (1 ana TEDAVI_GUN + 3 TEDAVI_SEANS)
INSERT islem_log (audit)
```

### Seans Tamamlama (drug_admin tek kaynak)
```
Eczacı dashboard'da "Gün 1 Seans 1 (08:00)" alt görevini tıklar
   ↓
seans_tamamla(seans_admin_id, false, "not...")
   ↓
UPDATE treatment_day_uygulamalar.uygulama_tamamlandi_at = now()
UPDATE gorev_log.tamamlandi = true (TEDAVI_SEANS)
   ↓
Tüm 3 seans done mi kontrol → evet ise
  UPDATE treatment_days.tamamlandi = true
  UPDATE gorev_log.tamamlandi = true (TEDAVI_GUN ana)
  INSERT islem_log (TEDAVI_GUN_TAMAM)
```

### Reçete Değişikliği
```
Eczacı 2. gün planını değiştirir: "08:00 + 16:00" → "08:00 + 20:00 + 24:00"
   ↓
recete_guncelle(case_id, [{day_no:2, sessions:[08:00, 20:00, 24:00]}, ...])
   ↓
Henüz açılmamış günleri bul (gün 2-5) → her biri için
  Mevcut treatment_day_uygulamalar varsa UPDATE (sıra_no + planned_time)
  Yoksa INSERT
  gorev_log TEDAVI_SEANS'leri güncelle (label + planned_time)
  drug_administrations'ı güncelle
  stok_hareket'i düzelt (eski ledger iptal + yeni ledger)
```

### Vaka Erken Kapatma
```
Eczacı "Tedaviyi durdur" der
   ↓
close_case_with_remaining(case_id, "tedavi yarıda kaldı")
   ↓
UPDATE cases.status = 'closed'
UPDATE treatment_days.tamamlandi = true (tüm günler, kalan seanslar dahil)
-- D-v3-1 duzeltme: kalan seanslar "yapildi" degil, "uygulanmadi" isaretlenir
UPDATE treatment_day_uygulamalar.uygulanmadi = true, iptal_nedeni = 'Vaka erken kapatildi' (kalan seanslar)
UPDATE drug_administrations.uygulanmadi = true (K5 FK uzerinden)
UPDATE stok_hareket.iptal = true (stok iade, drug_admins INSERT aninda dusmustu)
UPDATE gorev_log.tamamlandi = true (tüm görevler)
INSERT islem_log (CASE_CLOSED_EARLY)
```

## 🔌 RPC Sözleşmesi (özet)

| RPC | Sorumluluk | Yeni mi? |
|---|---|---|
| `add_treatment_day_with_sessions(case_id, date, sessions jsonb)` | Yeni gün + N seans + N görev | YENİ (eski add_treatment_day kalır) |
| `seans_tamamla(seans_admin_id, uygulanan, not)` | Tek seans done/iptal + zincirleme gün done | YENİ |
| `recete_guncelle(case_id, yeni_plan jsonb)` | Henüz açılmamış günlerin saat/sırasını değiştir | YENİ |
| `close_case_with_remaining(case_id, not)` | Kalan seansları otomatik tamamla + kapat | YENİ |
| `treatment_day_tamamla` (güncelleme) | Çok seanslı günlerde "tüm seanslar done" kontrolü | GÜNCELLE (geriye uyumlu) |
| `add_treatment_day` | Eski tek-seans davranışı (geriye uyumluluk) | KORUNUR |

## 🎨 UI Bölümleri

### 1. Tedavi Modal — A+B Hibrit (Soru 6)
- Mevcut modal korunur (vaka bilgisi, tanı, gün sayısı)
- İçine "⏰ Seans Listesi" accordion bölümü eklenir
- Her seans = 1 accordion satırı: saat + ilaç + doz + yol
- "+ Seans Ekle" butonu (max 10, validasyon)
- Mevcut "Planned Time" alanı → "1. seans saati"ne dönüşür (otomatik set)
- Eğer eczacı 1 seans bırakırsa → eski tek-seans davranışı (geriye uyumlu)

### 2. Görev Kartı (Dashboard) — Mevcut `renderTask` genişletmesi
- Mevcut subs render'ı korunur
- Her sub satırında **saat + ilaç adı** gösterilir
- Saati geçen sub'lar 🔴 kırmızı (grace period 3 saat)
- Bugünkü sub'lar ⏳
- Yarın sub'ları 💊
- `drugs` parametresi zaten var, ilaca tıklayınca detay modalı açılabilir (v2)

### 3. Vaka Modal — Plan Accordion (Soru 7)
- Görev sekmesi sade (sadece actionable işler)
- Vaka modalında "📅 Tedavi Planı" accordion
- 5 günlük plan accordion → her gün accordion → her seans listesi
- Kilitli günler kilit ikonu + tooltip
- Henüz açılmamış günler "🔒 Henüz açılmadı (1. gün done olunca açılır)"

### 4. Geciken/Bekleyen Seanslar (Soru 1 zincir)
- 🔴 Geciken: planned_time < now - 3h grace, henüz done değil
- ⏳ Bugün: planned_date = today, done değil
- 💊 Yarın: planned_date = tomorrow
- 📅 Açılacak: henüz açılmamış gün (sadece vaka modalında)

## ⚠️ Risk Analizi

| Risk | Olasılık | Şiddet | Azaltma |
|---|---|---|---|
| Mevcut 4 vakada geriye uyumsuzluk | Düşük | Yüksek | Geriye uyumluluk: seans_sayisi=1 ise eski akış; migration sırasında mevcut veri etkilenmez |
| Reçete değişikliği ortasında ilaç tutarsızlığı | Orta | Orta | recete_guncelle sadece tamamlanmamış günleri günceller; açılmış günler dokunulmaz |
| Stok ledger tutarsızlığı (recete_guncelle eski iade + yeni) | Orta | Orta | Eski stok_hareket.iptal=true + yeni INSERT atomik; trigger'lar sıralı çalışır |
| Çoklu eczacı aynı seansı done ederse | Çok düşük | Düşük | UPDATE WHERE uygulama_tamamlandi_at IS NULL atomic; row lock |
| Çok eski reçete (1. gün done, 2. gün açılmamış, 3-5. gün açılmamış) recete_guncelle | Orta | Düşük | 1. gün done ise sadece gün 2-5 güncellenebilir; gün 2 henüz açılmamışsa güncelle |
| Offline senkron (telefon çevrimdışı) | Düşük | Orta | IDB outbox + rpcOptimistic deseni korunur; seans_admin_id idempotent |
| Tetik zincirinde bug → sonsuz döngü | Çok düşük | Kritik | `tamamlandi=true` guard, parent_id ayrı, seans_admin_id farklı; döngü imkansız |
| DST (yaz saati uygulaması) → saat çakışması veya atlanmış saat | Orta | Düşük | `time` tipi DST'den etkilenmez; UI sadece saat:dakika gösterir; grace period saat farkı olmaz |
| Network yarım kalma (seans done isteği gitti, response gelmedi, retry) | Orta | Düşük | `seans_tamamla` SELECT FOR UPDATE + WHERE guard ile idempotent; ikinci çağrı `race=true` döner, UI tekrar denemez |
| Çoklu eczacı aynı anda recete_guncelle çalıştırır | Düşük | Orta | RPC transaction içinde; aynı case_id için 2 paralel çağrı → 2. çağrı `kısmi_acık` kontrolünde tutarsız seans sayısı görebilir, sonuç en son commit edileni yansıtır (last-write-wins, sonraki oturumda düzeltilebilir) |

## ✅ Definition of Done

- [ ] `treatment_day_uygulamalar` tablosu oluşturuldu, index'ler eklendi
- [ ] `treatment_days.seans_sayisi` kolonu eklendi
- [ ] `gorev_log.seans_admin_id` FK eklendi
- [ ] `add_treatment_day_with_sessions` RPC canlıda çalışıyor
- [ ] `seans_tamamla` RPC canlıda çalışıyor
- [ ] `recete_guncelle` RPC canlıda çalışıyor
- [ ] `close_case_with_remaining` RPC canlıda çalışiyor
- [ ] `treatment_day_tamamla` güncellendi (çok seanslı günlerde "tüm seanslar done" kontrolü)
- [ ] Tedavi modalı A+B hibrit (mevcut modal + accordion seans listesi)
- [ ] Görev kartı `renderTask` saat bazlı sub render
- [ ] Vaka modalı "📅 Tedavi Planı" accordion
- [ ] Dashboard 🔴 Geciken / ⏳ Bugün / 💊 Yarın seans rozetleri
- [ ] islem_log audit her RPC'de
- [ ] Geriye uyumluluk testi: mevcut 4 vaka (140, 5, 7, 9) etkilenmedi
- [ ] Senaryo A: 1 gün × 1 seans (eski davranış) — yeşil
- [ ] Senaryo B: 1 gün × 3 seans + hepsi done — yeşil
- [ ] Senaryo C: 5 gün × 3 seans + reçete ortasında değişim — yeşil
- [ ] Senaryo D: Vaka erken kapatma + kalan seanslar — yeşil
- [ ] Senaryo E: Uygulanmadi seans + stok iade — yeşil
- [ ] Senaryo F: Mevcut 4 vakaya dokunulmamasi (geriye uyumluluk) — yeşil
- [ ] Senaryo G: Race condition — ayni seansa 2 paralel done — yeşil
- [ ] Senaryo H: Recete degisikligi — kismen acilmis gun korunmali — yeşil
- [ ] Senaryo I: Recete tamamen yeni plana gecis — yeşil
- [ ] Senaryo J: Vaka erken kapatma + 1 seans acik — yeşil

## 📚 İlgili Dökümanlar

- BUG-059 (tedavi günü alt seans) — `.claude/knowledge/bugs.md`
- Mevcut tedavi sistemi — `supabase/migrations/99999999999999_ground_truth.sql` (treatment_days, drug_administrations, treatment_day_tamamla, add_treatment_day)
- Anyonik besleme sabah/akşam deseni — commit `5879977` (besleme_tamam)
- Tedavi Lock Fix + Görev Zinciri — `docs/superpowers/plans/2026-05-27-tedavi-plan-lock-ve-gorev-zinciri.md`
- Tedavi Done Sistemi — `docs/superpowers/plans/2026-05-25-tedavi-done-sistemi.md`
- Tedavi Gün UX Backend — `docs/superpowers/plans/2026-05-28-tedavi-gun-ux-backend.md`

## 🔧 DB Şeması (Migration SQL)

Asagidaki SQL 1 migration dosyasi olarak yazilacak:

```sql
-- 2026-06-10: BUG-059 — Saat bazli tedavi seans destegi
-- Yeni tablo: treatment_day_uygulamalar (seans bazli detay)
-- Eski tablolar: kolon ekleme (geriye uyumlu)

BEGIN;

-- 1. YENI TABLO: treatment_day_uygulamalar
CREATE TABLE IF NOT EXISTS public.treatment_day_uygulamalar (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id            uuid NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  case_id                     uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,

  -- SEANS BILGISI
  sira_no                     smallint NOT NULL CHECK (sira_no > 0),
  planned_time                time NOT NULL,
  planned_date                date NOT NULL,

  -- ILAC (drug_administrations ile birebir ayni semantik)
  stok_id                     text REFERENCES public.stok(id),
  drug_product_id             uuid REFERENCES public.drug_products(id),
  dose                        numeric NOT NULL CHECK (dose > 0),
  unit                        text NOT NULL,
  route                       text CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin')),

  -- DONE STATE (drug_admin tek dogruluk kaynagi)
  uygulama_tamamlandi_at      timestamptz,
  uygulayan                   text,
  uygulama_notu               text,

  -- UYARLILIK: yapilmadi olarak isaretlendi mi? (mevcut pattern)
  uygulanmadi                 boolean DEFAULT false,
  iptal_nedeni                text,

  -- STOK LEDGER REFERANSI (iptalde kullanilacak) — K1: stok_hareket.id text, FK text olmali
  stok_hareket_ref            text REFERENCES public.stok_hareket(id) ON DELETE SET NULL,

  -- AUDIT
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),

  UNIQUE(treatment_day_id, sira_no),
  -- O-v3-1 tasarim karari: Ayni saatte 2 farkli ilac PLANLANAMAZ (1 seans = 1 ilac).
  -- Farkli ilaclar icin pratik kullanim: 08:00 + 08:05 (5dk fark ile) girilir.
  -- Bu bilinçli karar: UX basitligi icin, hasta sahibi "08:00'da 2 ilac verilecek" bilgisi gorur.
  UNIQUE(treatment_day_id, planned_time)
);

CREATE INDEX IF NOT EXISTS tdu_day_id_idx       ON public.treatment_day_uygulamalar(treatment_day_id);
CREATE INDEX IF NOT EXISTS tdu_case_date_idx    ON public.treatment_day_uygulamalar(case_id, planned_date);
CREATE INDEX IF NOT EXISTS tdu_open_idx         ON public.treatment_day_uygulamalar(case_id) WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;
CREATE INDEX IF NOT EXISTS tdu_late_idx         ON public.treatment_day_uygulamalar(planned_date, planned_time) WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;

COMMENT ON TABLE public.treatment_day_uygulamalar IS 'Tedavi gunu alt seanslari. Saat + ilac + doz + yol, gercek zamanli zincir mimarisi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.sira_no IS 'Gun icinde 1, 2, 3... sirasi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.planned_time IS '08:00, 16:00, 24:00 gibi gercek saat';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulama_tamamlandi_at IS 'NULL = henuz yapilmadi, now() = yapildi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulanmadi IS 'true = "yapilmadi, stok iade"';

-- 2. MEVCUT treatment_days EK KOLON
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS seans_sayisi smallint DEFAULT 1;
COMMENT ON COLUMN public.treatment_days.seans_sayisi IS 'Bu gündeki planlanan seans sayisi (1 = eski davranis, N = yeni cok seans)';

-- 3. MEVCUT gorev_log EK KOLON
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
    REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.gorev_log.seans_admin_id IS 'Bu gorevi hangi seans tetikledi? NULL = gun seviyesi (eski davranis)';

ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS hedef_saat time;
COMMENT ON COLUMN public.gorev_log.hedef_saat IS 'Seansin planlanan saati (sadece TEDAVI_SEANS icin)';

-- K5: drug_administrations tablosuna seans baglantisi (yorum onerisi A)
-- Yeni cok-seansli akista her drug_admin hangi seansa ait olacak
-- Eski tek-seans akisinda NULL kalacak (geriye uyumlu)
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
    REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.drug_administrations.seans_admin_id IS 'Bu ilac hangi seansa ait? NULL = eski tek-seans akis (geriye uyumlu)';

CREATE INDEX IF NOT EXISTS da_seans_admin_id_idx
  ON public.drug_administrations(seans_admin_id) WHERE seans_admin_id IS NOT NULL;

COMMIT;
```

## ⚙️ RPC Tanimlari

### RPC 1: `add_treatment_day_with_sessions` (YENI)

```sql
-- ESKI: add_treatment_day(p_case_id, p_date, p_planned_time) → 1 gorev
-- YENI: add_treatment_day_with_sessions(p_case_id, p_date, p_sessions jsonb, p_existing_day_id uuid DEFAULT NULL)
--       p_sessions NULL gelirse ESKI davranis (geriye uyumlu)
--       p_existing_day_id NULL degilse: mevcut gunun alt verilerini SIL + yeniden olustur (K-NEW-1 C cozumu)
--         recete_guncelle tarafindan kullanilir; day_no hesaplanmaz, mevcut gun korunur

DROP FUNCTION IF EXISTS public.add_treatment_day_with_sessions(uuid, date, jsonb, uuid);
CREATE OR REPLACE FUNCTION public.add_treatment_day_with_sessions(
  p_case_id            uuid,
  p_date               date,
  p_sessions           jsonb DEFAULT NULL,
  p_existing_day_id    uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id         uuid;
  v_gorev_id       uuid;
  v_prev_gorev_id  uuid := NULL;
  v_day_no         int;
  v_case           record;
  v_gecmis         boolean;
  v_session        jsonb;
  v_seans_sayisi   smallint;
  v_admin_ids      uuid[] := '{}';
  v_admin_id       uuid;
  v_first_time     time;
  v_sira_no        smallint := 0;
  v_is_update      boolean := false;
BEGIN
  v_is_update := p_existing_day_id IS NOT NULL;

  -- Day no: yeni gun ise MAX+1, mevcut gun ise mevcut day_no
  IF v_is_update THEN
    SELECT day_no INTO v_day_no
    FROM public.treatment_days
    WHERE id = p_existing_day_id AND case_id = p_case_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Mevcut gun bulunamadi');
    END IF;
  ELSE
    SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
    FROM public.treatment_days WHERE case_id = p_case_id;
  END IF;

  -- Case
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadi');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapali vakaya gun eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  -- Onceki gun varsa parent_id
  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id AND td.day_no = v_day_no - 1 AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  -- YENI: seans sayisi
  v_seans_sayisi := CASE WHEN p_sessions IS NULL THEN 1 ELSE jsonb_array_length(p_sessions) END;
  v_first_time   := CASE 
    WHEN p_sessions IS NULL THEN NULL
    ELSE (p_sessions->0->>'planned_time')::time
  END;

  -- Day INSERT veya UPDATE (mevcut gun ise)
  IF v_is_update THEN
    -- ONCE eski alt verileri temizle (drug_admins, seanslar, gorevler, stok iade)
    -- Stok iade: drug_admins INSERT aninda stok dusmustu, geri al
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.treatment_day_id = p_existing_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;

    DELETE FROM public.drug_administrations WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.gorev_log
    WHERE gorev_tipi = 'TEDAVI_SEANS'
      AND (aciklama::jsonb->>'day_id')::uuid = p_existing_day_id;

    -- Mevcut gunu guncelle (seans_sayisi, planned_time degisebilir)
    UPDATE public.treatment_days
    SET planned_time = v_first_time,
        seans_sayisi = v_seans_sayisi,
        treatment_date = p_date
    WHERE id = p_existing_day_id
    RETURNING id INTO v_day_id;

    -- Mevcut TEDAVI_GUN gorevini yeniden ac (zaman/seans degisti)
    UPDATE public.gorev_log
    SET tamamlandi = false,
        tamamlanma_tarihi = NULL,
        aciklama = jsonb_build_object(
          'day_id', v_day_id, 'gun_no', v_day_no,
          'label', 'Gun ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
          'planned_time', COALESCE(v_first_time::text, ''),
          'seans_sayisi', v_seans_sayisi,
          'recete_guncellendi', true
        )::text
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND (aciklama::jsonb->>'day_id')::uuid = v_day_id
    RETURNING id INTO v_gorev_id;

    -- Eger TEDAVI_GUN gorevi yoksa (ilk kez tek seanslik acilip sonra recete degisimi)
    -- parent_id zinciri icin parent yok, NULL
  ELSE
    -- Yeni gun INSERT
    INSERT INTO public.treatment_days(
      id, case_id, day_no, treatment_date, tamamlandi,
      tamamlanma_tarihi, planned_time, seans_sayisi
    )
    VALUES (
      gen_random_uuid(), p_case_id, v_day_no, p_date,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_first_time, v_seans_sayisi
    )
    RETURNING id INTO v_day_id;
  END IF;

  -- Ana TEDAVI_GUN gorev (eski davranis, yeni gun ise olusur, mevcut gun ise yukarida UPDATE yapildi)
  IF NOT v_is_update THEN
    INSERT INTO public.gorev_log(
      id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
      tamamlandi, tamamlanma_tarihi, parent_id
    )
    VALUES (
      gen_random_uuid(), 'TEDAVI_GUN', v_case.animal_id, p_date,
      jsonb_build_object(
        'day_id', v_day_id, 'gun_no', v_day_no,
        'label', 'Gun ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
        'planned_time', COALESCE(v_first_time::text, ''),
        'seans_sayisi', v_seans_sayisi
      )::text,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_prev_gorev_id
    )
    RETURNING id INTO v_gorev_id;
  END IF;
  -- v_is_update durumunda v_gorev_id yukaridaki UPDATE RETURNING ile doldu

  -- YENI: N seans dongusu
  IF p_sessions IS NOT NULL THEN
    FOR v_session IN SELECT * FROM jsonb_array_elements(p_sessions)
    LOOP
      v_sira_no := v_sira_no + 1;

      -- treatment_day_uygulamalar INSERT
      INSERT INTO public.treatment_day_uygulamalar(
        treatment_day_id, case_id, sira_no, planned_time, planned_date,
        stok_id, drug_product_id, dose, unit, route
      )
      VALUES (
        v_day_id, p_case_id, v_sira_no,
        (v_session->>'planned_time')::time, p_date,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route'
      )
      RETURNING id INTO v_admin_id;

      v_admin_ids := array_append(v_admin_ids, v_admin_id);

      -- K2 + K3 DUZELTME: drug_admins INSERT + STOK INSERT ATOMIK
      -- Mevcut add_drug_administration RPC'sinin yaptigi sey (ground_truth L3271-3274)
      -- Stok trigger KALDIRILDI, stok dusumu RPC icinde yapilmali
      DECLARE
        v_drug_admin_id  uuid;
        v_stok_id        text;
        v_stok_hareket_id text;
      BEGIN
        -- drug_administrations INSERT
        INSERT INTO public.drug_administrations(
          treatment_day_id, stok_id, drug_product_id, dose, unit, route,
          seans_admin_id  -- K5: seans baglantisi
        )
        VALUES (
          v_day_id,
          v_session->>'stok_id',
          (v_session->>'drug_product_id')::uuid,
          (v_session->>'dose')::numeric,
          v_session->>'unit',
          v_session->>'route',
          v_admin_id  -- treatment_day_uygulamalar.id
        )
        RETURNING id INTO v_drug_admin_id;

        -- Stok INSERT (drug_admin_id ile birebir izlenebilir)
        v_stok_id := v_session->>'stok_id';
        IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
          INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
          VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
                  'drug_admin:' || v_drug_admin_id::text)
          RETURNING id INTO v_stok_hareket_id;

          -- Seans tablosuna stok referansini yaz (iptal icin gerekli)
          UPDATE public.treatment_day_uygulamalar
          SET stok_hareket_ref = v_stok_hareket_id
          WHERE id = v_admin_id;
        END IF;
      END;

      -- Her seans icin ayri TEDAVI_SEANS gorev
      INSERT INTO public.gorev_log(
        id, gorev_tipi, hayvan_id, hedef_tarih, hedef_saat,
        aciklama, tamamlandi, parent_id, seans_admin_id
      )
      VALUES (
        gen_random_uuid(), 'TEDAVI_SEANS', v_case.animal_id, p_date,
        (v_session->>'planned_time')::time,
        jsonb_build_object(
          'day_id', v_day_id, 'seans_no', v_sira_no,
          'planned_time', v_session->>'planned_time',
          'label', 'Gun ' || v_day_no || ' — Seans ' || v_sira_no || ' (' || (v_session->>'planned_time') || ')',
          'admin_id', v_admin_id
        )::text,
        false, v_gorev_id::text, v_admin_id  -- O3: parent_id text, explicit cast
      );
    END LOOP;
  END IF;

  -- islem_log audit (D-v3-2: update path'te RECETE_GUNCELLENDI tipi)
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    CASE WHEN v_is_update THEN 'RECETE_GUNCELLENDI' ELSE 'TEDAVI_GUN_EKLENDI' END,
    v_case.animal_id,
    v_day_id::text, 'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev_id::text)
      ) || COALESCE((
        SELECT jsonb_agg(jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', id::text))
        FROM unnest(v_admin_ids) AS id
      ), '[]'::jsonb),
      'seans_sayisi', v_seans_sayisi,
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object(
    'ok', true, 'day_id', v_day_id, 'day_no', v_day_no,
    'seans_sayisi', v_seans_sayisi, 'admin_ids', v_admin_ids,
    'gorev_id', v_gorev_id, 'gecmis', v_gecmis
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day_with_sessions TO anon, authenticated;
```

### RPC 2: `seans_tamamla` (YENI — tek seans done/iptal)

```sql
DROP FUNCTION IF EXISTS public.seans_tamamla(uuid, boolean, text);
CREATE OR REPLACE FUNCTION public.seans_tamamla(
  p_seans_admin_id  uuid,
  p_uygulanmadi      boolean DEFAULT false,
  p_not              text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_seans      public.treatment_day_uygulamalar%ROWTYPE;
  v_all_done   boolean;
  v_total      int;
  v_done       int;
  v_skip       int;
  v_tip        text;
BEGIN
  -- RACE CONDITION GUARD: SELECT FOR UPDATE ile satir kilitle
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar
  WHERE id = p_seans_admin_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadi');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans zaten kapatilmis', 'race', true);
  END IF;

  -- DONE veya UYGULANMADI (guard ile: sadece aciksa update et)
  IF p_uygulanmadi THEN
    -- Y2: seans tablosu + drug_admins + stok_hareket atomik senkron
    UPDATE public.treatment_day_uygulamalar
    SET uygulanmadi = true, iptal_nedeni = p_not, updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;

    -- drug_administrations tablosunu da senkronize et (Y2)
    UPDATE public.drug_administrations
    SET uygulanmadi = true
    WHERE seans_admin_id = p_seans_admin_id
      AND uygulanmadi IS DISTINCT FROM true;

    -- Stok iade (mevcut pattern: stok_hareket.iptal = true)
    IF v_seans.stok_hareket_ref IS NOT NULL THEN
      UPDATE public.stok_hareket SET iptal = true WHERE id = v_seans.stok_hareket_ref;
    END IF;
    v_tip := 'TEDAVI_SEANS_IPTAL';
  ELSE
    UPDATE public.treatment_day_uygulamalar
    SET uygulama_tamamlandi_at = now(), uygulama_notu = p_not, updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;
    -- GET DIAGNOSTICS ile gercek update sayisini kontrol et
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans baska biri tarafindan kapatilmis', 'race', true);
    END IF;
    v_tip := 'TEDAVI_SEANS_TAMAM';
  END IF;

  -- Ilgili gorev
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE seans_admin_id = p_seans_admin_id AND tamamlandi = false;

  -- Tum seanslar done mi?
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
  INTO v_total, v_done
  FROM public.treatment_day_uygulamalar
  WHERE treatment_day_id = v_seans.treatment_day_id;

  v_all_done := (v_total = v_done);

  IF v_all_done THEN
    UPDATE public.treatment_days
    SET tamamlandi = true, tamamlanma_tarihi = now()
    WHERE id = v_seans.treatment_day_id AND tamamlandi = false;

    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now()
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND tamamlandi = false
      AND (aciklama::jsonb->>'day_id')::uuid = v_seans.treatment_day_id;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, v_tip,
    (SELECT animal_id FROM public.cases WHERE id = v_seans.case_id),
    p_seans_admin_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', p_seans_admin_id::text)
      ),
      'gun_tamam', v_all_done
    )
  );

  RETURN jsonb_build_object('ok', true, 'seans_done', true, 'gun_tamam', v_all_done);
END;
$$;

GRANT EXECUTE ON FUNCTION public.seans_tamamla TO anon, authenticated;
```

### RPC 3: `recete_guncelle` (YENI — henuz acilmamis gunler)

```sql
DROP FUNCTION IF EXISTS public.recete_guncelle(uuid, jsonb);
CREATE OR REPLACE FUNCTION public.recete_guncelle(
  p_case_id     uuid,
  p_yeni_plan   jsonb  -- [{"day_no": 1, "sessions": [{...}]}, ...]
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_plan      jsonb;
  v_day_no        int;
  v_day_id        uuid;
  v_total_seans   int := 0;
  v_affected      jsonb := '[]'::jsonb;
  v_tamam         boolean;
  v_kismen_acik   boolean;
  -- D-v3-3: DRY refactor sonrasi v_session, v_admin_id, v_sira_no, v_first_time
  -- kaldirildi — RPC 1 (add_treatment_day_with_sessions) tarafindan yonetiliyor
BEGIN
  -- Case kontrol
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id AND status = 'active') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif vaka bulunamadi');
  END IF;

  FOR v_day_plan IN SELECT * FROM jsonb_array_elements(p_yeni_plan)
  LOOP
    v_day_no := (v_day_plan->>'day_no')::int;
    -- v_sira_no artik RPC 1 tarafindan yonetiliyor (DRY), kaldirildi

    -- Bu gun var mi?
    SELECT id, tamamlandi INTO v_day_id, v_tamam
    FROM public.treatment_days
    WHERE case_id = p_case_id AND day_no = v_day_no;

    -- KISMEN ACILMIS GUN DOKUNULMAZ (Soru 4-C + Guclendirme 4)
    -- Eger gun var ve EN AZ 1 seansi done ise, degistirilemez.
    IF v_day_id IS NOT NULL AND v_tamam = false THEN
      SELECT EXISTS(
        SELECT 1 FROM public.treatment_day_uygulamalar
        WHERE treatment_day_id = v_day_id
          AND (uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
      ) INTO v_kismen_acik;

      IF v_kismen_acik THEN
        -- Atla, bu gun kilitli
        CONTINUE;
      END IF;
    END IF;

    IF v_day_id IS NULL THEN
      -- YENI GUN EKLE (henuz yoksa) — K2/K3/Y1: add_treatment_day_with_sessions zaten dogru yapiyor
      PERFORM public.add_treatment_day_with_sessions(
        p_case_id,
        CURRENT_DATE + (v_day_no - 1),
        v_day_plan->'sessions'
      );
      v_total_seans := v_total_seans + jsonb_array_length(v_day_plan->'sessions');
    ELSIF v_tamam = false THEN
      -- TAMAMLANMAMIS + HENUZ HICBIR SEANS YAPILMAMIS GUN — RECETE DEGISIKLIGI
      -- K-NEW-1 (C cozumu): add_treatment_day_with_sessions'a p_existing_day_id ile devret
      -- RPC 1 mevcut gunu UPDATE eder: stok iade + eski verileri sil + yeni seanslari olustur
      -- Yeni treatment_days satiri OLUSMAZ, day_no KORUNUR, duplikat guneengel olur
      PERFORM public.add_treatment_day_with_sessions(
        p_case_id,
        CURRENT_DATE + (v_day_no - 1),
        v_day_plan->'sessions',
        v_day_id   -- p_existing_day_id: mevcut gunu gunceller, yeni gun OLUSMAZ
      );
      v_total_seans := v_total_seans + jsonb_array_length(v_day_plan->'sessions');
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'guncellenen_seans', v_total_seans);
END;
$$;

GRANT EXECUTE ON FUNCTION public.recete_guncelle TO anon, authenticated;
```

### RPC 4: `close_case_with_remaining` (YENI)

```sql
DROP FUNCTION IF EXISTS public.close_case_with_remaining(uuid, text);
CREATE OR REPLACE FUNCTION public.close_case_with_remaining(
  p_case_id  uuid,
  p_not      text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$  -- K4: RETURNS (RETURN degil)
DECLARE
  v_remaining_count int;
BEGIN
  -- Y3 + O2: Kalan seanslar gercekte YAPILMADI
  -- 1. Once stok iade et (drug_admins INSERT aninda dusmustu, geri al)
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_day_uygulamalar tdu
    ON tdu.id = da.seans_admin_id
  WHERE tdu.case_id = p_case_id
    AND tdu.uygulama_tamamlandi_at IS NULL
    AND tdu.uygulanmadi = false
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- 2. treatment_day_uygulamalar: uygulanmadi=true + iptal_nedeni (gercek durum)
  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = 'Vaka erken kapatildi' || COALESCE(': ' || p_not, ''),
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulama_tamamlandi_at IS NULL
    AND uygulanmadi = false;

  GET DIAGNOSTICS v_remaining_count = ROW_COUNT;

  -- 3. drug_administrations da senkron (Y2 pattern + Y-NEW-2 duzeltme)
  -- drug_admins'de uygulama_tamamlandi_at kolonu YOK, seans_admin_id FK uzerinden baglanir
  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_day_uygulamalar tdu
  WHERE tdu.id = da.seans_admin_id
    AND tdu.case_id = p_case_id
    AND tdu.uygulanmadi = true  -- adim 2'de zaten true yapildi
    AND da.uygulanmadi IS DISTINCT FROM true;

  -- 4. treatment_days tamamlandi isaretle
  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE case_id = p_case_id AND tamamlandi = false;

  -- 5. gorev_log kalan acik gorevler
  UPDATE public.gorev_log g
  SET tamamlandi = true, tamamlanma_tarihi = now()
  FROM public.treatment_days td
  WHERE td.case_id = p_case_id
    AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
    AND g.tamamlandi = false;

  -- 6. Case kapat
  UPDATE public.cases
  SET status = 'closed', closed_at = now()
  WHERE id = p_case_id;

  -- 7. Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'CASE_CLOSED_EARLY',
    (SELECT animal_id FROM public.cases WHERE id = p_case_id),
    p_case_id::text, 'cases',
    jsonb_build_object(
      'iptal_edilen_seans', v_remaining_count,
      'stok_iade_edildi', v_remaining_count > 0,
      'not', p_not
    )
  );

  RETURN jsonb_build_object('ok', true, 'iptal_edilen_seans', v_remaining_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_case_with_remaining TO anon, authenticated;
```

### RPC 5: `treatment_day_tamamla` (GUNCELLEME — geriye uyumlu)

```sql
-- Mevcut imza korunur, davranis seans_sayisi > 1 ise "tum seanslar done" kontrolu eklenir
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'  -- treatment_day_uygulamalar.id (yeni) veya drug_administrations.id (eski)
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day        public.treatment_days%ROWTYPE;
  v_seans_sayisi int;
  v_tamam       int;
  v_uygulanmadi int;
  v_onceki      boolean;
  v_admin_id    uuid;   -- Y-NEW-1: FOREACH dongusu icin
  v_stok_id     text;   -- Y-NEW-1: stok_id RETURNING icin
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tedavi gunu bulunamadi: %', p_day_id; END IF;
  -- IDEMPOTENT: seans_tamamla ile gunden bagimsiz done edilmis olabilir
  IF v_day.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'mesaj', 'Zaten tamamlanmis (idempotent)');
  END IF;

  -- Onceki gun tamamlanmali
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id AND day_no < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;
  IF v_onceki THEN RAISE EXCEPTION 'Onceki tedavi gunleri tamamlanmadan bu gun tamamlanamaz'; END IF;

  -- YENI: seans_sayisi > 0 ise "tum seanslar done" kontrolu
  SELECT v_day.seans_sayisi INTO v_seans_sayisi;
  IF v_seans_sayisi > 1 THEN
    SELECT
      COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL),
      COUNT(*) FILTER (WHERE uygulanmadi = true)
    INTO v_tamam, v_uygulanmadi
    FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id;

    IF (v_tamam + v_uygulanmadi) < v_seans_sayisi THEN
      RAISE EXCEPTION 'Tum seanslar tamamlanmadi (%/% done, % uygulanmadi)', 
        v_tamam, v_seans_sayisi, v_uygulanmadi;
    END IF;
  END IF;

  -- Uygulanmadi isaretlemeleri (O1: placeholder yerine gercek kod)
  -- p_uygulanmadi_ids: drug_administrations.id (eski) veya treatment_day_uygulamalar.id (yeni) olabilir
  -- Geriye uyumluluk: once drug_admins'de dene, bulamazsan seans tablosunda dene
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      -- 1. drug_administrations'ta ara (eski tek-seans akis)
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true
      RETURNING stok_id INTO v_stok_id;

      -- 2. Bulunamadiysa treatment_day_uygulamalar'da ara (yeni cok-seans akis)
      -- K5 uzerinden: seans'in bagli oldugu drug_admins'leri bul
      IF v_stok_id IS NULL THEN
        UPDATE public.drug_administrations
        SET uygulanmadi = true
        WHERE seans_admin_id = v_admin_id
          AND treatment_day_id = p_day_id
          AND uygulanmadi IS DISTINCT FROM true
        RETURNING stok_id INTO v_stok_id;

        -- Seans tablosunu da isaretle
        UPDATE public.treatment_day_uygulamalar
        SET uygulanmadi = true, iptal_nedeni = 'Ilac uygulanmadi (gun tamamla)'
        WHERE id = v_admin_id
          AND uygulama_tamamlandi_at IS NULL
          AND uygulanmadi = false;
      END IF;

      -- 3. Stok iade (Y-v3-1: stok_hareket_ref direkt kullan, varlik sebebiyle tutarli)
      -- v_admin_id = treatment_day_uygulamalar.id; o satirin stok_hareket_ref'i zaten kayitli
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE id = (
        SELECT stok_hareket_ref FROM public.treatment_day_uygulamalar WHERE id = v_admin_id
      )
        AND iptal = false
        AND id IS NOT NULL;

      -- Eski path fallback (geriye uyumluluk, seans_sayisi=1 vakalari):
      -- Eger stok_hareket_ref NULL ise (eski vakalarda tedavi_uygulamalar tablosu yoktu),
      -- drug_admins.notlar pattern'i ile dene
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE id IN (
        SELECT sh.id FROM public.stok_hareket sh
        JOIN public.drug_administrations da ON sh.notlar = 'drug_admin:' || da.id::text
        WHERE da.id = v_admin_id
          AND sh.iptal = false
      )
        AND NOT EXISTS (
          SELECT 1 FROM public.treatment_day_uygulamalar
          WHERE id = v_admin_id AND stok_hareket_ref IS NOT NULL
        );

      -- v_stok_id artik kullanilmiyor, kaldirildi
      v_stok_id := NULL;
    END LOOP;
  END IF;

  -- Gun done
  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now(), tamamlanma_notu = p_not
  WHERE id = p_day_id;

  -- Gorev log
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
    AND tamamlandi = false
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla TO anon, authenticated;
```

## 🧪 UI Davranisi (Sorular 6+7)

### 6a. Tedavi Modal — A+B Hibrit (Soru 6)

Mevcut modal korunur, icine yeni "⏰ Seans Listesi" accordion bolumu eklenir.

**Mevcut modal yapisinin korunan kismi:**
- Vaka bilgisi (hayvan, tani, hekim)
- Tedavi baslangic tarihi
- Toplam gun sayisi
- Mevcut "Planned Time" alani kaldirilir (cift kafa karisikligi olmasin)

**Yeni "⏰ Seans Listesi" accordion bolumu:**
- Baslangicta 1 bos seans satiri
- Her satir: saat input (time), ilac select (stok), doz input, yol select
- "➕ Seans Ekle" butonu (max 10)
- "🗑️" butonu ile seans sil
- Kaydet: `add_treatment_day_with_sessions(p_case_id, p_date, p_sessions)` cagirilir

**Eski tek seans geriye uyumluluk:**
- Eger sadece 1 seans varsa → `p_sessions NULL` gonderilir, eski akis (add_treatment_day) cagirilir
- 2+ seans → yeni RPC

### 6b. Gorev Karti (Dashboard) — Mevcut renderTask genisletmesi

Mevcut `renderTask` fonksiyonu (`js/ui.js:484`) zaten subs (alt gorevler) render edebiliyor. Yapilacak:

1. `subs` parametresi artik `treatment_day_uygulamalar`dan cagrilacak (her seans = 1 sub)
2. Her sub satirinda:
   - Saat (planned_time) — `🕐 08:00`
   - Ilac adi + doz + yol — `💊 PenStrep 20ml IM`
   - Done checkbox (mevcut toggleSub korunur, seans_admin_id ile)
3. Toplam rozet: `7/10 tamamlandi` (mevcut mantik)
4. Saati gecmis ve done olmamis sub'lar 🔴 kirmizi
5. Bugun sub'lari ⏳ (mevcut "soon" class'i)
6. Yarın sub'lari 💊 (mevcut "near" class'i)

**Onemli:** Mevcut `subs` mantigi `gorev_log.parent_id` ile cekiliyor. Yeni modelde:
- Parent = gorev_log (TEDAVI_GUN ana gorev)
- Sub'lar = `gorev_log` (TEDAVI_SEANS, parent_id = ana gorev) → toggleSub ayni mantikla calisir
- Tek fark: subs'in `aciklama` JSON'inda `seans_no`, `planned_time`, `admin_id` var (mevcut pattern zaten `JSON.parse` kullaniyor)

### 6c. Vaka Modal — Plan Accordion (Soru 7)

Gorev sekmesi sade (sadece actionable isler). Vaka modalina yeni "📅 Tedavi Plani" accordion bolumu eklenir.

- 5 gunluk plan accordion → her gun accordion → her seans listesi
- Kilitli gunler 🔒 ikonu + tooltip: "🔒 1. gun tamamlanmadan acilmaz"
- Henuz acilmamis gunler: "Henuz acilmadi (1. gun done olunca acilir)" gri
- Acilmis ama tamamlanmamis gunler: 🟡 sari, seanslar gorunur
- Tamamlanmis gunler: 🟢 yesil, saatler soluk
- Kalan seanslar: seans tiklaninca `seans_tamamla(admin_id, false, not)` cagirilir

### 6d. Dashboard Geciken/Bekleyen Rozetleri (Mevcut siniflar)

Mevcut `renderTask` zaten `late` / `soon` / `near` class'lari ile renklendirme yapiyor. Yeni modelde:
- 🔴 Geciken seans: `planned_time + 3h grace` < now, uygulama_tamamlandi_at IS NULL, uygulanmadi=false → `late` class
- ⏳ Bugun seansi: planned_date = today, done degil → `soon` class
- 💊 Yarin seansi: planned_date = tomorrow → `near` class
- 📅 Henuz acilmamis gun: sadece vaka modalinda, ayri rozet "🔒 1. gun bittikten sonra acilacak"

### 6e. Recete Degisikligi UI

Vaka modalindaki "📅 Tedavi Plani" accordion'da "✏️ Receteyi Duzenle" butonu:
- Modal acar: "Hangi gunu/gunleri duzenlemek istiyorsunuz?"
- Multi-select checkbox: gun 2, 3, 4, 5
- Acilmis ve tamamlanmis gunler secilemez (gri)
- "Secili gunleri yeniden planla" → saat + ilac tekrar girilir → `recete_guncelle` cagirilir
- Sonuc: "✅ 4 gun / 12 seans guncellendi, stok ledger'i duzeltildi"

## 🧪 Test Senaryolari

| Senaryo | Adimlar | Beklenen Sonuc |
|---|---|---|
| **A: 1 gun × 1 seans (eski davranis)** | Eski modal: 1 seans girilir → kaydet | `add_treatment_day` cagirilir (eski), `seans_sayisi=1`, `treatment_day_uygulamalar` bos, tek gorev |
| **B: 1 gun × 3 seans + hepsi done** | Yeni modal: 3 seans girilir → kaydet → 3 seans done isaretlenir | 3 `treatment_day_uygulamalar` + 3 TEDAVI_SEANS gorev, hepsi done, gun done, ana gorev done |
| **C: 5 gun × 3 seans + recete ortasinda degisim** | 5 gun × 3 seans planlanir → 1. gun done → 2. gun henuz acilmamis durumdayken recete_guncelle ile 2. gun plani degistirilir (2 seans → 3 seans) | Eski 2 seans iade + 3 yeni seans, gun 1 etkilenmez, gun 2 yeni planli, gun 3-5 etkilenmez |
| **D: Vaka erken kapatma** | 1. gun × 3 seans, 2'si done, 1'i acik → "Tedaviyi durdur" tiklanir | Kalan 1 seans `uygulanmadi=true` isaretlenir + ilgili `drug_admins.uygulanmadi=true` + `stok_hareket.iptal=true` (D1: Y3 ile tutarli), gun done, gorev done, vaka kapali, audit log |
| **E: 1 gun × 3 seans + uygulanmadi** | 1. seans done, 2. seans uygulanmadi isaretle (stok iade), 3. seans done | Uygulanmadi seans icin stok_hareket.iptal=true, diger 2 seans tamamlandi, gun done |
| **F: Mevcut 4 vakaya dokunulmamasi** | Mevcut 140, 5, 7, 9 vakalari acilir, "Tedavi Plani" accordion goruntulenir | Eski tek-seans davranisi (geriye uyumlu), `treatment_day_uygulamalar` bos, sadece `treatment_days` mevcut |
| **G: Race condition — ayni seansa 2 paralel done** | Tab acilir, 2 sekme ayni anda `seans_tamamla(admin_id, false)` cagirir | 1. cagri `ok=true`, 2. cagri `ok=false, race=true`. Sadece 1 satir done, stok 1 kez dusulmus |
| **H: Recete degisikligi — kismen acilmis gun** | 5 gun × 3 seans planlanir → 2. gun ilk seansi done edilir → recete_guncelle ile 2. gun plana yeni seans eklenmeye calisilir | 2. gun `kismen_acik=true` oldugu icin ATLANIR. 1, 3, 4, 5. gun guncellenir; 2. gun eski haliyle kalir |
| **I: Recete tamamen yeni plana gecis** | 5 gun × 3 seans planlanir → 1. gun done, 2. gun tamamen acilmis (3 seans acik, 0 done) → recete_guncelle ile 2. gun plana 4 seans eklenir | 2. gun eski 3 seans silinir, 4 yeni seans + 4 yeni gorev. Gun 1 etkilenmez, 3-5 degismez |
| **J: Vaka erken kapatma + 1 seans acik** | Vaka 5 gun × 3 seans, gun 1-2 done, gun 3 ilk seans done, 2. seans acik, 3. seans acik → "Tedaviyi durdur" tiklanir | Gun 3-5 kalan 5 acik seans `uygulanmadi=true` isaretlenir, ilgili `drug_admins.uygulanmadi=true` + `stok_hareket.iptal=true` (O2: stok drug_admins INSERT aninda dusmustu, geri alinmali), gun 3-5 tedavi_days tamamlandi, vaka kapali, audit log "5 seans erken kapatildi, stok iade edildi" |

## 🔄 Migration Plani

1. **Faz 0:** Spec review (Claude)
2. **Faz 1:** Schema migration (treatment_day_uygulamalar + ALTER 2 kolon)
3. **Faz 2:** RPC'ler (4 yeni + 1 guncelleme)
4. **Faz 3:** Ground truth sync
5. **Faz 4:** Deploy + canli dogrulama
6. **Faz 5:** UI implementasyonu (modal + renderTask + vaka modal accordion)
7. **Faz 6:** Test senaryolari A-F
8. **Faz 7:** Session update + handoff
