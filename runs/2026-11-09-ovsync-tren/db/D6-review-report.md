⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D6 T2 review⟧
sonuc: TAMAM

VERDICT: FAIL (DÜZELT): 1 ÖNEMLİ doğruluk bulgusu var (K6 a/b dışlaması). Geri kalan her şey kabul düzeyinde.
OKUDUM: D6-review-brief 30 satır · review-sablon 25 · D6-brief 53 · D6-report (DONE) tamamı ~150 · PLAN.md Global Constraints + R1–R20 + D6 + Kapı tur 2 (29–116, 347–376, 645–650) · progress.md RL-1..RL-11/SORU-3/SÖZLEŞME EKİ satırları · migration 006 tamamı (gövde diff + 249–453) · kabul.sql D6 TR-K6-A1..TR-K6-B-N1 (2430–2620) + kb_pg_tai · domain-rules §ovsync 9 · design.md K6 · araç 23
ÖLÇTÜM:
- kabul seri koşumu (001..006 + ovsync_tren_kabul.sql, BEGIN/ROLLBACK) → rc 0, `OZET: 362 PASS`, FAIL satırı 0 (MEASURED; DONE'daki 362 ile aynı)
- db-validate 006 --priors 001..005 → rc 0, `SONUÇ: PASS` (7b17f288) (MEASURED)
- `! grep -n CURRENT_DATE 2026111010000*.sql` → rc 0, çıktı yok (MEASURED)
- seans_tamamla gövde diff: kabul DB'deki prosrc (md5 4afb2221…, govde-taban.md prod sütunuyla EŞİT) ↔ migration gövdesi → farkın tamamı "D6" yorumlu 4 blokta: DECLARE +5, occurred_at CASE, uyarı bloğu, RETURN `|| ovsync_uyari` (MEASURED)
- sonda (BEGIN/ROLLBACK, kabul betiği sonrası; `$S/sonda.sql`): aşama 2 + açık PG_TOHUMLAMA TAI → ovsync_bastan_baslat (MEASURED, aşağıda)
- ss-kalite-sinyal --base 6a9e8db --head 00420d2 --butce 450 → `OZET sinyal=8 eklenen=453 butce=450` (MEASURED)

İŞARETLİ:
- [ÖNEMLİ] supabase/migrations/20261110100006_ovsync_tren_asama.sql:423-441 (ovsync_bastan_baslat, basladi=false dalı) — race-lifecycle — K6(b) seçilince hayvanın açık PG+48 s TAI'si (`PG_TOHUMLAMA:*`) açık kalıyor. Hayvan aynı anda (a)'nın ürünü olan PG+48 TAI'yi ve (b)'nin ürünü olan tren günlü OVSYNC_BASLAT'ı taşıyor; spec K6 bu iki seçeneği birbirini dışlayan seçenekler olarak tanımlıyor ("(a) … PG+48 TAI kalır · (b) baştan başlat → trene bin"). Aynı çağrı başlatma yolunda (tren bugün ya da p_bagimsiz) TAI'yi kapatıyor, yani sonuç "bugün tren günü mü" sorusuna bağlı. D7'nin toptan `BASTAN` seçimi de bu yolu kullanacağı için hata toptan ölçeğe taşınır. — kanıt: sonda S1 (tren bugün+3, aşama 2): `basladi:false`, eski vaka `closed/IPTAL`, `pg_tai_acik=c5d0f82f… (ayni=t)`, TOHUMLAMA görevleri `PG_TOHUMLAMA:…|2026-11-11|tam=f|ipt=f`, yeni OVSYNC_BASLAT hedefi 2026-11-12. S2 (tren bugün): `basladi:true`, `PG_TOHUMLAMA…|tam=t|ipt=t`, pg_tai_acik NULL. S3 (p_bagimsiz): `basladi:true`, pg_tai_acik NULL (MEASURED). Worker'ın açık kalemi (INFERRED) bu ölçümle CONFIRMED. — dar fix: `protokol_iptal`'den hemen sonra, hayvanın açık `TOHUMLAMA_PLANLI` + `kaynak LIKE 'PG_TOHUMLAMA:%'` görevlerini start_first_service_protocol'ün (004) kullandığı aynı kapatma yoluyla iptal et; böylece K6(b)'nin üç dalı da TAI bırakmaz. Bu, spec'in (a) için yazdığı "TAI kalır"ın tersini (b)'ye uygulayan bir okumadır. Root, "(b)'de TAI kalsın" diye ruling verirse fix yerine o ruling progress.md'ye işlenir.
- [ÖNEMLİ] supabase/tests/ovsync_tren_kabul.sql:2533 (TR-K6-B1) — fake-arm (test kapsamı) — K6(b)'nin testi aşama 1 fixture'ıyla kurulmuş (`fixture: aşama 1 (geriye tarihli GnRH1)`). Aşama 2'de baştan başlatma, yani K6'nın kendisi, hiçbir assert'te koşmuyor; yukarıdaki bulgu bu yüzden yeşil koşumdan geçti. — kanıt: TR-K6-B1/B2/B-N1 bloklarında `kb_seans_yap(v_c, 2)` yok (OBSERVED, 2523–2620). — dar fix: TR-K6-B1'e aşama 2 alt senaryosu ekle (seans 1+2 yapılmış, PG TAI açık); hem basladi=false hem basladi=true dalında `pg_temp.kb_pg_tai(v_h) IS NULL` assert'i olsun.
- [KÜÇÜK] supabase/migrations/20261110100006_ovsync_tren_asama.sql:352-357 ve 416-421 — race-lifecycle — vakanın `status='active'` kontrolü hayvan kilidinden (`FOR NO KEY UPDATE`) önce yapılıyor. Advisory kilit dışındaki bir `protokol_iptal` ya da son seans araya girerse kilitten sonra kapanmış vaka üzerinde devam edilir (pg48 `ok, kapanan_seans 0` döner). — kanıt: kod okuması (INFERRED; ölçülmedi). — dar fix: hayvan kilidini vaka SELECT'inden önce al (ovsync_hayvan_ertele'deki sıra), ya da kilitten sonra durumu yeniden doğrula.
- [KÜÇÜK] D6-report "Bayrak 0'da … ayar okunmaz" — doc-drift — bayrak 0'da da `_ovsync_tren_aktif()` → `_ayar('ovsync_tren_aktif', 0)` okunuyor (migration 006:172, 002:37). Okuma varsayılanlı, hata vermiyor; davranış eski ile aynı (TR-K11-REG PASS). Etkisi yok; yalnız ifade düzeltilmeli. — kanıt: 002:34-38 (OBSERVED).

Kabul edilen kontroller (bulgu yok):
1. Gövde türetimi: prod gövdesinden; fark yalnız plandaki R13 satırları (MEASURED diff).
2. md5: `4afb2221a7e95235e754b7ff508d0379`, imza `(uuid,boolean,text,boolean,text,boolean)`. govde-taban.md ile ve kabul DB prosrc ile eşit (MEASURED).
3. ACL: 4 imzada REVOKE PUBLIC, anon ve GRANT authenticated, service_role; yeni iç yardımcı yok (OBSERVED 446-453). anon'un varsayılan yetkisi kabul DB'sinde ölçülemiyor; bu, D4/D5'ten devralınan DM1 kalemi.
4. Bayrak 0: seans_tamamla'da `v_tren_ovs` false kalıyor; LEAST korunuyor, uyarı anahtarı eklenmiyor (TR-K11-REG). Üç RPC'de de `_ovsync_ic_ac → advisory lock → OVSYNC_TREN_KAPALI` sırası var (OBSERVED + TR-KAPALI).
5. TR tarih: yeni gövdelerde `CURRENT_DATE` yok (MEASURED). Hata kodları ve payload'lar plan D6 Interfaces ile birebir: OVSYNC_ASAMA1_TOLERANS{tolerans, mevcut_kayma, istenen, oneri, case_id}, ASAMA2_ERTELEME_YOK{case_id, secenekler}, ASAMA_BELIRSIZ{case_id, oneri}, VAKA_YOK, ASAMA2_DEGIL, PG48_TAI_YOK, PG48_GECMIS, BASTAN_BASLATILAMADI{yeniden_not} (OBSERVED).
6. RL-1: ovsync_hayvan_ertele `ovsync_tren`'i ayrıca artırmıyor (OBSERVED 249-329). TR-K4-2 +7 ve TR-K5-1 +1 tek sayımı ölçüyor.
7. R18: `v_kayma + p_gun > tolerans` reddediliyor (birikimli); TR-K5-N2 ve TR-K5-2 bunu ölçüyor.
8. K11 formülü: `bugün − PG1 + kayma` = `bugün − (GnRH1 tamamlanma + 7)` (cebirsel olarak R13 ile eşdeğer). TR-EK-UYARI dört alanı ölçüyor.
9. R12: kalan şablon seansları `seans_tamamla(p_uygulanmadi => true)` ile kapanıyor; TAI hayvanda kalıyor (TR-K6-A1).
10. Kapsam: diff yalnız iki yazılabilir dosya (`git diff --stat` 2 dosya, +1043). Gerekçeli varsayımlar (1–11) plan boşluklarında kalıyor, spec'i değiştirmiyor.

OZET sinyal=8
KALİTE: tekrar 006:29~252/334/397, 252~334/397, 334~397 (5 sinyal; pencere 6–7) → gerekli — `CREATE FUNCTION … RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path … DECLARE` başlık deyimi; SQL'de paylaşılamaz.
KALİTE: tekrar 006:29~397 (1 sinyal) → gerekli — aynı başlık deyimi (seans_tamamla kopyası ↔ bastan_baslat).
KALİTE: tekrar 006:351~415 pencere=6 → gerekli — `ic_ac → advisory → KAPALI → aktif OVSYNC vaka → VAKA_YOK` girişini plan her RPC için ayrı istiyor. Ortak yardımcıya çekmek yeni bir fonksiyon, ACL satırı ve kilit sırası riski getirir; 6 satır için değmez.
KALİTE: olcum-yok: 1 dosya — dil-desteksiz (006 .sql).
Boyut: 453/450. Aşım 3 satır ve gerekçeli (222 satır gövde kopyası); kabul (a).

BLOKLAYAN: 2 · ERTELENEBİLİR: 2
NOKTA NOTU: D7 (toptan erteleme) gövdesi henüz yok. Toptan `BASTAN` seçiminin ovsync_bastan_baslat'ı mı çağıracağını ölçmedim; bulgu 1'in toptan ölçeğe taşınacağı INFERRED.

## Ek soru cevabı (worker açık kalemi: aşama 2'de ovsync_bastan_baslat sonrası PG TAI)
- Ölçüm (MEASURED, sonda S1): tren ≠ bugün ve bağımsız değilken PG_TOHUMLAMA TAI açık kalıyor. Tren = bugün (S2) ve p_bagimsiz (S3) dallarında kapanıyor (start_first_service_protocol kapatıyor).
- K6 dışlaması: (a) "PG+48 TAI kalır, kalan günler iptal" ile (b) "baştan başlat → trene bin" iki ayrı karar. (b)'nin bir dalında (a)'nın TAI'si kalınca, kullanıcı (b)'yi seçmiş olsa da Görevler ekranında PG+48 tohumlama görevini görür. Eski vaka kapandığı için bu TAI artık R5(b) kapsamında "Ovsync görevi" sayılmıyor, K10 kilidi de yok. Kullanıcı TAI'yi uygularsa hayvan Bekliyor olur ve tren günündeki OVSYNC_BASLAT start'ta atlanır (TR-K6-B-N1(b)'deki BEKLIYOR muafiyeti). Böylece (b) kararı sessizce (a)'ya döner. Seçenekler bu dalda birbirini dışlamıyor → bulgu 1 (ÖNEMLİ, bloklayan).

## Run kanıtı
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
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-7b17f288.md
 İzole DB'ler drop edildi: egesut_val_3980519_e41e0bfe egesut_val_3980519_7041773d
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) Sonda (seri + kabul betiği + ~/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-tedavi-arge/0a3aaf88-b728-4de1-82e4-e9c37db2e88c/scratchpad/sonda.sql, BEGIN/ROLLBACK)
rc: 0
```
NOTICE:  SONDA S1 sonuc={"ok": true, "basladi": false, "hedef_tarih": "2026-11-12", "yeni_case_id": null, ...} | pg_tai_acik=c5d0f82f-a31b-42d5-ac06-c83be7ededa9 (ayni=t) | vaka=closed/IPTAL | TOH gorevleri: PG_TOHUMLAMA:14b21692-…|2026-11-11|tam=f|ipt=f
NOTICE:  SONDA S2 sonuc={"ok": true, "basladi": true, "hedef_tarih": "2026-11-09", ...} | pg_tai_acik=<NULL> | TOH gorevleri: TEDAVI_SABLON_TOHUMLAMA:…|2026-11-19|tam=f|ipt=f ; PG_TOHUMLAMA:…|2026-11-11|tam=t|ipt=t
NOTICE:  SONDA S3 sonuc={"ok": true, "basladi": true, "hedef_tarih": "2026-11-12", ...} | pg_tai_acik=<NULL> (onceki=746f1a47-…)
```
5) `~/tools-bank/scripts/ss-kalite-sinyal --repo … --base 6a9e8db --head 00420d2 --butce 450`
rc: 0
```
SINYAL olcum-yok supabase/migrations/20261110100006_ovsync_tren_asama.sql dil-desteksiz
OZET sinyal=8 eklenen=453 butce=450
```

## Kırıntılar
- gate (race-lifecycle): ovsync_bastan_baslat aşama 2, basladi=false → PG_TOHUMLAMA TAI açık kalıyor; K6 a/b dışlaması bozuk (sonda S1 MEASURED).
- gate (fake-arm): TR-K6-B1 fixture'ı aşama 1; K6(b) aşama 2'de test edilmiyor.
- decision: KALİTE: sinyal=8 hepsi gerekli (başlık deyimi + plan zorunlu RPC girişi); boyut 453/450 gerekçeli.
- open_item: D7 toptan BASTAN'ın aynı yolu kullanıp kullanmayacağı D7 review'unda ölçülmeli.

## Tur 2
⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D6 T2 review tur 2⟧
sonuc: TAMAM
VERDICT: PASS: tur 1'in 4 maddesi kapandı, yeni bloklayan bulgu yok.
OKUDUM: git diff 00420d2..7ce4781 (migration +11/-2, kabul.sql +29/-1) · progress.md RL-12 · 004:280-318 (start yolunun PG TAI kapatması) · D6-report tur 2 (satır 25, 184-249)
ÖLÇTÜM:
- kabul seri koşumu → rc 0, `OZET: 366 PASS` (MEASURED; lead'in 366'sıyla aynı, tur 1'e göre +4 assert)
- sonda S1 yeniden (aynı dosya: ~/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-tedavi-arge/0a3aaf88-b728-4de1-82e4-e9c37db2e88c/scratchpad/sonda.sql) → `basladi:false`, `pg_tai_acik=<NULL>`, `PG_TOHUMLAMA…|tam=t|ipt=t`. S2 ve S3 değişmedi, ikisinde de TAI kapalı (MEASURED)
- db-validate 006 --priors 001..005 → rc 0, PASS (eb7eaea9) (MEASURED); `! grep CURRENT_DATE` → rc 0 (MEASURED)
Madde madde:
1. K6 a/b dışlaması: KAPANDI. 006 `ELSE` dalı (basladi=false), 004:284-295'teki UPDATE ile aynı süzgeci ve işareti kullanıyor (`iptal=true, tamamlandi=true`, `ILK_TOH_PROTOKOL_YERINE:`). Sonda S1'de TAI kapalı (MEASURED).
2. TR-K6-B1 aşama 2 alt senaryosu: KAPANDI. Hem basladi=false hem basladi=true dalında `_ovsync_asama=2` fixture'ı ile `kb_pg_tai IS NULL` ve `kapatan_ref LIKE 'ILK_TOH_PROTOKOL_YERINE:%'` assert'leri var. Fix'siz gövdeyle ilk assert düşerdi (sonda S1 tur 1 = mutant kanıtı) (OBSERVED + MEASURED).
3. Kilit sırası: KAPANDI. pg48 ve bastan_baslat'ta hayvan `FOR NO KEY UPDATE` artık vaka durumu okunmadan önce alınıyor (OBSERVED diff). Vaka yoksa alt sorgu NULL döner, kilit boşa gider, ardından `OVSYNC_VAKA_YOK` (zararsız).
4. Report ifadesi: KAPANDI. D6-report satır 25 artık "varsayılanlı okunur, hata vermez" diyor (OBSERVED).
İŞARETLİ:
- [KÜÇÜK] supabase/migrations/20261110100006_ovsync_tren_asama.sql:439-445 — RL-12 dalı — ertelenebilir. Start yolu iptal ettiği TAI id'lerini islem_log detayına ve dönüşe `pg_gorev_iptal` olarak yazıyor (004:313, 318). Bu dal yazmıyor; iz yalnız `kapatan_ref`'te (ref görev id'si, vaka id'si değil: henüz vaka yok, yorumda gerekçeli). JS'te ve diğer SQL'de bu ref'i ayrıştıran tüketici yok (grep: yalnız yazanlar) (OBSERVED). — dar fix (isteğe bağlı): `RETURNING` ile id'leri toplayıp dönüşe `pg_gorev_iptal` ekle.
OZET sinyal=2
KALİTE: tekrar 006:351~416 pencere=8 → gerekli — kilit sırası fix'i iki RPC'nin aynı girişini 2 satır uzattı. Plan her RPC için bu girişi ayrı istiyor; ortak yardımcı yeni ACL ve kilit-sırası yüzeyi getirir.
KALİTE: olcum-yok: 1 dosya — dil-desteksiz (006 .sql).
Boyut: 462/450, aşım gerekçeli (D6-report:249) → kabul (a).
BLOKLAYAN: 0 · ERTELENEBİLİR: 1 (+ tur 1'den KÜÇÜK yok, ikisi kapandı)
NOKTA NOTU: D7 toptan `BASTAN`'ın bu RPC'yi çağırıp çağırmayacağı hâlâ D7 review'unda ölçülmeli.

### Run kanıtı (tur 2)
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
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-eb7eaea9.md
 İzole DB'ler drop edildi: egesut_val_4165233_9f69aec7 egesut_val_4165233_e7796b83
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) Sonda S1 (seri + kabul + sonda.sql, BEGIN/ROLLBACK)
rc: 0
```
NOTICE:  SONDA S1 sonuc={"ok": true, "basladi": false, "hedef_tarih": "2026-11-12", "yeni_case_id": null, ...} | pg_tai_acik=<NULL> (ayni=<NULL>) | vaka=closed/IPTAL | TOH gorevleri: PG_TOHUMLAMA:af8015b1-…|2026-11-11|tam=t|ipt=t
```
5) `~/tools-bank/scripts/ss-kalite-sinyal --repo ~/.herdr/worktrees/egesut-erp1/ovsync-tren --base 00420d2 --head 7ce4781 --butce 450`
rc: 0
```
SINYAL olcum-yok supabase/migrations/20261110100006_ovsync_tren_asama.sql dil-desteksiz
OZET sinyal=2 eklenen=11 butce=450
```

### Kırıntılar (tur 2)
- measurement: D6 tur 2 kabul 366 PASS, sonda S1 TAI kapalı, db-validate PASS (eb7eaea9).
- decision: KALİTE: tur 2 sinyal=2 gerekli; verdict PASS.
- open_item: RL-12 dalı iptal edilen TAI id'lerini dönüşe/log'a yazmıyor (KÜÇÜK, ertelenebilir).
