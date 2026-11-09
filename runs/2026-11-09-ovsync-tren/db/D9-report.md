⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D9: bağımsız vaka işareti cases.ovsync_bagimsiz, bağımsız vaka hiçbir yoldan trene bağlanmaz⟧
sonuc: TAMAM
commit: 7ff1e7b `ovsync-tren L-DB D9: bagimsiz vaka isareti (cases.ovsync_bagimsiz)` (6 dosya, dosya dosya `git add`, push yok). Bu report commit'e girmedi; D8'deki gibi lead "kulvar kayıtları" commit'ine bırakıldı.
BOYUT: bütçe 40 · gerçek 11 · bütçe içinde (migration diff'i +16/−5; yorumsuz eklenen üretim SQL satırı 11. Test, geri-al ve md sayılmadı.)

Gelen iş denetimi: bulgu yok. Brief ile kod uyumlu. Seri, `tedavi_sablon_uygula` dışında `ovsync_tren`i NULL'dan dolu değere yazan tek bir yer daha içeriyor (008 R14). Başlatma yollarının hepsi (a, c) tek noktadan, yani 004'teki `tedavi_sablon_uygula` üzerinden geçiyor (CONFIRMED, aşağıdaki tablo).

## Yapılanlar
1. **RD9-1 DDL** (`20261110100002_ovsync_tren_cekirdek.sql:32-35`): `ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS ovsync_bagimsiz boolean NOT NULL DEFAULT false;` ve COMMENT. Kolon `ovsync_tren` DDL'inin hemen altında. Yeni migration açılmadı, md5 korumalarına dokunulmadı.
2. **RD9-3a** (`20261110100004_ovsync_tren_baslatma.sql:470-476`, `tedavi_sablon_uygula`): tek UPDATE şunları yapıyor:
   - `ovsync_bagimsiz = ovsync_bagimsiz OR (v_tren IS NULL AND _ovsync_tren_aktif())`
   - `ovsync_tren = CASE WHEN ovsync_bagimsiz THEN NULL ELSE v_tren END`

   Satır yalnız `(ovsync_tren, ovsync_bagimsiz)` çifti değişiyorsa yazılıyor, yani bayrak 0'da önceki gibi ek UPDATE oluşmuyor. Davranış:
   - Bayrak açıkken tren günü olmayan D0 → `true`.
   - R4'e göre tren günü D0 → etiket = D0, `false`.
   - `true` olan değer `false`'a dönmüyor ve işaretli vaka etiket almıyor.
   - Bayrak 0'da işaret değişmiyor.
3. **RD9-3b** (`20261110100005_ovsync_tren_kilit.sql:711-712`, `ovsync_hastalik_gunu_ekle`): `SET ovsync_tren = NULL, ovsync_bagimsiz = true WHERE … AND ovsync_tren IS NOT NULL`, yani brief'in istediği gibi aynı UPDATE. `tren_ayrildi` için FOUND semantiği aynı kaldı (TR-K9-1 PASS).
4. **RD9-4** (`20261110100008_ovsync_tren_ayar_goc.sql:75` seçim, `:99` UPDATE): ikisine de `AND NOT c.ovsync_bagimsiz` eklendi. Bağımsız vaka artık `uyelik` listesinde de görünmüyor.
5. **RD9-4, 007 okundu, DOKUNULMADI:**
   - 007:115 `bagimsizlar` bloğu ve 007:234-239 `dokunulmaz` sayımı yalnız listeleme/sayım yapıyor, üyelik yazmıyor.
   - UI sözleşmesi "NULL etiket = bagimsizlar" olduğu gibi kaldı. Eski (NULL, false) vaka da bu listede görünmeye devam ediyor; bu mevcut davranış.
6. **RD9-6:** RPC imzası ve dönüş alanı değişmedi, yeni RPC yok (CONFIRMED: diff yalnız UPDATE/WHERE satırlarında).
7. `geri-al.sql`:
   - `ALTER TABLE public.cases DROP COLUMN IF EXISTS ovsync_bagimsiz;` eklendi.
   - Adım (7)'deki kolon assert'i `column_name IN ('ovsync_tren','ovsync_bagimsiz')` oldu.
   - Başlık ve NOTICE metni güncellendi.

## `ovsync_tren` yazan noktalar (seri, CONFIRMED grep `ovsync_tren(?![_a-z])`, yorum dışı)
| Dosya:satır | Yazma | İşaretin ele alınışı |
|---|---|---|
| 004:473-476 `tedavi_sablon_uygula` | etiket = D0 ya da NULL | (a) Bayrak açık + NULL → `true`. İşaretli vaka etiket almıyor. `start_first_service_protocol` (004:244) ve `ovsync_bastan_baslat` (006:447 → start) bu yoldan geçiyor; (c) için ek iş gerekmedi. |
| 005:396-397 `vaka_kalan_gunleri_kaydir` | `+= p_gun` (yalnız dolu) | Dokunulmadı. NULL'a değer yazmıyor; tek hayvan ertelemesi işarete dokunmuyor (RD9-3). |
| 005:712 `ovsync_hastalik_gunu_ekle` | NULL | (b) Aynı UPDATE'te `ovsync_bagimsiz = true`. |
| 008:98-99 `ovsync_tren_yeniden_hedefle` | NULL → D0 (R14) | RD9-4: `AND NOT c.ovsync_bagimsiz` (seçim 008:75 + UPDATE). |
| 002:29 DDL / 004:255, 004:584, 006:280-326, 007:33-239 | yalnız okuma | Değişmedi. |

`_vaka_ac_tek`'in cases INSERT'i işareti yazmıyor; DEFAULT false, işareti hemen ardından `tedavi_sablon_uygula` koyuyor (INFERRED: TR-BAG-1/6 bunu ölçüyor).

## Testler (supabase/tests/ovsync_tren_kabul.sql, yeni "BÖLÜM D9", mevcut testler değişmedi)
Yardımcı `pg_temp.kb_bag(case) → (tren, bag)`. Kolon `to_jsonb(c)` üzerinden okunuyor; böylece kolon yokken RED, şema hatası yerine `kb_ok` FAIL olarak görünüyor.

id → sonuç (MEASURED, `~/tmp/ovsync-tren-db/d9-green.log`):
- TR-BAG-1 → PASS (1 kb_ok): bağımsız başlatma, bugün ≠ tren → NULL + true
- TR-BAG-2 → PASS (2): `ayar_guncelle(true, bugün+7)` (çapa değişti, D0 yeni ritimde) → NULL + true; doğrudan `yeniden_hedefle(false)` → NULL + true, `uyelik` dışı
- TR-BAG-3 → PASS (3): K9 → `tren_ayrildi`, NULL + true; çapa değişimi sonrasında da NULL + true
- TR-BAG-4 → PASS (2): bayrak 0'da açılmış eski vaka (false) → açılışta trene bağlanıyor, işaret false (regresyon)
- TR-BAG-5 → PASS (1): bugün tren + `p_bagimsiz=>true` → trende, false (R4)
- TR-BAG-6 → PASS (2): V3 tren dışı D0 → NULL + true; tren D0 → etiket, false
- TR-GOC-6 → PASS (değişmedi)

Toplam 546 → 557 PASS (+11 kb_ok).

### RED (fix öncesi, ON_ERROR_STOP=0, MEASURED)
Kolonsuz (`~/tmp/ovsync-tren-db/d9-red.log`): TR-BAG-1..6 FAIL, OZET 546. Yalnız DDL eklendikten sonraki davranış RED'i (`~/tmp/ovsync-tren-db/d9-red2.log`):
```
ERROR:  FAIL TR-BAG-1: beklenen bağımsız başlatma: ovsync_tren NULL, ovsync_bagimsiz true gerçek  f {"ok": true, "case_id": "cfa44dcc-…", "baslangic": "2026-11-09", …, "ovsync_tren": null, …}
ERROR:  FAIL TR-BAG-2: beklenen çapa değişimi (D0 yeni ritimde): göç koştu, ovsync_tren NULL, işaret true gerçek 2026-11-09 f {"ok": true, "capa": "2026-11-16", "aktif": true, "yeniden_hedef": {"ok": true, "capa": "2026-11-16", "kuru": false, "uyelik": [{"tren": "2026-11-09", "case_id": "9c8796a2-…", "h…
ERROR:  FAIL TR-BAG-3: beklenen hastalık günü: tren_ayrildi, ovsync_tren NULL, işaret true gerçek  f {"ok": true, …, "tren_ayrildi": true}
NOTICE:  PASS TR-BAG-4: eski vaka açılışta bağlanır
NOTICE:  PASS TR-BAG-5: tren günü bağımsız trene biner
ERROR:  FAIL TR-BAG-6: beklenen V3 tren dışı D0: NULL + true gerçek  f
NOTICE:  OZET: 550 PASS
```
TR-BAG-2 RED'i L-DB-DONE açık kalem 2'yi doğruluyor (CONFIRMED): bağımsız vaka çapa değişince trene bağlandı (`uyelik` tren 2026-11-09).

### Mutantlar (MEASURED, `~/tmp/ovsync-tren-db/d9mut/`)
- 008'in iki `NOT c.ovsync_bagimsiz` filtresi kaldırılınca → `FAIL TR-BAG-2: … gerçek 2026-11-09 t …` (işaretli vaka etiket aldı; mutant öldü).
- 004'te işaret yazımı kaldırılınca → `FAIL TR-BAG-1` (öldü).
- geri-al'dan `DROP COLUMN ovsync_bagimsiz` kaldırılınca → `ERROR: GERI_AL_KOLON_KALDI` (assert çalışıyor).

## Run sonuçları
- Seri kabul: rc 0, `NOTICE:  OZET: 557 PASS` (n = 557 > 546)
- pgk seri: rc 0, `KABUL TAMAM: tüm testler PASS`. Bölüm sayıları 0: 29, **1-bayrak0: 33**, 2: 65, 3: 47, 4: 11, 5: 28, 6: 59, 7: 161, 8: 8, 9: 26, S1: 19 → kümülatif **487** (değişmedi).
- db-validate (`--priors`, kendinden önceki seri): 002 PASS (rc 0, `db-validation-ae0191c9.md`), 004 PASS (rc 0, `-29c0f3ee`), 005 PASS (rc 0, `-516f75b2`), 008 PASS (rc 0, `-8889c9fd`). Raporlar `~/egesut-erp1/reports/` altında.
- `grep -n CURRENT_DATE supabase/migrations/2026111010000*.sql`: boş, rc 0 (`!` ile).
- Geri alma provası `bash ~/tmp/ovsync-tren-db/prova_d9.sh` (D8 prova_pgk.sh kopyası, kolon sayımı iki kolonu da listeliyor): rc 0.
  ```
  NOTICE:  SERI UYGULANDI: yeni fn 27, kolon ovsync_bagimsiz,ovsync_tren
  NOTICE:  GERI_AL TAMAM: 16 gövde D0 md5, 24 yeni fonksiyon + 3 yeni imza yok, cases.ovsync_tren + ovsync_bagimsiz yok, 5 ayar yok
  NOTICE:  PROVA: public pg_proc (imza, md5, acl, secdef, config) seri öncesiyle fark = 0, protokol_ayar fark = 0
  NOTICE:  OZET: 482 PASS
  ```

## Run kanıtı
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-BAG-5: tren günü bağımsız trene biner
NOTICE:  PASS TR-BAG-6: V3 yolu işaret
NOTICE:  OZET: 557 PASS
```

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  KABUL TAMAM: tüm testler PASS
DO
ROLLBACK
```

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
```
rc: 0
```

════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-8889c9fd.md
 İzole DB'ler drop edildi: egesut_val_1218067_16346096 egesut_val_1218067_9525802a
════════════════════════════════════════════════
```

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## Kırıntılar
- assumption (ss-crumbs, workspace fable-rol-ve-davranislar): K9 işareti brief'in lafzına uyularak aynı UPDATE'e konuldu (`WHERE ovsync_tren IS NOT NULL`). Bayrak açıkken eski (NULL, false) bir vakaya hastalık günü girilirse işaret false kalıyor. Bu kabul edilebilir: R14 hastalık günlü vakayı zaten dışlıyor (008:76) ve `tren_ayrildi` semantiği korunuyor. Kanıt: TR-K9-1 PASS.
- Varsayım: 004'te işaretli vakaya ikinci bir OVSYNC şablonu uygulanırsa etiket yazılmıyor (`CASE WHEN ovsync_bagimsiz THEN NULL`). Gerekçe: RD9-3 "true geri dönmez" + değişmez (NULL ⇔ true).
- measurement: 557 PASS; pgk 487 / Bölüm 1 33; db-validate ×4 PASS; prova fark 0; 3 mutant öldü.
- open_item: işaretli vakaya ikinci şablon uygulaması dalı (004:473-476) testle ölçülmedi, INFERRED. Kapanış koşulu: T2 review kabul eder ya da test eklenir.
- Not: kolon `NOT NULL DEFAULT false` olduğu için PG11+ `ADD COLUMN` tabloyu yeniden yazmıyor (INFERRED, PG davranışı; prod sürümü bu görevde ölçülmedi).
- `gitnexus analyze` koşulmadı (ortak.md: L-DB yalnız SQL yazıyor, kulvar sonunda lead koşar).
