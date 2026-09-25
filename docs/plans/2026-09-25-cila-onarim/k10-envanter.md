# K10 — Demo'da hedefi geçmiş açık ovsync görevleri: envanter + erteleme talimatı (exec ajanına)

> ROL: R-ARAŞTIRMA (salt-okunur kulvar) · 2026-09-25 · Kalem: **K10 / talimat 2b**
> Tüm ölçümler demo psql (ref `vtzqjmazsvurxdeondmi` doğrulandı), yalnız SELECT, 2026-09-25 ~09:30 +03.
> Bu dosya ENVANTER + TALİMAT'tır; uygulama I-DB kulvarındadır (tip kilidi engeli → K11'e bağlanır).

**Kabul ölçütü hatırlatma (zarf K10):** "demo: hedef tarihi geçmiş açık ovsync görevi 0 **ya da
engel gerekçeli raporlandı**". Bu envanter: gecikmiş açık ovsync görevi = **16**; mevcut
mekanizmaların **hiçbiri** bunları kural-yoluyla erteleyemiyor (§3) → engel gerekçesi + exec
talimatı (§4) + K11 bağlantısı (§5).

---

## 1. Envanter (2026-09-25 ölçümü)

### 1.1 Gecikmiş açık ovsync görevleri — 16 görev / 8 vaka

Sahibin ekran dökümündeki "8 gecikmiş Buserin seansı"nın DB karşılığı: **8 aktif Ovsync vakası**,
her birinin **Gün 1** tedavisi 2026-09-24 10:00 hedefli ve uygulanmamış (seans
`uygulama_tamamlandi_at` NULL ×8 [OBSERVED]). Her gün bir `TEDAVI_GUN` (üst) + bir `TEDAVI_SEANS`
(alt) görevi üretir → 8 × 2 = **16 gecikmiş açık görev**.

| Küpe | case_id | Gün 1 (gecikmiş) TEDAVI_GUN id | TEDAVI_SEANS id | TAI görevi (TOHUMLAMA_PLANLI, açık) |
|---|---|---|---|---|
| 28 | `03b10e2a-1800-43b0-864d-c392329727b3` | `5c119a67-e9ac-474d-ac9f-6115f7ccc9cd` | `698cccf6-e20c-4219-86d2-dad3b775cb6b` | `267a8a03` (10-04) |
| 31 | `aa786467-806a-4e38-af64-41ffb1cf77c3` | `e1e1ead7-5519-4606-976b-2f98642c7bc4` | `0c5796b8-9363-4055-9617-b565cc9fa663` | `1db0c4d0` (10-04) |
| 122 | `25a638aa-1fa3-4925-9c6a-4362d6ff8e1b` | `8e3a6066-ac4b-41a7-99c3-e36268d6172a` | `ef4f88d0-66d6-40a6-9ce9-04d9eaca1271` | `71a58da1` (10-04) |
| 144 | `bf9644c7-7f1c-411b-8c1c-52bfa6a99c97` | `50fe4d41-bdf4-4bec-ab13-0141f2e42ff0` | `6d26c3f1-774e-4cff-9360-c22f13e36cfe` | `32944e4f` (10-04) |
| 149 | `1b5c2a83-461d-445e-ae25-33db59b4266a` | `54133d2e-9626-419a-ba94-c18333a599ce` | `ed9b3b0f-e43d-4862-9fbf-8e51c40bf786` | `b7d6ef6f` (10-04) |
| 168 | `f90731be-cce6-4420-b52a-6accec556868` | `25aca61b-3649-4fc2-b257-590aa8c536c6` | `e5649756-ef8a-4930-b0da-7223e9b5d891` | `8384790b` (10-04) |
| 186 | `b284807a-828d-42eb-b1f2-c276be8f9f2f` | `d401eaaa-8d3d-46cf-bc8d-26249d590610` | `2580d04b-10f5-4812-9818-8b991e0fb785` | `07c867a4` (10-04) |
| Test inek 3 | `1e9b93a9-3c1c-436f-a865-b284f62cbddc` | `f4b67cda-0b29-4ab9-a4fb-6820a929585c` | `427bca39-ba7c-4788-a664-8e5b806d7277` | `3af13eeb` (10-04) |

Vaka yapısı (8 vakanın TAMAMI aynı desen [OBSERVED]): Gün 1 = **2026-09-24** (gecikmiş), Gün 2 =
2026-10-01, Gün 3 = 2026-10-02, Gün 4 = 2026-10-03, TAI = 2026-10-04 10:00 — Ovsynch-56 aralıkları
(d0/d7/d8/d9/d10). Tüm günler `tamamlandi=f`, hiçbir seans uygulanmamış → **kaydırma temiz**.

### 1.2 Bağlam sayıları (aynı ölçüm)

| Kesit | Açık | Gecikmiş | Not |
|---|---|---|---|
| OVSYNC_BASLAT | 29 | **0** | hepsi ileri tarihli (2026-10-06 → 2027-09-22); sahibin düve-32 görevi iptal edilmiş (4cd3d45a) |
| TEDAVI_SEANS (ovsync zinciri) | 35 | 8 | 12 aktif Ovsync vakasının 8'inde gün1 gecikmiş |
| TEDAVI_GUN (ovsync zinciri) | 35 | 8 | — |
| TOHUMLAMA_PLANLI (toplam) | 9 | 0 | 8'i bu 8 vakanın TAI'si (10-04) + 1 küpe 002 (09-28) |
| TEDAVI_SEANS (ovsync DIŞI) | ~6 | 5 | küpe 008 vb. sıradan tedavi vakaları — K10 kapsamı DIŞI |

## 2. Sahibin isteği ve yorum (assumption kırıntısı atıldı)

Talimat 2b: "feature sonucu oluşmuş aktif ovsync görevleri **yarına ertelenmelidir**". Bugün
(09-25) itibarıyla "yarın" = **2026-09-26**. Gecikmiş gün-1 → 09-26 kaydırma **+2 gün**dür. Ovsynch-56
sabit aralıklı bir protokoldür (d0→d7 7 gün, d7→d8→d9 1'er gün): yalnız gün1'i +2 kaydırmak araları
bozar (d0→d7 6 güne düşer). **Varsayım (kırıntı `type:assumption`): zincir bütün olarak +2
kaydırılır — aralıklar aynen korunur.** Sahip yalnızca gün1'in kaymasını isterse §4-B'deki alternatif
kullanılır; bu karar exec ajanının değil sahibin kapısıdır (DONE'da sahip_kapisi listelenir).

## 3. Mevcut erteleme mekanizması envanteri (RPC/fonksiyon — canlı demo [OBSERVED pg_proc])

| Fonksiyon (canlı imza) | Kapsam | 16 gecikmiş görevi erteleyebilir mi? |
|---|---|---|
| `tohumlama_gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time)` | **Yalnız `TOHUMLAMA_PLANLI`**; tip dışı → `GOREV_ERTELENEMEZ:TIP_UYGUN_DEGIL` (gövde 20260923000003:562) | **HAYIR** (tip kilidi). TAI görevleri için EVET. |
| `hayvan_tohumlama_ertele(p_hayvan_id text, p_ay integer)` | hayvan-seviyesi AY bazlı tohumlama planı (SK3 dokunulmaz) | HAYIR (ilgisiz) |
| `update_treatment_session(p_seans_id, p_dose, p_unit, p_route, p_planned_time)` | seansın SAATİ/dozu; **tarihi değiştirmez** (20260613000004:203) | HAYIR |
| `add_treatment_day_with_sessions(p_case_id uuid, p_date date, p_sessions jsonb, p_existing_day_id uuid)` | update modu `treatment_days.treatment_date`'i taşır + seans görevlerini yeniden yaratır (yeni tarihli) **AMA üst `TEDAVI_GUN` görevinin `hedef_tarih`'ini güncellemez** (20260611000002:118-131 yalnız `tamamlandi=false` + aciklama; `hedef_tarih=p_date` yalnız INSERT dalında :134-141) | **KISMEN** — üst görev bayat kalır; ayrıca seansları söküp yeniden dikerek stok hareketlerini iade/yeniden yazar, zincirin diğer günlerine dokunmaz |
| Genel `gorev_ertele` | **YOK** (BUG-ERTELEME-KURAL-GENEL, sahip 2026-09-24: bu turda tam fix BEKLESİN) | HAYIR |

**Sonuç (engel gerekçesi):** `TEDAVI_GUN`/`TEDAVI_SEANS` için kural-yolu (RPC) erteleme yoktur; tip
kilidi `TIP_UYGUN_DEGIL` ile kesin engeldir. **K10, K11'in genel erteleme tasarımına bağlanır.**
Bununla birlikte zarf K10 "demo verisi; mevcut erteleme mekanizması neyi destekliyorsa onunla" der —
tek-seferlik demo veri bakımı (§4) kabul yoludur.

## 4. Exec ajanına (I-DB) NET talimat

Sıra: önce probe (BEGIN…ROLLBACK), sonra uygula, sonra doğrulama sorgusu. Ref doğrulama zorunlu:
`echo $SUPABASE_DEMO_REF` = `vtzqjmazsvurxdeondmi`.

### 4-A (ÖNERİLEN) — zincir bütün olarak +2 gün (aralıklar korunur)

Tek transaction; TAI görevleri mevcut destekli RPC ile, gün kaydırması tablo bakımıyla:

```sql
BEGIN;

-- 0) probe: etki edeceği satırlar (beklenen: 8 vaka, 32 gün satırı, 64 görev satırı, 8 TAI)
SELECT count(DISTINCT td.case_id), count(DISTINCT td.id), count(DISTINCT g.id)
  FROM public.treatment_days td
  JOIN public.gorev_log g ON (g.aciklama::jsonb->>'day_id')::uuid = td.id AND g.aciklama LIKE '{%'
  JOIN public.cases c ON c.id = td.case_id
  JOIN public.diseases d ON d.id = c.disease_id
 WHERE d.name ILIKE '%ovsync%' AND c.status='active'
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false;

-- 1) günler: 8 vakanın TÜM açık günleri +2 (09-24→09-26, 10-01→10-03, 10-02→10-04, 10-03→10-05)
UPDATE public.treatment_days td
   SET treatment_date = treatment_date + 2
  FROM public.cases c JOIN public.diseases d ON d.id = c.disease_id
 WHERE c.id = td.case_id AND d.name ILIKE '%ovsync%' AND c.status = 'active'
   AND td.tamamlandi = false;
-- beklenen: UPDATE 32

-- 2) görevler: aynı vakaların açık TEDAVI_GUN/TEDAVI_SEANS görevleri +2
UPDATE public.gorev_log g
   SET hedef_tarih = hedef_tarih + 2
  FROM public.treatment_days td
  JOIN public.cases c ON c.id = td.case_id
  JOIN public.diseases d ON d.id = c.disease_id
 WHERE (g.aciklama::jsonb->>'day_id')::uuid = td.id
   AND g.aciklama LIKE '{%'
   AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND d.name ILIKE '%ovsync%' AND c.status='active'
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false;
-- beklenen: UPDATE 64

COMMIT;
```

```sql
-- 3) TAI görevleri: DESTEKLİ RPC ile 10-04 → 10-06 (pencere 10:00 içeride kalır)
SELECT public.tohumlama_gorev_ertele(g.id, date '2026-10-06', time '10:00')
  FROM public.gorev_log g
  JOIN public.cases c ON g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || c.id::text || ':%'
  JOIN public.diseases d ON d.id = c.disease_id
 WHERE g.gorev_tipi='TOHUMLAMA_PLANLI' AND d.name ILIKE '%ovsync%' AND c.status='active'
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND g.hedef_tarih = date '2026-10-04';
-- beklenen: 8 satır, her biri ok=true, toplam_erteleme_gun=2
```

```sql
-- 4) audit (tablo bakımı için; RPC kendi islem_log'unu yazar)
INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
SELECT 'OVSYNC_ZINCIR_ERTELE_DEMO', c.animal_id, c.id::text, 'cases',
       jsonb_build_object('delta_gun',2,'hedef','2026-09-26','neden','K10 talimat 2b'),
       '{}'::jsonb
  FROM public.cases c JOIN public.diseases d ON d.id=c.disease_id
 WHERE d.name ILIKE '%ovsync%' AND c.status='active'
   AND c.id IN (<8 case_id — §1.1 tablosu>);
-- beklenen: INSERT 0 8
```

### 4-B (ALTERNATİF — sahibin "yalnız gecikmişler" yorumu)

Yalnız §1.1'deki 16 görev (8 GUN id + 8 SEANS id açık liste) ve bunların `treatment_days` gün-1
satırları `+2` (TAI ve gün2-4 DOKUNMAZ). Aynı sorgu kalıbı; WHERE `td.day_no = 1` + görev id listesi.
**Risk (raporda kalsın):** Ovsynch d0→d7 aralığı 7→6 güne düşer; protokol tıbbi anlamı bozulur.
Bu seçenek ancak sahibin açık tercihiyle.

### 4-C Doğrulama (K10 kabul sorgusu — DONE kanıtı)

```sql
-- gecikmiş açık ovsync görevi (beklenen: 0)
SELECT count(*) FROM public.gorev_log g
  JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id AND g.aciklama LIKE '{%'
  JOIN public.cases c ON c.id = td.case_id
  JOIN public.diseases d ON d.id = c.disease_id
 WHERE d.name ILIKE '%ovsync%' AND c.status='active'
   AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
   AND COALESCE(g.tamamlandi,false)=false AND COALESCE(g.iptal,false)=false
   AND g.hedef_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date;
```

### 4-D Engel yolunda raporlanacaksa (uygulama yapilmazsa)

DONE dosyasına K10 = KISMI/ENGEL gerekçesiyle: "gecikmiş açık ovsync görevi 16 (8 vaka × gün1);
`tohumlama_gorev_ertele` tip kilidi (TIP_UYGUN_DEGIL) TEDAVI_GUN/TEDAVI_SEANS'ı reddeder; tarih
taşıyan tek RPC (add_treatment_day_with_sessions update modu) üst görevin hedef_tarih'ini
güncellemez ve zincire yayılmaz → genel erteleme K11 planına bağlandı (docs/plans/2026-09-25-cila-onarim/plan-erteleme-genel.md)."

## 5. K11'e bağlanan bulgular (bu envanterden tasarım girdisi)

1. **Zincir kavramı eksik:** görev-bazlı erteleme ovsync zincirinde anlamsız — erteleme birimi
   "vakanın tüm açık günleri + türetilmiş TAI" olmalı (K11 spec'inde `zincir_tetikler` alanı bunu
   karşılar; bkz. plan-erteleme-genel.md Görev-Zincir diyagramı).
2. **BUG-ERTELEME-KURAL-GENEL'in somut bedeli:** 16 görev bugün ertelenemiyor; tip kilidi yalnız
   tohumlamaya açık (sahibin "dileğim onu tüm işlerde kullanabilmek" sözünün DB karşılığı yok).
3. **Üst-görev bayatlığı:** `add_treatment_day_with_sessions` update modu üst `TEDAVI_GUN`
   `hedef_tarih`'ini taşımıyor — genel erteleme RPC'si bu boşluğu kapatmalı ya da mevcut RPC
   onarılmalı (K11 risk listesinde).
4. 4-A'daki tablo bakımı yalnızca demo verisi içindir; K11 yürürlüğe girince bu tür bakımlar
   `gorev_ertele` üzerinden yapılır.

## 6. Kanıt sorguları (yeniden koşum için)

Envanterin tamamı şu üç sorguyla yeniden üretilebilir: (a) tip-bazlı açık/gecikmiş sayım
(`gorev_log` GROUP BY gorev_tipi), (b) ovsync zincir sayımı (§4-C join'i + GROUP BY gorev_tipi),
(c) vaka-gün dökümü (§1.1 — `treatment_days` × `cases` × `diseases`). Ham çıktılar kırıntıda
`type:measurement` (2026-09-25T09:56) kayıtlıdır.
