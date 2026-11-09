⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D8 T2 review⟧
sonuc: TAMAM
job_id: j-20261109T115810Z-144ab1
VERDICT: FAIL
(DÜZELT: 1 ÖNEMLİ doğruluk bulgusu, aşağıda dar fix'i var. KRİTİK bulgu yok. Brief TEK TUR dediği için yeni review turu gerekmez; worker düzeltip Run kanıtıyla kapatır.)
OKUDUM: kat1 yok (brief nokta-review paketi değil, şablonlu T2) · D8-brief tam · D8-report 142/142 · review-sablon tam · PLAN.md "### D8" + R14 satırı · migration 008 169/169 · kat2: `git diff 4e46386..acd0f71 -- ovsync_pg_kabul.sql` (tam), `git diff -U0 aeb2a78..4e46386 -- ovsync_pg_kabul.sql` (yorum dışı +/- satırlar), ovsync_tren_kabul.sql D8 eklerinin kb_ok satırları, 002/004/006/007'de hedefli grep, prova_pgk.sh · araç 15
ÖLÇTÜM: seri 001..008 + ovsync_tren_kabul → rc 0, `OZET: 539 PASS` · seri + pgk → rc 0, `BOLUM 0: 29`, `BOLUM 1-bayrak0: 33`, `OZET: 487 PASS` · prova_pgk.sh (geri-al) → rc 0, `GERI_AL TAMAM: 16 gövde D0 md5, 24 yeni fonksiyon + 3 yeni imza yok, cases.ovsync_tren yok, 5 ayar yok`, `fark = 0, protokol_ayar fark = 0`, taban `BOLUM 1-bayrak0: 31`, `OZET: 482 PASS` · db-validate → rc 0 PASS · CURRENT_DATE grep → rc 0 (boş)

## Kapsam (1) D8: kontrol edilenler
- Regresyon (SORU-4): MEASURED. Kendi koşumumda sonuç 487 ve Bölüm 1'de 33 çıktı. 33 = taban 31 + A5 dal (ii) için eklenen 2 assert. Geri almadan sonra taban 482 / 31 birebir tuttu. DONE'daki sayılar ham çıktıyla aynı.
- Assert diff'i: CONFIRMED. `git diff 4e46386 acd0f71 -- ovsync_pg_kabul.sql` yalnız A5 (iki dal + RL-13 d2 hatırlatması), A6 (imza değişimleri + 3 "DROP edildi") ve A7'yi (R10 kaynak anahtarı) içeriyor. Her değişiklikte `-- root ruling 2026-11-09 SORU-4 Ax` yorumu var. A6'da ACL kontrol sayısı ve rolleri azalmamış.
- D8a (aeb2a78..4e46386): CONFIRMED. Değişen kb_ok beklentileri yalnız T31 (A1), R32-2 (A3) ve ACL imza listesi (A4); A2 bir fixture değişikliği. Diğer değişiklikler kurulum ve fixture'dan ibaret: kb_gk_eski, kb_rota_elle, kb_bolum işaretleri, `CURRENT_DATE` yerine `kb_bugun()-51` tarih kaydırmaları ve `ovsync_pg_kurallari_aktif=0` kurulumu. Başka hiçbir kb_ok beklentisi değişmemiş.
- R9 göçü: R9 formülü `_ovsync_tren_gunu_ic(GREATEST(kural, eski), capa, one, bugün)` olarak RL-11 düzeltmesiyle aynı (008:59). Yazma `gorev_ertele` üzerinden iç bayrakla yapılıyor, bayrak sonra eski değerine dönüyor (008:86-99). Kilit anahtarı `hashtext('ovsync_tren')` 006 ve 007 ile aynı (R14). TR saati kullanılıyor (008:26).
- R6-EK: `belirsiz_asama` ve `belirsiz_sayisi` kuru modda da dönüyor (008:79-83, 102-103). TR-GOC-5 assert'i fixture'ın `_ovsync_asama` değerini de doğruluyor.
- ACL: iki RPC'de de PUBLIC ve anon REVOKE, authenticated ve service_role GRANT (008:166-169). TR-ACL-5 anon'un çağıramadığını ölçüyor.
- Gövde ve md5: D8 mevcut hiçbir gövdeye dokunmuyor. Geri alma provasında pg_proc farkı 0 çıktı (MEASURED).

## İŞARETLİ
- [ÖNEMLİ] supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql:74 + :151-153 — R14 üyelik kümesi `c.ovsync_tren IS NULL`. Ancak 004:465 ve 007:115'te NULL aynı zamanda **bağımsız** etiketi (K8/R4). Açılıştan sonra bayrak açıkken ve bağımsız olmadan başlatılan vakada üyelik NULL olursa 004:256 hata veriyor. Yani açılıştan sonra NULL kalan vakalar yalnız bağımsız ya da hastalık günlü olanlar. Bağımsız bir vaka tren gününde başlatılırsa (004:212 `v_s := v_bugun`) D0'ı ritme düşer. Bundan sonraki her `ovsync_tren_ayar_guncelle(true, aynı çapa)` çağrısı (Varsayım 2: her açılış çağrısı yeniden hedefliyor) ya da doğrudan `yeniden_hedefle(false)` çağrısı bu vakaya üyelik yazar. Sonuçta kullanıcının açıkça "bağımsız" seçtiği vaka trene bağlanır ve D7 toptan ertelemesine girer. Bunu ölçen bir test yok. — sınıf: doğruluk/semantik (plan boşluğuyla birlikte) — kanıt: `grep -n "değilse NULL (bağımsız)" 004:465`, `007:115 bagimsizlar = ovsync_tren IS NULL`, D8 test eklerinde `bagimsiz` 0 eşleşme — dar fix: (a) 008:151'deki `IF p_aktif` koşulunu `IF p_aktif AND (v_aktif = 0 OR v_yeni_c <> v_eski_c)` yap. Böylece göç yalnız açılışta ya da çapa değiştiğinde koşar (PLAN D8: "açılış/çapa değişikliğinde"), Varsayım 2 geri alınır. Değişmeyen çağrıda `yeniden_hedef` null döner; TR-GOC-3 idempotentliği doğrudan `yeniden_hedefle(false)` ile ölçülsün. (b) Yeni assert TR-GOC-6: açılıştan sonra tren gününde `start_first_service_protocol(.., p_bagimsiz=>true)` → `ayar_guncelle(true, aynı çapa)` → `ovsync_tren` NULL kalır. (c) SORU (root): doğrudan `yeniden_hedefle(false)` çağrısında ve çapa değişiminde bağımsız vakayı göç öncesi NULL'dan ayırmak için ayrı bir işaret (örn. `ovsync_bagimsiz`) gerekir mi? Bu PLAN R14/K8 kararıdır, worker'a ait değil.
- [KÜÇÜK] supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql:135 — report:24 ve 008:110 "kapatma ayarı doğrulamaz; bozuk ayarda da hızlı geri" diyor. Oysa `ovsync_tren_capa` satırı eksikse kapatma (`p_aktif=false`) da `OVSYNC_TREN_AYAR EKSIK` ile düşüyor; bozuk değerde çalışıyor, eksik satırda çalışmıyor. — sınıf: doc-drift / fail-closed yönü — kanıt: 008:135 koşulu p_aktif'ten bağımsız (INFERRED, koşulmadı) — dar fix: koşulu `IF v_aktif IS NULL OR (p_aktif AND v_eski_c IS NULL)` yap. TR-AYAR-P1'e "çapa satırı silinmiş + kapat → ok, aktif 0" assert'ini ekle.
- [KÜÇÜK] supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql:131-134 — aynı tabloya 4 ayrı tek-değer SELECT var. — ölçüt (b)/(d) — dar fix: tek sorguya indir: `SELECT max(deger) FILTER (WHERE anahtar='ovsync_tren_aktif'), max(deger) FILTER (WHERE anahtar='ovsync_tren_capa'), max(min_deger) FILTER (…capa), max(max_deger) FILTER (…capa) INTO v_aktif, v_eski_c, v_mn, v_mx FROM protokol_ayar WHERE anahtar IN (…)`.
- [KÜÇÜK] supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql:155-160 — dönüşteki `capa` için exception alt bloğu kullanılıyor; bu her çağrıda bir subtransaction açar. — ölçüt (c)/(d) — dar fix: isteğe bağlı. `p_capa` verildiyse doğrudan `p_capa`, açılış yolunda `(v_yh->>'capa')::date` kullanılabilir; blok yalnız kapatma ve eski çapa için kalır.
BLOKLAYAN: 1 · ERTELENEBİLİR: 3
NOKTA NOTU: Tam diff okunmadı (geri-al.sql'in 2467 satırının gövdeleri satır satır karşılaştırılmadı). Gövde eşitliğine yalnız provadaki md5/ACL farkı = 0 ölçümü kefil.

OZET sinyal=92
KALİTE: boyut eklenen=2794 oran=14.0 → gerekli — 2467 satırı geri-al.sql (D0'ın 16 prod gövdesinin kopyası + DROP/ACL; plan N7-P11 bunu istiyor). Migration 169 satır, bütçe 200'ün içinde.
KALİTE: tekrar geri-al.sql↔geri-al.sql ×64 → gerekli — prod gövdelerinin birebir kopyası; md5 koruması bu kopyayı şart koşuyor, sadeleştirilemez.
KALİTE: tekrar geri-al.sql↔008 ×22 → gerekli — tekrar eden kısım SECURITY DEFINER / search_path / ACL fonksiyon başlığı kalıbı.
KALİTE: tekrar 008:20~008:112 → gerekli — iki RPC'nin aynı fonksiyon başlığı (6 satırlık pencere).
KALİTE: olcum-yok: 4 dosya — dil-desteksiz (d8-pgk-assert-diff.txt, d8-regresyon.md, geri-al.sql, 008 .sql)
KALİTE: göz okuması: 008:131-134 ve 155-160 KÜÇÜK (yukarıda); ÖNEMLİ kalite bulgusu yok.

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
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-de268641.md
 İzole DB'ler drop edildi: egesut_val_1019474_0b1e20ab egesut_val_1019474_813b458e
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
```
( echo 'BEGIN;'; cat supabase/migrations/2026111010000{1..8}_*.sql supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql … egesut_ovsync_kabul -X -v ON_ERROR_STOP=1
```
rc: 0
```
NOTICE:  BOLUM 1-bayrak0: 33 PASS (kümülatif 62)
NOTICE:  BOLUM S1: 19 PASS (kümülatif 487)
NOTICE:  OZET: 487 PASS
```
```
bash ~/tmp/ovsync-tren-db/prova_pgk.sh   (BEGIN … seri … geri-al.sql … fark … pgk taban … ROLLBACK)
```
rc: 0
```
NOTICE:  GERI_AL TAMAM: 16 gövde D0 md5, 24 yeni fonksiyon + 3 yeni imza yok, cases.ovsync_tren yok, 5 ayar yok
NOTICE:  PROVA: public pg_proc (imza, md5, acl, secdef, config) seri öncesiyle fark = 0, protokol_ayar fark = 0
NOTICE:  OZET: 482 PASS
```

SORU: (root) Bağımsız (K8) ile göç öncesi NULL tek kolonda birleşiyor. Doğrudan `yeniden_hedefle(false)` çağrısında ve çapa değişiminde bağımsız vaka trene bağlanmalı mı? Bağlanmamalıysa ayrı bir işaret gerekir (PLAN R14 kararı).

## Kırıntılar
- gate (dead-path değil, semantik): 008:74 R14 üyeliği bağımsız vakayı (ovsync_tren NULL) trene bağlayabiliyor; dar fix olarak göç yalnız açılış/çapa değişiminde koşsun + TR-GOC-6.
- measurement: 539 / 487 (Bölüm 1 = 33) / geri alma sonrası 482 (Bölüm 1 = 31), pg_proc farkı 0. DONE'daki sayılar yeniden ölçüldü ve tuttu.
- decision: KALİTE: sinyal 92, hepsi gerekli ya da olcum-yok; KÜÇÜK 2 (008:131-134, 155-160).
