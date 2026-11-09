⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren N6 DM1: demo DB seri uygulaması + bayrak-0 regresyonu + gerçek demo e2e + zaman senaryosu⟧
sonuc: KISMI

commit: 5c9a05a `ovsync-tren N6 DM1: demo seri uygulandı + ACL + bayrak0 regresyon + zaman senaryosu (KISMI)`. 8 dosya, her biri ayrı `git add` ile eklendi. Push yapılmadı. Bu report, DM1-brief.md ve henüz koşulmamış `tests/e2e/ovsync-tren.spec.js` commit'e girmedi.
progress: adım 1–5 ve 8 tamam. Adım 5'te regresyon kümesi tabandan farklı çıktı; brief gereği adım 6'dan önce DURDUM. Devam noktası adım 6: bayrak açılacak (`ovsync_tren_ayar_guncelle(true, 2026-11-12)`, betik `~/tmp/dm1/js/ayar.mjs`). Ardından adım 7: `tests/e2e/ovsync-tren.spec.js` koşumu (spec yazıldı, henüz koşulmadı). Adım 9 SORU-2'de bekliyor.
BOYUT: bütçe e2e ≤450 · SQL ≤350 · üretim 0 · gerçek: üretim kodu 0 · e2e spec 377 satır (koşulmadı) · zaman senaryosu SQL 228 satır · bütçe içinde

SORU-1: Bayrak 0 regresyonunda tek fark var: Y-CIFT-TIK main tabanında FAIL, dalda PASS. Main kodu aynı testi tek başına koşunca PASS verdi, yani test kararsız. Brief'e göre fark çıkınca durmam gerekiyor; kabul edilsin mi?
- (a) Kararsız sayılır, fark kabul edilir. Adım 6–7'ye devam edilir.
- (b) Main ile dal, seri uygulanmış demo üzerinde bayrak 0'da yeniden ve tam koşulur, kümeler o koşumla karşılaştırılır. Serisiz taban artık üretilemez, çünkü demo seriyi taşıyor.
- (c) Dur.
- Önerim: (a). Dal tarafında FAIL'e dönen test yok, yani gerileme sıfır. Taban hatası bir DB bekleme zaman aşımı.

SORU-2: Adım 9 bu yazılabilir listeyle yapılamıyor.
- LUNA-3 bir kolonun etiketini `js/degisiklikler/etiketler.js` içindeki `tabloOzelAlanlar.cases` ya da `ortakAlanlar` alanında arıyor (`tests/unit/degisiklikler-etiketler.test.js:97-107`). JSON dosyası etiket taşımıyor.
- İki kolonu yalnız `degisiklikler-kapsam-kolonlari.json`'a eklersem LUNA-2/A3 kırmızıya döner (`:44-56`: açık etiketi olmayan kolon). LUNA-3 listesi de değişmez.
- Seçenekler:
  - (a) `js/degisiklikler/etiketler.js` dosyasının `cases` bloğuna `ovsync_tren: 'Tren üyeliği', ovsync_bagimsiz: 'Bağımsız işareti'` eklenir (1 satır) ve JSON'a 2 kolon girer. Bunun için ya js dosyası bu brief'in yazılabilir listesine eklenir ya da iş UI kulvarına verilir.
  - (b) Adım 9 düşer.
- Önerim: (a). JSON'a dokunmadım.

## Gelen iş denetimi
Beş bulgu var. Hepsi tek turda ele alındı.
1. Adım 9 `js/` dosyası gerektiriyor ve bu dosya yazılabilir listede yok. SORU-2'ye taşındı (CONFIRMED, kod okundu).
2. Bugün Pazartesi; çapa Perşembe (2026-11-12). ▶ Başlat penceresi hedef−2 ≤ bugün kuralını kullanıyor. Bu yüzden "Trene bin → vaka D0 = tren" Pazartesi ya da Perşembe günü üretilemez (INFERRED, `start_first_service_protocol` gövdesinden).
   - Çözüm: spec beforeAll'da çapayı bugün+2 yapıyor. afterAll koşum öncesi çapaya döndürüyor ve işaretsiz açık OVSYNC_BASLAT hedeflerini koşum öncesine geri yazıyor. Assumption kırıntısı olarak işlenecek: çapa gene adım 6'daki Perşembe değerine dönüyor.
3. Run-1 komutu kabul betiğini (`ovsync_tren_kabul.sql`) içermiyor. Bu yüzden zaman senaryosu dosyası yardımcılarını kendisi kuruyor (kb_ok ve kb_bugun aynı sözleşmeyle).
4. Kabul betiğinde `kb_bugun()` için hazır bir "ilerletme" kalıbı yok. `now()` işlem içinde sabit; yalnız geriye tarihleyen `kb_geri` var (`ovsync_tren_kabul.sql:299`).
   - Zaman ilerletme şöyle kuruldu: senaryonun bütün tarihleri ve çapa t gün geri alınıyor (`zs_ilerle`, kb_geri'nin genellemesi). Assumption kırıntısı yazıldı.
5. `demo_sema_diff()` yalnız demoda eksik olan tablo ve kolonları raporluyor. Demoda fazla olan kolonları göstermiyor. Planın beklediği "demo tarafında fazla" satırı bu fonksiyonla görünemez (CONFIRMED, gövde okundu).

## Yapılanlar

### Adım 1 — demo durumu
- Durum `ACTIVE_HEALTHY` (MEASURED, Management API `GET /v1/projects/vtzqjmazsvurxdeondmi`). Restore gerekmedi.
- Bütün çağrılar `~/tmp/dm1/dq.sh` ile yapıldı. Ref bu betikte sabit kodlu; prod ref değişkeni okunmadı.

### Adım 2 — taban
- Ortam: main kodu (`~/egesut-erp1`, b9542b1), serisiz demo.
- Sonuç: `ovsync-takip.spec.js` → 15 PASS / 5 FAIL (MEASURED). Küme: `e2e-taban-main.txt`, ham log: `e2e-taban-main.ham.log`.
- Spec başlığındaki docker satırı main checkout'ta olduğu gibi çalışmadı: `/main` ve `/work` iki ayrı playwright kopyası açtı (`test.describe.configure() … not expected`). Main koşumunda `/work/node_modules/.bin/playwright` kullanıldı; komut başka yönden aynı (`~/tmp/dm1/run-e2e.sh`).

### Adım 3 — uygulama
- Önce yedek alındı: `oncesi-yedek.sql`. İçinde 16 fonksiyonun `pg_get_functiondef` çıktısı, proacl ve md5 başlığı, ayrıca 11 `protokol_ayar` satırı var. 16 md5'in 16'sı da D0 tabanıyla aynı (MEASURED).
- Kuru prova: `BEGIN; seri; DO RAISE DRYRUN_OK` → hata ile geri alındı. Prova sonrası iz yok (sm 0, kolon 0; MEASURED).
- Uygulama: 2026-11-09T16:19:43Z, tek transaction (`BEGIN; 8 dosya; schema_migrations INSERT 8; COMMIT; SELECT`), `apply.sql` sha256 a8d00ad1….
  - md5 korumaları geçti; `*_GOVDE_FARKLI` görülmedi.
  - Uygulanan dosyaların sha256'ları db-validate raporlarıyla aynı (ae0191c9, 29c0f3ee, 516f75b2, 8889c9fd …).
- Ham API yanıtı:
```
[{"sonuc":{"sm":["20261110100001","20261110100002","20261110100003","20261110100004","20261110100005","20261110100006","20261110100007","20261110100008"],"kolon":["ovsync_bagimsiz","ovsync_tren"],"ayar":[{"dogum_sonrasi_pg_gorev_aktif":0},{"ovsync_pg_erteleme_tolerans_gun":1},{"ovsync_tren_aktif":0},{"ovsync_tren_capa":20261112},{"ovsync_tren_one_cekme_gun":2}]}}]
HTTP 201
```
- `SELECT public.demo_sema_diff()`:
  - İlk deneme `read_only` modda yapıldı ve 42501 ile reddedildi.
  - read_only olmadan:
```
{"demo_sema_diff": {"eksik_kolon": [], "eksik_tablo": []}}
```
  - Fonksiyon yalnız prod_fdw'de olup demoda olmayanı listelediği için iki yeni kolon görünmüyor (bkz. Gelen iş denetimi 5).

### Adım 4 — ACL
`acl-olcum.md`: 40 imza, anon false, authenticated beklenen değerde, **sapma 0** (MEASURED). Eski imzalardan hiçbiri kalmadı. `_vaka_ac_tek` için authenticated yetkisi bilerek kapatıldı (D4-review-report).

### Adım 5 — bayrak 0 regresyonu
- Ortam: dal kodu, worktree yerel sunucu :8137, seri uygulanmış demo, `ovsync_tren_aktif`=0.
- Sonuç: 16 PASS / 4 FAIL. Küme: `e2e-regresyon-bayrak0.txt`, ham log: `e2e-regresyon-bayrak0.ham.log`.
- Fark (tek satır): `Y-CIFT-TIK: çift Ekle tek hastalık günü açar; tekrar mevcut döner, ilaç yinelenmez`, tabanda FAIL, dalda PASS.
  - Taban hatası: `expect(gunler, 'çift çağrı günü DBde').toBeTruthy()` → `Received: null`. Bu, 45 s'lik DB bekleme döngüsünün zaman aşımı (`ovsync-takip.spec.js:885`).
  - Main kodu aynı testi tek başına koşunca 25.1 s'te PASS verdi (`e2e-taban-main-ciftik-tekrar.ham.log`). Bu koşum seri uygulanmış ve bayrağı 0 olan demo üzerindeydi (MEASURED).
- Sonuç: PASS'ten FAIL'e dönen test yok. Brief gereği DUR → SORU-1.

### Adım 6–7 — yapılmadı (DUR)
- `tests/e2e/ovsync-tren.spec.js` yazıldı: 377 satır, planın on testi birebir adlarıyla, `E2E-TREN-PW-` işaretli seed, afterAll temizlik. **Henüz koşulmadı** (UNKNOWN); bu yüzden commit'e girmedi.
- Tasarım notları (INFERRED, kod okumasından):
  - Çapa bugün+2 alınıyor, böylece T başlatma penceresinde kalıyor ve tren günü bugün olmuyor; K8 modalı açılıyor.
  - Testler bu sırayla koşuyor: trene bin → bağımsız → V3 → G7 → geç tamamlama → görevler TAI → aşama 2 (a) → aşama 2 (b) → toptan +1 → toptan +3.
  - "toptan +3"teki d hayvanının yolu:
    - d, D7 treninde başlıyor; GnRH1'i D0'a geriye tarihleniyor (kayma 0).
    - Toptan +1'de KAYAR oluyor; etiketi ve PG1'i +1 kayıyor.
    - Toptan +3'te pg_pay 0 olduğu için BASTAN'a düşüyor; eski vaka IPTAL oluyor ve yeni görev X'+3'e açılıyor.
  - Toptan erteleme demo'nun kendi görevlerini de (T'deki 2 görev) kaydırır. afterAll bunları koşum öncesi hedeflerine geri yazar.

### Adım 8 — zaman senaryosu
- Dosya: `supabase/tests/ovsync_tren_zaman_senaryosu.sql` (228 satır).
- Kurgu: 5 hayvan, D0–D15.
  - **Hafta 1:** D0'da T1–T4 trene biner. D1'de B1 bağımsız başlar. D3'te T3'e hastalık günü girilir (K9).
  - **Hafta 2:**
    - D7'de T1'in PG1'i zamanında yapılır. Toptan +7'de T1 SECIM'e düşer: seçimsiz koşum reddedilir, PG48 seçilir.
    - Aynı toptanda T2 ve T4 BASTAN'a düşer; yeni görevleri D14'e açılır.
    - D8'de T3'ün PG1'i 1 gün geç yapılır (tolerans içi). D10'da B1'in PG1'i 2 gün geç yapılır: K11 uyarısı çıkar, B1 baştan başlatılır (bağımsız).
  - **Hafta 3:** D14'te T2 ve T4 trene biner. D15'te çapa iki kez değiştirilir. Bağımsız B1 de, hastalıklı T3 de trene GİRMİYOR (D9).
- Her assert'in yanında kural kimliği var (R*, K*, RL-*, §18.x, D9). `awk` taramasında kimliksiz assert yok (MEASURED).
- Sonuç: **OZET 45 PASS** (MEASURED, Run-1).
- Mutant ölçümü (MEASURED):
  - 008'den `NOT c.ovsync_bagimsiz` kaldırılınca `FAIL ZS-8a`.
  - Tolerans 2 yapılınca `FAIL ZS-6a`.

### Adım 9 — SORU-2
- `node --test tests/unit/degisiklikler-etiketler.test.js` canlı demoya karşı koşuldu (rc 1, 10 PASS / 1 FAIL).
- LUNA-3 çıktısı: `canlı DEMO'da haritasız kolon: cases.close_reason, cases.ovsync_bagimsiz, cases.ovsync_tren, cases.protocol_family, cases.protocol_snapshot, cases.source_template_id, drug_classes.farmakolojik_sinif_kodu, drug_classes.sistem, gorev_log.takip_kapanis_nedeni, tedavi_sablonu.protokol_ailesi`.
- Bu listede 8 kolon tabanda zaten haritasız; 2'si (ovsync_*) yeni (MEASURED, `~/tmp/dm1/luna.out`).

## Demo'ya yazılanlar (geri dönüş listesi)
1. Seri 20261110100001..008:
   - 24 yeni fonksiyon, 16 değişen gövde ve 3 imza değişikliği.
   - `cases.ovsync_tren` ve `cases.ovsync_bagimsiz` kolonları.
   - 5 yeni `protokol_ayar` satırı: `ovsync_tren_aktif`=0, `ovsync_tren_capa`=20261112, `ovsync_tren_one_cekme_gun`=2, `ovsync_pg_erteleme_tolerans_gun`=1, `dogum_sonrasi_pg_gorev_aktif`=0.
   - 8 `supabase_migrations.schema_migrations` satırı.
   - Geri dönüş: `runs/2026-11-09-ovsync-tren/db/geri-al.sql` (tam geri) ve `demo/oncesi-yedek.sql` (gövde ve ayar kanıtı). schema_migrations satırları ayrıca `DELETE … WHERE version LIKE '20261110100%'` ile silinir.
2. Kuru prova: aynı seri DO RAISE ile kendini geri aldı; kalıcı iz yok (MEASURED).
3. `ovsync-takip.spec.js` iki tam koşum ve bir tek-test koşumu yaptı. Kendi `E2E-TAKIP-PW-` seed ve temizliği:
   - Hayvanlar FK yüzünden Satıldı'ya çekilir.
   - Seans ve PG olayları stok hareketi bırakır.
   - `pg_application_event` satırları silinemez; spec bunu belgeliyor.
4. Bayrak açılmadı. Demo şu an seri uygulanmış ve `ovsync_tren_aktif`=0 durumunda.

## Run kanıtı
Brief `## Run` bloğu birebir koşuldu (2026-11-09).

Run-1:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_zaman_senaryosu.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
REVOKE
GRANT
NOTICE:  OZET 45 PASS
```

Run-2:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && cat runs/2026-11-09-ovsync-tren/demo/e2e-cikti.txt | tail -15
```
rc: 0. tail'in rc'si 0 döndü; cat ise başarısız oldu. Dosya henüz yok, çünkü adım 7 yapılmadı.
```
cat: runs/2026-11-09-ovsync-tren/demo/e2e-cikti.txt: Böyle bir dosya ya da dizin yok
```

Run-3:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && diff <(sort runs/2026-11-09-ovsync-tren/demo/e2e-taban-main.txt) <(sort runs/2026-11-09-ovsync-tren/demo/e2e-regresyon-bayrak0.txt) && echo REGRESYON-AYNI
```
rc: 1
```
3d2
< FAIL Y-CIFT-TIK: çift Ekle tek hastalık günü açar; tekrar mevcut döner, ilaç yinelenmez
15a15
> PASS Y-CIFT-TIK: çift Ekle tek hastalık günü açar; tekrar mevcut döner, ilaç yinelenmez
```

Ek koşumlar (ham):
- Taban son satırlar: `5 failed … 15 passed (11.8m) RC=1`
- Regresyon son satırlar: `4 failed … 16 passed (10.5m) RC=1`
- Y-CIFT-TIK main tekrar: `1 passed (57.6s) RC=0`

## Kırıntılar
Workspace: fable-rol-ve-davranislar.
- measurement: seri demo'ya uygulandı ve md5 korumaları geçti.
- measurement: ACL 40/40.
- gate (env-mismatch): regresyon farkı Y-CIFT-TIK, kararsız test → DUR.
- measurement: zaman senaryosu 45 PASS ve mutantlar öldü.
- assumption: zaman ilerletme geri sarma ile yapıldı.
- open_item: LUNA-3 için etiketler.js gerekiyor.
- Bekleyen assumption: e2e çapası bugün+2 olacak; afterAll çapayı ve işaretsiz görevleri geri yükleyecek. Adım 7 koşulunca yazılacak.

## Devam turu (2026-11-09, taze worker — ROOT RULING SORU-1 (a), SORU-2 (a))
sonuc: KISMI
commit: 896b288 `ovsync-tren N6 DM1: demo bayrak açık + tren e2e 9/10 PASS + LUNA-3 iki kolon etiketi` (7 dosya, dosya dosya `git add`; push yok). Bu report ayrı commit'te.
BOYUT: bütçe e2e ≤450 · SQL ≤350 · üretim 0 (+ root SORU-2 izniyle etiketler.js 1 satır) · gerçek: üretim 1 satır (etiketler.js) · e2e spec 415 satır · bütçe içinde

Gelen iş denetimi: bulgu yok (adım 1–5, 8 tekrarlanmadı).

### Adım 6 — bayrak açıldı
- Çağrı: `ovsync_tren_ayar_guncelle(true, 2026-11-12)`, demo kullanıcısıyla (`~/tmp/dm1/js/ayar.mjs`). rc 0 (MEASURED).
- Dönüş: `{ok:true, aktif:true, capa:'2026-11-12'}`.
- `yeniden_hedef` (tam metin `demo/bayrak-ac-donus.json`, öncesi `demo/bayrak-ac-oncesi.json`):
  - gorevler: 23 ileri OVSYNC_BASLAT. 20'si TASINIR (ör. 11-14→11-12, 11-30→12-03), 3'ü AYNI. Gecikmiş 2 görev listede yok (R9).
  - uyelik: 1 vaka (`<prod-id>` → tren 2026-10-29).
  - belirsiz_asama: 0 (`belirsiz_sayisi` 0).

### Adım 7 — `tests/e2e/ovsync-tren.spec.js` demo koşumu
Son koşum (koşum 6, ham çıktı `demo/e2e-cikti.txt`): **9 PASS / 1 FAIL** (MEASURED). Koşum geçmişi `demo/e2e-kosumlar.txt`.

| # | test (PLAN :577-581 adı birebir) | sonuç |
|---|---|---|
| 1 | trene bin: ▶ Başlat modalında Trene bin → vaka D0 = tren | PASS |
| 2 | bağımsız başlat → D0 bugün, listede bağımsızlar | PASS |
| 3 | V3 Vaka Aç + Ovsync şablonu: Trene bin → gün#1 = tren | PASS |
| 4 | G7 Boş sonrası Ovsync uygula: Trene bin → görev hedefi tren; Bağımsız → vaka bugün | PASS |
| 5 | geç tamamlama: PG1 seansı 2 gün geç → uyarı sheet'i | PASS |
| 6 | aşama 2 (a): PG48 → kalan günler kapandı, TAI durur | PASS |
| 7 | aşama 2 (b): baştan başlat → yeni görev tren günü | PASS |
| 8 | toptan +1: önizleme KAYAR, onay sonrası görev hedefleri +1, başlık yeni gün | PASS |
| 9 | toptan +3: aşama 1 BASTAN → eski vaka IPTAL | PASS |
| 10 | görevler ekranı: Ovsync TAI'de Ertele yok | **FAIL (UI)** |

Spec düzeltmeleri (koşum 1–5'teki FAIL'lerin kökü testteydi; her biri koşum çıktısıyla ölçüldü):
- **default → serial mod.** Default modda bir FAIL işçiyi yeniden başlatıyor. beforeAll yeniden seed ediyor, temizlik önceki testlerin durumunu siliyor. Sonraki sıra bağımlı testler bu yüzden sahte FAIL veriyordu (koşum 1: 7 FAIL). beforeAll'a 180 s zaman aşımı eklendi (koşum 2'de 30 s aşıldı).
- **Bağımsız bölümü locator'ı.** Bağımsız `.ovs-bolum` Trenler bölümünün içinde yer alıyor, bu yüzden locator iki öğe buluyordu (strict ihlali). Artık `:has(> .ovs-bh > h2:text-is("Bağımsız"))` kullanılıyor.
- **geç tamamlama.** TEDAVI_GUN kartı, günün seansları olduğu için listede gizleniyor (ui.js:3736). Görevler listesindeki seans kartı ✓ işareti `flushPendingDone`'dan geçiyor ve uyarı kancası taşımıyor. Test artık vaka kartı yolunu kullanıyor: `openCaseDet` → `.seans-row[data-seans-id] .seans-btn-ok`, yani `seansTamamla` (forms.js:5429).
  - Ayrıca geriye tarihli şablon uygulaması geçmiş günleri tamamlandı yapıyor, seanslar ise açık kalıyor (demo ölçümü, `js/gunprobe.mjs`). Seed bu yüzden gün#2 ve sonrasını yeniden açıyor.
- **İlk pull beklemesi (`acTren`).** Pull bitmeden IDB `protokol_ayar` boş kalıyor; bayrak kapısı da eski yola düşüyor:
  - Koşum 3'te Ovsync ekranı klasik görünümde kaldı.
  - Koşum 4'te pull sonu render seçimi sıfırladı ("Hastalık seçilmedi").
  - Çözüm: önce IDB'de bayrak bekleniyor, ardından `pullTables(['protokol_ayar'])` zinciri tamamlanıyor.
- **toptanAc.** Düğme artık x treninin kendi başlığından seçiliyor (bkz. BULGU-2).
- G7 bağımsız vaka beklemesi 15 s'ten 45 s'e çıkarıldı (koşum 2'de bir kez zaman aşımı oldu).

**BULGU-1 (testi kıran; kök neden UI, seed değil):** `js/ui.js:2241-2254` `_ovsyncKartKararBaglami`.
- Kart kararı hayvan kümesini `window._ovsyncBaglam.vakaAktif`'ten kuruyor. Bu bağlamı yalnız `_ovsyncBaglamYukle` kuruyor (`js/ui.js:999`), o da yalnız `loadOvsyncDash`'ten çağrılıyor.
- Sonuç: Ovsync ekranı açılmadan doğrudan Görevler'e gidildiğinde küme boş kalıyor. `ovsyncTrenGorevMu` (`js/ovsync-tren.js:494`) TAI'yi Ovsync saymıyor ve `_erteleBtnHtml` (`js/ui.js:5398-5401`) eski yola düşüp Ertele çiziyor.
- Beklenen: Ovsync TAI kartında `[data-ertele]` sayısı 0 ve "Ovsync ekranında düzenle →" bağlantısı.
- Görülen: `Expected: 0 · Received: 1` (MEASURED, `demo/e2e-cikti.txt`).
- Seed hatası olmadığının kanıtı: spec'in `h` seed'i birebir yeniden kuruldu (`~/tmp/dm1/js/taiprobe.mjs`, sonra silindi) ve demoda SQL R5 tanımıyla sınandı (`_ovsync_gorev_mu`, 20261110100002:184-207) (MEASURED):
  - vaka: `status=active, protocol_family=OVSYNC, source_template_id=a152f7fe…`
  - TAI: `gorev_tipi=TOHUMLAMA_PLANLI, kaynak=TEDAVI_SABLON_TOHUMLAMA:<case>:a152f7fe…, hedef bugün`
  - `_ovsync_gorev_mu(TAI) = true`. Seed R5'e uyuyor, sunucu bu görevi Ovsync görevi sayıyor.
- js/ düzeltilmedi (brief). Düzeltme UI kulvarının işi: kart kararı bağlamı Ovsync ekranından bağımsız kurulmalı.

**BULGU-2 (testi kırmıyor; spec düğmeyi başlıktan seçerek dolandı):** `js/ovsync-tren.js:269-276` + `:325-326`.
- Geçen haftanın treninde ("Tren · Çar 4 Kas") `ovsyncToptanTarih` d7 değerini döndürüyor. Bu değer `ilkTarih`'e eşit, bu yüzden o başlık da `data-tarih=2026-11-11` taşıyan "Tren gününü ertele…" düğmesi alıyor.
- Ekranda iki ertele düğmesi var (MEASURED, koşum 5 error-context: e83 ve e122). UB-ekler 6 ve UB2 F9 testi tek düğme istiyor.

**Gözlem (INFERRED, kod okuması):**
- Görevler listesindeki seans kartının ✓ işareti (`js/ui.js:3491`) `rpcSeansTamamla` dönüşünü atıyor. K11 "PG1 geç" uyarı sheet'i bu yoldan açılmıyor.
- İlk pull bitmeden açılan Ovsync ekranı ve K8 sorusu eski yola düşüyor. Bu bir kullanıcı yarışı; demoda testle ölçüldü, UI kararı gerektiriyor.

Demo geri dönüş (MEASURED):
- Her koşumun afterAll'u çapayı 20261112'ye ve işaretsiz açık OVSYNC_BASLAT hedeflerini geri yazdı. Koşum 6 sonrası 25/25 hedef, adım 6 sonrası durumla birebir (`~/tmp/dm1/karsilastir.py` → `fark {}`).
- `degisim_log`'da E2E dışı satıra dokunan değişiklikler:
  - yalnız aynı 23 OVSYNC_BASLAT'ın `hedef_tarih` gidiş-dönüşleri;
  - adım 6'nın tek üyelik yazımı.
- E2E hayvanı Aktif 0, E2E vaka 0. 3 işaretli hayvan Satıldı durumunda (pg_application_event FK; takip spec'iyle aynı kalıp).
- Bayrak açık kaldı (`ovsync_tren_aktif`=1, çapa 20261112).

### Adım 9 — LUNA-3
- TDD:
  - JSON'a 2 kolon eklendi → LUNA-2/A3 kırmızı: `açık etiketi olmayan kolonlar: cases.ovsync_bagimsiz, cases.ovsync_tren`.
  - etiketler.js `cases` bloğuna tek satır eklendi (`ovsync_tren: 'Tren üyeliği', ovsync_bagimsiz: 'Bağımsız işareti'`) → yeşil (pass 1, fail 0).
- LUNA-3 canlı demo (MEASURED, `~/tmp/dm1/luna.out`): haritasız liste `cases.close_reason, cases.protocol_family, cases.protocol_snapshot, cases.source_template_id, drug_classes.farmakolojik_sinif_kodu, drug_classes.sistem, gorev_log.takip_kapanis_nedeni, tedavi_sablonu.protokol_ailesi`. Bunlar taban 8 kolon; yeni 2 kolon listede yok.
- Birim süit (`node --test tests/unit/*.test.js`): 2386 test, 2382 pass, 4 fail. Dört fail = taban dördü (LUNA-3 taban 8 kolon, EG-7, EG-8, `ay ‹/›`; UA1-report:127-131'de de var).

## Run kanıtı (devam turu)
Run-1:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_zaman_senaryosu.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
REVOKE
GRANT
NOTICE:  OZET 45 PASS
```
Run-2:
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && cat runs/2026-11-09-ovsync-tren/demo/e2e-cikti.txt | tail -15
```
rc: 0
```
    > 413 |   await expect(kart.locator('[data-ertele]'), 'Ovsync TAI kartında Ertele düğmesi').toHaveCount(0);
          |                                                                                     ^
      414 |   await expect(kart.locator('.ovs-duzenle-link')).toHaveText('Ovsync ekranında düzenle →');
      415 | });
      416 |
        at /work/tests/e2e/ovsync-tren.spec.js:413:85

    Error Context: ../pwout/e2e-ovsync-tren-görevler-ekranı-Ovsync-TAI-de-Ertele-yok-chromium/error-context.md

  Slow test file: [chromium] › tests/e2e/ovsync-tren.spec.js (5.3m)
  Consider running tests from slow files in parallel. See: https://playwright.dev/docs/test-parallel
  1 failed
    [chromium] › tests/e2e/ovsync-tren.spec.js:409:5 › görevler ekranı: Ovsync TAI'de Ertele yok ───
  9 passed (6.1m)
RC=1
```
Run-3. Fark root ruling SORU-1 (a) ile kabul edildi; Y-CIFT-TIK kararsız test, PASS'ten FAIL'e dönen yok.
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && diff <(sort runs/2026-11-09-ovsync-tren/demo/e2e-taban-main.txt) <(sort runs/2026-11-09-ovsync-tren/demo/e2e-regresyon-bayrak0.txt) && echo REGRESYON-AYNI
```
rc: 1
```
3d2
< FAIL Y-CIFT-TIK: çift Ekle tek hastalık günü açar; tekrar mevcut döner, ilaç yinelenmez
15a15
> PASS Y-CIFT-TIK: çift Ekle tek hastalık günü açar; tekrar mevcut döner, ilaç yinelenmez
```

## Kırıntılar (devam turu)
Workspace: fable-rol-ve-davranislar.
- assumption: SORU-1 (a).
- assumption: e2e çapası bugün+2; geri dönüş ölçüldü.
- measurement: e2e 9/10.
- gate dead-path: `js/ui.js:2241-2254`, BULGU-1.
- open_item: BULGU-2, iki ertele düğmesi.
- open_item: flush yolunda K11 uyarısı yok.
- measurement: LUNA-3 ve birim süit.
progress: DM1 bitti. Tek açık nokta UI kulvarı (BULGU-1/2). Düzeltme sonrası yalnız "görevler ekranı" testi tek koşulur (`-g "görevler ekranı"`; serial modda beforeAll seed ediyor, bağımsız koşar).

## ROOT-KABUL (2026-11-09)
DM1 kanıtları (MEASURED, bu report): demo md5 16/16, schema_migrations 8, ACL 40/40 sapma 0, bayrak-0 regresyonu PASS→FAIL dönen yok (Y-CIFT-TIK kararsız, SORU-1 ruling), zaman senaryosu 45 PASS, e2e 9/10 + tek FAIL'in kökü UI H1 → N4-F3 (9411ca4) düzeltti, demo tek test PASS (N4-F3-report). Ruling: T2 ayrı review açılmadı (kanıtlar ölçümlü; DM2 tarayıcı kapısı + sahip demosu sıradaki doğrulama) — maliyet: e2e spec/zaman SQL kalite bulguları DM2 sonrasına kalır. DM1 KABUL, kabul SHA 60a3b79.
