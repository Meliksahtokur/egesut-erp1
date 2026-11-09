⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D5 T2 review⟧
sonuc: TAMAM

```
VERDICT: DÜZELT
OKUDUM: kat1 yok (brief nokta-paketi değil; şablon review-sablon.md + git diff 1adffe6..4dd94df -- supabase/ runs/.../db/ ile yürüdü) · DONE (D5-report) 185 · lead review progress.md RL-1/RL-11/ROOT RULING satırları (22, 52-56) · kat2 004 tam diff (65 satır), 005 beş gövde ↔ kanit/fn difflib (tam), kabul test D4-EK hunk'ları + 235-248, 1076-1095 · araç 19
ÖLÇTÜM: kabul seri 001-005+test BEGIN/ROLLBACK → rc 0, "OZET: 286 PASS" (lead 286 ile eşit) · db-validate 005 --priors 001-004 → rc 0 SONUÇ: PASS · db-validate 004 --priors 001-003 → rc 0 SONUÇ: PASS · grep CURRENT_DATE → rc 0 (boş) · 005 gövdeleri ↔ prod kanit difflib → yalnız D5 blokları farklı (5/5) · ss-kalite-sinyal → OZET sinyal=31 eklenen=807 butce=600
İŞARETLİ:
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:97,103,174,571 — doc-drift (spec K2/§18.3) — ÖNEMLİ — gelecekteki ritim dışı görevde ilk tren bugünden aranıyor: kural günü öncesine >2 gün öne çekiyor ve K4 OVSYNC_ERKEN kapısını atlıyor
- supabase/tests/ovsync_tren_kabul.sql:1694-1698 — fake-arm (yanlış beklenti kodlanmış) — ÖNEMLİ — TR-D4EK-2 "bugün+12 → bugün+3" (9 gün öne çekme) K2'ye aykırı davranışı PASS sayıyor
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:181 — silent-success — KÜÇÜK — yeniden_hedef = v_ilk_tren; gorev_ertele 'tohumlama' pencere yuvarlamasının sonucu (gerçek hedef_tarih) değil
- supabase/migrations/20261110100005_ovsync_tren_kilit.sql:527 — kalite (b) tekrar — KÜÇÜK — cozulen CTE'nin 3. kopyası (prod gövde birebirliği için gerekçeli; senkron riski yorumda)
- supabase/tests/ovsync_tren_kabul.sql:1529-1555 — test raporlama — KÜÇÜK — TR-D4EK-3'ün kendi "PASS TR-D4EK-3" satırı yok (TR-ONIZLE-1 bloğu içinde kb_ok; rc 0 ile geçtiği ölçülü)
- supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:96 — test boşluğu — KÜÇÜK — bayrak 0'da cron+gecikmiş görev için ayrı assert yok (kod koruması _ovsync_tren_aktif() ile var; start bayrak 0 yolu TR-D4EK-2 son assert'iyle ölçülü)
BLOKLAYAN: 2 (aynı kök: K2 ihlali, kod+test) · ERTELENEBİLİR: 4
NOKTA NOTU: kat1 paketi olmadan tam diff okundu; kaçırma riski düşük, ancak 005 test bölümünün (D5, +437) tamamı değil yalnız id→PASS sayımı ve D4-EK hunk'ları okundu.
```

## Bulgular (şablon biçimi)
VERDICT: FAIL (şablon karşılığı; üst blokta DÜZELT)

[ÖNEMLİ] supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:97,103,174,207 + :570-571 — D4-EK `v_eski` hem gecikmiş (hedef < bugün) hem GELECEKTEKİ ritim dışı hedefi kapsıyor ve ikisinde de ilk tren `_ovsync_tren_gunu(v_bugun)` ile bugünden aranıyor. Gelecekteki ritim dışı hedefte (örn. hedef = bugün+12) bu, tasarım K2'yi ("hayvan `tren_gunu ≥ kural_gunu − 2` olan en yakın trene biner", design.md:84) ve §18.19 "öne çekme ≤2 gün"ü çiğniyor. `:103`'te K4 OVSYNC_ERKEN kapısı da `NOT v_eski` ile atlanıyor (§18.3 "erken çağrıyı OVSYNC_ERKEN ile reddeder"). Sonuç: bugün tren günüyse vaka bugün açılır, yani kural gününden (VWP/düve yaşı) 12 gün önce; değilse görev 9 gün öne çekilir. Önizleme (:571) de yanlış tren gösterir. Gecikmiş hedefte ise davranış doğru (bugün > hedef − 2). Erişim: UI ▶ Başlat'ı yalnız hedef−2 penceresinde çiziyor ve cron yalnız hedef ≤ bugün görevleri başlatıyor. Bu yüzden yol doğrudan RPC çağrısı, önizleme gösterimi ve çapa/gün ayarı değişince ritim dışı kalan bütün gelecek görevlerdir. Sunucu son kapısı (fail-closed) zayıfladı.
  — kanıt: CONFIRMED kod (004:97 `v_eski := COALESCE(v_g.hedef_tarih < v_bugun OR NOT public._ovsync_tren_gunu_mu(v_g.hedef_tarih), false)`; 004:174 `v_ilk_tren := public._ovsync_tren_gunu(v_bugun)`); MEASURED test TR-D4EK-2 (kabul.sql:1694-1698) bugün+12 hedefli görevin bugün+3'e yeniden hedeflendiğini PASS sayıyor (kabul koşumu rc 0).
  — dar fix: 004:174 ve 004:571'de ilk treni `_ovsync_tren_gunu(GREATEST(v_bugun, <hedef> - 2))` ile hesapla (start'ta `v_g.hedef_tarih`, önizlemede `v_ghedef`). Gecikmiş görev değişmez (GREATEST = bugün). Gelecekteki ritim dışı görev K2'ye uyar ve bugün başlatma yalnız bugün ≥ hedef−2 iken mümkün olur; K4 kapısı da kendiliğinden korunur. kabul.sql:1694-1698 beklentisini bugün+10'a (bugün+10 ≥ 12−2 olan ilk tren) çevir. Ayrıca "bugün tren + uzak ritim dışı → başlamaz" assert'i ekle. Root ruling "bugünden itibaren ilk tren" lafzı gecikmiş görev için yazılmıştı; bu fix ruling'i K2 ile uzlaştırıyor. Root'a bilgi (SORU aşağıda).

[ÖNEMLİ] supabase/tests/ovsync_tren_kabul.sql:1694-1698 — TR-D4EK-2 "uzak ritim dışı → OVSYNC_ERKEN değil, ilk trene (bugün+3)" assert'i K2'ye aykırı davranışı kodluyor (yanlış beklenti). — kanıt: yukarıdaki. — dar fix: yukarıdaki fix ile birlikte beklentiyi düzelt.

[KÜÇÜK] supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:181 — dönüşteki `yeniden_hedef` = `v_ilk_tren`. Oysa gorev_ertele `pencere_kurali='tohumlama'` ile tarihi `_tohumlama_pencere` üzerinden yuvarlıyor (005:93-104); görevin hedef_saat'i geç bir saatse gerçek hedef ertesi güne kayabilir ve bir sonraki çağrıda görev yine "ritim dışı" sayılır (INFERRED, ölçülmedi). — dar fix: `yeniden_hedef` değerini gorev_ertele dönüşündeki `hedef_tarih`'ten al (ya da yeniden oku).

[KÜÇÜK] supabase/migrations/20261110100005_ovsync_tren_kilit.sql:527 — cozulen CTE'nin 3. birebir kopyası (kalite b). Prod gövde birebirliğini korumak için gerekçeli; senkron riski yorumda yazılı. — dar fix: yok (kabul).

[KÜÇÜK] supabase/tests/ovsync_tren_kabul.sql:1529,1541,1555 — TR-D4EK-3'ün ayrı bir `PASS TR-D4EK-3` satırı yok; kb_ok TR-ONIZLE-1 bloğunun içinde. kb_ok başarısızlıkta RAISE ettiği için rc 0 = geçti (MEASURED). — dar fix: blok sonuna `RAISE NOTICE 'PASS TR-D4EK-3: …'`.

[KÜÇÜK] supabase/migrations/20261110100004_ovsync_tren_baslatma.sql:96 — bayrak 0'da cron + gecikmiş görev için ayrı assert yok. Kod koruması var: v_eski yalnız `_ovsync_tren_aktif()` iken hesaplanıyor; :252 UYELIK kontrolü ve :103 kapısı da bayrak 0'da eskisiyle aynı (OBSERVED). Start bayrak 0 yolu TR-D4EK-2 son assert'iyle ölçülü; cron aynı fonksiyonu çağırıyor (INFERRED). — dar fix: TR-D4EK-1'e bayrak 0 + `ilk_tohumlama_zamanlayici()` → vaka bugün açılır, görev hedefi değişmez assert'i.

### Odak soruları
- K10 kilidi iç zincirleri kırıyor mu: HAYIR (CONFIRMED + MEASURED).
  - kaydir→tohumlama_gorev_ertele: Ovsync vakası iç bayrakla geçiyor (TR-K10-IC PASS). Mastit kaydırması yalnız kendi TAI'sini seçiyor (005:384 `kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id`), Ovsync TAI'sine dokunmuyor (TR-K10-8 PASS).
  - hastalık: `_ovsync_ic_ac()` 005:658'de, TAI ötelemesi 005:733'te (TR-K9-1 PASS).
  - D4-EK: 004:176-178'de iç bayrak açılıyor → gorev_ertele → önceki değer geri yükleniyor (TR-D4EK-1 "iç bayrak geri yüklendi" PASS).
- `_coklu`: ovsync_atlanan satırları toplam/atlanan/hatalar'a girmiyor (TR-K10-5 PASS). Döngü dışlaması 005:578; boş dizi `'{}'` olduğundan NULL tuzağı yok.
- Bayrak 0 regresyonu: TR-K10-REG, TR-K8-REG ve TR-REG-1 PASS. Kilit yardımcıları bayrak 0'da erken dönüyor. 004:464 iç içe CASE fix'i brief metniyle birebir.
- `pg_catalog.jsonb_array_elements` (005:717): davranış eşdeğer. Fonksiyon `search_path='public','pg_temp'` ile tanımlı; pg_catalog listede yokken örtük olarak ilk sırada aranır (PG belgeli davranış), dolayısıyla çözümleme aynı (INFERRED, belge). Gövdedeki tek plan dışı fark bu ve yorumlu.
- md5 korumaları (005:18-30): 5 imza govde-taban.md prod sütunuyla eşit; kanit md5'i de aynı (difflib betiği kanit gövde md5'lerini yeniden hesapladı, 5/5 EŞİT). ACL (005:745-754): her fonksiyonda REVOKE PUBLIC, anon ve GRANT authenticated, service_role. İç yardımcılar 002:257-261'de authenticated'dan da kapalı.
- Kapsam: diff yalnız 004, 005 ve kabul.sql. Brief'in yazılabilirleri içinde, scope-violation yok.

OZET sinyal=31
KALİTE: tekrar 004:19/39/320 ~ 005:14/34/183/275/461/639 → gerekli. md5 koruma DO bloğu ve CREATE OR REPLACE tam gövde başlıkları; prod gövde kopyası zorunlu.
KALİTE: tekrar 005 iç (43~191, 115~233, 163~255, 329~342, 412~441) → gerekli. Prod gövdelerinin birebir kopyası (kanit difflib yalnız D5 bloklarını farklı gösteriyor).
KALİTE: tekrar 005:504~529~560 pencere=15 → gerekli. cozulen CTE'nin 2 kopyası prod'dan, 1 kopyası D5'ten; prod gövdesine dokunmamak için kabul (KÜÇÜK yukarıda).
KALİTE: boyut eklenen=807 > butce=600 → gerekli. 649 satır 5 prod gövdesinin tam kopyası (BOYUT gerekçesi D5-report'ta; D4-EK +63/−15).
KALİTE: olcum-yok: 2 dosya — dil-desteksiz

SORU: (root) RL-11 ve ROOT RULING "hedef < bugün ya da ritim dışı → _ovsync_tren_gunu(bugün)" lafzı, gelecekteki ritim dışı hedefte design.md K2 ("tren_gunu ≥ kural_gunu − 2") ile çelişiyor. Önerilen uzlaştırma `_ovsync_tren_gunu(GREATEST(bugün, hedef − 2))`: gecikmişte ruling'le aynı sonucu verir, gelecekte K2'ye uyar. Onay gerekir.

## Run kanıtı
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
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-d8b305f2.md
 İzole DB'ler drop edildi: egesut_val_3259155_492503cb egesut_val_3259155_f7f26a69
```
2b) 004 yeniden (D4-EK sonrası): `bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql`
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-548fa783.md
 İzole DB'ler drop edildi: egesut_val_3276087_1b796c0c egesut_val_3276087_7ed3487e
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) `~/tools-bank/scripts/ss-kalite-sinyal --repo ~/.herdr/worktrees/egesut-erp1/ovsync-tren --base 1adffe6 --head 4dd94df --butce 600`
rc: 0
```
SINYAL olcum-yok supabase/migrations/20261110100005_ovsync_tren_kilit.sql dil-desteksiz
OZET sinyal=31 eklenen=807 butce=600
```
5) TR id → PASS satırı sayımı (kabul çıktısı): TR-K10-1..9, TR-K10-REG, TR-K10-IC, TR-K9-1, TR-K9-N1, TR-K8-REG, TR-D4EK-1, TR-D4EK-2, TR-D4EK-4, TR-ONIZLE-1 ve TR-ACL-D5 her biri 1. TR-D4EK-3'ün 0 olması bilinen durum: kb_ok TR-ONIZLE-1 bloğunun içinde.
Ham çıktılar: ~/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-tedavi-arge/0a3aaf88-b728-4de1-82e4-e9c37db2e88c/scratchpad/{kabul,dbv5,dbv4,cd,sinyal}.txt

## Kırıntılar
- gate (doc-drift): 004:97/174/571 gelecekteki ritim dışı hedef → ilk tren bugünden (K2 ve öne çekme ≤2 ihlali, K4 kapısı atlanıyor); TR-D4EK-2:1694 bunu kodluyor.
- measurement: kabul 286 PASS rc 0; db-validate 005 ve 004 PASS; CURRENT_DATE boş; 5 gövde ↔ kanit yalnız D5 blokları.
- decision: KALİTE: sinyal=31 → hepsi gerekli (prod gövde kopyası ve md5/ACL kalıbı); boyut 807/600 gerekçeli.
- open_item: yeniden_hedef ↔ pencere yuvarlaması (004:181), TR-D4EK-3 PASS satırı, bayrak 0 cron assert'i (KÜÇÜK; dar fix turunda).

## Tur 2 (fix 6a9e8db, base 4dd94df)
```
VERDICT: KABUL
OKUDUM: git diff 4dd94df..6a9e8db -- supabase/migrations/ (004 +13/−8) ve supabase/tests/ (+43/−5) tam · progress.md:54,57 (RL-11 düzeltmesi) · 002:50-81 (_ovsync_tren_ayar doğrulaması, _ovsync_tren_gunu_ic) · araç 3 (tur 2)
ÖLÇTÜM: kabul seri → rc 0, OZET: 290 PASS (lead 290 ile eşit) · db-validate 005 → rc 0 PASS · db-validate 004 → rc 0 PASS (1b160e37) · CURRENT_DATE grep → rc 0 boş · ss-kalite-sinyal 4dd94df..6a9e8db → OZET sinyal=1 eklenen=13
İŞARETLİ:
- supabase/tests/ovsync_tren_kabul.sql:1646-1653 — test gücü — KÜÇÜK — 22:00 senaryosu yeniden_hedef ile gorev_log eşitliğini ölçüyor ama yuvarlamanın gerçekten başka güne kaydırdığını (yeniden_hedef ≠ R9 treni) assert etmiyor; eski kod da tarih kaymasa PASS verirdi
BLOKLAYAN: 0 · ERTELENEBİLİR: 1
NOKTA NOTU: tur 2 yalnız fix diff'i ve tur 1 bulgularının kapanışı ölçüldü; D5 kilit gövdeleri değişmedi (diff 005'e dokunmuyor).
```

### Tur 1 bulgularının kapanışı
- **K2 öne çekme ≤2: KAPANDI (CONFIRMED + MEASURED).** 004:177-178 ve 004:576 artık `_ovsync_tren_gunu_ic(GREATEST(kural, hedef), capa, one_cekme, bugün)` çağırıyor; bu `GREATEST(taban − one_cekme, bugün)` sonrasındaki ilk tren demek (002:79-80).
  - `_ovsync_tren_ayar` one_cekme'yi 0..2 aralığında ve NOT NULL, çapayı da geçerli tarih olarak doğruluyor (002:50-66, aksi halde OVSYNC_TREN_AYAR). Bu yüzden STRICT `_ic` NULL döndüremez. GREATEST NULL kuralı yok sayar; v_eski yolunda hedef zaten NOT NULL.
  - Önizleme ile start aynı formülü kullanıyor (TR-D4EK-2 "önizleme = başlat" assert'i).
- **ERKEN kapısını atlama yalnız v_tren = bugün iken: KAPANDI.** Kapı (004:103) v_eski'de hâlâ atlanıyor, ama başlatma yalnız v_ilk_tren = bugün iken oluyor.
  - Bu durumda bugün ≥ max(kural, hedef) − one_cekme ≥ hedef − 2, yani K4 koşulu kendiliğinden sağlanıyor.
  - Aksi halde (v_ilk_tren > bugün) vaka açılmıyor; görev yalnız yeniden hedefleniyor (INFERRED, aritmetik).
- **TR-D4EK-2 yeni beklenti: KAPANDI (MEASURED).** kabul.sql:1714-1731 üç durumu doğruluyor:
  - kural = hedef = bugün+12 → bugün+10;
  - `yeniden_hedef ≥ kural − 2` ve bugün+3 değil;
  - kural > hedef (bugün+12 / bugün+5) → bugün+10.
- **yeniden_hedef kaynağı: KAPANDI.** 004:183-186 değeri `v_er := gorev_ertele(...)` dönüşündeki `hedef_tarih`'ten alıyor. Testin gücüyle ilgili not yukarıda KÜÇÜK olarak duruyor.
- **TR-D4EK-3 NOTICE: KAPANDI (MEASURED).** kabul2 çıktısında `PASS TR-D4EK-3` satırı 1 kez geçiyor.
- **Bayrak 0 cron assert'i: KAPANDI (MEASURED).** kabul.sql:1680-1690 doğruluyor: `kb_tren_kapat` + `ilk_tohumlama_zamanlayici()` → görev hedefi değişmiyor ve tamamlanıyor, vaka bugün açılıyor, ovsync_tren NULL, GOREV_ERTELE kaydı yok.

OZET sinyal=1
KALİTE: olcum-yok: 1 dosya — dil-desteksiz
KALİTE: boyut eklenen=13 ≤ butce=600 → gerekli (dar fix)

### Run kanıtı (tur 2)
1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-K9-N1: hastalık günlü hayvan trende değil
NOTICE:  PASS TR-ACL-D5: D5 ACL
NOTICE:  OZET: 290 PASS
```
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-d8b305f2.md
 İzole DB'ler drop edildi: egesut_val_3467331_32601de6 egesut_val_3467331_ca0a1430
```
2b) 004 (`… db-validate.sh …/20261110100004_ovsync_tren_baslatma.sql --priors …100001 …100002 …100003`, mutlak yollar)
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-1b160e37.md
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```
4) `~/tools-bank/scripts/ss-kalite-sinyal --repo ~/.herdr/worktrees/egesut-erp1/ovsync-tren --base 4dd94df --head 6a9e8db --butce 600`
rc: 0
```
SINYAL olcum-yok supabase/migrations/20261110100004_ovsync_tren_baslatma.sql dil-desteksiz
OZET sinyal=1 eklenen=13 butce=600
```

### Kırıntılar (tur 2)
- gate tur 2 KABUL: K2, ERKEN, TR-D4EK-2, yeniden_hedef, TR-D4EK-3 ve bayrak 0 cron bulgularının hepsi kapandı; 290 PASS.
- open_item KÜÇÜK: 22:00 yuvarlama testi tarih kaymasını assert etmiyor.
