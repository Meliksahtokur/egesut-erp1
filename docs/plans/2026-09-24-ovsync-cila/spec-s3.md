# SPEC S-3 — Stale Temizlik + Erteleme Geneli (Tur 2, Adım 3)

- **Tarih:** 2026-09-24 · **Spec-yazar:** prd-to-spec ajanı (S-3) · **Worktree:** `ovysch-feature-cila-turu`
- **Rev-2 (2026-09-24 ~23:30, 3. tur review onarımı):** canlı demo şeması yeniden ölçüldü; dört bulgu işlendi — (1) R1'in `cases.protocol_family` veri çapası demo'da sürüklenmiş (pf NULL ×132, K20), (2) demo'da pg_cron YOK (K18/K21), (3) demo `schema_migrations` bayat — 0b kapısı davranışsal yapıldı (K22, E-7), (4) `_trg_gorev_parent_kapandi` cascade'i OBSERVED'a çıkarıldı ve taslak KISIR-B sıralaması düzeltildi (K23/V-3/D-2). Beklenen küme farkı: R1=0 / R2=1 / KISIR_GOREV=27 senaryosu bu spec'te birinci senaryodur (§6).
- **Girdi çapaları:** `reports/plans/ovsync-cila-plan-2.md` (sahibin emirleri + §5A araştırma), `reports/plans/ovsync-cila-sentez.md` (§3 Adım 3 sırası, §5A sınıflandırma kuralı, §9 karar tablosu), canlı kod (`CONFIRMED` dosya:satır) ve canlı şema (`OBSERVED` — tools-bank supabase sorguları, 2026-09-24). **KANAL NOTU (tutarlılık turu):** tools-bank `supabase_*` kanalı PROD'a bağlıdır (spec-s1 KANAL KURALI, plan-s2 F7) — aşağıdaki K11-K18 "OBSERVED" etiketli demo değerleri bu kanaldan okunmuşsa PROD okumasıdır; bağlayıcı olan koşum günü plan-s3 Adım 0c'nin **DEMO kanalından** (Mgmt query endpoint / demo pooler psql) taze ölçümüdür.
- **Kanıt sözlüğü:** `CONFIRMED` = dosya:satır ile kodda teyitli · `OBSERVED` = canlı demo DB salt-okunur sorgu çıktısı · `INFERRED` = kanıttan çıkarım · `UNKNOWN` = bu oturumda teyit edilemedi.

---

## 0. Kapsam kapısı — ÖNCE BUNU OKU (sahibin bağlayıcı kararlarıyla)

Bu spec **iki ayrı zarf** taşır; ikisinin tur-içi durumu FARKLIDIR:

| Zarf | İçerik | Bu turdaki durum | Dayanak |
|---|---|---|---|
| **ZARF A** | `ureme_temizlik_reconcile` migration'ı + dry-run rapor + onaylı koşum (stale R1/R2 + kısır temizlik) | **UYGULANIR** | Sahip: kısır 184/199/208 zincirleri kapatılacak (sentez §9 S1 "evet"); dry-run liste sunumu "evet" (S9); sentez §3 Adım 3 |
| **ZARF B** | Genel `gorev_ertele` RPC + `gorev_ertele_kural` tablosu + UI açılımı | **BORÇ — bu turda FIX YOK** | BUGS.md `BUG-ERTELEME-KURAL-GENEL` (sahip kararı 2026-09-24: "bu turda tam fix BEKLESİN"); hedef tasarım kaydı: hibrit, ağırlık DB'de, JS kopyası YASAK |

**Çelişki kaydı (dürüstlük):** Görev metni "erteleme geneli"ni spec konusu sayar; sahibin BUGS.md kararı fix'i bu tura almaz. Bu spec ikisini uzlaştırır: Zarf B'nin migration/RPC taslağı ve kabul blokları **tasarım kaydı olarak** burada tam taşınır (borç kapısı açıldığında implementer spec'ten yola çıkar), ancak hiçbir implementer Zarf B'yi **bu turda uygulamaz**.

**Sınır (kapsam disiplini):** Sessiz eşik 55→50 ve Bekliyor ≥40g gebelik-muayenesi kuralı **SPEC S-4**'ündür. Zarf A'nın temizliği **eşik-bağımsız** tasarlandı: R1 aktif-vaka testini, R2 tohumlama-sonucu testini okur; hiçbir yerde `sessiz_gun` eşiğine bakmaz. Böylece S-4'ün view değişikliğinden bağımsız doğru çalışır.

**A3 güncellemesi (plan-2 §3):** "Bugün hedefli açık OVSYNC_BASLAT'ları yarına ertele" operasyonu bugün **moot**: canlıda hedefi 2026-09-24 olan sıfır açık OVSYNC_BASLAT var; en erken hedef 2026-09-26 (`OBSERVED` — tools-bank/PROD kanalı: 31 açık; DEMO'da 29, en erken hedef 2026-10-06 — spec-s1 K12. Mootluk iki kanalda da geçerlidir: hedefi 2026-09-24 olan açık görev iki kanalda da yok).

---

## 1. Amaç

1. Demo'da işletmeciye çift/yanlış planlama görünen **tarihsel kirleri** tek-seferlik, denetlenebilir, dry-run'lı bir koşumla kapatmak:
   - **R1:** aktif ovsync vakası (`cases.status='active'` + `protocol_family IS NOT NULL`) olan hayvanın hâlâ açık duran "Sessiz hayvan" vet-kontrol görevi (ispat.png 168/186 tipi);
   - **R2:** son tohumlama `Gebe`/`Bekliyor` olan hayvanın açık "Sessiz hayvan" görevi (ispat.png 173 tipi — yanlış grup damgası; kalıcı fix S-4'ün view değişikliğidir);
   - **KISIR:** kısır hayvanların açık ovsync/ileri-gebe zincirleri (184/199/208 — sahibin S1 "evet, kapatılsın" kararı).
2. Silme YOK: yalnız `iptal=true` + `kapatan_ref` + `islem_log` audit (L4 geri-alma uyumlu snapshot deseni).
3. Erteleme geneli için sahibin onayladığı **hibrit, ağırlık-DB'de** hedef tasarımı bozulmadan kaydetmek (Zarf B) — bu turda kodu yazılmaz.

---

## 2. Mevcut durum — kanıt envanteri

| # | Bulgu | Kanıt |
|---|---|---|
| K1 | Erteleme bugün tek tipte: `tohumlama_gorev_ertele(uuid,date,time)`; `gorev_tipi IS DISTINCT FROM 'TOHUMLAMA_PLANLI'` → `GOREV_ERTELENEMEZ:TIP_UYGUN_DEGIL` | CONFIRMED `supabase/migrations/20260923000003_ovsync_pg_yardimcilar.sql:540,562-563` |
| K2 | Pencere sabiti `_tohumlama_pencere` (MK1, IMMUTABLE) + MK2 ">7 gün → uyari" + ilk-hedef islem_log okuması + `islem_log` audit deseni | CONFIRMED aynı dosya `:34,585-618` |
| K3 | UI kilidi: `_erteleModal` yalnız TOHUMLAMA_PLANLI'ya açılır; [Ertele] butonu yalnız o kartta; çağrı `rpc('tohumlama_gorev_ertele',…)` | CONFIRMED `js/ui.js:1009-1012,1058,1167-1170,1259` |
| K4 | Hata sözlüğünde `GOREV_ERTELENEMEZ`/`GECMIS_TARIH` yok (D18) | CONFIRMED `js/api.js:44-52` |
| K5 | JS pencere aynası `TOHUMLAMA_PENCERELERI` + `pencereYuvarla` — birim testle DB ile karşılaştırılır | CONFIRMED `js/config.js:195-222` |
| K6 | Ay-bazlı ikinci erteleme `hayvan_tohumlama_ertele` — SK3 gereği DOKUNULMAZ | CONFIRMED `js/forms.js:2901` |
| K7 | Sessiz görev üreticisi: `kaynak='SESSIZ-<id>'`, metin `'Sessiz hayvan: %s gündür…'`; cron `sessiz-reconcile-daily` 05:00; iptal edilen görev için cooldown YOK (yalnız kullanıcı-tamamlaması) | CONFIRMED `supabase/migrations/20260625000020_sessiz_reconcile.sql:15-56,80` |
| K8 | `v_eligible` yalnız `sonuc='Gebe'`'i hariç tutar (Bekliyor tutulur); eşiğe gömülü 55 | CONFIRMED `supabase/migrations/20260831000002_duve_sessiz_13ay.sql:34-35` |
| K9 | Ovsync üretim muafiyetleri: son tohumlama `Gebe/Bekliyor` → NULL (MK3); aktif `cases.protocol_family` vakası → NULL; açık OVSYNC_BASLAT → NULL | CONFIRMED `supabase/migrations/20260924000001_ovsync_pg_r32_acik_disi.sql:262-279` |
| K10 | OVSYNC_BASLAT idempotensi: `protokol_instance.kaynak_ref` UNIQUE (`'ACIK-DISI-<id>-<kural>'`); instance varsa ikinci çağrı NULL; yeni rota eski açık OVSYNC_BASLAT'ı `ILK_TOH_YENI_OLAY` ile kapatır; `gorev_log`'da `kaynak_ref` kolonu YOK (`kaynak` var) | CONFIRMED aynı dosya `:141-147,150-159,174-179,299-300` + canlı constraint `protokol_instance_kaynak_unique` (OBSERVED) |
| K11 | Canlı fonksiyon seti: `gorev_ertele` YOK; `tohumlama_gorev_ertele`, `sessiz_hayvanlar_reconcile`, `sessiz_hayvanlar_listele`, `_tohumlama_pencere`, `hayvan_tohumlama_ertele` VAR | OBSERVED pg_proc sorgusu |
| K12 | Canlı `protokol_ayar`: 10 satır, `ovsync_pg_kurallari_aktif=1`, sessiz/erteleme anahtarı YOK | OBSERVED select |
| K13 | Demo'da 3 açık "Sessiz hayvan" görevi (24.09 hedefli): 168 `5fe2ef8b`, 173 `e341a0a9`, 186 `65012b75`; üçünün `kapatan_ref=NULL`. **23:15 yeniden ölçüm: birebir aynı** | OBSERVED gorev_log sorgusu (2 ölçüm) |
| K14 | 168 ve 186: aktif `cases` satırı (`f90731be`/`b284807a`, `status='active'`) + açık 4-gün `TEDAVI_GUN/SEANS` zincirleri + açık `TOHUMLAMA_PLANLI` görevi; 173: son tohumlama 2026-07-30 `sonuc='Bekliyor'`. **İlk ölçümde pf='OVSYNC' sanıldı — 23:15 yeniden ölçümde pf NULL (bkz. K20)** | OBSERVED |
| K15 | Kısır durumu: 184/208'te aktif `ILERI_GEBE-<id>` instance (tip=UREME, alttip=GEBELIK); 184/199/208'de **27** açık zincir görevi (8+8+8 TEDAVI_GUN/SEANS = 24 **+ 3 TOHUMLAMA_PLANLI**, hedef 2026-10-04: 184=`113c327f`, 199=`9c3c7180`, 208=`af9dd507`); 199'un aktif instance'ı YOK; üçünün de açık OVSYNC_BASLAT'ı YOK; **kısır kümesi 3→6 büyüdü: +115/204/185 (açık görevleri ve aktif instance'ları YOK — kapsam etkisi sıfır)** | OBSERVED (23:15 yeniden ölçüm) |
| K16 | `kupe 168/173/186 → kisir=false, tohumlama_durumu='gebe'`; `184/199 → kisir=true, tdm='gebe'`; `208 → kisir=true, tdm='-'` | OBSERVED hayvanlar sorgusu |
| K17 | Demo'da `TOHUMLAMA_ERTELE` islem_log kaydı = 0 (ilk-hedef hesabı hedef_tarih'e düşer); `PROTOKOL_AYAR` = 2 | OBSERVED islem_log sorgusu |
| K18 | Cron kayıtları: ilk ölçümde `cron.job` listesi OBSERVED sanıldı; **23:15 yeniden ölçüm: demo'da pg_cron YOK** (`pg_extension` boş, `cron` şeması yok — `cron.job` sorgusu "relation does not exist" verir). Cron semantiği (`sessiz-reconcile-daily` 05:00 vb.) **PROD'a aittir**; demo'da yeniden-üretim vektörü yalnız **ELLE** `sessiz_hayvanlar_reconcile()` çağrısıdır | OBSERVED 23:15 |
| K19 | `kapatan_ref` kolonu `20260603000001_protokol_etken_kod.sql:13`'ten beri var | CONFIRMED |
| K20 | **R1 veri çapası sürüklenmiş:** demo `cases.protocol_family` **132 satırın tümünde NULL** (`IS NOT NULL` = 0 satır) → R1 yüklemi canlıda **0** döner; 168/186'nın aktif case'leri duruyor (`status='active'`) ama pf boş. R32 üretim muafiyeti (K9) ve S-4'ün view fix'i de aynı veriye dayanır — bu bir **veri-borcu**dur (U-6/E-6); RPC kuralının hatası DEĞİL | OBSERVED 23:15 |
| K21 | 168/186'nın MK3 son tohumlaması `sonuc='Doğum Yaptı'` (2025-09-12 / 2025-10-29) → **R2 de yakalamaz**; pf NULL iken bu iki görevin kapanması R1/R2'nin hiçbir koluna düşmez — görevler açık kalır (sapma değil, veri gerçeği) | OBSERVED 23:15 |
| K22 | Demo `supabase_migrations.schema_migrations` **bayat**: en üst `20260706052550` (repo geçmişi 20260924'te). Ham `psql -f` apply bu tabloya KAYIT YAZMAZ → S1/S2 apply kontrolü bu sorguyla demo'da **asla** görünmez; kapı davranışsal kanıtla kurulmalı (E-7) | OBSERVED 23:10 |
| K23 | Trigger envanteri (gorev_log/protokol_instance/cases): `gorev_log_cycle_guard_trigger` (yalnız INSERT, NEW.iptal guard), `trg_degisim_log` (I/U/D → `degisim_log` tablosuna yazar; islem_log DEĞİL), `trg_gorev_asip_iade` (UPDATE; yalnız `referans_tipi='asi_plan'` eşleşmesine yazar — hedef tiplerimiz eşleşmez → no-op), **`trg_gorev_parent_kapandi` (U/D): kapanan görevin çapraz-tip açık çocuklarını `kapatan_ref='parent-kapandi'` ile KAPATIR**; `protokol_instance.trg_degisim_log`; `cases.trg_kizginlik_case_close` (yalnız active→closed geçişinde kizginlik_log'a yazar) | OBSERVED (pg_get_functiondef, 23:20) |
| K24 | KISIR hedef kümesinde ebeveyn-çocuk ilişkisi: her tarih çiftinde **TEDAVI_SEANS, TEDAVI_GUN'ün çocuğu** (`parent_id` bağlı; 12 çift: 184/199/208 × 4 gün) → parent_kapandi cascade'i KISIR-B içinde kalır; SESSIZ vet görevlerinin ve TOHUMLAMA_PLANLI'ların açık çocuğu YOK; kısır hayvanlarda açık OVSYNC_BASLAT YOK | OBSERVED 23:20 |

---

## 3. Tek-yazıcı zarfları — dokunulacak dosyaların TAM listesi

### 3.1 ZARF A — bu turda uygulanır (temizlik)

| Dosya | İşlem | Not |
|---|---|---|
| `supabase/migrations/<boş-numara>_ureme_temizlik_reconcile.sql` | **YENİ** | Ad/tarih implementer tarafından kaydırılabilir; **numara plan-s3 Adım 0d kuralıyla verilir** (koşum anında boş olan en düşük `20260925NNNNNN` — bu turda S1/S2 001-002'yi kullanıyor, aşağıdaki `20260925000001` taslak adı BAYATTİR); içerik §5'teki validated taslak (sha `b02f28ff…`) |
| `.harness/references/rpc-reference.md` | ekleme | Yalnız yeni RPC girdisi (İmza + amaç + çağrı yeri: koşum betiği); mevcut satırlara dokunma |
| `reports/ureme-temizlik-kosum-<tarih>.md` | YENİ | Dry-run + koşum çıktısı (reports/ gitignore — commit DIŞI) |

Zarf A'da **JS dosyası YOK**: temizlik saf DB operasyonudur; iptal görevler UI'da zaten görünmez (mevcut filtre davranışı).

**Zarf A'da DOKUNULMAZ:** `js/*` (hepsi), `tohumlama_gorev_ertele` gövdesi, `hayvan_tohumlama_ertele` (SK3), `sessiz_hayvanlar_reconcile` gövdesi (üretici; kalıcı fix S-4'te), 188'in İLAÇ görevi ve tüm aktif OVSYNC TEDAVI zincirleri, `protokol_ayar`, BUGS.md (10 eşzamanlı ajan çakışması; koşum kaydı reports/'ta).

### 3.2 ZARF B — BORÇ (bu turda uygulanmaz; kapı açılırsa implementasyon zarfı)

| Dosya | İşlem | Ön-şart |
|---|---|---|
| `supabase/migrations/<tarih>_gorev_ertele_genel.sql` | YENİ | §8.1-8.2 taslak → db-validate PASS |
| `js/ui.js` | `_erteleModal` tip kilidi (1009-1044) kural-okur hale gelir; `_erteleKaydet` RPC adı (1058); `_tohErteleBtnHtml` (1167-1170) ve kart bağlama (1259) kural-ertelenebilir tiplere açılır | blast-radius pre-check (gitnexus/LSP) |
| `js/api.js` | `_ERR_MAP` (44-52) `GOREV_ERTELENEMEZ`/`GECMIS_TARIH` Türkçe mesajları (D18 kapanır); RPC→tablo haritasına (321 civarı) `gorev_ertele` girişi | aynı |
| `index.html` | `?v=` damgası tek değer güncellenir (cache-busting; mevcut değer `20260924-01`) | — |
| `tests/unit/erteleme-kural.test.js` | YENİ | kural tablosu JS-mirror'suz davranış testi |
| `tests/sql/gorev_ertele_kabul_test.sql` | YENİ | §8.4 kabul blokları |
| `.harness/references/rpc-reference.md` | ekleme | `gorev_ertele` + kural tablosu girdisi |

**Zarf B'de DOKUNULMAZ:** `js/config.js` (§5A karar 3: JS'e kural kopyası YAZILMAZ — üçüncü kopya doğmasın; pencere aynası 195-222 olduğu gibi kalır), `js/forms.js:2901` (SK3), `tohumlama_gorev_ertele` gövdesi (S-6 test sözleşmesi; genel RPC üstüne BÜYÜR, eski dokunulmaz).

---

## 4. Zarf A — koşum akışı (sıralı, operasyonel)

1. **Sıra bağımlılığı (ENGEL E-1):** Koşum, sentez §3 Adım 1 (kısır blok) ve Adım 2 (v_eligible yeniden sınıflandırma) demo'ya uygulandıktan SONRA yapılır. Neden: R1/R2 görevleri kapatılıp hayvan hâlâ eski `v_eligible`'da ise görev **yeniden üretilir** — üretim vektörü PROD'da 05:00 `sessiz-reconcile-daily` cron'u (K7: iptal için cooldown yok), **demo'da pg_cron olmadığından (K18/K21) elle `sessiz_hayvanlar_reconcile()` çağrısıdır** (test/lane çağrıları dahil). Taze kanıt: 173'ün görevi Tur 1 içinde kapanmıştı, bugün yeniden açık (K13; kapanma→yeniden-üretim INFERRED — demo'da elle çağrı yoluyla). Apply kanıtı **davranışsaldır** (K22: `schema_migrations` demo'da kör kapı): S1 → kısır hayvana `_acik_disi_hedef_ic` NULL döner; S2 → `sessiz_hayvanlar_listele` default eşiği 50 + `v_eligible` tanımında Bekliyor hariç.
2. Migration dosyasını §5 taslağından yaz → `scripts/db-validate.sh <dosya>` PASS (taslakta koşuldu, §5.2).
3. Migration'ı **demo** DB'ye uygula (prod'a ASLA).
4. **Dry-run:** `SELECT public.ureme_temizlik_reconcile(true);` → çıktıyı rapora dök (`reports/ureme-temizlik-kosum-<tarih>.md`), grup bazlı tablo halinde: R1 / R2 / KISIR_INSTANCE / KISIR_GOREV, her satırda gorev_id + küpe + açıklama + uygulanacak `kapatan_ref`.
5. **Onay kapısı:** KISIR grubu sahibin S1 kararıyla **ön-onaylıdır** ("evet, kapatılsın"). R1/R2 grupları plan-2 akışı gereği dry-run tablosuyla sahibe sunulur; onay gelmeden `p_dry_run=false` koşulmaz. (Orkestratör notu: sahibin "kesintisiz koş" talimatı KISIR + nesnel R1/R2 vakaları için okunabilir; onay damgası rapora mutlaka işlenir.)
6. **Onaylı koşum:** `SELECT public.ureme_temizlik_reconcile(false, ARRAY['R1','R2','KISIR']);` (onay gelmeyen grup dizide çıkarılır).
7. **Yeniden üretim denetimi (T-A4):** koşumu izleyen `sessiz_hayvanlar_reconcile()` **elle çağrısında** `uretilen=0, kapatilan=0` beklenir (demo'da pg_cron YOK — K18; cron-tabanlı izleme maddesi PROD'a aittir, bu turun kapsamı dışıdır). `gorev-orphan-temizle-daily` (05:15, PROD) ile temassızdır — o yalnız `v_orphan_gorev` kümesini kapatır.

---

## 5. Zarf A — Migration/RPC taslağı (SQL gövde seviyesinde)

### 5.1 Taslağın tamamı

Dosya: `supabase/migrations/<boş-numara>_ureme_temizlik_reconcile.sql` (final numara plan-s3 Adım 0d kuralıyla; aşağıdaki `20260925000001` başlığı yalnız taslak-tarihseldir) · SHA-256 başı: `b02f28ff` (aşağıdaki metin birebir doğrulanan taslaktır; implementer yalnız baş yorumundaki SPEC yolunu ve gerekirse dosya adını günceller — her içerik değişikliği yeniden db-validate gerektirir).

```sql
-- Migration: ureme_temizlik_reconcile — stale sessiz görevleri + kısır zincirleri tek-seferlik,
-- dry-run'lı tasfiye RPC'si. SPEC: docs/plans/2026-09-24-ovsync-cila/spec-s3.md §5 (S-3).
-- Kurallar: R1 (aktif protocol_family vakalı hayvanın açık SESSIZ görevi),
--           R2 (son tohumlama Gebe/Bekliyor olan hayvanın açık SESSIZ görevi),
--           KISIR (kisir=true hayvanın aktif UREME instance'ları + açık zincir görevleri).
-- R3: ILAC görevleri ve aktif akışa ait TEDAVI zincirleri ASLA dokunulmaz (188 kasıtlı çift zincir).
-- Silme YOK — yalnız iptal + kapatan_ref + islem_log audit. Cron yeniden-üretimi Adım 1-2
-- (kısır blok + v_eligible yeniden sınıflandırma) merge'ünden sonra doğal olarak kesilir;
-- bu RPC yalnız tarihsel kiri kapatır.
BEGIN;

CREATE OR REPLACE FUNCTION public.ureme_temizlik_reconcile(
  p_dry_run boolean DEFAULT true,
  p_gruplar text[] DEFAULT ARRAY['R1', 'R2', 'KISIR']
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  r record;
  v_r1          jsonb := '[]'::jsonb;
  v_r2          jsonb := '[]'::jsonb;
  v_k_inst      jsonb := '[]'::jsonb;
  v_k_gorev     jsonb := '[]'::jsonb;
  v_gunc        jsonb := '[]'::jsonb;
  v_say_r1      integer := 0;
  v_say_r2      integer := 0;
  v_say_inst    integer := 0;
  v_say_gorev   integer := 0;
BEGIN
  -- ── R1: aktif protocol_family vakası olan hayvanın açık SESSIZ vet-kontrol görevi ──
  IF 'R1' = ANY (p_gruplar) THEN
    FOR r IN
      SELECT g.id, g.hayvan_id, h.kupe_no, g.aciklama
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'VETERINER_KONTROL'
         AND g.kaynak LIKE 'SESSIZ-%'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND EXISTS (SELECT 1 FROM public.cases c
                      WHERE c.animal_id = g.hayvan_id
                        AND c.status = 'active'
                        AND c.protocol_family IS NOT NULL)
       ORDER BY g.hayvan_id, g.id
    LOOP
      v_r1 := v_r1 || jsonb_build_object('gorev_id', r.id, 'hayvan_id', r.hayvan_id,
                 'kupe_no', r.kupe_no, 'aciklama', r.aciklama);
      v_say_r1 := v_say_r1 + 1;
      IF NOT p_dry_run THEN
        UPDATE public.gorev_log
           SET iptal = true, kapatan_ref = 'OVSYNC_KAPLANDI'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'gorev_log', 'id', r.id::text,
                   'onceki', jsonb_build_object('iptal', false, 'kapatan_ref', NULL),
                   'sonraki', jsonb_build_object('iptal', true, 'kapatan_ref', 'OVSYNC_KAPLANDI'));
      END IF;
    END LOOP;
  END IF;

  -- ── R2: son tohumlama Gebe/Bekliyor (MK3 sıralaması) olan hayvanın açık SESSIZ görevi ──
  --    R1 kapsamındaki hayvanlar R2'de tekrar sayılmaz (R1 önceliği, çift-kapatma yok).
  IF 'R2' = ANY (p_gruplar) THEN
    FOR r IN
      SELECT g.id, g.hayvan_id, h.kupe_no, g.aciklama, v_son.sonuc
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
        LEFT JOIN LATERAL (
          SELECT t.sonuc
            FROM public.tohumlama t
           WHERE t.hayvan_id = g.hayvan_id
           ORDER BY t.tarih DESC NULLS LAST, t.created_at DESC NULLS LAST
           LIMIT 1
        ) v_son ON true
       WHERE g.gorev_tipi = 'VETERINER_KONTROL'
         AND g.kaynak LIKE 'SESSIZ-%'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND v_son.sonuc IN ('Gebe', 'Bekliyor')
         AND NOT EXISTS (SELECT 1 FROM public.cases c
                          WHERE c.animal_id = g.hayvan_id
                            AND c.status = 'active'
                            AND c.protocol_family IS NOT NULL)
       ORDER BY g.hayvan_id, g.id
    LOOP
      v_r2 := v_r2 || jsonb_build_object('gorev_id', r.id, 'hayvan_id', r.hayvan_id,
                 'kupe_no', r.kupe_no, 'aciklama', r.aciklama, 'son_tohumlama_sonuc', r.sonuc);
      v_say_r2 := v_say_r2 + 1;
      IF NOT p_dry_run THEN
        UPDATE public.gorev_log
           SET iptal = true, kapatan_ref = 'TOHUMLAMA_SONUCU_VAR'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'gorev_log', 'id', r.id::text,
                   'onceki', jsonb_build_object('iptal', false, 'kapatan_ref', NULL),
                   'sonraki', jsonb_build_object('iptal', true, 'kapatan_ref', 'TOHUMLAMA_SONUCU_VAR'));
      END IF;
    END LOOP;
  END IF;

  -- ── KISIR-A: kısır hayvanın aktif UREME instance'ları (ILERI_GEBE vb.) ──
  IF 'KISIR' = ANY (p_gruplar) THEN
    FOR r IN
      SELECT pi.id, pi.kaynak_ref, pi.hayvan_id, h.kupe_no, pi.tip, pi.alttip, pi.baslangic
        FROM public.protokol_instance pi
        JOIN public.hayvanlar h ON h.id = pi.hayvan_id
       WHERE h.kisir IS TRUE
         AND pi.durum = 'aktif'
       ORDER BY pi.hayvan_id, pi.id
    LOOP
      v_k_inst := v_k_inst || jsonb_build_object('instance_id', r.id, 'kaynak_ref', r.kaynak_ref,
                   'hayvan_id', r.hayvan_id, 'kupe_no', r.kupe_no, 'tip', r.tip,
                   'alttip', r.alttip, 'baslangic', r.baslangic);
      v_say_inst := v_say_inst + 1;
      IF NOT p_dry_run THEN
        UPDATE public.protokol_instance
           SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'KISIR_TEMIZLIK'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'protokol_instance', 'id', r.id::text,
                   'onceki', jsonb_build_object('durum', 'aktif', 'kapandi_at', NULL, 'kapandi_sebep', NULL),
                   'sonraki', jsonb_build_object('durum', 'iptal', 'kapandi_sebep', 'KISIR_TEMIZLIK'));
      END IF;
    END LOOP;

    -- ── KISIR-B: kısır hayvanın açık zincir görevleri (instance bağlı olsun olmasın) ──
    FOR r IN
      SELECT g.id, g.hayvan_id, h.kupe_no, g.gorev_tipi, g.aciklama
        FROM public.gorev_log g
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE h.kisir IS TRUE
         AND g.gorev_tipi IN ('OVSYNC_BASLAT', 'TEDAVI_GUN', 'TEDAVI_SEANS')
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
       ORDER BY g.hayvan_id, g.gorev_tipi DESC, g.id  -- D-2: SEANS (çocuk) GUN (ebeveyn)'den ÖNCE; bkz. §5.1 tasarım notları
    LOOP
      v_k_gorev := v_k_gorev || jsonb_build_object('gorev_id', r.id, 'hayvan_id', r.hayvan_id,
                    'kupe_no', r.kupe_no, 'gorev_tipi', r.gorev_tipi, 'aciklama', r.aciklama);
      v_say_gorev := v_say_gorev + 1;
      IF NOT p_dry_run THEN
        UPDATE public.gorev_log
           SET iptal = true, kapatan_ref = 'KISIR_TEMIZLIK'
         WHERE id = r.id;
        v_gunc := v_gunc || jsonb_build_object('tablo', 'gorev_log', 'id', r.id::text,
                   'onceki', jsonb_build_object('iptal', false, 'kapatan_ref', NULL),
                   'sonraki', jsonb_build_object('iptal', true, 'kapatan_ref', 'KISIR_TEMIZLIK'));
      END IF;
    END LOOP;
  END IF;

  -- ── Audit: gerçek koşumda tek islem_log satırı (L4 geri-alma snapshot deseni) ──
  IF NOT p_dry_run AND (v_say_r1 + v_say_r2 + v_say_inst + v_say_gorev) > 0 THEN
    INSERT INTO public.islem_log (tip, ref_tablo, snapshot, kullanici_notu)
    VALUES ('UREME_TEMIZLIK', 'gorev_log',
            jsonb_build_object(
              'olusturulan', '[]'::jsonb,
              'silinen', '[]'::jsonb,
              'guncellenen', v_gunc),
            format('Üreme temizlik koşumu: R1=%s, R2=%s, KISIR-instance=%s, KISIR-gorev=%s',
                   v_say_r1, v_say_r2, v_say_inst, v_say_gorev));
  END IF;

  RETURN jsonb_build_object(
    'dry_run', p_dry_run,
    'gruplar', to_jsonb(p_gruplar),
    'R1',            jsonb_build_object('sayi', v_say_r1,    'kapatan_ref', 'OVSYNC_KAPLANDI',      'kayitlar', v_r1),
    'R2',            jsonb_build_object('sayi', v_say_r2,    'kapatan_ref', 'TOHUMLAMA_SONUCU_VAR', 'kayitlar', v_r2),
    'KISIR_INSTANCE',jsonb_build_object('sayi', v_say_inst,  'kapandi_sebep','KISIR_TEMIZLIK',      'kayitlar', v_k_inst),
    'KISIR_GOREV',   jsonb_build_object('sayi', v_say_gorev, 'kapatan_ref', 'KISIR_TEMIZLIK',       'kayitlar', v_k_gorev),
    'zaman', now());
END;
$fn$;

REVOKE ALL ON FUNCTION public.ureme_temizlik_reconcile(boolean, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ureme_temizlik_reconcile(boolean, text[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
-- EOF ureme_temizlik_reconcile (S-3 taslak)
```

Tasarım notları: R1 kapatan_ref değeri `OVSYNC_KAPLANDI` plan-2 R1 metninden aynen alınır; MK3 sıralaması (`tarih DESC, created_at DESC`) K9'daki otorite tanımıyla birebir; R1⊃R2 çift-kapatma önleme R2'de `NOT EXISTS` ile; kapatılan instance/görev listesi snapshot `guncellenen`'e onceki/sonraki ile yazılır (L4 `surum_gecmisi` geri-alma deseniyle uyumlu).

**D-2 (Rev-2 trigger-sırası düzeltmesi):** Canlı demo'da her tarih çiftinde `TEDAVI_SEANS`, `TEDAVI_GUN`'ün **çocuğudur** (K24) ve `_trg_gorev_parent_kapandi` UPDATE tetiği, kapanan ebeveynin çapraz-tip açık çocuklarını `kapatan_ref='parent-kapandi'` ile kapatır (K23). Taslağın eski `ORDER BY g.hayvan_id, g.id` sıralamasında bir GUN ebeveynden ÖNCE işlenebilirdi: tetik çocuğu kendisi kapatır, sonra RPC aynı satırı güncelleyip `kapatan_ref`'i ezerek snapshot `onceki` değerini yalan söylerdi. Düzeltme: `ORDER BY g.hayvan_id, g.gorev_tipi DESC, g.id` — `'TEDAVI_SEANS' > 'TEDAVI_GUN'` sözlük sırasıyla **çocuklar önce** kapanır; ebeveyn kapanınca tetiğin cascade'i `NOT c.iptal` guard'ına takılıp no-op olur; tüm satırlar `KISIR_TEMIZLIK` ref'iyle, doğru onceki/sonraki snapshot'ıyla kapanır. Cascade'in hedef-küme DIŞINA çıkmadığı K24 ile ölçülüdür (SESSIZ/TOHUMLAMA_PLANLI/OVSYNC_BASLAT hedeflerinin açık çocuğu yok). Bu içerik değişikliği de D-1 gibi **final dosyada db-validate'i zorunlu kılar** (Adım-2 kapısı zaten koşulsuzdur).

### 5.2 Taslak db-validation kanıtı (kapı koşuldu)

`bash scripts/db-validate.sh <taslak>` — 2026-09-24, rapor `db-validation-b02f28ff.md`:

| Kriter | Sonuç |
|---|---|
| A.sqlfluff-parse | PASS (0 parse hatası; yalnız stil uyarısı) |
| A.squawk | PASS (2 WARNING: lock/statement_timeout önerisi — repo genelinde migration'lar bu uyarıyla yaşıyor; sahip politikası: WARNING FAIL değil) |
| B.sema-uyum | INCONCLUSIVE (statik `LATERAL` takma-adı çözemedi — yardımcı faz; C1 karar verdi) |
| C1.baseline-restore (schema+data) | PASS — parite=uyumlu (prod PG 17.6 = yerel PG 17.6, T54/F243/V13) |
| C1.migration-apply | **PASS** (psql ON_ERROR_STOP hatasız) |
| C1.postcheck-nesne / -rls | PASS / PASS (RLS farkı yok) |
| C2.sentetik-tohum / veri-uyumluluk | INCONCLUSIVE — validator tohum üreticisi `islem_log`'a sentetik satır üretemedi (`VALUES ()` üretti; üretici kısıtı, migration hatası DEĞİL); tohumlu DB üzerinde C2 apply yine hatasız geçti |

Ortam notu: worktree kökünde `.env` yoktu (db-validate `scripts/../.env` okur); kapı, `~/tmp` altında mini-körök workaround'ıyla koşuldu — implementer final dosyayı kendi `.env`'iyle yeniden koşmalı (ENGEL E-3).

---

## 6. Zarf A — kabul testleri (ölçülebilir)

Ölçüm taban çizgisi (Rev-2, 2026-09-24 23:15 `OBSERVED`, K13/K15/K20/K21): **R1 = 0** (pf NULL ×132 — bkz. K20), R2 = {173→`e341a0a9`}, KISIR_INSTANCE = 2 (`ILERI_GEBE-…184` `5570df8f`, `ILERI_GEBE-…208` `9bc82033`), KISIR_GOREV = **27** (24 TEDAVI_GUN/SEANS + 3 TOHUMLAMA_PLANLI: `113c327f`/`9c3c7180`/`af9dd507`). **Bu veri hâliyle beklenen koşum: toplam 30 kayıt (0+1+2+27); 168/186'nın SESSIZ görevleri (R1-boş + R2-dışı, K21) açık kalır.** pf verisi borcu kapanırsa (U-6) taban çizgisi spec'in ilk ölçümüne döner: R1 = {168, 186} → toplam 32. Koşum günü taze dry-run çıktısı esastan geçer; 0f sentetik R1 kanıtı (plan) kuralın kendisinin çalıştığını ayrıca gösterir.

- **T-A1 (kapı):** Final migration dosyasında `scripts/db-validate.sh` → sonuç PASS veya (aynı C2 tohum-üretici kısıtı tekrarlırsa) INCONCLUSIVE-with-C1-PASS; FAIL kabul DEĞİL.
- **T-A2 (dry-run salt-okunurluk):** Koşum öncesi/sonrası `SELECT count(*) FROM gorev_log WHERE iptal` + `protokol_instance WHERE durum='iptal'` farkı **0**; dönen jsonb'de yukarıdaki taban çizgisi kümesi satır satır görünüyor; her R1 kaydında kupe + aciklama + gorev_id var.
- **T-A3 (onaylı koşum):** `p_dry_run=false` sonrası (a) hedef görevlerin tümünde `iptal=true` ve grup-bazlı doğru `kapatan_ref` (R1=`OVSYNC_KAPLANDI`, R2=`TOHUMLAMA_SONUCU_VAR`, KISIR=`KISIR_TEMIZLIK`); (b) `islem_log`'da **tam 1** `tip='UREME_TEMIZLIK'` satırı; `snapshot.guncellenen` uzunluğu = kapatılan toplam kayıt (D-2 sıralamasıyla tetik cascade'i snapshot'a karışmaz); `olusturulan`/`silinen` boş; (c) instance'larda `durum='iptal'`, `kapandi_sebep='KISIR_TEMIZLIK'`, `kapandi_at` dolu. **Trigger gürültüsü (beklenen, T-A3'ü bozmaz):** `trg_degisim_log` her UPDATE'e `degisim_log` satırı yazar (islem_log DEĞİL — K23); D-2 sayesinde `parent-kapandi` ref'i hiçbir hedefte KALICI yazılmaz (cascade no-op).
- **T-A4 (yeniden üretim yok — Adım 1-2 bağımlı):** Koşumdan sonra `SELECT public.sessiz_hayvanlar_reconcile();` → `uretilen=0 AND kapatilan=0`. Adım 1-2 demo'ya uygulanmadan koşulursa bu test BEKLENEN ŞEKİLDE fail eder ve koşum sonraki adıma ertelenir (E-1).
- **T-A5 (dokunulmazlar):** Koşum diff'inde şunlar YOK: 188'in İLAÇ görevi (`0818cd2e`), 168/186'nın aktif OVSYNC `TEDAVI_GUN/SEANS` zincirleri (Gun 1-4), 168/186'nın `TOHUMLAMA_PLANLI` görevleri, 186'nın `ILERI_GEBE` instance'ı (kisir=false — K16), `tohumlama` tablosu, tamamlanmış/iptal hiçbir kayıt.
- **T-A6 (regresyon):** `tohumlama_gorev_ertele` gövdesine diff YOK (dosya değişmedi kanıtı); demo'da bir açık `TOHUMLAMA_PLANLI` görev ertelenip eski haline döndürülerek RPC akışı canlı doğrulanır; `hayvan_tohumlama_ertele` akışına dokunulmaz.
- **T-A7 (tersine çevrilebilirlik):** `UREME_TEMIZLIK` satırının `snapshot.guncellenen` listesindeki her id için §7'deki geri-açma SQL'i çalıştırılabiliyor (koşum sonrası boş bir demo hayvanla prova; gerçek geri-dönüş §7 ile).
- **T-A8 (demo sahipliği):** Koşum bağlantısı yalnız demo projesine (anon keyli PostgREST/Mgmt yok); prod URL'si hiçbir komutta geçmez.

---

## 7. Zarf A — geri-dönüş planı

1. **Görevleri geri aç:** `UPDATE gorev_log SET iptal=false, kapatan_ref=NULL WHERE id IN (<UREME_TEMIZLIK snapshot.guncellenen 'tablo=gorev_log' id listesi>);`
2. **Instance'ları geri aç:** `UPDATE protokol_instance SET durum='aktif', kapandi_at=NULL, kapandi_sebep=NULL WHERE id IN (<protokol_instance id listesi>);`
3. `UREME_TEMIZLIK` islem_log satırı **silinmez** (audit izi; yeniden koşum yeni satır açar).
4. **RPC kalkışı (isteğe bağlı):** `DROP FUNCTION IF EXISTS public.ureme_temizlik_reconcile(boolean, text[]);` — tek-seferlik araçtır; geri-dönüş migration dosyası YAZILMAZ (repo konvansiyonu: ileri-yönlü migration geçmişi; yalnız bu branch'te uygulanmış demo'ya elle psql ile).
5. Risk tablosu: geri-açma sonrası 05:00 cron görevleri yeniden üretir (beklenen davranış — kiri geri getirir; yalnız sahibin bilinçli geri-dönüş kararında kullanılır).

---

## 8. ZARF B — Erteleme geneli tasarım kaydı (BORÇ: bu turda uygulama YOK)

> Sahip kararı: BUGS.md `BUG-ERTELEME-KURAL-GENEL` — "bu turda tam fix BEKLESİN; hedef tasarım kaydedildi: hibrit, ağırlık DB'de — kurallar `gorev_ertele_kural` tablosunda (protokol_ayar deseni), pencere/geçmiş-tarih kontrolü RPC gövdesinde, JS kopyası YASAK". Bu bölüm o kaydın uygulanabilir hâlidir.

### 8.1 Kural tablosu DDL + seed taslağı

```sql
BEGIN;

CREATE TABLE IF NOT EXISTS public.gorev_ertele_kural (
  gorev_tipi        text PRIMARY KEY,
  ertelenebilir     boolean NOT NULL DEFAULT false,
  max_erteleme_gun  integer,                          -- NULL = sınırsız (MK2: sayısal sınır yok)
  pencere_uygulanir boolean NOT NULL DEFAULT false,   -- MK1 pencere yuvarlaması yalnız tohumlama
  aciklama          text,
  guncellendi       timestamptz DEFAULT now()
);
ALTER TABLE public.gorev_ertele_kural ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gorev_ertele_kural_all ON public.gorev_ertele_kural;
CREATE POLICY gorev_ertele_kural_all ON public.gorev_ertele_kural
  FOR ALL USING (true) WITH CHECK (true);

INSERT INTO public.gorev_ertele_kural(gorev_tipi, ertelenebilir, max_erteleme_gun, pencere_uygulanir, aciklama) VALUES
  ('TOHUMLAMA_PLANLI',   true,  NULL, true,  'Mevcut pencere kuralı — tohumlama_gorev_ertele ile bit-bit aynı davranış'),
  ('OVSYNC_BASLAT',      true,  NULL, false, 'Hedef kayar; instance/kaynak_ref DEĞİŞMEZ (T-B4 çift-üretim testi kilit)'),
  ('VETERINER_KONTROL',  true,  NULL, false, 'Vet kontrol randevu kaydırma'),
  ('ILAC',               true,  NULL, false, '188 kuralı: otomatik iptal YOK, erteleme serbest'),
  ('TOHUMLAMA_HAZIRLIK', true,  NULL, false, ''),
  ('MUAYENE',            true,  NULL, false, ''),
  ('GEBELIK_KONTROL',    true,  NULL, false, ''),
  ('BESLEME',            false, NULL, false, 'Zincir bütünlüğü: ret döner'),
  ('TEDAVI_GUN',         false, NULL, false, 'Zincir bütünlüğü: seans saatleri şablondan'),
  ('TEDAVI_SEANS',       false, NULL, false, 'Zincir bütünlüğü: seans saatleri şablondan')
ON CONFLICT (gorev_tipi) DO NOTHING;

-- Yeni tipler VARSAYILAN olarak ertelenemez (beyaz liste); explicit false satırları niyet belgeler.
NOTIFY pgrst, 'reload schema';
COMMIT;
```

### 8.2 Genel RPC taslağı: `gorev_ertele(uuid, date, time) → jsonb`

Eski RPC'nin guard/audit/yapısı aynen taşınır (K1-K2); tek farklar: tip kilidi kural tablosundan, pencere yuvarlama koşullu, `islem_log` tipi `GOREV_ERTELE`.

```sql
CREATE OR REPLACE FUNCTION public.gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 VOLATILE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_g record;  v_k record;
  v_bugun date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_saat time;  v_hedef timestamptz;  v_yerel timestamp;
  v_yeni_tarih date;  v_yeni_saat time;
  v_ilk_hedef date;  v_toplam integer;  v_uyari text;
BEGIN
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_BULUNAMADI');
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_ACIK_DEGIL');
  END IF;
  SELECT * INTO v_k FROM public.gorev_ertele_kural WHERE gorev_tipi = v_g.gorev_tipi;
  IF NOT FOUND OR NOT v_k.ertelenebilir THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id,
      'sebep', 'TIP_UYGUN_DEGIL', 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF p_yeni_tarih IS NULL THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'YENI_TARIH_BOS');
  END IF;
  IF p_yeni_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih, 'bugun', v_bugun);
  END IF;

  v_saat := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
  IF v_k.pencere_uygulanir THEN
    v_hedef := public._tohumlama_pencere((p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul');
  ELSE
    v_hedef := (p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul';
  END IF;
  IF v_hedef < now() THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_saat', v_saat, 'hedef_at', v_hedef);
  END IF;
  v_yerel := v_hedef AT TIME ZONE 'Europe/Istanbul';
  v_yeni_tarih := v_yerel::date;  v_yeni_saat := v_yerel::time;

  SELECT (l.payload->>'eski_tarih')::date INTO v_ilk_hedef
    FROM public.islem_log l
   WHERE l.tip IN ('TOHUMLAMA_ERTELE', 'GOREV_ERTELE')
     AND l.ref_tablo = 'gorev_log' AND l.ref_id = p_gorev_id::text
     AND l.payload ? 'eski_tarih'
   ORDER BY l.tarih ASC, l.degisim_txid ASC NULLS LAST
   LIMIT 1;
  v_ilk_hedef := COALESCE(v_ilk_hedef, v_g.hedef_tarih, v_yeni_tarih);
  v_toplam := v_yeni_tarih - v_ilk_hedef;
  v_uyari  := CASE WHEN v_toplam > 7 THEN 'ERTELEME_7_GUN_ASILDI' END;   -- MK2 sabiti gövdede kalır

  UPDATE public.gorev_log SET hedef_tarih = v_yeni_tarih, hedef_saat = v_yeni_saat WHERE id = p_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES ('GOREV_ERTELE', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
          jsonb_build_object('gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
            'eski_tarih', v_g.hedef_tarih, 'eski_saat', v_g.hedef_saat,
            'yeni_tarih', v_yeni_tarih, 'yeni_saat', v_yeni_saat,
            'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari),
          jsonb_build_object('olusturulan', '[]'::jsonb, 'silinen', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'gorev_log', 'id', p_gorev_id::text,
              'onceki', jsonb_build_object('hedef_tarih', v_g.hedef_tarih, 'hedef_saat', v_g.hedef_saat),
              'sonraki', jsonb_build_object('hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat)))),
          format('%s görevi ertelendi: %s %s → %s %s', v_g.gorev_tipi,
            v_g.hedef_tarih, v_g.hedef_saat, v_yeni_tarih, v_yeni_saat));

  RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
    'hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat,
    'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari);
END;
$fn$;

REVOKE ALL ON FUNCTION public.gorev_ertele(uuid, date, time) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_ertele(uuid, date, time) TO authenticated;
NOTIFY pgrst, 'reload schema';
```

**S2 skeptik şartına tasarım kararı (plan-2 ile fark — gerekçeli):** Plan-2 S2/skeptik revizyon "erteleme `kapatan_ref='ERTELENDI'` ile eski görevi kapatıp yenisini açar; `protokol_instance.kaynak_ref` yeni kural tarihine güncellenmeli" der. Bu taslak onun yerine **görev-düzeyi güncelleme** (eski RPC'nin deseni) seçer ve OVSYNC_BASLAT için `kaynak_ref`'e DOKUNMAZ. Gerekçe: (a) kaynak_ref kural-tarihi ELİGİBİLİTENİN hesapladığı tarihtir; operatör ertelemesiyle üzerine yazmak kural tarihini yalan söyletir ve cron aynı gerçek kural-tarihiyle geldiğinde **ikinci instance açıp ertelemeyi geri alır** (K10: kur, açık OVSYNC_BASLAT'ı kapatıp yenisini kurar); (b) görev-düzeyi güncellemede cron aynı anahtarla NULL döner (K10 — instance var), ertelenmiş görev kalır; kural-tarihi gerçekten değişirse kur eski ertelenmiş görevi `ILK_TOH_YENI_OLAY` ile kapatıp doğrusunu kurar. Nihai koruma T-B4'tür: çift-üretim VE erteleme-geri-alımı testle kilitlenir.

### 8.3 Zarf B frontend taslağı (özet)

- `_erteleModal`: tip kilidi kalkar; modal her AÇIK görev için açılır, kural tablosu `SELECT`'i (sahip listeleme RPC'si ya da doğrudan PostgREST read — RLS `true` policy'si okumaya açık) ile "bu görev ertelenebilir mi" önizlenir; pencere önizlemesi yalnız `pencere_uygulanir` tiplerinde gösterilir.
- `_erteleKaydet`: RPC adı `gorev_ertele`'e; `toplam_erteleme_gun` toast'ta gösterilir (plan-drift D18/plan-2 §4.2-3).
- `_tohErteleBtnHtml` → `_erteleBtnHtml(t)`: kural-ertelenebilir tiplerde kartta görünür (kural cache'i sayfa başına 1 okuma).
- `_ERR_MAP` + `getUserMessage`: `GOREV_ERTELENEMEZ` → "Bu görev türü ertelenemez (kural: <sebep>)"; `GECMIS_TARIH` → "Geçmiş tarih/saat seçilemez".
- `index.html` `?v=` tek değer; `js/config.js` ve `js/forms.js:2901` dokunulmaz.

### 8.4 Zarf B kabul blokları (borç kapısı açılırsa)

- **T-B1:** Kural tablosundaki 7 beyaz tip için `gorev_ertele` başarılı; `BESLEME`/`TEDAVI_GUN`/`TEDAVI_SEANS` ve tabloda-satırı-olmayan her tip `GOREV_ERTELENEMEZ:TIP_UYGUN_DEGIL` döner.
- **T-B2 (bit-bit regresyon):** Aynı girdiyle `tohumlama_gorev_ertele` ve `gorev_ertele` bir TOHUMLAMA_PLANLI görevde aynı sonucu verir (tarih/saat/uyari); eski RPC'ye diff YOK.
- **T-B3:** MK1 pencere yuvarlaması yalnız `pencere_uygulanir=true`'da uygulanır (OVSYNC_BASLAT 10:00'ı korunur); `>7 gün` uyarısı + `toplam_erteleme_gun` dönüşte; ikinci ertelemede ilk hedef ilk islem_log'dan okunur (demo'da ilk kayıt T-A6'dan gelir; K17).
- **T-B4 (OVSYNC_BASLAT çift-üretim/geri-alım kilidi):** (a) erteleme sonrası `SELECT public._acik_disi_gorev_kur('<hayvan>');` → NULL (instance aynı); (b) kural-tarihi değişen senaryoda (test kizginlik_log insert'iyle) kur yeni görev açar ve ertelenmiş eski görev `kapatan_ref='ILK_TOH_YENI_OLAY'` ile kapanır; (c) `protokol_instance.kaynak_ref` erteleme sonrası DEĞİŞMEMİŞ olmalı.
- **T-B5:** Tamamlanmış/iptal görev ret: `GOREV_ACIK_DEGIL`; geçmiş tarih: `GECMIS_TARIH`; boş tarih: `YENI_TARIH_BOS`.
- **T-B6 (UI):** 4 farklı tipte modal açılır-ertelenir; `BESLEME` kartında buton yok; hata mesajları Türkçe sözlükten; `?v=` damgası tek değer değişti.
- **T-B7:** offline replay haritasına `gorev_ertele: ['gorev_log','islem_log']` eklendi; birim testi geçti.
- **T-B8:** db-validate PASS (data-mode on — seed satırı ekler).

### 8.5 Zarf B geri-dönüşü

`DROP FUNCTION IF EXISTS public.gorev_ertele(uuid,date,time);` + `DROP TABLE IF EXISTS public.gorev_ertele_kural;` + JS/`?v=` revert'i (ayrı revert commit'i). Ertelenmiş görevler için eski RPC'nin erteleme yolu (TOHUMLAMA_PLANLI) ya da elle `hedef_tarih/saat` geri-yazımı + islem_log kaydı.

---

## 9. Varsayımlar ve UNKNOWN kayıtları

**Varsayımlar (kanıtlı):**
- V-1: Aktif ovsync zinciri tespiti için `cases.status='active' AND protocol_family IS NOT NULL` **kod otoritesi**dir — üretim muafiyeti aynı önsözü kullanıyor (K9). [CONFIRMED] **Ancak veri çapası demo'da şu an boştur: pf NULL ×132 (K20) → yüklem canlıda 0 verir.** Kuralın hatası değil, veri borcudur (U-6/E-6); koşum planı buna göre R1=0'ı birinci senaryo sayar (§6) ve plan 0f sentetik pf kanıtıyla kuralın kendisini doğrular.
- V-2: R1⊃R2 çakışması bugünkü canlıda örneklenmedi (pf NULL iken hiçbiri R1'de değil) ama kod çakışmayı R1 lehine çözer. [INFERRED, kod-düzeyinde güvence]
- V-3: KISIR-B'nin hayvan-bazlı (instance-bağımsız) kapatması 199'un yetim zincirlerini yakalar. **Rev-2: trigger davranışı INFERRED'den OBSERVED'a çıktı (K23/K24)** — `iptal` UPDATE'ine dokunan tek tetik `trg_gorev_parent_kapandi`'dır; cascade'i yalnız çapraz-tip açık çocukları kapatır, KISIR kümesinde SEANS(çocuk)⊂GUN(ebeveyn) ilişkisi vardır ve D-2 sıralamasıyla cascade no-op'a düşer; `cycle_guard` INSERT-only, `asip_iade` hedef tiplerde eşleşmez, `degisim_log` yalnız audit yazar.
- V-4: Temizlik sonrası S-4/S-2'nin view değişikliği bu hayvanları sessiz üretimden düşürür (sahibin tanımı: ovsync tedavisinde olan sessiz sayılmaz; S-2 kapsamı yalnız Boş+durumu-bilinmeyen — Bekliyor ≥40g ayrı gebelik-muayenesi görevine gider). S-4 bunu garanti etmezse T-A4 kalıcı olarak fail eder → S-4'e kesin gereksinim olarak yansıtılmalı. Demo'da yeniden üretim vektörü elle çağrıdır (K18). [INFERRED]

**UNKNOWN:**
- **U-1:** 199'un açık TEDAVI görevlerinin `protokol_instance_id` değerleri kapandı instance'a mı bağlı, NULL mu (temizliği etkilemez — KISIR-B hayvan-bazlı; dry-run raporunda görünür).
- **U-2:** 186'nın aktif `ILERI_GEBE` instance'ının kaynağı (kisir=false + tdm='gebe' kombinasyonu) — KISIR kapsamı DIŞI; `NOT-KISIR-GEBE-OTORITE` normalizasyonuna kalır.
- **U-3:** `sessiz_gun=9999` ("hiç kayıt yok"; sentezde 906/2044) hayvanların bugünkü açık görev durumu — Adım 0 taze ölçümü.
- **U-4:** R2'nin `sonuc='Abort'`/`'Boş'` hayvanlarda davranışı: bu spec'te dokunulmaz (R2 yalnız Gebe/Bekliyor); kapsamı S-4'ün üçlü sınıflandırması belirler.
- **U-5:** `gorev-orphan-temizle`'nin `v_orphan_gorev` kümesinin KISIR-R1/R2 hedefleriyle kesişimi (kesişirse çifte `kapatan_ref` yazımı: son yazar kazanır — zararsız ama raporda notlanır; demo'da cron yoksa yalnız elle çağrı riski).
- **U-6 (Rev-2, veri-borcu):** demo `cases.protocol_family` neden NULL ×132? (demo klonlama/restore pf verisini taşımıyor olabilir; ilk ölçümde dolu görünmesi bir lane'in demo yazımıyla da açıklanamaz — iki ölçüm arasındaki 25 dakikada demo refresh olmuş olabilir). R32 üretim muafiyeti + R1 + S-4 view fix'i bu kolona dayanır; **boş kaldığı sürece 168/186 tipi çakışma demo'da çözülmez.** Sahibin pf veri-borcu kararı: demo'ya pf backfill mi, klonlama-borcu kaydı mı? [UNKNOWN — bu tura dokunulmaz]

---

## 10. Engeller ve bağımlılık kayıtları (orchestrator'a)

- **E-1 (sıra bağımlılığı — en kritik):** Temizlik koşumu Adım 1 (kısır blok) + Adım 2 (S-4 view) demo'ya uygulanmadan yapılırsa kapatılan görevler yeniden üretilir — PROD'da 05:00 cron'la (K7), **demo'da pg_cron yokken elle `sessiz_hayvanlar_reconcile()` çağrısıyla** (K18 + K13 taze kanıtı). Koşum Adım 1-2 sonrasına ÇEKİLMELİ; dry-run ise her zaman güvenle koşulabilir (salt-okunur).
- **E-2 (bayat ölçüm):** §6 taban çizgisi Rev-2 (23:15) ölçümüdür; koşum günü taze dry-run esas alınır (R1=0 senaryosu dahil).
- **E-3 (kapı ortamı):** db-validate çalışma dizini kökünde `.env` arar; worktree'de yok. Workaround mini-körök (~/tmp) kullanıldı; implementer kendi .env'iyle final dosyayı yeniden koşmalı. **Düzeltme: ana checkout `.env`'inde `SUPABASE_DEMO_DB_URL` diye bir değişken YOK; gerçek değişkenler `SUPABASE_DEMO_REF` + `SUPABASE_DEMO_POOLER` + `SUPABASE_DEMO_DB_PASSWORD`'dir — psql URL'si bunlardan kurulur (plan Adım 2-6'da uygulanmıştır).**
- **E-4 (C2 tohum kısıtı):** Validator'un `islem_log` sentetik-tohum üretimi `VALUES ()` syntax hatası veriyor (araç kısıtı); C1 apply PASS + C2 apply PASS ile telafi edildi; finalde aynı kısıt tekrarlarsa INCONCLUSIVE-with-C1-PASS kabul kriteridir.
- **E-5 (Zarf B kapısı):** Erteleme geneli sahibin açık borç kararındadır (BUGS.md `BUG-ERTELEME-KURAL-GENEL`, satır 183 — 23:10 doğrulandı). Bu spec Zarf B'yi UYGULAMAZ; kapı sahibin "borç aç" kararıyla.
- **E-6 (Rev-2, R1 veri sürüklenmesi):** demo `cases.protocol_family` NULL ×132 (K20) → R1 canlıda 0; 168/186 görevleri R2-dışı da (K21) → beklenen koşum 30 kayıt. Bu ENGEL DEĞİLDİR (veri gerçeği); plan 0f sentetik kanıt + rapor notu ile işler; kalıcı çözüm U-6'da sahibin kararıdır.
- **E-7 (Rev-2, kör kapı):** demo `schema_migrations` bayat (üst: 20260706052550) ve ham psql apply kayıt yazmaz (K22) → S1/S2 apply kontrolü yalnız davranışsal kanıtla yapılır (spec §4.1).
- **E-8 (Rev-2, trigger cascade):** `_trg_gorev_parent_kapandi` çapraz-tip çocukları kapatır (K23); taslağa D-2 sıralaması işlendi, final db-validate zaten zorunlu.

---

*Spec sonu — yazma yetkisi bu dosyayla sınırlıydı; hiçbir kod/migration dosyasına dokunulmadı (taslak SQL, db-validate koşumu için ~/tmp altına yazıldı; rapor ~/tmp altında).*
