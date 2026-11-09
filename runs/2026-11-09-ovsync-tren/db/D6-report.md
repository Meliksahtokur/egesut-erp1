⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D6 tur 2 dar düzeltme⟧
sonuc: TAMAM

BOYUT: bütçe 450 · gerçek 453 · 3 satır aşım. Dosyanın tamamı sayıldı: 222 satır `seans_tamamla` prod gövdesi kopyası (bunun 32 satırı D6) ve 25 satır başlık/md5 koruması.
commit: 00420d2 (`ovsync-tren L-DB D6: …`). Yalnız 2 dosya, dosya dosya stage edildi (`git diff --cached --stat` = 2 dosya, +1043).

## Gelen iş denetimi
Bloklayan bulgu yok. Okuduklarım:
- brief, ortak.md, progress.md (RL-1..RL-11, SORU-1..3 cevapları, R6-EK, RL-11 düzeltmesi, SÖZLEŞME EKİ)
- PLAN.md: Global Constraints, R1–R20, N1 sözleşmesi, D0–D8, Kapı tur 2
- design.md, domain-rules §5 ve §18 (18.6, 18.9, 18.10, 18.19). Çelişki yok.
- D5-report, D5-review-report, govde-taban.md, UA1-report (sapma 5) ve `js/ovsync-tren.js` hata metni tablosu

Plan boşlukları aşağıdaki Varsayımlar'da gerekçeli. Hiçbiri spec'i değiştirmiyor.

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql` (yeni, 453 satır)
  - md5 koruması: `seans_tamamla` = `4afb2221…` (D0 prod sütunu). Fark varsa `SEANS_TAMAMLA_GOVDE_FARKLI`.
  - Gövde üretici betikle kopyalandı: `~/tmp/ovsync-tren-db/d6gen/gen.py`. Betik kanit md5'ini kopyadan önce doğruluyor.
  - Kanit ile fark +32/−4 satır, hepsi "D6" bloklarında (CONFIRMED, `~/tmp/ovsync-tren-db/d6gen/govde-diff.txt`).
  - `seans_tamamla` (R13):
    - Tren açık ve seans aktif OVSYNC vakasınınsa `v_occurred_at := now()`; aksi durumda eski `LEAST`.
    - PG1 seansında (R6 gün#2) `gecikme = bugün − PG1 günü + _ovsync_pg1_kayma(case)`. Bu, `tamamlanma günü − (GnRH1 çapası + 7)` ile aynı şey (R18 tek tanım).
    - Gecikme toleransı aşarsa dönüşe `ovsync_uyari` eklenir: `{kod:'PG1_TOLERANS_ASILDI', gecikme_gun, oneri:'BASTAN_BASLAT', case_id}`, sözleşme eki ile birlikte `kupe_no, planlanan_tarih, tamamlanan_tarih, bastan_tren_gunu=_ovsync_tren_gunu(bugün)`.
    - Bayrak 0'da davranış birebir eski: anahtar eklenmez; ayar (`_ovsync_tren_aktif()` → `_ayar('ovsync_tren_aktif', 0)`) varsayılanlı okunur, hata vermez, davranış aynı (TR-K11-REG). (tur 2 düzeltmesi)
  - `ovsync_hayvan_ertele(p_hayvan_id text, p_gun integer)` → `{ok, asama, sonuc:'KAYDI'|'SONRAKI_TREN', yeni_tarih}`
    - Açık OVSYNC_BASLAT: `_ovsync_tren_gunu_ic(hedef + p_gun, capa, 0, bugün)` hesaplanır, `gorev_ertele` ile yazılır.
    - Aşama 0, trende: D0 sonraki trene, `vaka_kalan_gunleri_kaydir(fark)`.
    - Aşama 0, bağımsız: `p_gun` kadar kaydırma.
    - Aşama 1: R18 birikimli tolerans; aşılırsa `OVSYNC_ASAMA1_TOLERANS{tolerans, mevcut_kayma, istenen, oneri, case_id}`.
    - Aşama 2 → `OVSYNC_ASAMA2_ERTELEME_YOK{case_id, secenekler}`; aşama NULL → `OVSYNC_ASAMA_BELIRSIZ{case_id, oneri}`; hiçbir şey yok → `OVSYNC_VAKA_YOK`.
    - Etiketi ayrıca artırmaz (RL-1). TR-K4-2 ve TR-K5-1 tam +7 / +1 ölçüyor; çift sayım mutantı öldü.
  - `ovsync_pg48_tohumla(p_case_id uuid)` → `{ok, tai_gorev_id, tai_hedef, kapanan_seans}` (R12)
    - Hata kodları: `OVSYNC_VAKA_YOK` / `OVSYNC_ASAMA2_DEGIL` / `OVSYNC_PG48_TAI_YOK` / `OVSYNC_PG48_GECMIS`.
    - Kalan açık şablon-günü seansları `seans_tamamla(p_uygulanmadi => true)` ile kapanır; stok iadesi mevcut yoldan.
  - `ovsync_bastan_baslat(p_case_id uuid, p_bagimsiz boolean DEFAULT false, p_not text DEFAULT NULL)` → `{ok, kapanan_case_id, yeni_gorev_id, hedef_tarih, basladi, yeni_case_id|null}`
    - `protokol_iptal(case, true, p_not)`; yeni görev çıkmazsa `OVSYNC_BASTAN_BASLATILAMADI{case_id, yeniden_not}`.
    - `p_bagimsiz` ya da hedef = bugün ise aynı işlemde `start_first_service_protocol(g, false, p_bagimsiz)` çağrılır.
  - Üç RPC de aynı başlangıçla açılır: `_ovsync_ic_ac()` → `pg_advisory_xact_lock(hashtext('ovsync_tren'))` → bayrak kapalıysa `OVSYNC_TREN_KAPALI` → hayvan `FOR NO KEY UPDATE`.
  - ACL: 4 imzada `REVOKE ALL … FROM PUBLIC, anon` ve `GRANT EXECUTE … TO authenticated, service_role` (canlı `seans_tamamla` ACL'siyle aynı).
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql` (+590)
  - D6 yardımcıları ilk savepoint'ten önce: `kb_kod`, `kb_geri` (geriye fixture), `kb_seans_yap_r`, `kb_seanslar`, `kb_pg_tai`.
  - Yeni "BÖLÜM D6": 22 senaryo bloğu. Önceki bölümlere dokunulmadı.

## Test id → PASS (MEASURED, `~/tmp/ovsync-tren-db/d6/yesil.txt`)
OZET **362 PASS**: önceki 290 ve D6'nın 72 assert'i. Her id en az bir `kb_ok` ile koşuyor.

| id | kapsam | sonuç |
|---|---|---|
| TR-K4-1 | görev bugün+2 → bugün+9 (SONRAKI_TREN), GOREV_ERTELE soyu; +7 → yine +7; p_gun 8/0 → `OVSYNC_TREN_N_GECERSIZ`, hedef değişmedi; boş hayvan → `OVSYNC_VAKA_YOK` | PASS |
| TR-K4-2 | trende aşama 0 vaka: 4 gün +7, etiket bugün+1 → bugün+8 (tek sayım), şablon TAI +7; bağımsız +3 → KAYDI, etiket NULL | PASS |
| TR-K5-1 | aşama 1 +1: gün#1 sabit, gün#2..4 +1, etiket +1, kayma 1 | PASS |
| TR-K5-N1 | +2 → `OVSYNC_ASAMA1_TOLERANS{1,0,2,BASTAN_BASLAT,case_id}`, değişiklik yok | PASS |
| TR-K5-N2 | +1 başarılı, ikinci +1 → TOLERANS `mevcut_kayma 1`, PG1 ilk çağrının halinde | PASS |
| TR-K5-2 | GnRH1 1 gün geç (kayma −1): +2 başarılı (kayma 1, etiket +2), sonra +1 red | PASS |
| TR-K6-N1 | aşama 2 → `OVSYNC_ASAMA2_ERTELEME_YOK{case_id, ["PG48","BASTAN"]}` | PASS |
| TR-ASAMA-N | kısmi seans (aşama NULL) → `OVSYNC_ASAMA_BELIRSIZ{case_id, BASTAN_BASLAT}` | PASS |
| TR-K6-A1 | aşama 2 + PG TAI → pg48: tai_gorev_id/tai_hedef/kapanan_seans; 4 gün tamamlandı, kalan seanslar uygulanmadı, TAI açık, vaka aktif; aşama 1 → `OVSYNC_ASAMA2_DEGIL`; Mastit → `OVSYNC_VAKA_YOK` | PASS |
| TR-K6-A-N1 | VWP içi (doğum bugün−20) → PG TAI yok → `OVSYNC_PG48_TAI_YOK`, seanslar açık | PASS |
| TR-K6-A-N2 | PG olayı ve TAI 3 gün geri → `OVSYNC_PG48_GECMIS`, seanslar açık | PASS |
| TR-K6-B1 | tren bugün+3: eski vaka IPTAL, görev hedefi bugün+3, basladi false, yeni_case_id null; tren bugün: basladi, yeni vaka D0 = etiket = bugün, görev kapandı; Mastit → `OVSYNC_VAKA_YOK` | PASS |
| TR-K6-B2 | `p_bagimsiz` → basladi, D0 = start_date = bugün, etiket NULL | PASS |
| TR-K6-B-N1 (ek) | TABANSIZ → `OVSYNC_BASTAN_BASLATILAMADI{yeniden_not TABANSIZ…}`; Bekliyor tohumlama → `…{BASLATMA_OLMADI, sonuc.atlandi BEKLIYOR}`; ikisinde de vaka açık, görev yok (geri sarıldı) | PASS |
| TR-K11-1 | PG1 planından 2 gün sonra: `occurred_at` = now() ±1 dk, `ovsync_uyari{PG1_TOLERANS_ASILDI, 2, BASTAN_BASLAT, case_id}`; gün#3 geç → uyarı yok | PASS |
| TR-EK-UYARI | `kupe_no`, `planlanan_tarih` = bugün−2, `tamamlanan_tarih` = bugün, `bastan_tren_gunu` = `_ovsync_tren_gunu(bugün)` = bugün+5 | PASS |
| TR-K11-2 | 1 gün geç → uyarı yok, olay anı now() | PASS |
| TR-K11-3 | ertele +1 (kayma 1), yeni plandan 1 gün geç → gecikme 2, uyarı var, planlanan_tarih bugün−1 | PASS |
| TR-K11-REG | bayrak 0: `occurred_at` = planlanan an (LEAST; bir günden eski), uyarı yok | PASS |
| TR-KAPALI | bayrak 0: üç RPC `OVSYNC_TREN_KAPALI`, vaka değişmedi | PASS |
| TR-ACL-3 | 4 imza: anon kapalı, authenticated ve service_role açık, SECDEF, overload yok | PASS |

## Mutant denetimi (MEASURED: `~/tmp/ovsync-tren-db/d6/mutant.txt`, betik `~/tmp/ovsync-tren-db/d6gen/mutant.py`)
**32/32 öldü.** Kapsanan alanlar:
- R13: hep LEAST; bayraksız now().
- K11: gün#2 kontrolü yok; kayma yok; `>=` tolerans; uyarı dönüşe eklenmiyor; iki ek alan yanlış.
- KAPALI kontrolü: 3 RPC'de ayrı ayrı.
- `ovsync_hayvan_ertele`: gün aralığı; görevde ritim formülü; aşama 0'da fark yerine p_gun; aşama 1 çift etiket; kayma yok; `>=`; aşama 2 ve belirsiz reddi; vaka/görev önceliği.
- `ovsync_pg48_tohumla`: aşama, geçmiş, seans kapatma ve TAI kontrolleri.
- `ovsync_bastan_baslat`: başlatma yok; bağımsız iletilmiyor; görev NULL sessiz; muaf sessiz; yeniden başlat yok.
- ACL (authenticated yok, anon açık) ve md5.

Not: "ACL anon açık" mutantı bu sefer öldü, çünkü mutant `GRANT … TO anon` yazıyor (D5'teki REVOKE silme mutantından farklı). Kabul DB'sinin varsayılan anon yetkisi hâlâ ölçülemiyor (D4/D5 açık kalemi, DM1).

## Etki (PLAN.md D6 "Etki")
- JS çağıranlar (atlas `rpc seans_tamamla`, atlas tazelik "taze", sha b9542b1 = main):
  - `api.js:rpcSeansTamamla@1122/cagri@1131`, `forms.js:seansTakipRetry@5336`, `ui.js:_pgKapiAc@2899` (2922'deki rpc).
  - Bu dalda `js/api.js|forms.js|ui.js` main ile aynı; `git diff --stat b9542b1..HEAD -- js/` yalnız `js/ovsync-tren.js` veriyor (OBSERVED). Yani atlas sonucu bu dal için de geçerli.
  - Üçü de adlandırılmış argüman geçiyor ve yalnız `ok/_pgKapi` gibi mevcut alanları okuyor. `ovsync_uyari` ek anahtar, kırıcı değil (INFERRED, kod okuması).
  - Uyarının gösterimi UB4 işi; `js/ovsync-tren.js:ovsyncGecTamamlamaUyariHtml` zaten `kod/gecikme_gun/case_id/kupe_no` okuyor (CONFIRMED).
- authenticated rolüyle JS'deki argüman adlarıyla sondalandı (MEASURED, `~/tmp/ovsync-tren-db/d6/etki.txt`):
  - `seans_tamamla` iki çağrı biçiminde de çözüldü ve `{"ok": false, "mesaj": "Seans bulunamadi"}` döndü.
  - Üç yeni RPC adlandırılmış çağrıyla çözüldü ve `OVSYNC_TREN_KAPALI` verdi (kabul DB'sinde bayrak 0).
  - anon → `permission denied`.
- DB çağıranlar (prosrc taraması, MEASURED):
  - `seans_tamamla`'yı yalnız yeni `ovsync_pg48_tohumla` çağırıyor.
  - `protokol_iptal`'i yalnız yeni `ovsync_bastan_baslat` çağırıyor; imzası ve gövdesi değişmedi.
  - `start_first_service_protocol` 3 argümanlı D4 imzasıyla çağrılıyor; imza değişmedi.
- Regresyon (`ovsync_pg_kabul.sql`, D4 scratch kopyası `pgk-d4imza.sql`, seri 002–006 — D5 ile aynı tarif): **OZET 482 PASS**, `BOLUM 1-bayrak0: 31 PASS`. İkisi de D8a tabanına eşit (MEASURED, `~/tmp/ovsync-tren-db/d6/pgk.txt`).
  - Not: 001 seriye eklenince bu betik S10'da (`gorev_sayisi` 12 ≠ 15) düşüyor. Bu D1'in planlı etkisi, D8 SORU listesinde. D6 ile ilgisiz (MEASURED).

## Varsayımlar (plan boşlukları, gerekçeli)
1. **`ovsync_hayvan_ertele` p_gun 1..7 dışı → `OVSYNC_TREN_N_GECERSIZ{gun,min,max}`.** Plan bu durum için kod vermiyor. UA1 bu koda zaten "Erteleme günü 1 ile 7 arasında olmalı." metnini bağlamış; yeni kod üretmemek için bu seçildi.
2. **Hayvanda aktif OVSYNC vaka varsa vaka esastır, yoksa açık OVSYNC_BASLAT kullanılır.** Normal akışta ikisi birlikte olmaz (start görevi kapatır). Birlikte olursa biyolojik süreç vakadadır.
3. **Aşama 0 trende vakada "sonraki tren" = `_ovsync_tren_gunu_ic(D0 + p_gun, capa, 0, bugün)`.** Görev yoluyla aynı formül. D0 tren günüyse p_gun 1..7 için sonuç her zaman +7; D0 geçmişte kaldıysa bugünden itibaren ilk tren.
4. **`yeni_tarih` değerleri:**
   - görev yolunda `gorev_ertele` dönüşündeki gerçek `hedef_tarih` (D5 review KÜÇÜK dersi: pencere yuvarlaması);
   - aşama 0'da kaydırma sonrası gün#1;
   - aşama 1'de kaydırma sonrası gün#2 (PG1).
5. **pg48 ayrıntıları:**
   - TAI = hayvanın en son hedefli açık `PG_TOHUMLAMA:*` görevi (§18.6 son PG kazanır).
   - Saatsiz TAI gün sonu (23:59 TR) sayılır.
   - Yalnız hastalık-dışı (şablon) günlerin seansları kapanır.
   - `tai_hedef` = görevin `hedef_tarih`'i (tarih).
   - Yeni iç kod `OVSYNC_PG48_SEANS_KAPANMADI`: hayvan kilidi altında `seans_tamamla` `ok:false` dönemez, ama dönerse sessiz geçilmesin diye.
6. **bastan_baslat fail-closed:**
   - aktif OVSYNC olmayan vaka → `OVSYNC_VAKA_YOK`;
   - başlatma istendi (bağımsız ya da hedef = bugün) ama `start_first_service_protocol` vaka açmadıysa (muafiyet, ör. Bekliyor) → `OVSYNC_BASTAN_BASLATILAMADI{yeniden_not:'BASLATMA_OLMADI', sonuc}`. İşlem geri sarılır; vaka sessizce kapanıp hayvan Ovsync'siz kalmaz (TR-K6-B-N1).
7. **R13 kapsamı:** tren açık ve aktif OVSYNC vakanın her seansı (plan: "OVSYNC vaka seansında"). Uyarı yalnız PG1 günü seansında ve kayma hesaplanabildiğinde çıkar. Çok seanslı PG1 gününde son seans kapanınca; aşama belirsizse uyarı yok.
8. **`planlanan_tarih` = PG1 gününün güncel `treatment_date`'i** (ertelendiyse yeni plan, ruling lafzı "PG1 gününün planlı tarihi"). `gecikme_gun` ise birikimli (R18): K11-3'te planlanan bugün−1, gecikme 2. UI metni "PG planlanan günden N gün sonra" `gecikme_gun`'u kullanıyor. Kullanıcı ertelemiş hayvanda iki sayı farklı görünebilir; UB4'te dikkat.
9. **Yeni `islem_log` tipi yok.** Alt çağrılar kendi kaydını yazıyor: GOREV_ERTELE, VAKA_KAYDIR, TOHUMLAMA_ERTELE, TEDAVI_SEANS_IPTAL, PROTOKOL_IPTAL, FIRST_SERVICE_PROTOCOL_STARTED. Geçmiş sekmesine (§16) bilinmeyen tip eklenmedi.
10. **İç bayrak (`app.ovsync_tren_ic`) işlem sonuna kadar açık kalıyor** (R5 "başta set_config", is_local). PostgREST'te her RPC kendi işlemi olduğu için etkisi yok.
11. **Kilit sırası** `seans_tamamla` ile aynı: hayvan `FOR NO KEY UPDATE` → vaka/seans → görev. Advisory kilit en başta.

## Kırıntılar
- measurement: OZET 362 PASS; db-validate 006 PASS (7b17f288); mutant 32/32; pg_kabul seri 002–006 482/31 = taban; commit 00420d2 (ss-crumbs yazıldı).
- assumption: p_gun aralığı → `OVSYNC_TREN_N_GECERSIZ`; vaka > görev önceliği (ss-crumbs yazıldı).
- assumption: `ovsync_uyari.planlanan_tarih` = güncel PG1 günü, `gecikme_gun` birikimli (ss-crumbs yazıldı).
- open_item: `ovsync_bastan_baslat` aşama 2'de, tren bugün değilse (başlatma yok), hayvanın açık `PG_TOHUMLAMA` TAI'si açık kalıyor. Sebep: `_vaka_kapat` yalnız `TEDAVI_SABLON_TOHUMLAMA:<case>` TAI'sini kapatıyor (kanit `_vaka_kapat.sql:118-121`); start ise PG TAI'lerini ancak başlattığında kapatıyor (004 start gövdesi). Sonuç: hayvan treni beklerken PG+48 TAI görünmeye devam eder. INFERRED, kod okuması; ölçülmedi. Kapanış: root/sahip kararı ya da D7/UB3'te kabul (ss-crumbs yazıldı).
- open_item (devralınan): anon EXECUTE'un kabul DB'sinde varsayılan yetkiyle ölçülememesi → DM1 apply sonrası `has_function_privilege` (D4/D5 ile aynı).
- Kod keşfi: atlas (`rpc`, `status` taze, main b9542b1) kullanıldı. Dalın js/ farkı yalnız `js/ovsync-tren.js`, bu yüzden atlas bu dal için geçerli. gitnexus kullanılmadı: worktree indeksli değil (UA1-report). `analyze` koşulmadı (ortak.md: lead kulvar sonunda).

## Run kanıtı
Kırmızı (testler önce yazıldı, 006 seride yok; ham çıktı `~/tmp/ovsync-tren-db/d6/kirmizi.txt`), rc: 3:
```
NOTICE:  PASS TR-ACL-D5: D5 ACL
ERROR:  function public.ovsync_hayvan_ertele(text, integer) does not exist
SATIR 1: v_r := public.ovsync_hayvan_ertele(v_h, 1)
                ^
İPUCU:  No function matches the given name and argument types. You might need to add explicit type casts.
SORGU:  v_r := public.ovsync_hayvan_ertele(v_h, 1)
BAĞLAM:  PL/pgSQL function inline_code_block line 9 at assignment
```

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-KAPALI: bayrak 0 → OVSYNC_TREN_KAPALI
NOTICE:  PASS TR-ACL-3: D6 ACL
NOTICE:  OZET: 362 PASS
```

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-7b17f288.md
 İzole DB'ler drop edildi: egesut_val_3890044_fdbeff78 egesut_val_3890044_d29f86dd
════════════════════════════════════════════════
```

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## Kabul
- Kabul betiği son satırı `NOTICE:  OZET: 362 PASS`. Brief'teki 19 id ile TR-EK-UYARI (sözleşme eki) ve ek TR-K6-B-N1 en az bir `kb_ok` ile PASS (tablo). MEASURED
- db-validate exit 0 (PASS, 7b17f288). MEASURED
- `grep CURRENT_DATE` boş. MEASURED
- Etki maddesindeki çağıranlar kırılmıyor (Etki bölümü). MEASURED (sonda), INFERRED (JS sonuç tüketimi)
- Commit dosya dosya, mesaj `ovsync-tren L-DB D6: …` (00420d2). CONFIRMED

## D6 tur 2
sonuc: TAMAM · commit: 7ce4781 (`ovsync-tren L-DB D6 tur 2: K6 a/b dışlaması (PG TAI kapanır) + kilit sırası`). Staged yalnız 2 dosya (`git diff --cached --stat`: migration 006 +11/-2, kabul.sql +29/-1). CONFIRMED
Gelen iş denetimi: bulgu yok. Kapsam = Devam'daki 4 dar fix (T2 tur 1 DÜZELT, review-report:15-18; RL-12).
Tur 1 rapor başlığı: `iş=ovsync-tren D6 aşama RPC'leri + K11` (ilk satır tur 2 başlığıyla değişti; tur 1 içeriği aynen duruyor).

### Fix'ler
1. (ÖNEMLİ, RL-12) `ovsync_bastan_baslat` basladi=false dalı (`ELSE`): hayvanın açık `TOHUMLAMA_PLANLI` + `kaynak LIKE 'PG_TOHUMLAMA:%'` görevleri 004 `start_first_service_protocol` ile aynı UPDATE yolu ve işaretiyle kapanır (`iptal=true, tamamlandi=true, kapatan_ref='ILK_TOH_PROTOKOL_YERINE:…'`). basladi=true dalı değişmedi (orada start_first_service_protocol zaten kapatıyor). Artık üç dal da (tren bugün / tren ileride / p_bagimsiz) PG TAI bırakmaz. MEASURED (TR-K6-B1 aşama 2 alt senaryosu)
   - Varsayım: başlamayan dalda henüz yeni vaka yok → sonek `v_case_id` yerine yerine geçen OVSYNC_BASLAT görevinin id'si (`yeni_gorev_id`). Önek birebir aynı; tek tüketici `LIKE 'ILK_TOH_PROTOKOL_YERINE%'` (supabase/tests/ovsync_pg_kabul.sql:1318), js/'de tüketici yok (grep). INFERRED
2. (ÖNEMLİ) TR-K6-B1'e aşama 2 alt senaryosu (seans 1+2, PG TAI açık): tren bugün+3 → `basladi=false` ve tren bugün → `basladi=true`; ikisinde de `pg_temp.kb_pg_tai(v_h) IS NULL` + eski TAI satırı `iptal AND tamamlandi AND kapatan_ref LIKE 'ILK_TOH_PROTOKOL_YERINE:%'`. 4 yeni `kb_ok` (2 fixture + 2 assert). Önce test → FAIL → fix → PASS.
3. (KÜÇÜK) `ovsync_pg48_tohumla` ve `ovsync_bastan_baslat`: hayvan kilidi (`FOR NO KEY UPDATE`) artık vaka `status='active'` SELECT'inden önce alınıyor (hayvan id vaka id'den alt sorguyla); kilitten sonra kapanmış vaka OVSYNC_VAKA_YOK ile reddedilir. Sıra ovsync_hayvan_ertele ile aynı. Yarış ölçülmedi; mevcut testler (TR-K6-A*, TR-K6-B*, TR-ACL-3, TR-KAPALI) PASS. OBSERVED (kod) / INFERRED (yarış)
4. (KÜÇÜK) Tur 1 bölümündeki "Bayrak 0'da … ayar okunmaz" ifadesi düzeltildi: ayar varsayılanlı okunur, hata vermez, davranış aynı.

### Etki
İmzalar değişmedi (`ovsync_bastan_baslat(uuid, boolean, text)`, `ovsync_pg48_tohumla(uuid)`; ACL satırları aynı). Çağıran: js/ ve index.html'de yok; migration 003:84 yalnız yorum; D7 henüz yazılmadı (toptan BASTAN bu düzeltilmiş davranışı devralır). OBSERVED (grep)

### Run kanıtı
Red (fix öncesi, test eklendikten sonra):
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat … 006 … ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1
```
rc: 3
```
ERROR:  FAIL TR-K6-B1: beklenen aşama 2, basladi=false: PG TAI iptal (ILK_TOH_PROTOKOL_YERINE) gerçek {"ok": true, "basladi": false, "hedef_tarih": "2026-11-12", "yeni_case_id": null, "yeni_gorev_id": "e075be73-d1d9-4375-a6a9-2c6a5c9a167c", "kapanan_case_id": "1b69d035-4d14-4c9b-946e-fa3fe503dbdc"} ce529dc7-e7cb-4260-abec-c3beea2cc538
```

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-KAPALI: bayrak 0 → OVSYNC_TREN_KAPALI
NOTICE:  PASS TR-ACL-3: D6 ACL
NOTICE:  OZET: 366 PASS
```
(tam günlükte FAIL satırı 0; `NOTICE:  PASS TR-K6-B1: baştan başlat → trene bin` var. 362 → 366 = +4 yeni kb_ok.) MEASURED

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-eb7eaea9.md
 İzole DB'ler drop edildi: egesut_val_4130130_5fcb6979 egesut_val_4130130_6fb3e297
════════════════════════════════════════════════
```
MEASURED

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
MEASURED

### Kırıntılar (tur 2)
- assumption: kapatan_ref soneki = yeni OVSYNC_BASLAT görev id'si (fable-rol-ve-davranislar)
- measurement: red → 366 PASS, db-validate PASS eb7eaea9, grep boş

BOYUT: bütçe 450 · gerçek 462 (tur 2: +11/-2 üretim SQL) · aşım 12 satır: tur 1'deki 453'ün 3 satırlık aşımına (222 satır prod gövdesi kopyası) RL-12 kapatma bloğu (7) ve kilit sırası (2×2 eklendi, 2 silindi) eklendi.
