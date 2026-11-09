⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D4: başlatma yolları (p_bagimsiz, tren üyeliği, TR vaka günü) + K8 önizleme RPC'si + kabul bölümü⟧
sonuc: TAMAM

## Gelen iş denetimi
- Bulgu 1 (MEASURED): planın ~450 satırlık bütçesi tam gövde kopyalarını sayıyor ama yeni RPC ve md5/ACL bloğu eklenince 573 satıra çıkıyor (bkz. BOYUT). Kapsam değişmedi.
- Bulgu 2 (MEASURED): kabul DB oturumunun saat dilimi `Europe/Istanbul`. Bu yüzden düz bir TR-TZ-2 testi `CURRENT_DATE` mutantını yakalayamaz. Test, senaryo içinde oturum saat dilimini TR'den farklı bir güne düşecek biçimde ayarlıyor (aşağıda).
- Bulgu 3 (MEASURED): kabul DB'si yeni fonksiyonlarda anon'a varsayılan EXECUTE vermiyor; prod veriyor. Bu yüzden `ovsync_tren_onizle` anon REVOKE'u bu ortamda ölçülemiyor (mutant sağ, aşağıda).
- Bunların dışında bulgu yok. Okuduklarım:
  - PLAN.md: Global Constraints, R1–R20, N1, D0–D4, Kapı tur 2.
  - ortak.md, progress.md (RL-1..RL-10, SORU-1..3).
  - D3-report, D3-review, govde-taban.md, UA1-report sapma 1, mockup 01a.
  - domain-rules §18.4/§18.5/§18.19.
- Çelişki yok. build.sh koşulmadı (RL-9).

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql` (yeni, 573 satır)
  - md5 koruması: 3 fonksiyon, D0 prod değerleri. Fark olursa `START_FIRST_SERVICE_PROTOCOL_GOVDE_FARKLI`, `TEDAVI_SABLON_UYGULA_GOVDE_FARKLI` ya da `VAKA_AC_TEK_GOVDE_FARKLI` atılır.
  - `DROP FUNCTION public.start_first_service_protocol(uuid, boolean)` ve ardından `CREATE FUNCTION …(p_gorev_id uuid, p_takip_onay boolean DEFAULT false, p_bagimsiz boolean DEFAULT false) RETURNS jsonb`:
    - `v_bagimsiz := COALESCE(p_bagimsiz,false) AND _ovsync_tren_aktif()`.
    - Bağımsızsa `OVSYNC_ERKEN` kapısı atlanır ve `v_s := bugün_TR`.
    - Diğer her durumda gövde eskisiyle aynı.
    - Dönüşe `ovsync_tren` eklendi (vakadan okunur; bayrak 0'da null).
  - `tedavi_sablon_uygula` (imza aynı): şablonun ailesi OVSYNC ise son UPDATE'ten sonra şu yapılır:
    - `v_bas := COALESCE(p_baslangic_tarihi, v_case.start_date)`
    - `v_tren := CASE WHEN _ovsync_tren_aktif() AND _ovsync_tren_gunu_mu(v_bas) THEN v_bas END`
    - `UPDATE cases SET ovsync_tren = v_tren WHERE id = p_case_id AND ovsync_tren IS DISTINCT FROM (v_tren)`
  - `_vaka_ac_tek`: `COALESCE(p_tarih, CURRENT_DATE)` yerine `COALESCE(p_tarih, (now() AT TIME ZONE 'Europe/Istanbul')::date)`.
  - Yeni `ovsync_tren_onizle(p_hayvan_id text DEFAULT NULL) RETURNS jsonb STABLE SECURITY DEFINER`:
    - Kapalıyken `{ok:true, aktif:false}` döner.
    - Açıkken `{ok, aktif:true, bugun, tren_gunu, tren_bugun_mu, uye_sayisi, gorev:{id,hedef_tarih}|null, kupe_no, kural_tarihi, uye_kupeler}` döner.
    - `tren_gunu` = hayvanın açık `OVSYNC_BASLAT` hedefi; yoksa `_ovsync_tren_gunu_ic(bugun, capa, 0, bugun)`.
    - Ayar bozuksa `OVSYNC_TREN_AYAR` atılır.
  - ACL:
    - start: REVOKE PUBLIC/anon, GRANT authenticated + service_role.
    - tedavi_sablon_uygula: REVOKE PUBLIC/anon, GRANT authenticated.
    - `_vaka_ac_tek`: REVOKE PUBLIC/anon/authenticated, GRANT service_role.
    - onizle: REVOKE PUBLIC/anon, GRANT authenticated + service_role.
  - LATERAL ve `unnest … k(alias)` kullanılmadı. İlk db-validate koşumu INCONCLUSIVE verdi, sebebi şu desen: `IS DISTINCT FROM <değişken>` statik denetimde `FROM <tablo>` sanılıyor. `(v_tren)` parantezi ve `p_hayvan_id IS NULL OR k.hayvan_id <> p_hayvan_id` ile giderildi; ikinci koşum PASS.
  - Gövde kopyası `~/tmp/ovsync-tren-db/d4gen/gen.py` ile üretildi. Betik kopyadan önce her kanit gövdesinin md5'ini D0 değeriyle doğruluyor.
  - Kanit ile migration arasındaki fark **+26 / −5** satır, hepsi "D4" yorumlu (CONFIRMED, `~/tmp/ovsync-tren-db/d4gen/govde-diff.txt`):
    - start +13/−4
    - tedavi +12/−0
    - `_vaka_ac_tek` +1/−1
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql` (+355)
  - D4 yardımcıları ilk savepoint'ten önce: `kb_ob_gorev(hayvan, hedef)` ve `kb_vaka_d0(case)` (ovsync_tren, start_date, gün#1).
  - Yeni "BÖLÜM D4". Önceki bölümler değişmedi.

## Test id → PASS (MEASURED, `~/tmp/ovsync-tren-db/d4-yesil.txt`)
OZET **220 PASS** (önceki 176 + D4'ün 44'ü). Her id en az bir `kb_ok` ile koşuyor.
| id | kapsam | sonuç |
|---|---|---|
| TR-K8-1 | tren açık, hedef b+3 → `OVSYNC_ERKEN`; vaka açılmadı, görev açık | PASS |
| TR-K8-2 | aynı görev `p_bagimsiz` → baslangic/start_date/gün#1 = b, ovsync_tren NULL, dönüş alanı null; pencere içi (b+1) görev de bugüne çekilir | PASS |
| TR-K8-3 | çapa b, hedef b → ovsync_tren b (dönüş + vaka); bağımsız + tren=bugün → yine trende (R4); **cron `ilk_tohumlama_zamanlayici()` tek-arg çağrısı başlatır**, ovsync_tren b, hatalar boş | PASS |
| TR-K8-REG | bayrak 0 + bozuk çapa: `p_bagimsiz` → `OVSYNC_ERKEN`; pencere içi görev D0 = hedef b+1, ovsync_tren NULL; OVSYNC şablonu ayar okumadan uygulanır, NULL; pg bayrağı 0 → `OZELLIK_KAPALI` | PASS |
| TR-K8-V3 | şablon b+2 / b+9 → gün#1 = ovsync_tren; b+3 (tren değil) → NULL; `p_baslangic` NULL → start_date (tren) etiketlenir; Ovsync dışı şablon (Enterit) → NULL | PASS |
| TR-K8-V4 | `vaka_toplu_ac(p_tarih => b+4)` 2 hayvan → ikisi de ovsync_tren = start_date = b+4; b+5 → NULL | PASS |
| TR-K8-KISIR | kısır: `tedavi_sablon_uygula` (OVSYNC) → `KISIR_HAYVAN_OVSYNC_YASAK`, gün/etiket yok; `vaka_toplu_ac` basari 0; start bağımsız → `atlandi KISIR` | PASS |
| TR-TZ-2 | oturum saat dilimi CURRENT_DATE ≠ TR bugünü olacak biçimde kurulur (fixture assert'i) → `_vaka_ac_tek(..NULL)` ve `create_case` start_date = `kb_bugun()`; `p_tarih` dolu → o gün | PASS |
| TR-ONIZLE-1 | boş tren b+2, 0 üye; X (kendi görevi b+2): tren = görev hedefi, `gorev{id,hedef}`, uye_sayisi 4 (2 vaka + 2 görev; kapalı vaka/iptal görev/sonraki tren sayılmaz); Y görevsiz: ritimde ve ≥ bugün; Z (görevi b+9): 3 üye; çapa b → `tren_bugun_mu`; bozuk çapa → `OVSYNC_TREN_AYAR` | PASS |
| TR-EK-ONIZLE | X: `kupe_no` = X küpesi, `kural_tarihi` b+4, `uye_kupeler` = `["36","169","5708"]` (sayısal görünümlü sıra, X hariç); Y: kural_tarihi = `_ovsync_kural_tarihi`, 4 küpe; hayvansız çağrıda kupe_no/kural_tarihi null, `[]` | PASS |
| TR-ONIZLE-2 | kapalı (bozuk çapa) → tam `{"ok":true,"aktif":false}`; pg bayrağı 0 + tren 1 → aynı | PASS |
| TR-ACL-2 | onizle, start (yeni imza), tedavi: anon kapalı, authenticated + service_role açık; `_vaka_ac_tek` anon/authenticated kapalı, service_role açık; eski start imzası yok, overload yok; onizle STABLE SECDEF | PASS |

## Mutant denetimi (MEASURED: `~/tmp/ovsync-tren-db/d4-mutant.txt`, betik `~/tmp/ovsync-tren-db/d4gen/mutant.py`)
**22/23 öldü.** Kapsadığı yerler:
- start: kapı, başlangıç, bayrak bağı, dönüş alanı
- tedavi: aile, tren günü, `p_baslangic`/start_date
- `_vaka_ac_tek`: `CURRENT_DATE`
- onizle: kendini dışlama, sıra, kendi görevi, kapalı vaka, iptal görev, `tren_bugun_mu`, kural, küpe, ayar, kapalı alan sayısı, VOLATILE
- ACL: `_vaka_ac_tek` authenticated, start service_role
- md5 koruması

Sağ kalan mutant: "ACL onizle anon açık" (`REVOKE … FROM PUBLIC` yalnız).
- Sebep: kabul DB'si yeni fonksiyona anon için varsayılan EXECUTE vermiyor, prod veriyor. Bu ortamda eşdeğer mutant (env-mismatch, INFERRED).
- Migration satırı doğru: `FROM PUBLIC, anon` (CONFIRMED).
- Prod/demo apply sonrası `has_function_privilege('anon', …)` ölçülmeli (open_item).

## Etki (PLAN.md D4 "Etki"), MEASURED `~/tmp/ovsync-tren-db/d4-etki.txt`
Ölçüm D4 uygulandıktan sonra, BEGIN/ROLLBACK içinde yapıldı.
- **pg_proc çağıran taraması** (hepsi SECURITY DEFINER; her adda tek overload):
  - `ilk_tohumlama_zamanlayici` → `start_first_service_protocol(r.id)`: TR-K8-3'te çalışma anında koştu.
  - `create_case` → `_vaka_ac_tek(…, NULL)`: TR-TZ-2 ve TR-K8-V3'te koştu.
  - `vaka_toplu_ac` → `_vaka_ac_tek(…, p_tarih)` + `tedavi_sablon_uygula(p_case_id :=, p_sablon_id :=)`: TR-K8-V4 ve KISIR'da koştu.
  - `start_first_service_protocol` → `_vaka_ac_tek` + `tedavi_sablon_uygula`: TR-K8-*'da koştu.
  - `tedavi_sablon_bos_ata_uygula` → `tedavi_sablon_uygula(5 konumsal)`: imza değişmedi, çalışma anında koşulmadı (INFERRED).
- **JS çağrıları** (atlas `rpc`: start ← `ui.js:ovsyncBaslat@4324`/`takipRetry@4330`; tedavi ← `forms.js:submitCase@792`/`cagri@827,882`, `ui.js:caseSablonUygula@14122`; `_vaka_ac_tek` ← JS yok). Authenticated rolüyle sondalandı:
  - `{p_gorev_id}` ve `{p_gorev_id, p_takip_onay}` çözüldü (`GOREV_BULUNAMADI`).
  - tedavi 5 adlı argümanla çözüldü.
  - `ovsync_tren_onizle(p_hayvan_id => NULL)` çalıştı.
  - authenticated ile `_vaka_ac_tek` doğrudan çağrı → `42501` (bilinçli, Varsayım 3).
- **Regresyon `ovsync_pg_kabul.sql`** (MEASURED `~/tmp/ovsync-tren-db/d4-pgk.txt`):
  - D3 scratch kopyası (3 satır) D2–D4 seriyle koşunca ilk FAIL `ACL: public.start_first_service_protocol(uuid,boolean) var` (:1506 eski imza; planlı değişiklik).
  - Yalnız o imza `(uuid,boolean,boolean)` yapılınca **OZET 482 PASS**, `BOLUM 1-bayrak0: 31 PASS`. İkisi de D8a tabanına eşit.
  - Düzeltme D8'in işi (open_item); dosya bu görevin yazılabilir listesinde değil.

## Run kanıtı
Kırmızı (D4 migration yokken, test önce yazıldı; `~/tmp/ovsync-tren-db/d4-kirmizi.txt`). rc: 3:
```
NOTICE:  PASS TR-ACL-D3: yeni imza ACL
NOTICE:  PASS TR-K8-1: tren açık, pencere dışı görev OVSYNC_ERKEN
ERROR:  function public.start_first_service_protocol(uuid, p_bagimsiz => boolean) does not exist
```
(TR-K8-1 eski davranışı da sınadığı için D4'ten önce de PASS; ilk kırmızı TR-K8-2.)

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-ONIZLE-2: kapalı önizleme
NOTICE:  PASS TR-ACL-2: D4 ACL
NOTICE:  OZET: 220 PASS
```
(psql PIPESTATUS 0.)

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-ea0ab099.md
 İzole DB'ler drop edildi: egesut_val_2612884_4e275cf0 egesut_val_2612884_572c31fb
════════════════════════════════════════════════
```
(İlk koşum INCONCLUSIVE idi, rapor db-validation-f6bb7c89.md: `B.sema-uyum statik çözülemedi: p_hayvan_id v_tren`. Sebep `IS DISTINCT FROM <değişken>` deseni; giderildi, yukarıda.)

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## Kabul
- `OZET: 220 PASS`; listelenen 11 TR-* id'si ve sözleşme eki TR-EK-ONIZLE en az bir `kb_ok` ile PASS (tablo). MEASURED
- db-validate exit 0, PASS (RL-8 biçimi). MEASURED
- CURRENT_DATE grep'i boş (yorumlar dahil). MEASURED
- Etki listesindeki çağıranlar yeni imza ve davranışla kırılmıyor. MEASURED: 4 yol çalışma anında, JS imzaları sondalandı. 1 yol (`tedavi_sablon_bos_ata_uygula`) INFERRED.
- Cron tek-arg çağrısı test edildi (TR-K8-3). MEASURED
- Commit `1adffe6`: "ovsync-tren L-DB D4: başlatma yolları ve K8 sunucu tarafı (p_bagimsiz, tren üyeliği, TR vaka günü, ovsync_tren_onizle)".
  - `git add` dosya dosya yapıldı (migration, sonra test).
  - `git diff --cached --stat` = yalnız 2 dosya (928 ekleme).
  - Report commit'lenmedi (önceki görevlerle aynı). Push yok. MEASURED

BOYUT: bütçe 450 · gerçek 573 · gerekçe:
- 439 satır 3 prod gövdesinin zorunlu tam kopyası (242+143+54; CREATE [OR REPLACE] tam gövde ister).
- Yeni `ovsync_tren_onizle` ~70 satır; md5 koruması + başlık + ACL ~55 satır.
- D4'ün değişen gövde satırı +26 / −5.

## Varsayımlar
- Varsayım 1 (uye_kupeler ve uye_sayisi):
  - `uye_kupeler`, sorulan hayvanı (`p_hayvan_id`) dışlar. Gerekçe: root eki "o trene **zaten binmiş** hayvanlar" diyor; sahip onaylı mockup 1a'da da 212 listede yok ("Bu trende: 36 · 38 · 169 · 5708. 212 … onlarla birlikte başlar").
  - `uye_sayisi` plan lafzıyla aynı: hayvanın kendi görevi o gündeyse sayıya dahil. İki küme UNION ile birleşiyor, yani hayvan başına bir kez sayılıyor.
  - Sonuç: hayvanın kendi görevi o trendeyse `uye_sayisi = len(uye_kupeler) + 1`. Mockup "(4 hayvan)" diyor, sunucu 5 döner. UB2 isterse `uye_kupeler.length` gösterebilir (open_item).
- Varsayım 2 (sıra): "sıralı" için küpe uzunluğu + metin + hayvan_id sırası seçildi; sayısal küpeler mockup'taki gibi 36 · 169 · 5708 dizilir. Küpe NULL ise hayvan_id kullanılır.
- Varsayım 3 (ACL):
  - `_vaka_ac_tek` yeniden yaratılan bir iç yardımcı, Global Constraints gereği authenticated'a kapatıldı. Çağıranların hepsi SECDEF, JS çağırmıyor (atlas + grep). service_role korundu.
  - DROP + CREATE edilen start ve yeni onizle'ye `GRANT service_role` verildi. Gerekçe: canlı ACL ile eşlik (D3 Varsayım 4 emsali).
- Varsayım 4 (etiket UPDATE'i): değer değişmiyorsa `cases` güncellenmez (`IS DISTINCT FROM`). Böylece bayrak 0'da `trg_degisim_log` ek kayıt üretmez ve davranış birebir kalır.
- Varsayım 5 (dönüş alanı): start dönüşündeki `ovsync_tren` bayrak 0'da da var (null); yalnız ekleme.
- Varsayım 6 (kapalı önizleme): kapalıyken yalnız `{ok, aktif:false}` döner; sözleşme eki alanları yalnız açıkken var (JS kapalıda erken döner).
- Varsayım 7 (`gorev` seçimi): birden çok açık `OVSYNC_BASLAT` varsa `hedef_tarih DESC, created_at DESC` ile en yenisi alınır (D3 Varsayım 5 ile aynı).

## Kırıntılar
- measurement: OZET 220 PASS, db-validate PASS ea0ab099, mutant 22/23, ovsync_pg_kabul scratch 482/31 = taban, commit 1adffe6.
- assumption: uye_kupeler hayvanı dışlar / uye_sayisi lafız; küpe sırası; `_vaka_ac_tek` authenticated REVOKE; service_role GRANT; değişmeyen etikette UPDATE yok.
- open_item (D8): `ovsync_pg_kabul.sql:1506` ACL imza listesi `start_first_service_protocol(uuid,boolean)` → `(uuid,boolean,boolean)`. D3'ün 3 satırına eklenir; anlam değişikliği listesi root'a gider.
- open_item (UB2/root): açık `OVSYNC_BASLAT` hedefi geçmişteyse (gecikmiş görev) `tren_gunu` geçmiş bir tarih döner (plan lafzı "görev hedefi varsa o"). K8 modalı geçmiş tren gösterebilir; start yine bugün başlatır. UB2'de ele alınmalı ya da plan kararı gerekir.
- open_item (UB2): mockup "(N hayvan)" ile `uye_sayisi` farkı (Varsayım 1).
- open_item (DM1/prod): `ovsync_tren_onizle` anon EXECUTE false, apply sonrası `has_function_privilege` ile ölçülmeli (kabul DB'de ölçülemiyor).
- Not: gitnexus analyze koşulmadı (ortak.md: kulvar sonunda lead koşar). Geçici dosyalar `~/tmp/ovsync-tren-db/` altında (d4-*.txt, d4gen/).

## D4-EK (root ruling "D4 notları" + RL-11; lead resume 2026-11-09)
sonuc: TAMAM · commit `4dd94df` "ovsync-tren L-DB D4-EK: gecikmiş/ritim dışı görev → ilk tren (root ruling)" (2 dosya, dosya dosya stage, push yok)

### Gelen iş denetimi
Bulgu yok. D5'in (6eabd94) bu dosyadaki iç içe CASE değişikliği (:432, tedavi_sablon_uygula) üretecin içine taşındı ve korundu; gorev_ertele K10 kilidi D5'te, iç bayrakla aşılıyor (CONFIRMED: diff'te o satır değişmedi; "iç bayraksız" mutantı `OVSYNC_TREN_EKRANI` ile öldü).

### Yapılan (`20261110100004_ovsync_tren_baslatma.sql`, +49/−11; `ovsync_tren_kabul.sql` +155/−4)
- `start_first_service_protocol`:
  - `v_eski` = tren açık, `p_bagimsiz` false ve görev hedefi < bugün_TR ya da tren günü değil.
  - `v_eski` iken `OVSYNC_ERKEN` kapısı atlanır (RL-11: "OVSYNC_ERKEN değil").
  - Muafiyetlerden sonra, takip kapısından önce `v_ilk_tren := _ovsync_tren_gunu(bugün)` hesaplanır:
    - `> bugün` ise: önceki iç bayrak saklanır, `_ovsync_ic_ac()` çağrılır, sonra `gorev_ertele(p_gorev_id, v_ilk_tren)`, sonra iç bayrak geri yüklenir. Dönüş `{ok:true, basladi:false, gorev_id, yeniden_hedef, ovsync_tren:null}`. Vaka açılmaz, takip kapanmaz.
    - `= bugün` ise: `v_s := v_ilk_tren` ve başlatır.
  - Şablon uygulamasından hemen sonra: tren açık, bağımsız değil ve `ovsync_tren` NULL ise `OVSYNC_TREN_UYELIK_YOK:{gorev_id, case_id, d0}` RAISE edilir.
  - Bayrak 0'da hiçbir dal çalışmaz.
- `ovsync_tren_onizle`:
  - Görev hedefi < bugün ya da ritim dışıysa `tren_gunu = _ovsync_tren_gunu(bugün)` ve yeni alan `gorev_hedef_eski` true olur. Görev yoksa ya da normalse false.
  - `uye_sayisi` artık `uye_kupeler` ile aynı WHERE'dan geliyor (sorulan hayvan hariç, tek kaynak). D4 Varsayım 1 bununla kapandı.
- Test değişiklikleri:
  - TR-ONIZLE-1'de iki beklenen değer root ruling (2) gereği değişti: X `uye_sayisi` 4 → 3, Z 3 → 2. Yorum satırı "root ruling D4 notları (2)".
  - Yeni testler TR-D4EK-1/2/3/4. Yeniden hedefleme senaryoları `kb_ertele_kural()` çağırıyor.

### Test id → PASS (MEASURED `~/tmp/ovsync-tren-db/d4ek-yesil.txt`) — OZET **286 PASS** (D5 sonrası 265 + 21)
| id | kapsam | sonuç |
|---|---|---|
| TR-D4EK-1 | gecikmiş (b−2) görev: önizleme tren b+3, `gorev_hedef_eski` true; başlat → `{basladi:false, yeniden_hedef b+3, ovsync_tren null}`, görev açık hedef b+3, vaka yok, `GOREV_ERTELE` soyu b−2→b+3, iç bayrak geri yüklendi; sonra önizleme eski değil, tekrar başlat `OVSYNC_ERKEN`; **cron** gecikmiş görevi b+3'e yeniden hedefler (vaka/hata yok); ayrı fixture: bugün tren + gecikmiş görev → bugün başlar, ovsync_tren = start_date = gün#1 = bugün | PASS |
| TR-D4EK-2 | ritim dışı b+1 (pencere içi) ve b+12 (uzak; `OVSYNC_ERKEN` değil) → yeniden hedef b+3; tren günündeki gelecek görev (b+10) eski değil, `OVSYNC_ERKEN`; bugün tren + ritim dışı b+1 → bugün başlar; bayrak 0 gecikmiş görev eski yol (baslangic bugün, ovsync_tren NULL, `basladi` alanı yok) | PASS |
| TR-D4EK-3 | X, Y (görevsiz), Z: `uye_sayisi = jsonb_array_length(uye_kupeler)` | PASS |
| TR-D4EK-4 | ölçüldü (fixture): senaryo içinde `cases.ovsync_tren`'i silen geçici tetikleyici (savepoint ile düşer) → TREN yolu `OVSYNC_TREN_UYELIK_YOK`, payload `{gorev_id, case_id, d0 bugün}`, geri sarıldı (vaka yok, görev açık); aynı tetikleyiciyle bağımsız yol başarılı (NULL izinli). Normal akışta bu durum oluşmuyor: D0 her zaman tren günü (INFERRED, kod yolu). | PASS |
| TR-K8-*, TR-ONIZLE-*, D1–D5 tüm önceki | değişmeden PASS (TR-ONIZLE-1'de iki beklenen değer ruling gereği değişti) | PASS |

Kırmızı (MEASURED `~/tmp/ovsync-tren-db/d4ek-kirmizi.txt`): testler, EK öncesi 004 (D5 HEAD kopyası) ile koşuldu, rc 3: `ERROR:  FAIL TR-ONIZLE-1: beklenen X: … uye_sayisi 3 (2 vaka + 1 görev; X hariç), hedef eski değil gerçek {… "uye_sayisi": 4 …}`.

Mutant (MEASURED `~/tmp/ovsync-tren-db/d4ek-mutant.txt`, betik `~/tmp/ovsync-tren-db/d4gen/mutant-ek.py`): **15/15 öldü**. Kapsadığı yerler:
- `v_eski` hiç / ritim dışısız / bayrak 0'da da
- ERKEN kapısında `v_eski` yok sayılır
- yeniden hedef dalı yok
- iç bayraksız `gorev_ertele` / iç bayrak geri yüklenmez
- `v_s` eskiyi yok sayar
- UYELIK_YOK yok / bağımsızda da
- dönüşte `basladi` yok
- önizleme: eski hesabı yok / ritim dışısız / bayrak sabit / sayı kendini içerir

Not: D4'ün 23 mutantı EK sonrası yeniden koşulmadı. Kapsayan testler değişmeden PASS (INFERRED).

Regresyon `ovsync_pg_kabul.sql` (scratch imza düzeltmesiyle, 002..005): OZET 482 PASS, `BOLUM 1-bayrak0` 31 PASS. Taban eşit (MEASURED `~/tmp/ovsync-tren-db/d4ek-pgk.txt`).

### Run kanıtı (D4-EK)
1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-K9-N1: hastalık günlü hayvan trende değil
NOTICE:  PASS TR-ACL-D5: D5 ACL
NOTICE:  OZET: 286 PASS
```
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-548fa783.md
 İzole DB'ler drop edildi: egesut_val_3142035_e72174d4 egesut_val_3142035_99a2436e
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-d8b305f2.md
 İzole DB'ler drop edildi: egesut_val_3168210_e582c242 egesut_val_3168210_416bc5ac
```
4)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

BOYUT (D4-EK): bütçe 450 (D4 görevi, büyütülmedi) · gerçek migration 614 satır (D4 573 + EK net +38 ve başlık notu) · D4 gerekçesi aynen geçerli (439 satır prod gövde kopyası); EK'in kendi mantık farkı +49/−11.

### Varsayımlar (D4-EK)
- EK-1 (sıra): "eski" kararı, erken-çağrı kapısından önce kilitsiz `v_g`'den verilir. Yeniden hedefleme muafiyetlerden SONRA yapılır; böylece kısır/gebe/aktif senkronlu hayvanın gecikmiş görevi eskisi gibi `atlandi` olur, yeniden hedeflenmez. Takip kapısından ÖNCE yapılır; böylece başlamayan görevde `_takip_kapat` yazılmaz.
- EK-2 (iç bayrak): `_ovsync_ic_ac()` işlem sonuna kadar yerel kaldığı için önceki değer saklanıp geri yükleniyor. Gerekçe: cron döngüsünde ya da aynı işlemde sonraki K10 kontrolleri açık kalmasın (mutantla ölçüldü).
- EK-3 (`gorev_hedef_eski`): görev yoksa `false` döner (null değil).
- EK-4 (önizleme, görevsiz): tren hâlâ `_ovsync_tren_gunu_ic(bugün, capa, 0, bugün)` ile hesaplanıyor. `_ovsync_tren_gunu(bugün)` ile eşdeğer, çünkü `alt = GREATEST(bugün−öne_çekme, bugün) = bugün`.

### Kırıntılar (D4-EK)
- measurement: OZET 286 PASS; db-validate 004 PASS 548fa783, 005 PASS d8b305f2; mutant 15/15; pgk 482/31; commit 4dd94df.
- open_item (UB/cron raporu): `ilk_tohumlama_zamanlayici` yeniden hedeflenen görevi (`basladi:false`, `case_id` yok) `baslatilan` sayısına ve `baslatilanlar` listesine `case_id` null olarak yazıyor. Cron gövdesi D4 kapsamında değil; sayım kozmetik ama yanıltıcı. D8 ya da plan kararı gerekir. JS `ovsyncBaslat`, `r.basladi===false` dönüşünü UB2'de "görev <tarih> trenine taşındı" diye göstermeli.
- open_item (önceki): `ovsync_pg_kabul.sql:1506` imza düzeltmesi D8'de; anon EXECUTE DM1'de (root ruling (3)).

## D4-EK tur 2 (T2 DÜZELT, D5-review-report.md:22-34; RL-11 düzeltilmiş)
sonuc: TAMAM · commit `6a9e8db` "ovsync-tren L-DB D4-EK tur 2: K2 öne çekme sınırı (review)"
- (1) start + önizleme: `v_tren = _ovsync_tren_gunu_ic(GREATEST(_ovsync_kural_tarihi(h), eski_hedef), capa, one_cekme, bugün)`. Kural NULL ise GREATEST yalnız hedefi alır; ayar `_ovsync_tren_ayar()`'dan gelir. Başlatma yalnız v_tren = bugün iken olur; aksi hâlde yeniden hedeflenir. Gecikmiş görevlerde sonuç değişmedi (TR-D4EK-1 aynen PASS).
- (2) TR-D4EK-2 düzeltildi:
  - Kural = hedef = b+12 → tren b+10 (önizleme = başlat). Ek assert: `yeniden_hedef ≥ kural−2` ve b+3 değil.
  - Ek fixture: kural b+12, hedef b+5 → b+10.
- (3) `yeniden_hedef` = `gorev_ertele` dönüşündeki `hedef_tarih`. Assert: hedef_saat 22:00 fixture'ında `yeniden_hedef = gorev_log.hedef_tarih`.
- (4) `RAISE NOTICE 'PASS TR-D4EK-3: …'` eklendi. (5) TR-D4EK-1'e bayrak 0 cron assert'i eklendi: gecikmiş görev → vaka bugün, ovsync_tren NULL, GOREV_ERTELE kaydı yok.
- Kırmızı (MEASURED): yeni testler önceki 004 (4dd94df) ile koşuldu → `ERROR:  FAIL TR-D4EK-2: beklenen uzak ritim dışı (kural bugün+12) → … tren bugün+10`, rc 3.
- Mutant (MEASURED `~/tmp/ovsync-tren-db/d4ek2-mutant.txt`): 4/4 öldü (start R9 yok, start kural yok, önizleme R9 yok, yeniden_hedef ertele dönüşü değil).
- Not (open_item, INFERRED): hedef_saat > 21:00 olan görevde `gorev_ertele` yuvarlaması tarihi +1 kaydırır; görev tren günü dışına düşer. Dönüş bunu dürüstçe yansıtır. OVSYNC_BASLAT saatleri normalde 10:00.

### Run kanıtı (tur 2)
1) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3`
rc: 0
```
NOTICE:  PASS TR-K9-N1: hastalık günlü hayvan trende değil
NOTICE:  PASS TR-ACL-D5: D5 ACL
NOTICE:  OZET: 290 PASS
```
2) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql`
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-1b160e37.md
```
3) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql`
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-d8b305f2.md
```
4) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql`
rc: 0
```
(çıktı yok)
```
BOYUT (tur 2): migration 619 satır (+13/−8 bu tur); bütçe 450, gerekçe D4 ile aynı (prod gövde kopyası).
