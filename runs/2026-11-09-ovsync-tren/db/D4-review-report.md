⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D4 T2 kapı review⟧
sonuc: TAMAM

```
VERDICT: KABUL
OKUDUM: kat1 0 (brief kat1.md taşımıyor; kapsam brief'teki diff komutu: 9aba75e..1adffe6 -- supabase/ runs/.../db/) · DONE 178 (D4-report.md tamamı) · lead review 0 (yok; D4-brief 48 + review-sablon 24 + D4-review-brief 36 okundu) · kat2 migration 20261110100004 :1-80,:380-441,:478-573 + ACL/D4 grep; ovsync_tren_kabul.sql :1405-1432,:1519-1546 + hunk başlıkları · araç 15
ÖLÇTÜM: kabul seri koşumu (BEGIN/ROLLBACK) → rc: 0, `NOTICE:  OZET: 220 PASS` (MEASURED) · db-validate --priors → rc: 0, `SONUÇ: PASS` (MEASURED) · `! grep CURRENT_DATE` → rc: 0, çıktı yok (MEASURED) · 3 gövde kanit/fn ↔ migration diff → yalnız D4 yorumlu satırlar (start +12/−3, tedavi +12/−0, _vaka_ac_tek +1/−1) (MEASURED) · rol sondası: anon→onizle `permission denied`, authenticated→_vaka_ac_tek `permission denied`, authenticated→onizle `{"ok": true, "aktif": false}`, authenticated→start tek-arg `GOREV_BULUNAMADI` (MEASURED) · pg_default_acl (objtype f) kabul DB'de 0 satır → anon mutantının sağ kalması env-mismatch (MEASURED)
İŞARETLİ:
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:432 — sağlamlık — KÜÇÜK — `CASE WHEN _ovsync_tren_aktif() AND _ovsync_tren_gunu_mu(v_bas)` bayrak 0'da ayarın okunmamasını AND kısa devresine bırakıyor; PG belgesi alt ifade sırasını garanti etmez (pratikte soldan sağa, TR-K8-REG bozuk çapayla PASS) — iç içe CASE ile garanti edilebilir.
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:534 — plan boşluğu — KÜÇÜK — tren_gunu = açık OVSYNC_BASLAT hedefi; hedef geçmişteyse ya da (bayrak açılmadan önce doğmuş görevde) ritim dışıysa önizleme tren olmayan/geçmiş bir günü "tren" diye döndürür (worker open_item'ı ile aynı; UB2/root kararı).
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:549-551 — yüzey (c) — KÜÇÜK — uye_sayisi sorulan hayvanı sayar, uye_kupeler dışlar; aynı kümeden iki farklı kuralla türeyen iki alan (hayvanın kendi görevi o trendeyse sayı = len+1) — UI tek kaynağa bağlanmalı (Varsayım 1, open_item).
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:566-573 — env-mismatch — KÜÇÜK — dört fonksiyonun hepsinde REVOKE satırı `FROM PUBLIC, anon` (_vaka_ac_tek'te + authenticated) metin olarak var (CONFIRMED); prod varsayılan ACL'i anon'a EXECUTE verdiği için apply sonrası has_function_privilege('anon', …) ölçümü açık kalem.
BLOKLAYAN: 0 · ERTELENEBİLİR: 4
NOKTA NOTU: kat1/lead review yok ve kat2 yalnız risk hunk'ları okundu; testlerin TR-K8-1/2/V3/V4/ONIZLE-1/EK-ONIZLE gövdeleri satır satır okunmadı, bu yüzden bu id'lerde vacuous-assert avı worker'ın 22/23 mutant ölçümüne dayanıyor (INFERRED).
```

## Şablon karşılığı (review-sablon.md)
VERDICT (şablon dili): PASS

Bulgular (şablon biçimi):
- [KÜÇÜK] supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:432 — bayrak 0'da ayar okunmaması AND değerlendirme sırasına dayanıyor — kanıt: satır metni; TR-K8-REG PASS (pratikte kısa devre) — dar fix: `CASE WHEN public._ovsync_tren_aktif() THEN CASE WHEN public._ovsync_tren_gunu_mu(v_bas) THEN v_bas END END`.
- [KÜÇÜK] …:534 — gecikmiş/ritim dışı görev hedefi tren_gunu olarak döner — kanıt: `v_tren := COALESCE(v_ghedef, …)` — dar fix: yok (plan lafzı); UB2/root kararı.
- [KÜÇÜK] …:549-551 — uye_sayisi/uye_kupeler dışlama kuralı farklı — kanıt: FILTER yalnız jsonb_agg'de, count(*) filtresiz — dar fix: UB2 `uye_kupeler.length` kullanır ya da count'a aynı FILTER (root kararı).
- [KÜÇÜK] …:566-573 — anon REVOKE kabul DB'de ölçülemiyor — kanıt: pg_default_acl objtype f = 0 satır; proacl'de anon yok — dar fix: DM1 apply sonrası `has_function_privilege('anon', …)` 4 imza için.

Odak maddeleri:
1. Gövde türetimi: kanit/fn (tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/kanit/fn) ↔ migration diff'inde yalnız "D4" yorumlu satırlar farklı (CONFIRMED). Worker'ın +26/−5'i başlık imza satırı dahil sayıyla uyumlu.
2. md5: :23-25 değerleri govde-taban.md :19/:26/:27 prod sütunuyla birebir, imzalar doğru (CONFIRMED).
3. ACL: start/tedavi/onizle REVOKE PUBLIC, anon + GRANT authenticated (start/onizle + service_role); _vaka_ac_tek REVOKE PUBLIC, anon, authenticated + GRANT service_role (CONFIRMED). _vaka_ac_tek çağıranları create_case, start, vaka_toplu_ac hepsi prosecdef=t; js/'de _vaka_ac_tek çağrısı yok (MEASURED) → authenticated kapatma güvenli.
4. Bayrak 0: v_bagimsiz bayrağa bağlı (:87), kapı (:92) ve v_s (:181) bayrak 0'da eskiyle aynı; tedavi etiketi IS DISTINCT FROM ile UPDATE üretmez; TR-K8-REG PASS (MEASURED).
5. TR tarih: CURRENT_DATE yok (MEASURED); TR-TZ-2 fixture'ı her saatte CURRENT_DATE ≠ TR bugünü kuruyor (h<14 → Etc/GMT+12, aksi → Kiritimati; iki aralık 24 saati örter) ve kendini assert ediyor — vacuous değil (CONFIRMED).
6. Testler: 11 TR-* + TR-EK-ONIZLE PASS satırları seri koşumda; her bölüm SAVEPOINT/ROLLBACK TO içinde (set_config is_local savepoint geri alımıyla döner). Cron tek-arg: ilk_tohumlama_zamanlayici gövdesinde `start_first_service_protocol(r.id)` var (MEASURED) ve TR-K8-3'te koşuyor.
7. Kapsam: diff yalnız 2 dosya (migration +573, kabul +355) = brief yazılabilir listesi (MEASURED). ovsync_pg_kabul.sql:1506 eski imza D8 kapsamı, bulgu sayılmadı.

OZET sinyal=3 eklenen=573 butce=450
KALİTE: tekrar :36~:288 → gerekli — iki CREATE FUNCTION başlığı (RETURNS/LANGUAGE/SECDEF/search_path) PG idiomu, soyutlanamaz.
KALİTE: tekrar :350~:397 → gerekli — tedavi_sablon_uygula gövdesinin prod kopyası (md5 korumalı), D4 dokunmuyor.
KALİTE: olcum-yok: 1 dosya — dil-desteksiz
KALİTE: boyut 573 > 450 → gerekli — 439 satır zorunlu tam gövde kopyası; D4'ün kendi eklemesi (onizle ~60 + ACL/md5/başlık) ölçülü.

## Run kanıtı
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
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-ea0ab099.md
 İzole DB'ler drop edildi: egesut_val_2663749_1739daf4 egesut_val_2663749_16df6716
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) `~/tools-bank/scripts/ss-kalite-sinyal --repo ~/.herdr/worktrees/egesut-erp1/ovsync-tren --base 9aba75e --head 1adffe6 --butce 450`
rc: 0
```
SINYAL tekrar supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:36 ~ supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:288 pencere=6
SINYAL tekrar supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:350 ~ supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:397 pencere=6
SINYAL olcum-yok supabase/migrations/20261110100004_ovsync_tren_baslatma.sql dil-desteksiz
OZET sinyal=3 eklenen=573 butce=450
```
5) Rol/ACL sondası (BEGIN; 4 migration; sonda; ROLLBACK — kabul DB'ye kalıcı yazma yok):
```
acl|_vaka_ac_tek(text,uuid,text,date)|{lsp_user=X/lsp_user,service_role=X/lsp_user}
acl|start_first_service_protocol(uuid,boolean,boolean)|{lsp_user=X/lsp_user,authenticated=X/lsp_user,service_role=X/lsp_user}
acl|ovsync_tren_onizle(text)|{lsp_user=X/lsp_user,authenticated=X/lsp_user,service_role=X/lsp_user}
cron-call|t
ERROR:  permission denied for function ovsync_tren_onizle        (anon)
ERROR:  permission denied for function _vaka_ac_tek              (authenticated)
{"ok": true, "aktif": false}                                    (authenticated onizle)
ERROR:  GOREV_BULUNAMADI:{"gorev_id": "00000000-0000-0000-0000-000000000000"}   (authenticated start tek-arg)
```

## Kırıntılar
- measurement: D4 kapı yeniden ölçüm — OZET 220 PASS, db-validate PASS (ea0ab099), CURRENT_DATE grep boş, gövde diff yalnız D4 satırları, pg_default_acl(f)=0.
- decision: KALİTE: D4 KABUL; sinyal 3 (2 tekrar gerekli, 1 olcum-yok dil-desteksiz); boyut aşımı gövde kopyasından, gerekli.
- open_item (DM1/prod): 4 imza için apply sonrası has_function_privilege('anon', …) = false ölçümü (kabul DB'de default ACL yok).
- open_item (UB2/root): tren_gunu gecikmiş/ritim dışı görev hedefi; uye_sayisi vs uye_kupeler dışlama farkı.
- not: brief kat1.md taşımıyordu; repo taraması yapılmadı, kapsam brief'in diff komutuyla sınırlandı.
