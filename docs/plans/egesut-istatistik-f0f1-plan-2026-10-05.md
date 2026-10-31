# İstatistik Modülü F0+F1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Tarih:** 2026-10-05 · **Yazar:** ss-mimar (oturum 4fa30ecb) · **Dal:** `istatistik-modülü` · **Durum:** TASLAK — root yürütür (sahip kararı: implementasyon root'ta)

**Goal:** Eski `stat-hesapla` Edge Function emekli edilir, istatistik iskeleti (3 tablo + `v_stat_vaka`) kurulur ve tedavi pilotunun üç SQL ölçümü RPC + ekran iskeletiyle demo'da çalışır hâle gelir.

**Kapsam notu (sahip 2026-10-05):** Bu plan backend + DB + çekirdek UI içindir. T8 ekranı yalnız doğrulama iskeletidir (ölçümlerin ekranda okunabilmesi ve UI testi kapısı için); görsel tasarım, grafik kütüphanesi (A1) ve yükleme ekranları AYRI UI spec'i ve brainstorming ile gelir. T8'de tasarım kararı verilmez, mevcut ovsync kalıbı kopyalanır.

**Architecture:** Her ölçüm Postgres'te tek bir `STABLE SECURITY INVOKER` SQL fonksiyonudur ve §8.1 zarfını (`n`, `yetersiz`, `x`, `seriler`, `tablo`, `dipnot`) döner. Ekran bu zarfı olduğu gibi tabloya basar; hesap yapmaz. Motor (F2) bu planda yok; yalnız yazacağı tablolar (`stat_analiz_sonuc`, `stat_motor_kosum`) açılır.

**Tech Stack:** PostgreSQL (plpgsql/SQL, Supabase), vanilla JS (`js/api.js`, `js/ui.js`, `js/app.js`, `index.html`), `node --test` birim testleri, `psql -f` SQL test betikleri, `scripts/db-validate.sh`.

**Spec:** `docs/2026-10-05-istatistik-modulu-spec.md` (ONAYLI v1; bu plan §3.4, §4.3, §5, §8, §9 F0+F1, §10, §11'i uygular). Plan maddeleri `P1…P10`; her görev bir maddeye referans verir (PLAN DRIFT KAPISI).

## Global Constraints

- Yeni tablolar: `farm_id uuid NOT NULL DEFAULT '<varsayılan farm_id>'` + `(farm_id, …)` index; RLS açık, policy `FOR ALL USING (true)`; FK yok (domain-rules §14). Eski tablolardan türeyen view/ölçümde farm filtresi yok (spec K14).
- Her SQL fonksiyon: `STABLE`, `SECURITY INVOKER`, `SET search_path = public, pg_temp`; `REVOKE ALL ON FUNCTION … FROM PUBLIC, anon;` + `GRANT EXECUTE … TO authenticated;` (anon'a hiçbir GRANT yok — hafıza "anon EXECUTE açığı"; mevcut repo kalıbı DEFINER'dır, spec §5.1 INVOKER'ı bağlar).
- Migration adı `2026100500000N_<ad>.sql` (son mevcut `20261002000002`); her migration `bash scripts/db-validate.sh <dosya> --priors <önceki yeni migration'lar>` → exit 0 (PASS) olmadan commit edilmez (hafıza "db-validation kapısı"). Rapor `reports/db-validation-<sha8>.md` `git add -f` ile.
- "Bugün" SQL'de `(now() AT TIME ZONE 'Europe/Istanbul')::date`; `CURRENT_DATE` yasak (hafıza "TZ CURRENT_DATE sunucu dersi").
- `treatment_days`, `cases`, `drug_administrations` satırları hiçbir görevde değiştirilmez (domain-rules §13.9); bu plan yalnız okur.
- Yetersiz veri: `n < 5` → değer alanları `null`, `"yetersiz": true` (spec K8); eşik fonksiyon içinde sabit `5`.
- Zarf (spec §8.1) alanları birebir: `olcum, hesap_at, surum, n, yetersiz, x{ad,deger}, seriler[{ad,n,y,alt,ust}], tablo[], dipnot[]`; `surum` SQL ölçümde `'sql:<migration no>'`.
- Fail-closed: geçersiz parametre (`p_bitis < p_baslangic`, tanınmayan `p_filtre` anahtarı, tanınmayan ölçüm adı) `RAISE EXCEPTION`; boş sonuç başarı değildir.
- JS: HTML'e basılan her değer `escHtml`/`escAttr` ile (güvenlik review 2026-07-10); `index.html` `?v=` damgası tek değere bump edilir (test `tests/unit/coklu-kaydir-ui.test.js:597` korur).
- git: `git add <dosya>` dosya dosya; `-A`/`.` yasak. Push yalnız `ss-merge-gate`. Prod DB'ye uygulama bu planın dışı (yedek + kırıntı + root; hafıza "p5b prod teslimi").
- Demo DB bağlantısı `OVS_DEMO_DB_URL` ortam değişkeni (ref `vtzqjmazsvurxdeondmi`); test fixture'ları `E2E-STAT-` önekli, betik başında ve sonunda silinir (idempotent). Sahip demo şifresine dokunulmaz.

## Review Focus

Spec'in ima ettiği ama hiçbir görev testinin kendiliğinden kapsamadığı beş girdi sınıfı; her biri ilgili görevin testine eklendi:

1. **Yıllardır açık kalmış vaka** (`status='active'`, `start_date` 2 yıl önce): `sonuc='devam'`, `sansur=true`, `olay_gun` = bugün − başlangıç; ekran "devam" sayısını ayrı gösterir, iyileşme yüzdesine katmaz → P3 T3 test `devam_eski`.
2. **30 gün içinde satış çıkışı** (`cikis_tipi='satis'`): ölüm değildir → `iyilesti`; yalnız `olum|kesim` → `oldu_kesildi` → P3 T3 test `satis_iyilesti`.
3. **Hiç ilaç uygulanmamış kapalı vaka**: `ilk_uygulama/son_uygulama/tedavi_suresi_gun NULL`, `protokol = '{}'`, `protokol_uyum NULL` (sıfıra bölme yok); ozet medyanı bu vakayı tedavi süresine katmaz → P3 T3 test `ilacsiz`, P5 T5 test `ozet_ilacsiz`.
4. **Bozuk tarih sırası** (`closed_at::date < start_date`): `vaka_suresi_gun NULL` (negatif süre basılmaz), vaka `n`'e girer ama süre dağılımına girmez → P3 T3 test `ters_tarih`.
5. **Geçersiz çağrı**: `p_bitis < p_baslangic`, `p_filtre` içinde bilinmeyen anahtar (`{"hastalk": …}`): `RAISE EXCEPTION`, sessiz boş zarf yok → P5 T5 test `gecersiz_param`.

**Ekran akışı (hafıza "UI akış yürüyüşü zorunlu"):**

```mermaid
flowchart LR
    D["Panel (pg-dash) kartı: İstatistik"] -->|goTo('istatistik')| P["pg-istatistik"]
    P --> L["stat_olcum_listele() → ölçüm sekmeleri"]
    L --> F["Dönem (başlangıç/bitiş) + hastalık filtresi"]
    F -->|"stat_tedavi_<olcum>(p_baslangic,p_bitis,p_filtre)"| Z["zarf (§8.1)"]
    Z -->|"yetersiz=true"| Y["'Yetersiz veri (n<5)' rozeti"]
    Z -->|"yetersiz=false"| T["tablo + dipnot + hesap_at"]
    Z -->|"hata"| E["Hata şeridi, eski tablo kalır"]
```

---

## Dosya yapısı

| Dosya | Görev | Sorumluluk |
|---|---|---|
| `supabase/config.toml:398-404` | T1 | `stat-hesapla` `enabled=false` |
| `supabase/functions/_archive/stat-hesapla/` | T1 | emekli klasör (git mv) |
| `supabase/migrations/20261005000001_stat_iskelet.sql` | T2 | `stat_olcum_kayit`, `stat_analiz_sonuc`, `stat_motor_kosum` |
| `supabase/migrations/20261005000002_v_stat_vaka.sql` | T3 | `v_stat_vaka` view |
| `supabase/migrations/20261005000003_stat_tedavi_ozet.sql` | T5 | `stat_zarf_bos`, `stat_olcum_listele`, `stat_sonuc_oku`, `stat_tedavi_ozet` + kayıt satırları |
| `supabase/migrations/20261005000004_stat_tedavi_protokol.sql` | T6 | `stat_tedavi_protokol`, `stat_tedavi_sure_dagilim` + kayıt satırları |
| `tests/sql/stat_vaka_test.sql` | T3, T4 | fixture + `v_stat_vaka` sonuç doğrulama + 10 vaka örnekleme çıktısı |
| `tests/sql/stat_tedavi_test.sql` | T5, T6 | fixture ile ölçüm sayıları |
| `js/api.js` | T7 | `statOlcumListele`, `statOlcumCagir`, `statSonucOku` |
| `tests/unit/stat-api.test.js` | T7 | sarmalayıcı birim testi (mock `db.rpc`) |
| `js/ui.js` | T8 | `loadIstatistik`, `_istatistikTabloHtml`, `_istatistikZarfHtml` |
| `js/app.js:131-139` | T8 | `goTo` dalı `istatistik` |
| `index.html` | T8 | `pg-istatistik` paneli, dashboard kartı, `?v=` bump |
| `tests/unit/stat-ui.test.js` | T8 | saf HTML üreticileri |
| `runs/2026-10-05-istatistik-modulu/f0f1/` | T4, T9, T10 | örnekleme kaydı, UI test zarfı/raporu, DONE |

---

### Task 1: `stat-hesapla` emekli (P1 — spec §3.4, K13)

**Files:**
- Modify: `supabase/config.toml:398-404`
- Move: `supabase/functions/stat-hesapla/` → `supabase/functions/_archive/stat-hesapla/`

**Interfaces:** Produces: hiçbir js/ dosyası `stat-hesapla` çağırmaz (CONFIRMED önceki keşif); sonraki görevler bu klasöre dokunmaz.

- [ ] **Step 1: Çağıran yok doğrulaması**

Run: `grep -rn "stat-hesapla\|stat_hesapla" js/ index.html tests/ | grep -v _archive`
Expected: boş çıktı (bir satır bile çıkarsa dur, ruling yaz).

- [ ] **Step 2: config.toml düzenle**

`supabase/config.toml:399` → `enabled = false`; bloğun üstüne tek satır yorum: `# 2026-10-05 emekli (spec K13, docs/2026-10-05-istatistik-modulu-spec.md §3.4)`.

- [ ] **Step 3: Klasörü arşive taşı**

Run: `mkdir -p supabase/functions/_archive && git mv supabase/functions/stat-hesapla supabase/functions/_archive/stat-hesapla`
Expected: `git status --short` iki `R` satırı + `M supabase/config.toml`.

- [ ] **Step 4: Birim testleri hâlâ yeşil**

Run: `npm run test:unit`
Expected: önceki koşumla aynı pass sayısı, 0 fail.

- [ ] **Step 5: Commit**

```bash
git add supabase/config.toml supabase/functions/_archive/stat-hesapla supabase/functions/stat-hesapla
git commit -m "istatistik F0: stat-hesapla edge function emekli (K13)"
```

---

### Task 2: İskelet tabloları (P2 — spec §4.3, §5.1 `stat_olcum_kayit`)

**Files:**
- Create: `supabase/migrations/20261005000001_stat_iskelet.sql`
- Test: `scripts/db-validate.sh`

**Interfaces:** Produces:
- `stat_olcum_kayit(id bigint identity PK, farm_id uuid, ad text UNIQUE, alan text, baslik text, aciklama text, tip text CHECK IN ('sql','motor'), surum text, aktif boolean DEFAULT true, sira int DEFAULT 100)`
- `stat_analiz_sonuc(id bigint identity PK, farm_id uuid, olcum text, anahtar jsonb NOT NULL DEFAULT '{}', sonuc jsonb NOT NULL, girdi_ozeti text, hesap_at timestamptz NOT NULL DEFAULT now(), motor_surum text, UNIQUE (farm_id, olcum, anahtar))`
- `stat_motor_kosum(id bigint identity PK, farm_id uuid, baslangic_at timestamptz NOT NULL DEFAULT now(), bitis_at timestamptz, durum text CHECK IN ('ok','hata','atlandi'), mesaj text, degisen_kaynaklar jsonb, surum text)`
- GRANT: `SELECT` üçüne `authenticated`; `INSERT/UPDATE` yok (motor rolü F2'de). `anon`'a hiçbir şey.

- [ ] **Step 1: Migration yaz**

Üç `CREATE TABLE IF NOT EXISTS`, her birine `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `DROP POLICY IF EXISTS <t>_all; CREATE POLICY <t>_all ON <t> FOR ALL USING (true)`; index `(farm_id, olcum)` (`stat_analiz_sonuc`), `(farm_id, baslangic_at DESC)` (`stat_motor_kosum`), `(farm_id, aktif, sira)` (`stat_olcum_kayit`). `COMMENT ON TABLE` her birine spec §4.3 tek cümle.

- [ ] **Step 2: db-validate**

Run: `bash scripts/db-validate.sh supabase/migrations/20261005000001_stat_iskelet.sql`
Expected: exit 0, rapor `reports/db-validation-<sha8>.md` içinde `PASS`. İkinci kez aynı dosya (idempotentlik): yine exit 0.

- [ ] **Step 3: Demo'ya uygula ve tekillik kapısını gör**

Run: `psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20261005000001_stat_iskelet.sql` sonra
`psql "$OVS_DEMO_DB_URL" -X -c "insert into stat_analiz_sonuc(olcum,anahtar,sonuc) values ('t','{}','{}'),('t','{}','{}')"`
Expected: ikinci insert `duplicate key value violates unique constraint`. Temizlik: `delete from stat_analiz_sonuc where olcum='t'`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20261005000001_stat_iskelet.sql
git add -f reports/db-validation-<sha8>.md
git commit -m "istatistik F0: stat_olcum_kayit, stat_analiz_sonuc, stat_motor_kosum iskeleti"
```

---

### Task 3: `v_stat_vaka` view (P3 — spec §5.2)

**Files:**
- Create: `supabase/migrations/20261005000002_v_stat_vaka.sql`
- Create: `tests/sql/stat_vaka_test.sql`

**Interfaces:**
- Consumes (CONFIRMED GT:3530-3604, M0923:335-338): `cases(id, animal_id, disease_id, start_date, status, closed_at, source_template_id, protocol_family)`, `treatment_days(id, case_id, day_no, treatment_date, tamamlandi)`, `drug_administrations(treatment_day_id, drug_product_id, dose, unit, route, uygulanmadi)`, `drug_products(id, name, drug_class_id)`, `drug_classes(id, name)`, `diseases(id, name, category)`, `hayvanlar(id, cikis_tipi, cikis_tarihi)`, `stok(maliyet)` ← `drug_products` bağı (`stok_id`? önce kolonu doğrula; yoksa `maliyet_tl` bu görevde `NULL` döner ve ruling yazılır).
- Produces: `public.v_stat_vaka` (`WITH (security_invoker = true)`), kolonlar spec §5.2 tablosu birebir: `vaka_id uuid, hayvan_id text, hastalik text, kategori text, protokol_ailesi text, baslangic date, kapanis date, vaka_suresi_gun int, ilk_uygulama date, son_uygulama date, tedavi_suresi_gun int, uygulanan_gun int, plan_gun int, protokol_uyum numeric(5,3), protokol text[], protokol_sinif text[], sonuc text, olay_gun int, sansur boolean, maliyet_tl numeric(12,2)`. `GRANT SELECT ON v_stat_vaka TO authenticated`.

- [ ] **Step 1: A3 canlı doğrulama (salt-okuma)**

Run (demo + prod salt-okuma, hafıza "canlı şema doğrulama Mgmt API"): `select cikis_tipi, count(*) from hayvanlar group by 1`
Expected: değer kümesi ⊆ `{olum, satis, kesim, kayip, NULL}`. Dışında değer varsa dur: progress.md'ye `Ruling:` yaz, view'daki `IN ('olum','kesim')` kümesini ona göre genişlet.

- [ ] **Step 2: Test betiğini yaz (önce kırmızı)**

`tests/sql/stat_vaka_test.sql`, `ovsync_takip_test.sql` kalıbı (`\echo`, geçici `_stat_durum(kod, deger, etiket)`, `ovs_fixture_ok` yerine `stat_fixture_ok`). Fixture: `E2E-STAT-` küpeli 6 hayvan, 7 vaka, aynı `disease_id` (Mastit):
- `iyilesti_temiz`: closed, 3 uygulama günü, çıkış yok → `sonuc='iyilesti'`, `tedavi_suresi_gun=3`, `olay_gun=vaka_suresi_gun`, `sansur=false`
- `oldu_10gun`: closed, hayvan `cikis_tipi='olum'`, `cikis_tarihi = kapanis+10` → `oldu_kesildi`
- `kesim_aktif`: active, `cikis_tipi='kesim'` → `oldu_kesildi`, `sansur=false`
- `nuks_20gun`: closed; aynı hayvan aynı hastalık ikinci vaka `start_date = kapanis+20` → ilk vaka `nuks`
- `satis_iyilesti` (Review Focus 2): closed, `cikis_tipi='satis'`, `cikis_tarihi=kapanis+5` → `iyilesti`
- `devam_eski` (RF 1): active, `start_date = bugün − 730` → `devam`, `sansur=true`, `olay_gun=730`
- `ilacsiz` (RF 3): closed, `treatment_days` var ama tüm `drug_administrations.uygulanmadi=true` → `ilk_uygulama IS NULL`, `protokol='{}'`, `protokol_uyum IS NULL`
- `ters_tarih` (RF 4): `closed_at::date = start_date − 2` → `vaka_suresi_gun IS NULL`, `sonuc='iyilesti'`

Her beklenti `_stat_durum`'a `PASS`/`FAIL` satırı; sonda `select * from _stat_durum`; betik sonu fixture temizliği (`E2E-STAT-%`).

- [ ] **Step 3: Kırmızı koş**

Run: `psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_vaka_test.sql`
Expected: `relation "v_stat_vaka" does not exist`.

- [ ] **Step 4: Migration yaz**

`CREATE OR REPLACE VIEW v_stat_vaka WITH (security_invoker = true) AS …`. `sonuc` için `CASE` sırası spec §5.2 birebir (1 oldu_kesildi, 2 nuks, 3 iyilesti, 4 devam). `kapanis = closed_at::date`; `vaka_suresi_gun = CASE WHEN kapanis >= baslangic THEN kapanis − baslangic END`; `olay_gun = CASE WHEN sonuc='oldu_kesildi' THEN cikis_tarihi − baslangic WHEN sonuc='nuks' THEN (ikinci vaka start_date) − baslangic WHEN sonuc='iyilesti' THEN vaka_suresi_gun ELSE bugün − baslangic END`. `uygulanmadi=false` filtresi ilk/son uygulamada; `protokol` = `array_agg(DISTINCT drug_products.name ORDER BY …)`; `plan_gun = count(treatment_days)`; `protokol_uyum = uygulanan_gun::numeric / NULLIF(plan_gun,0)`. `COMMENT ON VIEW` spec §5.2 sınırlama cümlesi (şiddet alanı yok; cikis_tipi kümesi).

- [ ] **Step 5: db-validate + demo uygula + yeşil koş**

Run: `bash scripts/db-validate.sh supabase/migrations/20261005000002_v_stat_vaka.sql --priors supabase/migrations/20261005000001_stat_iskelet.sql` → exit 0;
`psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=1 -f supabase/migrations/20261005000002_v_stat_vaka.sql`;
test betiği tekrar → `_stat_durum`'da 8/8 `PASS`, `FAIL` yok.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20261005000002_v_stat_vaka.sql tests/sql/stat_vaka_test.sql
git add -f reports/db-validation-<sha8>.md
git commit -m "istatistik F0: v_stat_vaka view + sonuç kuralı testleri (K7-K9)"
```

---

### Task 4: F0 kabulü — 10 vaka elle örnekleme (P4 — spec §9 F0 kabul, §11 risk 1)

**Files:**
- Modify: `tests/sql/stat_vaka_test.sql` (sonuna `\echo '--- ORNEKLEME'` bölümü; `stat_fixture_ok=false` iken de koşar)
- Create: `runs/2026-10-05-istatistik-modulu/f0f1/f0-ornekleme.md`

**Interfaces:** Consumes `v_stat_vaka` (T3).

- [ ] **Step 1: Örnekleme sorgusunu ekle**

`select vaka_id, hayvan_id, hastalik, baslangic, kapanis, sonuc, olay_gun, protokol from v_stat_vaka where kapanis is not null order by md5(vaka_id::text) limit 10` + her vaka için kanıt satırı: `hayvanlar.cikis_tipi/cikis_tarihi`, aynı hayvanın sonraki aynı-hastalık vakası `start_date`.

- [ ] **Step 2: Demo'da koş, dağılımı gör**

Run: `psql "$OVS_DEMO_DB_URL" -X -v stat_fixture_ok=false -f tests/sql/stat_vaka_test.sql | sed -n '/ORNEKLEME/,$p'`
ve `select sonuc, count(*) from v_stat_vaka group by 1`.
Expected: 10 satır; `sonuc` dağılımı dört değerden en az ikisini içerir. Yalnız tek değer (`devam` ya da `iyilesti`) çıkarsa spec §11 risk 1 gerçekleşmiştir: dur, `Ruling:` + sahibe `SORU:`.

- [ ] **Step 3: Elle doğrula ve kaydet**

10 satırın her biri için kanıt satırıyla kuralın (spec §5.2 sırası) tutup tutmadığı `f0-ornekleme.md` tablosuna `TUTUYOR/TUTMUYOR` yazılır; `TUTMUYOR` varsa T3 Step 4'e geri dönülür (view düzeltme, test ekleme). Kabul: 10/10 `TUTUYOR`.

- [ ] **Step 4: Commit**

```bash
git add tests/sql/stat_vaka_test.sql runs/2026-10-05-istatistik-modulu/f0f1/f0-ornekleme.md
git commit -m "istatistik F0 kabul: 10 vaka elle örnekleme kaydı"
```

---

### Task 5: Zarf yardımcısı, kayıt/okuma RPC'leri, `stat_tedavi_ozet` (P5 — spec §5.1, §5.3, §8)

**Files:**
- Create: `supabase/migrations/20261005000003_stat_tedavi_ozet.sql`
- Create: `tests/sql/stat_tedavi_test.sql`

**Interfaces:**
- Consumes: `v_stat_vaka` (T3), `stat_olcum_kayit`, `stat_analiz_sonuc` (T2).
- Produces:
  - `stat_zarf_bos(p_olcum text, p_surum text, p_n int, p_dipnot text[]) RETURNS jsonb` — §8.1 zarfı, `yetersiz = (p_n < 5)`, `x/seriler/tablo` boş.
  - `stat_filtre_dogrula(p_filtre jsonb, p_izinli text[]) RETURNS void` — izinli dışı anahtar → `RAISE EXCEPTION 'stat: bilinmeyen filtre anahtarı %'`.
  - `stat_donem_dogrula(p_baslangic date, p_bitis date) RETURNS void` — `p_bitis < p_baslangic` ya da NULL → `RAISE EXCEPTION`.
  - `stat_olcum_listele() RETURNS jsonb` — `stat_olcum_kayit` `aktif` satırları `sira` sırasıyla `[{ad, alan, baslik, aciklama, tip, surum}]`; `farm_id = current_farm_id()`.
  - `stat_sonuc_oku(p_olcum text, p_anahtar jsonb DEFAULT '{}') RETURNS jsonb` — `stat_analiz_sonuc` tek satır `sonuc` + `hesap_at`; yoksa `stat_zarf_bos(p_olcum,'motor:-',0, ARRAY['Henüz hesaplanmadı'])`.
  - `stat_tedavi_ozet(p_baslangic date, p_bitis date, p_filtre jsonb DEFAULT '{}') RETURNS jsonb` — izinli filtre anahtarları `hastalik, kategori`; vaka seçimi `baslangic BETWEEN p_baslangic AND p_bitis`; `tablo` satırı hastalık başına: `{hastalik, n, devam_n, iyilesme_pct, nuks_pct, olum_pct, vaka_suresi_medyan, tedavi_suresi_medyan, maliyet_ort}`; yüzdeler yalnız `sonuc <> 'devam'` paydasıyla; medyanlar `percentile_cont(0.5)`; `n<5` satırda değerler `null` + satır `yetersiz:true`; toplam `n` zarfta; `surum='sql:20261005000003'`; `dipnot` spec §5.2 sınırlama cümleleri (2 satır).
  - Kayıt satırları: `stat_olcum_kayit` upsert (`ON CONFLICT (ad)`): `stat_tedavi_ozet` (sql, aktif), `stat_tedavi_protokol`, `stat_tedavi_sure_dagilim` (sql, aktif — gövde T6'da; T6 öncesi ekran "ölçüm yok" döner, kabul edilir), `stat_tedavi_sagkalim`, `stat_tedavi_protokol_fark` (motor, `aktif=false`).
  - Hepsi `STABLE SECURITY INVOKER SET search_path = public, pg_temp`; `REVOKE … FROM PUBLIC, anon; GRANT EXECUTE … TO authenticated`.

- [ ] **Step 1: Test betiğini yaz (kırmızı)**

`tests/sql/stat_tedavi_test.sql`: T3 fixture'ını yeniden kurar (aynı `E2E-STAT-` kümesi; ortak fixture bloğu `\i` ile değil kopya olarak — betikler bağımsız koşar) + Mastit dışı `Pnömoni` 2 vaka. Beklentiler:
- `ozet_n`: `stat_tedavi_ozet(bugün−800, bugün, '{"hastalik":"Mastit"}')` → `n = 8`, `tablo[0].iyilesme_pct` = iyilesti sayısı / (8 − devam_n) × 100 (fixture'dan sabit sayı yaz), `yetersiz=false`
- `ozet_yetersiz`: `'{"hastalik":"Pnömoni"}'` → `n=2`, `yetersiz=true`, `tablo[0].iyilesme_pct IS NULL`
- `ozet_ilacsiz` (RF 3): `tedavi_suresi_medyan` `ilacsiz` vakayı saymaz (fixture sayısıyla sabit)
- `gecersiz_param` (RF 5): `stat_tedavi_ozet(bugün, bugün−1, '{}')` ve `… '{"hastalk":"x"}'` → her ikisi `EXCEPTION` (`DO $$ BEGIN … EXCEPTION WHEN OTHERS THEN PASS END $$`)
- `listele`: `stat_olcum_listele()` → `jsonb_array_length = 3`, ilk `ad = 'stat_tedavi_ozet'`
- `sonuc_yok`: `stat_sonuc_oku('stat_tedavi_sagkalim')` → `yetersiz=true`, `dipnot[0]='Henüz hesaplanmadı'`
- `anon_yok`: `select has_function_privilege('anon','stat_tedavi_ozet(date,date,jsonb)','EXECUTE')` → `false`; aynı sorgu `authenticated` → `true`

- [ ] **Step 2: Kırmızı koş**

Run: `psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_tedavi_test.sql`
Expected: `function stat_tedavi_ozet… does not exist`.

- [ ] **Step 3: Migration yaz**

İmzalar yukarıdaki Interfaces bloğu. `stat_tedavi_ozet` gövdesi: `stat_donem_dogrula` → `stat_filtre_dogrula(p_filtre, ARRAY['hastalik','kategori'])` → `WITH v AS (select * from v_stat_vaka where baslangic between … and (p_filtre->>'hastalik' is null or hastalik = p_filtre->>'hastalik') and (… kategori …))` → gruplama → `jsonb_build_object` ile zarf.

- [ ] **Step 4: db-validate + demo uygula + yeşil**

Run: `bash scripts/db-validate.sh supabase/migrations/20261005000003_stat_tedavi_ozet.sql --priors supabase/migrations/20261005000001_stat_iskelet.sql supabase/migrations/20261005000002_v_stat_vaka.sql` → exit 0; demo'ya `psql -f`; test betiği → 7/7 `PASS`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261005000003_stat_tedavi_ozet.sql tests/sql/stat_tedavi_test.sql
git add -f reports/db-validation-<sha8>.md
git commit -m "istatistik F1: zarf yardımcıları, stat_olcum_listele/stat_sonuc_oku, stat_tedavi_ozet"
```

---

### Task 6: `stat_tedavi_protokol`, `stat_tedavi_sure_dagilim` (P6 — spec §5.3)

**Files:**
- Create: `supabase/migrations/20261005000004_stat_tedavi_protokol.sql`
- Modify: `tests/sql/stat_tedavi_test.sql`

**Interfaces:**
- Consumes: T5 yardımcıları, `v_stat_vaka.protokol`, `protokol_sinif`, `protokol_uyum`, `tedavi_suresi_gun`.
- Produces:
  - `stat_tedavi_protokol(p_baslangic date, p_bitis date, p_filtre jsonb DEFAULT '{}') RETURNS jsonb` — izinli filtre `hastalik, kategori, duzey` (`duzey ∈ {'urun','sinif'}`, varsayılan `urun`; başka değer → EXCEPTION); `tablo` satırı hastalık × protokol (`array_to_string(protokol,' + ')`): T5 ozet kolonları + `protokol_uyum_ort`; `dipnot` += `'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır; neden-sonuç değildir.'`
  - `stat_tedavi_sure_dagilim(p_baslangic date, p_bitis date, p_filtre jsonb DEFAULT '{}') RETURNS jsonb` — izinli filtre `hastalik` (**zorunlu**; yoksa EXCEPTION `'stat: hastalik filtresi zorunlu'`), `protokol` (isteğe bağlı, tam eşleşme); `x = {ad:'gün', deger:[1..maks]}`; `seriler[]` protokol başına `{ad, n, y: histogram sayıları, alt:[], ust:[]}` + `tablo` satırı `{protokol, n, q1, medyan, q3}` (`percentile_cont(0.25/0.5/0.75)`); `tedavi_suresi_gun IS NULL` vakalar dışarıda (`dipnot`'a "ilaç uygulaması olmayan k vaka dahil edilmedi").

- [ ] **Step 1: Testleri ekle (kırmızı)**

`stat_tedavi_test.sql`'e: `protokol_satir` (Mastit, `duzey=urun` → fixture'daki ayrık protokol sayısı kadar satır; her satır `n` toplamı 8), `protokol_duzey_gecersiz` (`duzey='x'` → EXCEPTION), `sure_hastalik_zorunlu` (`'{}'` → EXCEPTION), `sure_histogram` (Mastit → `x.deger[0]=1`, `seriler` toplam `y` = tedavi süresi NULL olmayan vaka sayısı, `tablo[0].medyan` fixture sabiti).

- [ ] **Step 2: Kırmızı koş**

Run: T5 Step 2 komutu. Expected: yeni 4 kalem `FAIL`/`does not exist`, eski 7 `PASS`.

- [ ] **Step 3: Migration yaz**

İmzalar Interfaces'ta; `surum='sql:20261005000004'`; T5'in kayıt satırlarını değiştirmez.

- [ ] **Step 4: db-validate (priors: 3 önceki) + demo uygula + yeşil 11/11**

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261005000004_stat_tedavi_protokol.sql tests/sql/stat_tedavi_test.sql
git add -f reports/db-validation-<sha8>.md
git commit -m "istatistik F1: stat_tedavi_protokol ve stat_tedavi_sure_dagilim"
```

---

### Task 7: `js/api.js` sarmalayıcıları (P7 — spec §8.2)

**Files:**
- Modify: `js/api.js` (`ovsyncTakipGetir` `:1184` kalıbının altına yeni blok)
- Create: `tests/unit/stat-api.test.js` (kalıp `tests/unit/api.test.js:1-12`, `node:test` + `node:assert`)

**Interfaces:**
- Consumes: `rpc(name, params)` (`js/api.js:71`).
- Produces (hepsi `async`, `window.API` ya da mevcut dışa aktarım kalıbıyla):
  - `statOlcumListele()` → `rpc('stat_olcum_listele', {})`; sonucu `window.__statOlcumler` içinde 5 dk önbellekler.
  - `statOlcumCagir(ad, {baslangic, bitis, filtre = {}})` → `ad` `/^stat_[a-z_]+$/` değilse `throw new Error('stat: geçersiz ölçüm adı')`; `rpc(ad, {p_baslangic: baslangic, p_bitis: bitis, p_filtre: filtre})`; önbellek anahtarı `${ad}|${baslangic}|${bitis}|${JSON.stringify(filtre)}`; `_statInvalidate()` tümünü boşaltır.
  - `statSonucOku(olcum, anahtar = {})` → `rpc('stat_sonuc_oku', {p_olcum: olcum, p_anahtar: anahtar})`.

- [ ] **Step 1: Birim testi yaz (kırmızı)**

`stat-api.test.js`: `db.rpc` mock'u (api.test.js'deki kalıpla) ile: `statOlcumCagir('stat_tedavi_ozet', {...})` → `db.rpc` `('stat_tedavi_ozet', {p_baslangic, p_bitis, p_filtre})` ile bir kez çağrılır; ikinci aynı çağrı önbellekten (mock sayacı 1 kalır); `statOlcumCagir('drop table', …)` → reject `geçersiz ölçüm adı`; `_statInvalidate()` sonrası sayaç 2.

- [ ] **Step 2: Kırmızı koş** — `node --test tests/unit/stat-api.test.js` → `is not a function`.

- [ ] **Step 3: Uygula** — Interfaces imzaları; önbellek `ovsyncTakipGetir` kalıbıyla.

- [ ] **Step 4: Yeşil** — `node --test tests/unit/stat-api.test.js` → tüm `ok`; `npm run test:unit` → 0 fail.

- [ ] **Step 5: Commit**

```bash
git add js/api.js tests/unit/stat-api.test.js
git commit -m "istatistik F1: api.js stat RPC sarmalayıcıları + birim test"
```

---

### Task 8: Ekran iskeleti (P8 — spec §9 F1 "liste + tablo", §8.1 zarf, ekran akışı şekli)

**Files:**
- Modify: `index.html` (panel `pg-ovsync` `:1009-1021` kalıbı; dashboard kartı `js/ui.js:310` kalıbı; `?v=` bump `:11`, `:2434-…`)
- Modify: `js/app.js:131-139` (`else if (pg==='istatistik') loadIstatistik()`)
- Modify: `js/ui.js` (`loadOvsyncDash` `:619` kalıbının yanına)
- Create: `tests/unit/stat-ui.test.js`

**Interfaces:**
- Consumes: T7 sarmalayıcıları; `goTo(pg)` (`js/app.js:105`); `escHtml`/`escAttr`.
- Produces:
  - `index.html`: `<div id="pg-istatistik" class="pg">` başlık `İstatistik` + `data-action="nav-geri"`, gövde `<div id="istatistik-root">`; `pg-dash` içine "İstatistik" kartı (`onclick="goTo('istatistik')"`), alt çubuğa buton **eklenmez** (ovsync kalıbı).
  - `js/ui.js` saf üreticiler (DOM'suz, test edilebilir): `_istatistikTabloHtml(zarf)` → `yetersiz===true` ise `<div class="stat-yetersiz">Yetersiz veri (n=<n>, eşik 5)</div>`; değilse `tablo[]`'nun anahtarlarından başlık satırı + satırlar (her hücre `escHtml`), `null` hücre `—`; altına `dipnot[]` `<small>` listesi ve `Hesap: <hesap_at yerel saat> · <surum>`. `_istatistikFiltreHtml(olcumler, secili, donem)` → ölçüm sekmeleri + iki `type="date"` (varsayılan: bitiş bugün, başlangıç 365 gün önce) + hastalık `<select>` (`HASTALIK_KAT` düzleştirilmiş, ilk seçenek "Tümü").
  - `loadIstatistik()`: `statOlcumListele()` → filtre HTML → seçili ölçüm için `statOlcumCagir` → `_istatistikTabloHtml`; hata → `#istatistik-root` üstüne `.stat-hata` şeridi, önceki tablo silinmez. Olaylar: sekme/filtre `change` → yeniden çağır. `stat_tedavi_sure_dagilim` seçiliyken hastalık "Tümü" ise çağrı yapılmaz, şerit "Bu ölçüm için hastalık seçin".
  - CSS: `index.html` ovsync CSS bloğu (`:561`) yanına `.stat-yetersiz`, `.stat-hata`, `.stat-tablo` (yatay kaydırmalı).

- [ ] **Step 1: Birim testi yaz (kırmızı)**

`stat-ui.test.js` (ui.js saf fonksiyonlarını yükleme kalıbı mevcut `tests/unit/*ui*.test.js`'den): `yetersiz` zarfı → çıktı `Yetersiz veri (n=2` içerir, `<table` içermez; dolu zarf (`tablo` 2 satır, bir hücre `null`, bir hücre `<b>x</b>`) → 2 `<tr>` gövde satırı, `—` var, `&lt;b&gt;` var (kaçış); `dipnot` 2 satır → 2 `<small>`; `_istatistikFiltreHtml` → `type="date"` 2 adet, seçili ölçüm `class="on"`.

- [ ] **Step 2: Kırmızı koş** — `node --test tests/unit/stat-ui.test.js`.

- [ ] **Step 3: Uygula** — dört dosya; `?v=` tek yeni değer (`20261005-01`).

- [ ] **Step 4: Yeşil + damga testi**

Run: `npm run test:unit` → 0 fail (`coklu-kaydir-ui.test.js` damga testi dahil).

- [ ] **Step 5: Demo'da elle tarayıcı yürüyüşü (yerel sunucu `?demo`)**

Panel kartı → İstatistik → `stat_tedavi_ozet` tablosu (fixture yoksa gerçek demo verisi) görünür; hastalık seçince tablo değişir; `stat_tedavi_sure_dagilim` + "Tümü" → uyarı şeridi; konsolda hata yok. Ekran görüntüsü `runs/2026-10-05-istatistik-modulu/f0f1/ekran-01..03.png`.

- [ ] **Step 6: Commit**

```bash
git add index.html js/app.js js/ui.js tests/unit/stat-ui.test.js
git commit -m "istatistik F1: ekran iskeleti (pg-istatistik, ölçüm sekmeleri, zarf tablosu)"
```

---

### Task 9: UI testi kapısı (P9 — proje CLAUDE.md "UI testi kapısı", bağlayıcı)

**Files:**
- Create: `runs/2026-10-05-istatistik-modulu/f0f1/ui-test-zarf.md`, `…/ui-test-rapor.md`

- [ ] **Step 1: Test listesini zarfa yaz** (madde başına beklenen görünüm): (1) panel kartı var ve tıklanır; (2) üç ölçüm sekmesi listelenir, motor ölçümleri listelenmez; (3) varsayılan dönem son 365 gün; (4) `stat_tedavi_ozet` tablosu başlıkları `hastalik, n, devam_n, iyilesme_pct, …`; (5) n<5 hastalıkta "Yetersiz veri" rozeti; (6) `sure_dagilim` + Tümü → uyarı; (7) hastalık seçince tablo + `tablo[0].medyan`; (8) dipnotlar ve `Hesap:` satırı görünür; (9) ağ kesilince hata şeridi, eski tablo kalır; (10) konsolda hata yok; (11) mevcut Sürü kartı (`stat_suru_ozet`) aynı sayıları gösterir (regresyon).
- [ ] **Step 2: `ss-worker` (sonnet, medium) koltuğuna zarf** — demo modunda koşar, madde başına PASS/FAIL + kanıt (png/DOM/konsol). Playwright belgelendiyse tekrarlanmaz (hafıza "Playwright bir kez yeter").
- [ ] **Step 3: FAIL → düzelt (ilgili görevin adımına dön) → yalnız FAIL maddeleri yeniden koşulur.** Tümü PASS → sahibe demo linki + liste.
- [ ] **Step 4: Commit** — `git add runs/2026-10-05-istatistik-modulu/f0f1/ui-test-zarf.md runs/2026-10-05-istatistik-modulu/f0f1/ui-test-rapor.md` (+ png'ler) → `"istatistik F1: UI testi kapısı PASS"`.

---

### Task 10: Kapanış ve teslim (P10 — spec §10, acceptance.md)

- [ ] **Step 1: Spec drift kontrolü** — spec §3.4 tablosu (`stat-hesapla` emekli ✓), §4.3, §5.3 ilk üç satır, §8.2 ilk üç RPC: her birinin karşılığı commit'te; sapma varsa spec'e tek satır not (`[F1 ruling]`) ve bu planın maddesine referans.
- [ ] **Step 2: Tam test koşumu** — `npm run test:unit` 0 fail; iki SQL betiği demo'da `FAIL` yok; dört db-validate raporu `reports/`'ta PASS.
- [ ] **Step 3: Review** — `Skill(requesting-code-review-obra)`; faz kapısı review'u root açar (`ss-reviewer-kapi`), verdict + işaretli satır listesi; `ÇALIŞIR ama DÜZELT` → aynı worker'a tek tur.
- [ ] **Step 4: DONE** — `runs/2026-10-05-istatistik-modulu/f0f1/DONE.md`: kabul SHA, görev → commit tablosu, F0 örnekleme sonucu, UI kapısı raporu yolu, açık kalemler (A3 sonucu, maliyet_tl ruling varsa, prod DB uygulaması bekliyor). Mimara `DONE:` mesajı.
- [ ] **Step 5: Merge/push yalnız `ss-merge-gate --apply`** (kırmızıda root). Prod DB migration uygulaması ayrı adım: yedek etiketi + kırıntı `gate` + `scripts/veri-eslesme-kontrol.py hepsi` (hafıza).

---

## Önceden cevaplanmış kararlar (bu plan için)

- Yürütücü: root (sahip 2026-10-05, "implementasyon root'ta"); mimar plan yazar, sorular `SORU:` ile mimara/roota.
- `SECURITY INVOKER` (spec §5.1) repo kalıbı `DEFINER`'a tercih edilir; RLS `USING(true)` olduğundan davranış farkı yok, saldırı yüzeyi küçülür.
- Ölçüm doğruluğu testi `tests/sql/*.sql` (psql, demo DB) ile; spec §10'daki "Node unit test RPC çıktısını fixture ile karşılaştırır" cümlesi buna çevrildi (`tests/unit` yalnız saf JS; DB'ye bağlanan unit test kalıbı repoda yok — ruling, plan yazarı).
- Alt çubuğa yeni buton eklenmez; ekran panel kartından açılır (ovsync kalıbı, 2026-10-02).
- Nüks penceresi `(kapanis, kapanis+30]`: aynı gün yeniden açılan vaka nüks sayılmaz (spec birebir). Pratikte sık çıkarsa F2 öncesi sahibe sorulur.
- `maliyet_tl` için `stok.maliyet` ↔ `drug_products` bağı doğrulanamazsa kolon `NULL` döner ve ozet `maliyet_ort` `null`; F4 bunu gider bağıyla iyileştirir (spec §9 F4).

## Self-review notları (mimar)

- Spec kapsamı: §3.4 → T1; §4.3 + §5.1 kayıt tablosu → T2; §5.2 → T3/T4; §5.3 SQL satırları → T5/T6; §8.1-8.2 (ham yükleme RPC'leri hariç, onlar F3) → T5/T7; §9 F1 ekran → T8/T9; §10 → her görevin test adımı + T10; §11 risk 1 → T4, risk 6 (cron yok) → bu planda cron yok. Motor satırları (§5.3 son iki) kayıt tablosuna `aktif=false` girer, gövdesi F2.
- Tip tutarlılığı: `stat_<x>(p_baslangic date, p_bitis date, p_filtre jsonb)` üç ölçümde aynı; JS `statOlcumCagir` aynı üç parametreyi `p_` önekiyle geçer; zarf alan adları T5 Interfaces ↔ T8 `_istatistikTabloHtml` aynı.
- Oran: spec ~430 satır, plan ~330 satır; gövde yok, yalnız imza + test + kabul.
