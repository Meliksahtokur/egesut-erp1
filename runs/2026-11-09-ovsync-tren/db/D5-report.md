⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D5: K10 sunucu kilidi (gorev_ertele/tohumlama_gorev_ertele/vaka_kalan_gunleri_kaydir/_coklu) + K9 hastalık günü + RL-1 etiket + D4 :432 dar fix⟧
sonuc: TAMAM

## Gelen iş denetimi
- Bulgu 1 (MEASURED): kabul DB'sinde `gorev_ertele_kural` boş (verisiz kurulum). `gorev_ertele`'nin kural adımı (fail-closed) kilitten önce geliyor. Bu yüzden kural tohumlanmadan TR-K10-1/2 kilide hiç ulaşmaz (sahte PASS/FAIL riski). Çözüm: test yardımcısı `kb_ertele_kural()` prod satırlarını senaryo içinde tohumluyor. Prod değerleri Mgmt API `read_only` ile okundu (OVSYNC_BASLAT/TOHUMLAMA_PLANLI `tohumlama`, ILAC `yok`, TEDAVI_GUN/SEANS ertelenemez).
- Bulgu 2 (MEASURED): Ovsync şablonu TAI'yi `tedavi_sablon_uygula` içinde açmıyor; TAI ayrı RPC `tedavi_sablon_tohumlama_gorev_ekle` ile açılıyor. Testler `kb_ovsync_tai()` ile TAI'yi bu RPC'den açıyor.
- Bulgu 3 (MEASURED): db-validate statik denetimi, prod `ovsync_hastalik_gunu_ekle` gövdesindeki `FROM jsonb_array_elements(…)` satırını tablo sanıp INCONCLUSIVE (rc=2) verdi (rapor db-validation-b7c863ff.md). Satıra `pg_catalog.` öneki eklendi; fonksiyon çözümlemesi aynı (pg_catalog her zaman önce aranır). Ayrıntı Varsayım 2'de.
- Bunların dışında bulgu yok. Okuduklarım:
  - PLAN.md: Global Constraints, R1–R20, N1 sözleşmesi, D0–D8, Kapı tur 2.
  - ortak.md, progress.md (RL-1..RL-10, SORU-1..3).
  - D4-report, D4-review-report, govde-taban.md.
  - domain-rules §18 (18.6/18.10/18.18/18.19).
  - Etkilenen 5 prod gövdesi (kanit/fn).
- build.sh koşulmadı (RL-9).

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql` (yeni, 754 satır).
  - md5 koruması: 5 fonksiyon, D0 prod değerleri. Gövde farklıysa `<FN>_GOVDE_FARKLI`.
  - Gövdeler üretici betikle kopyalandı: `~/tmp/ovsync-tren-db/d5gen/gen.py`. Betik her kanit gövdesinin md5'ini kopyadan önce doğruluyor.
  - Kanit ile migration farkı +63/−6 satır, hepsi "D5" bloklarında (CONFIRMED, `~/tmp/ovsync-tren-db/d5gen/govde-diff.txt`).
  - `gorev_ertele`: adım 3 (yalnız açık görev) sonrası `PERFORM public._ovsync_kilit_gorev(p_gorev_id);`.
  - `tohumlama_gorev_ertele`: açık-görev kontrolü sonrası aynı satır.
  - `vaka_kalan_gunleri_kaydir`:
    - vaka kilidi/doğrulamasından sonra `PERFORM public._ovsync_kilit_vaka(p_case_id);`.
    - RL-1: TAI döngüsünden sonra `UPDATE cases SET ovsync_tren = ovsync_tren + p_gun WHERE id = p_case_id AND ovsync_tren IS NOT NULL`.
  - `vaka_kalan_gunleri_kaydir_coklu`:
    - Döngüden önce, tren açık ve iç çağrı değilken, `cozulen` CTE'sinin 3. birebir kopyası ile aktif `protocol_family='OVSYNC'` vakalarının görevleri ayrılıyor.
    - Vaka döngüsü `NOT (case_id = ANY(v_ovsync_vakalar))` ile bu vakaları dışlıyor.
    - Dönüşe ve `VAKA_KAYDIR_TOPLU` payload'ına `ovsync_atlanan:[{gorev_id, case_id, hayvan_id, kupe_no}]` ekleniyor (görev başına bir satır).
    - Bu satırlar `toplam/atlanan/hatalar`'a girmiyor.
  - `ovsync_hastalik_gunu_ekle`:
    - İlk deyim `PERFORM public._ovsync_ic_ac();`.
    - Yeni gün INSERT'inden sonra `UPDATE cases SET ovsync_tren = NULL WHERE id = p_case_id AND ovsync_tren IS NOT NULL; v_tren_ayrildi := FOUND;`.
    - Her `ok:true` dönüşünde `tren_ayrildi` alanı var.
  - ACL (dosya sonu, 5 imza): `REVOKE ALL … FROM PUBLIC, anon` ve `GRANT EXECUTE … TO authenticated, service_role` (canlı ACL ile eşlik).
  - İmzalar aynı, DROP yok.
  - Bayrak 0'da davranış:
    - Kilit yardımcıları erken döner; çapa okunmaz (TR-K10-REG bozuk çapayla).
    - coklu kümesi boş kalır.
    - Etiket UPDATE'leri satır bulmaz (kolon NULL).
    - Tek fark ek dönüş alanları: `ovsync_atlanan:[]`, `tren_ayrildi:false`.
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:432` — D4 review KÜÇÜK dar fix, brief'teki metinle birebir: `CASE WHEN public._ovsync_tren_aktif() THEN CASE WHEN public._ovsync_tren_gunu_mu(v_bas) THEN v_bas END END`. TR-K8-REG yeniden PASS, db-validate 004 yeniden PASS.
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql` (+437).
  - D5 yardımcıları ilk savepoint'ten önce: `kb_ertele_kural`, `kb_ovsync_tai`, `kb_mastit`, `kb_vaka_gorev`, `kb_gunler`, `kb_ekrani`.
  - Yeni "BÖLÜM D5" (14 senaryo bloğu). Önceki bölümler değişmedi.

## Test id → PASS (MEASURED, `~/tmp/ovsync-tren-db/d5/yesil.txt`)
OZET **265 PASS** (önceki 220 + D5'in 45'i). Her id en az bir `kb_ok` ile koşuyor.

| id | kapsam | sonuç |
|---|---|---|
| TR-K10-1 | açık: Ovsync şablon TAI'sine `gorev_ertele` → `OVSYNC_TREN_EKRANI{gorev_id, hayvan_id, tren_gunu=vaka treni}`; TAI yerinde, erteleme kaydı yok | PASS |
| TR-K10-2 | `OVSYNC_BASLAT`'a `gorev_ertele` → aynı kod (tren_gunu = hedef); hedef yerinde | PASS |
| TR-K10-3 | `tohumlama_gorev_ertele` hem şablon TAI'sinde hem `PG_TOHUMLAMA` TAI'sinde → kilit; ikisi de yerinde | PASS |
| TR-K10-4 | `vaka_kalan_gunleri_kaydir` (OVSYNC) → `{case_id, hayvan_id, tren_gunu}`; günler, TAI ve etiket yerinde | PASS |
| TR-K10-5 | `_coklu([ovsync_gorev, mastit_gorev],1)` → toplam 1, kaydırılan 1, atlanan 0, hatalar `[]`, `ovsync_atlanan` tam 1 satır (4 alan, küpe dahil); mastit +1, Ovsync yerinde; islem_log payload'ında var; yalnız Ovsync (aynı vakadan 2 görev) → 2 satır, toplam 0 | PASS |
| TR-K10-6 | Ovsync'siz hayvanın TAI'si `gorev_ertele` ve `tohumlama_gorev_ertele` ile ertelenir | PASS |
| TR-K10-7 | aktif OVSYNC vakalı hayvanın ILAC (E Vitamini) görevi ertelenir | PASS |
| TR-K10-8 | aynı hayvanın Mastit vakası +2 kayar, Ovsync vakası yerinde, Mastit etiketi NULL | PASS |
| TR-K10-9 | `_ovsync_gorev_mu`: OVSYNC_BASLAT / PG_TOHUMLAMA TAI / Ovsync TEDAVI_SEANS true; Mastit TEDAVI_GUN / ILAC false | PASS |
| TR-K10-REG | bayrak 0 + bozuk çapa: 1–4 ertelenir/kayar (TAI +1), etiket NULL; coklu Ovsync vakasını kaydırır, `ovsync_atlanan []` | PASS |
| TR-K10-IC | `_ovsync_ic_ac()` sonrası OVSYNC vaka kayar, TAI +1 (TOHUMLAMA_ERTELE soyu); **RL-1**: etiket +1, ardışık +2 → +3 toplam; bağımsız vaka kayar ve NULL kalır; iç bayrakla `gorev_ertele` ve coklu çalışır (etiket +1 daha) | PASS |
| TR-K9-1 | açık: hastalık → `tren_ayrildi true`, etiket NULL, TAI +7, gün bugün, iç bayrak açık; 2. çağrı `mevcut`, `tren_ayrildi false`, TAI tekrar ötelenmez; bağımsız → false; bayrak 0 → TAI +7, false | PASS |
| TR-K9-N1 | K9 sonrası `ovsync_tren IS NULL`; sonraki kaydırmada da NULL (D7'de `ovsync_tren_listele` assert'i eklenecek) | PASS |
| TR-ACL-D5 | 5 imza var, tek overload; anon kapalı; authenticated ve service_role açık; SECDEF | PASS |
| TR-K8-REG | D4 :432 fix sonrası yeniden | PASS |

## Mutant denetimi (MEASURED: `~/tmp/ovsync-tren-db/d5/mutant.txt`, betik `~/tmp/ovsync-tren-db/d5gen/mutant.py`)
**19/21 öldü.** Öldürülen mutantlar: üç kilit satırı, RL-1 yok ya da +1, coklu (ayırma yok, bayrak yok, iç yok, döngü dışlama yok, aile filtresi yok, payload yok, dönüş yok, küpe yok), hastalık (iç bayrak yok, ayırma yok, `ayrildi` hep true, mevcut alanı yok), ACL authenticated, md5.

Sağ kalan ya da uygulanamayan iki mutant:
- "ACL anon açık": env-mismatch. D4 ile aynı sebep: kabul DB'si anon'a varsayılan EXECUTE vermiyor (INFERRED). Migration satırı doğru (`FROM PUBLIC, anon`, CONFIRMED). Açık kalem: apply sonrası ölçülecek.
- "RL-1 IS NOT NULL koruması yok": desen eşleşmedi, uygulanamadı. Mutant zaten eşdeğer: NULL + n = NULL, ve `_degisim_log_yaz` değişmeyen satırda kayıt yazmıyor (`v_alanlar IS NULL → RETURN NULL`, OBSERVED gövde). Kalan tek fark ölü bir UPDATE (INFERRED).

## Etki (PLAN.md D5 "Etki"), MEASURED
- **DB çağıranlar** (pg_proc prosrc taraması, kabul DB):
  - `tohumlama_gorev_ertele` ← `vaka_kalan_gunleri_kaydir` ve `ovsync_hastalik_gunu_ekle`. İkisi de iç bayrakla korunuyor:
    - kaydırma: TR-K10-IC'de iç bayrakla TAI taşındı.
    - hastalık: RPC bayrağı kendi açıyor. TR-K9-1'de TAI +7 oldu; "hastalık iç yok" mutantında `OVSYNC_TREN_EKRANI` ile düştü, yani koruma gerçek.
  - `vaka_kalan_gunleri_kaydir` ← `_coklu`: OVSYNC vakaları döngüye girmeden ayrılıyor (TR-K10-5).
  - `gorev_ertele`'yi çağıran DB fonksiyonu yok.
- **JS çağıranlar** (atlas `rpc`):
  - `gorev_ertele` ← `ui.js:_erteleKaydet@3793`
  - `vaka_kalan_gunleri_kaydir` ← `ui.js:caseKalanGunleriKaydir@13194`
  - `vaka_kalan_gunleri_kaydir_coklu` ← `api.js:apiCokluKaydir@1237`
  - `ovsync_hastalik_gunu_ekle` ← `ui.js:hastalikGunKaydet@1545` / `cagri@1618`
  - `tohumlama_gorev_ertele` ← JS yok (yalnız RPC_TABLES)
- authenticated rolüyle JS'deki adlandırılmış argümanlarla sondalandı (`~/tmp/ovsync-tren-db/d5/etki.txt`). Hepsi çözüldü ve beklenen iş hatasını ya da dönüşü verdi:
  - `GOREV_BULUNAMADI` / `VAKA_BULUNAMADI`
  - coklu `{… "ovsync_atlanan": []}`
  - hastalık `OVSYNC_VAKA_BULUNAMADI`
  - anon → `permission denied`.
- Dönüş alanı eklemeleri kırıcı değil; `js/ovsync-tren.js:ovsyncCokluAtlananNot` zaten `ovsync_atlanan[].kupe_no` bekliyor (CONFIRMED).
- **Regresyon** (`ovsync_pg_kabul.sql`, D4 scratch kopyası `pgk-d4imza.sql`, seri 002–005): **OZET 482 PASS**, `BOLUM 1-bayrak0: 31 PASS`. İkisi de D8a tabanına eşit (MEASURED, `~/tmp/ovsync-tren-db/d5/pgk.txt`). D5 yeni bir kırılma eklemiyor.

## Run kanıtı
Kırmızı (005 yok, testler önce yazıldı; `~/tmp/ovsync-tren-db/d5/kirmizi.txt`), rc: 3:
```
NOTICE:  PASS TR-ACL-2: D4 ACL
ERROR:  FAIL TR-K10-1: beklenen OVSYNC_TREN_EKRANI {gorev_id, hayvan_id, tren_gunu = vakanın treni} gerçek <NULL>
BAĞLAM:  PL/pgSQL function pg_temp_3.kb_ok(boolean,text,text,text) line 4 at RAISE
```

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-K9-N1: hastalık günlü hayvan trende değil
NOTICE:  PASS TR-ACL-D5: D5 ACL
NOTICE:  OZET: 265 PASS
```

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-d8b305f2.md
 İzole DB'ler drop edildi: egesut_val_2934277_26ca0b75 egesut_val_2934277_0f256bb6
════════════════════════════════════════════════
```
(İlk koşum INCONCLUSIVE idi, rc 2, rapor db-validation-b7c863ff.md: `B.sema-uyum statik çözülemedi: jsonb_array_elements`. Bulgu 3 ile giderildi.)

2b) D4 dosyası yeniden (brief görev notu):
```
bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-e02fdf5f.md
 İzole DB'ler drop edildi: egesut_val_2945316_64b6c17b egesut_val_2945316_730572b1
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
- `OZET: 265 PASS`; listelenen 13 TR-* id'si ve ek TR-ACL-D5 en az bir `kb_ok` ile PASS (tablo). MEASURED
- db-validate 005 exit 0, PASS. 004 de yeniden PASS. MEASURED
- CURRENT_DATE grep'i boş. MEASURED
- Etki listesindeki çağıranlar kırılmıyor (yukarıda). MEASURED; tek istisna anon ACL, kabul DB'de ölçülemiyor (INFERRED).
- Commit `6eabd94`: "ovsync-tren L-DB D5: K10 sunucu kilidi + K9 hastalık günü (…) + D4 :432 iç içe CASE".
  - `git add` dosya dosya yapıldı.
  - `git diff --cached --stat` = yalnız 3 dosya (004 +1/−1, 005 +754, kabul +437).
  - Report commit'lenmedi (önceki görevlerle aynı). Push yok. MEASURED

BOYUT: bütçe 600 · gerçek 755 · gerekçe:
- 649 satır 5 prod gövdesinin zorunlu tam kopyası (145+88+177+144+95; CREATE OR REPLACE tam gövde ister).
- Başlık, md5 koruması ve ACL ~48 satır.
- D5'in kendi değişikliği +63/−6 satır; bunun 15 satırı coklu CTE'sinin 3. kopyası.
- Ayrıca 004'te 1 satır değişti.

## Varsayımlar
- Varsayım 1 (hastalık, mevcut gün): `tren_ayrildi` mevcut-gün dönüşlerinde (idempotent ikinci çağrı, unique yarışı) `false`. Etiket yalnız yeni gün yazıldığında düşer (plan lafzı "gün yazıldıktan sonra").
  - D5 sonrası her hastalık günü yazımı etiketi zaten düşürüyor; D8 göçü de hastalık günlü vakaya üyelik yazmıyor (R14). Bu yüzden "gün var ama etiket dolu" durumu yalnız D5 öncesi veride olabilir, o da bayrak 0 olduğu için olmaz (INFERRED).
  - `ok:false` hata dönüşlerine alan eklenmedi.
- Varsayım 2 (gövde sapması): `ovsync_hastalik_gunu_ekle` içinde `FROM jsonb_array_elements(` → `FROM pg_catalog.jsonb_array_elements(` (D5 yorumlu).
  - Sebep: plan dışı ama zorunlu; db-validate kabul kriteri statik denetimin INCONCLUSIVE'ini başka türlü geçemez. Emsal: D4'ün `(v_tren)` paranteziyle aynı.
  - Davranış eşdeğer: `search_path` = public, pg_temp; pg_catalog örtük olarak önce aranır; public'te aynı adlı fonksiyon yok (INFERRED).
- Varsayım 3 (coklu küme tanımı): ayrılan vaka = `status='active' AND protocol_family='OVSYNC'`. Bu `_ovsync_kilit_vaka` ile aynı tanım; ayrılan her vaka iç RPC'de kilide takılacak olanla birebir.
  - `_vaka_ovsync_mu`'nun eski (ailesiz) vakaları kapsanmıyor, çünkü kilit de onları kapsamıyor.
  - Kapalı OVSYNC vakasının açık görevi `ovsync_atlanan`'a değil, eskisi gibi `hatalar`/`atlanan`'a düşer. Bu durum için test yok (ERTELENEBİLİR).
- Varsayım 4 (RL-1 yeri): etiket UPDATE'i başarı yolunda TAI döngüsünden sonra ve audit'ten önce. Kaydırılan gün satırı 0 olsa da etiket kayar (RL-1 lafzı: "kaydırma başarılıysa").
- Varsayım 5 (ACL): 5 fonksiyonda canlı ACL korundu, yani authenticated ve service_role açık (D4 emsali).
- Varsayım 6 (test fixture'ı): `kb_ertele_kural()` prod `gorev_ertele_kural` satırlarının alt kümesini tohumluyor (MEASURED 2026-11-09, Mgmt API `read_only`, yazma yok).

## Kırıntılar
- measurement: OZET 265 PASS; db-validate 005 PASS d8b305f2 ve 004 PASS e02fdf5f; mutant 19/21; ovsync_pg_kabul scratch 482/31 = taban; commit 6eabd94 (ss-crumbs kaydedildi).
- assumption: mevcut gün `tren_ayrildi=false`; `pg_catalog.jsonb_array_elements`; coklu küme = kilit tanımı (ss-crumbs kaydedildi).
- open_item (DM1/prod): 5 RPC için apply sonrası `has_function_privilege('anon', …) = false` ölçümü (ss-crumbs kaydedildi, koşul: apply sonrası ölçüm).
- open_item (D7): TR-K9-N1'e `ovsync_tren_listele` assert'i (plan gereği D7'de).
- open_item (D8, bilgi): kabul DB'sinde `gorev_ertele_kural` boş. Gelecekte `gorev_ertele` kullanan D6–D8 testleri (R9 yeniden hedefleme `gorev_ertele` üzerinden) `kb_ertele_kural()` çağırmalı, yoksa `TIP_ERTELENEMEZ` alırlar.
- Not: gitnexus analyze koşulmadı (ortak.md: kulvar sonunda lead koşar). Geçici dosyalar `~/tmp/ovsync-tren-db/d5/` ve `~/tmp/ovsync-tren-db/d5gen/` altında.
