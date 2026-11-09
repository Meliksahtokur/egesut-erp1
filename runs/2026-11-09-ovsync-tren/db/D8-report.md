⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D8 ayar/göç + regresyon + geri alma provası⟧
sonuc: TAMAM
job_id: j-20261109T084230Z-dc2082
commit: acd0f71 (dal ovsync-tren, push yok)
BOYUT: bütçe 200 · gerçek 169 · bütçe içinde. Migration'da 169 satır var; yorum ve boş satırlar hariç 137. Test, geri-al.sql ve md dosyaları sayılmadı.

## Gelen iş denetimi
- PLAN.md D8'de "Etki" maddesi yok. D8 mevcut hiçbir fonksiyonun gövdesini ya da imzasını değiştirmiyor, yalnız iki yeni RPC ekliyor. Etki kanıtı aşağıda "Etki" bölümünde.
- Kalan maddeler ölçülebilir ve verilen dosyalarla yapılabilir.

## Yapılan
1. `supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql`
   - `ovsync_tren_yeniden_hedefle(p_kuru DEFAULT true, p_capa DEFAULT NULL)` şunu döndürür: `{ok, kuru, capa, gorevler:[{gorev_id, hayvan_id, kupe_no, eski, yeni, durum}], uyelik:[{case_id, hayvan_id, tren}], belirsiz_asama:[{case_id, hayvan_id, kupe_no}], belirsiz_sayisi}`.
     - Yeni hedef R9 formülüyle hesaplanır.
     - Kural yoksa `KURAL_YOK` olur, `yeni` null kalır ve göreve dokunulmaz.
     - Kuru mod bayrağa bakmaz ve hiçbir şey yazmaz.
     - Kuru olmayan modda bayrak kapalıysa `OVSYNC_TREN_KAPALI` döner. Açıksa advisory lock alınır, iç bayrakla `gorev_ertele` çağrılır (GOREV_ERTELE soyu korunur), R14 üyeliği yazılır ve iç bayrak eski değerine döner.
     - `belirsiz_asama` alanı R6-EK için eklendi.
   - `ovsync_tren_ayar_guncelle(p_aktif, p_capa)` şunu döndürür: `{ok, aktif, capa, yeniden_hedef|null}`.
     - `p_aktif` NULL ise ya da açılışta `p_capa` NULL ise `OVSYNC_TREN_AYAR EKSIK` döner.
     - Çapa satırın min/max sınırı (20260101..20991231) dışındaysa `ARALIK_DISI` döner.
     - Değişen satır `protokol_ayar_guncelle` üzerinden yazılır, böylece PROTOKOL_AYAR snapshot'ı birebir aynı olur. Değişmeyen satır yazılmaz.
     - Açılışta önce `_ovsync_tren_ayar()` doğrulaması, ardından `yeniden_hedefle(false)` koşar.
     - Kapatma ayarı doğrulamaz; böylece bozuk ayarda da hızlı geri çalışır.
   - ACL: iki RPC'de de anon ve PUBLIC kapalı, authenticated ve service_role açık.
2. `supabase/tests/ovsync_tren_kabul.sql`: D8 bölümü eklendi. Mevcut bölümlere dokunulmadı; tek ek, aşağıdaki 22:00 assert'i.
   - TR-GOC-1..5, TR-AYAR-P1/N3/N5/CRON, TR-ACL-5 ve TR-ANAH-2 (D3 KÜÇÜK) yazıldı.
   - D5 KÜÇÜK için TR-D4EK-1'e assert eklendi: 22:00'deki görev R9 treni olan bugün+3'e gitmiyor, yuvarlamayla bugün+4 09:00'a kayıyor.
3. `supabase/tests/ovsync_pg_kabul.sql`: root ruling SORU-4 kapsamında A5 (S10 iki dal + d2 hatırlatması, RL-13), A6 (3 imza + 3 "DROP edildi") ve A7 (R32-3 R10 anahtarı) uygulandı. Her değişikliğin yanında `-- root ruling 2026-11-09 SORU-4 Ax` yorumu var.
4. `runs/2026-11-09-ovsync-tren/db/geri-al.sql` (N7-P11): hızlı geri yorum olarak duruyor; tam geri çalıştırılabilir. Kapsamı:
   - D3/D4'ün 3 yeni imzası DROP.
   - 24 yeni fonksiyon DROP; D6 `ovsync_bastan_baslat(uuid,boolean,text,date)` ve D8'in iki RPC'si dahil.
   - D0 kanıt gövdelerinden 16 CREATE OR REPLACE.
   - Prod desenine göre ACL.
   - `cases.ovsync_tren` DROP; bu adım sahip onayı ister.
   - 5 ayar satırı DELETE.
   - Doğrulama DO bloğu; md5 tutmazsa RAISE.
5. `d8-regresyon.md` ve `d8-pgk-assert-diff.txt`.

## TR-* id → PASS (son koşum, MEASURED)
```
NOTICE:  PASS TR-GOC-1: kuru göç listesi
NOTICE:  PASS TR-GOC-2: açılışta göç yazıldı
NOTICE:  PASS TR-GOC-3: idempotent
NOTICE:  PASS TR-GOC-4: R14 üyelik
NOTICE:  PASS TR-GOC-5: belirsiz aşama sayımı
NOTICE:  PASS TR-AYAR-P1: kapatma
NOTICE:  PASS TR-AYAR-N3: eksik/bozuk ayar
NOTICE:  PASS TR-AYAR-N5: çapa aralığı
NOTICE:  PASS TR-AYAR-CRON: bozuk ayar sessiz geçmez
NOTICE:  PASS TR-ACL-5: D8 ACL
NOTICE:  PASS TR-ANAH-2: R10 son tohumlama sırası
NOTICE:  PASS TR-D4EK-1: gecikmiş görev ilk trene bağlanır   (22:00 assert'i dahil)
```
TR-*-REG testlerinin hepsi PASS: REG-1, REG-DOGUM, G9-REG, UYARI-REG, K8-REG, K10-REG, K11-REG.

## Test-önce (kırmızı) — MEASURED
Testler 001..007 serisiyle, migration yokken koşuldu. rc 3 döndü ve ilk D8 testinde durdu:
```
ERROR:  function public.ovsync_tren_yeniden_hedefle(boolean, date) does not exist
SORGU:  v_r := public.ovsync_tren_yeniden_hedefle(true, v_x)
```

## Mutant denetimi — MEASURED (13/13 öldü)
Mutantlar şunlardı:
- M1 GREATEST(kural, eski) yerine yalnız kural
- M2 hedef ≥ bugün yerine > bugün
- M3 hastalık dışlaması kaldırıldı
- M4 iç bayrak geri yüklenmiyor
- M5 üst çapa sınırı kaldırıldı
- M6 TASINIR yazılmıyor
- M7 üyelik yazılmıyor
- M8 belirsiz filtresi bozuldu
- M9 KURAL_YOK dalı kaldırıldı
- M10 değişmeyen ayar da yazılıyor
- M11 KAPALI kapısı kaldırıldı
- M12 003 R10 sırası ASC
- M13 ritim filtresi kaldırıldı

Her biri ilgili TR-* assert'inde FAIL verdi (TR-GOC-1/2/3/4/5, TR-AYAR-N5, TR-ANAH-2). Betik: `~/tmp/ovsync-tren-db/mut.sh`.

## Etki (yeni imza/davranış ile çağıranlar)
- D8 mevcut fonksiyon gövdesini ya da imzasını değiştirmiyor; geri alma provası bunu dolaylı olarak da gösteriyor (seri öncesiyle fark 0). Kullandığı fonksiyonlar `gorev_ertele`, `protokol_ayar_guncelle`, `_ovsync_tren_ayar`, `_ovsync_tren_gunu_ic`, `_ovsync_kural_tarihi` ve `_ovsync_asama`; hepsi değişmeden çağrılıyor. Seri bütün koşumu 539 PASS ve önceki görevlerin testleri dahil. MEASURED
- JS'de yeni RPC'lerin çağıranı henüz yok; UB3 bağlayacak. `protokol_ayar_guncelle`'nin tek JS çağıranı `js/forms.js:protokolAyarKaydet@3748` (atlas). Ayarlar ekranı yalnız `index.html`'deki data-ayar anahtarlarını yazıyor ve `ovsync_tren_*` aralarında yok (MEASURED grep). Bayrağın göçsüz açılmasına yol açan bir UI yolu yok.
- Cron: `ilk_tohumlama_zamanlayici` bayrak 1 iken çapa bozuksa OVSYNC_TREN_AYAR ile düşüyor, sessizce başarılı dönmüyor (TR-AYAR-CRON). Bayrak 0 iken aynı bozuk çapa cron'u düşürmüyor.

## Regresyon / seri / geri alma (ayrıntı d8-regresyon.md)
- pgk taban (D8a, serisiz, 4e46386) 482 / Bölüm 0 29 / Bölüm 1 31.
- Seri 001..008 + düzeltilmiş betik: **487 / 29 / 33**. Bölüm 1'deki +2, A5 dal (ii) için eklenen 2 S10 assert'i; 31 taban assert'inin hepsi PASS. Bölüm 7'deki +3, A6 için eklenen 3 "DROP edildi" assert'i. Diğer bölümler birebir. MEASURED
- `git diff 4e46386 -U0`: değişen `kb_ok` satırı 2, ikisi de A5 dal (ii) eki. Değişikliklerin hepsi A5–A7. MEASURED
- Geri alma provası (aynı transaction): `GERI_AL TAMAM`; public pg_proc (imza, md5, ACL kümesi, secdef, config) ve protokol_ayar seri öncesiyle fark 0. Ardından taban betik **482 / Bölüm 1 31**. MEASURED

## Varsayımlar (plan boşluğu)
- Varsayım 1: Göç kümesi = açık OVSYNC_BASLAT ve `hedef_tarih >= bugün_TR`. Spec "22 ileri tarihli" diyor. Gecikmiş görev listeye girmez; başlatılırken RL-11 yolu onu yeniden hedefler (TR-GOC-1 f).
- Varsayım 2: `ayar_guncelle(true, …)` her çağrıda `yeniden_hedefle(false)` koşar; ikinci çağrı idempotent ve satırlar AYNI çıkar (TR-GOC-3). Plan "açılış/çapa değişikliğinde" diyor; bu davranış onun üst kümesi ve yan etkisi yok.
- Varsayım 3: Kuru olmayan modda `p_capa` ayardaki çapadan farklıysa `OVSYNC_TREN_AYAR {sebep:'AYARDAN_FARKLI'}` döner. Parametre sessizce yok sayılmasın diye.
- Varsayım 4: Yazma dönüşündeki `yeni`, `gorev_ertele`'nin gerçekten yazdığı gün. Tohumlama penceresi 21:00'ten sonraki saati ertesi güne kaydırırsa bu fark görünür kalır. Prod'da açık 25 OVSYNC_BASLAT'ın hepsi 10:00'da, yani bugün etkisi yok (MEASURED, read_only).
- Varsayım 5: Üyelik D0'ı = hastalık dışı gün#1 `treatment_date` (R3: "ovsync_tren GnRH1 planlı günü"). Hastalık günlü vaka (`disease_id IS NOT NULL` gün) üyelik almaz.
- db-validate yalancı pozitifi: `IS DISTINCT FROM v_x` deseni betiğin FROM regex'ine takılıp INCONCLUSIVE veriyor. Bu desen `<>` ile değiştirildi (değişken önceden NULL değil diye denetleniyor). D2 notuna ek bir desen.

## Kırıntılar
(workspace fable-rol-ve-davranislar; 4 kırıntı)
- measurement: seri 539 PASS; pgk 487 (Bölüm 1 33 = 31 + 2); geri alma sonrası taban 482/31.
- measurement: geri-al provasında pg_proc ve protokol_ayar farkı 0.
- assumption: göç kümesi hedef ≥ bugün, AYARDAN_FARKLI, ayar_guncelle her açılışta yeniden hedefliyor.
- open_item: 21:00'ten sonraki hedef_saat yeniden hedeflemede ertesi güne kayıyor (ritim dışı). Prod'da bugün etkisi yok. UB/DC1 notu.

## Açık kalemler (DONE'a)
- geri-al.sql'deki `ALTER TABLE cases DROP COLUMN ovsync_tren` adımı sahip son onayı ister (P11). Prod ACL deseni 2026-11-09'da read_only ölçüldü. P2 yedeğinden sonra gövdelerin md5'i yeniden doğrulanmalı (dosyadaki DO bloğu bunu zaten yapıyor).
- UB3: ayar düğmesi `ovsync_tren_ayar_guncelle`'yi çağırmalı; genel `protokol_ayar_guncelle` göç yapmaz. P10: dönen `belirsiz_asama` listesi sahibe gitmeli.

## Run kanıtı
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-ANAH-2: R10 son tohumlama sırası
NOTICE:  PASS TR-ACL-5: D8 ACL
NOTICE:  OZET: 539 PASS
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-de268641.md
 İzole DB'ler drop edildi: egesut_val_974239_9f7b1f37 egesut_val_974239_e5477773
════════════════════════════════════════════════
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
Ek koşumlar (ham, d8-regresyon.md'de):
- pgk + seri: `( echo 'BEGIN;'; cat supabase/migrations/2026111010000{1,2,3,4,5,6,7,8}_*.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql … egesut_ovsync_kabul -X -v ON_ERROR_STOP=1` → rc 0, `NOTICE:  BOLUM 1-bayrak0: 33 PASS (kümülatif 62)` … `NOTICE:  OZET: 487 PASS`.
- Geri alma provası: `bash ~/tmp/ovsync-tren-db/prova_pgk.sh` (pre-snapshot → seri → geri-al.sql → karşılaştırma → 4e46386 pgk → ROLLBACK) → rc 0, `PROVA: … fark = 0, protokol_ayar fark = 0` / `NOTICE:  OZET: 482 PASS`.

## D8 tur 2
⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D8 tur 2 RL-18⟧
sonuc: TAMAM
commit: b69a195 (dal ovsync-tren, push yok; staged yalnız 008 + ovsync_tren_kabul.sql — `git diff --cached --stat` 2 dosya)
BOYUT: bütçe 200 · gerçek +9/−8 (008 artık 170 satır) · bütçe içinde

Gelen iş denetimi: 1 bulgu. Brief'teki TR-GOC-6 lafzı ("tren gününde bağımsız başlat → NULL kalır") R4 ile çelişiyor. TR-K8-3 ve 004:469'a göre tren gününde bağımsız başlatılan vaka zaten trende (etiket = bugün), yani o lafızla test fix'ten bağımsız olarak FAIL verirdi. Varsayım (assumption kırıntısı): testin amacı korunarak fixture değiştirildi. Vaka bugün≠tren günü bağımsız başlatılıyor (etiket NULL), sonra `ovsync_hayvan_ertele(h, 3)` (aşama 0 bağımsız, serbest kaydırma) ile gün#1 tren günü X'e taşınıyor. Fixture assert'i gün#1 = X, tren günü ve etiketin NULL olduğunu doğruluyor. Ardından `ayar_guncelle(true, X)` çağrılınca vaka NULL kalıyor.

### Yapılanlar (yalnız ## Devam 1–3)
1. RL-18 — 008: `IF p_aktif AND (v_aktif = 0 OR v_yeni_c <> v_eski_c)`. Açıkken aynı çapayla çağrılınca `yeniden_hedef` null dönüyor. TR-GOC-3 yeniden yazıldı. İdempotentlik artık doğrudan `yeniden_hedefle(false)` ×2 ile ölçülüyor. Testte ayrıca açıkken aynı çapada null dönüş ve çapa X→X+7 değişince göçün yine koştuğu dalı var. Yeni test TR-GOC-6 eklendi (yukarıdaki fixture).
2. 008:135 → `IF v_aktif IS NULL OR (p_aktif AND v_eski_c IS NULL)`. Çapa satırı NULL olabildiği için `IF v_yeni_c IS NOT NULL AND v_yeni_c <> v_eski_c` yerine `IF v_yeni_c <> v_eski_c` yazıldı; NULL karşılaştırması yazmayı atlıyor, davranış aynı. TR-AYAR-P1'e iki assert eklendi: "çapa satırı silinmiş + kapat → ok, aktif 0" ve dönüş `{ok, aktif:false, capa:null}`.
3. 008:131-134'teki dört SELECT tek sorguya indirildi (`max(..) FILTER`, `anahtar IN (..)`).

### Kanıt
- RED (fix öncesi, ON_ERROR_STOP=0 ile tüm FAIL'ler görülsün diye; MEASURED, `~/tmp/ovsync-tren-db/d8t2-red.log`):
  `FAIL TR-GOC-3: … yeniden_hedef:null (göç yok) gerçek {… "yeniden_hedef": {"ok": true, … "kuru": false …}}`
  `FAIL TR-GOC-6: … ovsync_tren NULL kalır gerçek {… "uyelik": [{"tren": "2026-11-12", "case_id": "dd4a9629-…"}] …} / 2026-11-12`. Bu çıktı review'daki ÖNEMLİ bulgunun gerçek olduğunu CONFIRMED etti: bağımsız vaka trene bağlandı.
  `FAIL TR-AYAR-P1: … çapa satırı silinmiş + kapat → ok, aktif 0 gerçek P0001|OVSYNC_TREN_AYAR:{… "sebep": "EKSIK", "anahtar": "ovsync_tren_capa"}`
- GREEN: 546 PASS. 539'dan +7 artış: TR-GOC-3 +2, TR-GOC-6 +3, TR-AYAR-P1 +2 (MEASURED).
- Mutant: `IF p_aktif AND v_aktif = 0` (çapa değişimi dalı silinmiş) → `FAIL TR-GOC-3: … açıkken çapa X→X+7 → göç koşar … gerçek {… "yeniden_hedef": null}` ile öldü (MEASURED).
- pgk seri: 487 PASS, Bölüm 1 33. Değişmedi, Bölüm 0 da 29 (MEASURED).
- Etki: değişiklik yalnız `ovsync_tren_ayar_guncelle` gövdesinde ve imza aynı. Açılış yolunu kullanan TR-GOC-2/4/5 (bayrak 0'dan açılış) PASS (INFERRED: çağıranlar etkilenmez; UI çağıranı henüz yok).

## Run kanıtı
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-ANAH-2: R10 son tohumlama sırası
NOTICE:  PASS TR-ACL-5: D8 ACL
NOTICE:  OZET: 546 PASS
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-e6b98dde.md
 İzole DB'ler drop edildi: egesut_val_1092937_8ef52b5a egesut_val_1092937_3a2d9259
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/2026111010000{1,2,3,4,5,6,7,8}_*.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1
```
rc: 0
```
NOTICE:  BOLUM 0: 29 PASS (kümülatif 29)
NOTICE:  BOLUM 1-bayrak0: 33 PASS (kümülatif 62)
NOTICE:  BOLUM S1: 19 PASS (kümülatif 487)
NOTICE:  OZET: 487 PASS
ROLLBACK
```

## Kırıntılar (tur 2)
- assumption: TR-GOC-6 fixture'ı R4 çelişkisi yüzünden bağımsız başlatma + hayvan_ertele(+3) üzerine kuruldu (yukarıda).
- measurement: 546 PASS / pgk 487·33 / mutant öldü.
- open_item: açıkken çapa değişiminde ve doğrudan `yeniden_hedefle(false)` çağrısında bağımsız (NULL) vakayı ayırt eden bir işaret yok. Bu R14/K8 kararı, root'ta (review (c)). TR-GOC-3'teki X→X+7 dalı göçü bilerek koşturuyor ama bağımsız vaka hakkında assert içermiyor.
