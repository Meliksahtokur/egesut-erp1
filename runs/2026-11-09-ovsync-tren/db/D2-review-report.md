⟦ss-sub model=opus effort=high rol=ss-reviewer-kapi iş=D2 T2 review⟧
sonuc: TAMAM

```
VERDICT: KABUL
OKUDUM: kat1 yok (brief nokta-paket taşımıyor; root kapsamı `git diff 4e46386 0426ce2 -- supabase/ runs/.../db/` olarak verdi, ağaç taraması yapılmadı) · DONE (D2-report.md) 151 · lead review yok (T2 tek kapı) · kat2 migration 257/257 satır tam + kabul betiği seçili bölümler (kb_hata 134-140, TR-K1-2 345-362, TR-AYAR-N2 436-453, TR-ASAMA-N 566-589, TR-ACL-1 son blok) + PLAN.md 29-53/169-204/236-267/645-650 + R1-R20 tablosu + design.md §5/§7 · araç 17
ÖLÇTÜM: kabul koşumu → rc 0, `NOTICE:  OZET: 108 PASS` (DONE ile aynı) · db-validate --priors 001 → rc 0 `SONUÇ: PASS` (db-validation-c86a2fd0.md) · CURRENT_DATE grep → rc 0 boş · ss-kalite-sinyal → OZET sinyal=1 (olcum-yok) · sonda (BEGIN/ROLLBACK) → dün başlayan vaka aşama NULL; çapa 1e25/negatif → OVSYNC_TREN_AYAR (P0001)
İŞARETLİ:
- docs/plans/2026-11-09-ovsync-tren/PLAN.md:97 (R6) + :109 (R18) — plan boşluğu / open_item — ÖNEMLİ (D2'yi bloklamaz) — geçmiş D0'lı Ovsync vakasında gün#1 `tamamlandi=t` + seans açık olduğu için aşama NULL; GnRH1 seansı sonradan işaretlenince kayma, işaretleme anından hesaplanıyor (gerçek −0 yerine −1, sahte +1 gün pay); D6/D7 başlamadan root ruling gerekir.
- supabase/tests/ovsync_tren_kabul.sql:350 — test determinizmi — KÜÇÜK — TR-K1-2 `random()` kullanıyor; olası FAIL yeniden üretilemez, `generate_series(-30,59,9)` gibi sabit bir küme daha sade.
- supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql:56 — doğrulama tutarlılığı — KÜÇÜK — öne çekme ve tolerans için 0..2 aralığı okuyucuda sabit, çapa için 20260101..20991231 aralığı denetlenmiyor (19000101 kabul ediliyor); R1 bunu istemediği için kusur değil, D8 yazma yolu min/max'ı uygulamalı.
- supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql:139 — belgelenmemiş yorum — KÜÇÜK — aşama 2 = `YY__` (gün 3-4 X olsa da 2). spec §5 "PG1 tamam → 2" ile uyumlu, R12 iptal sonrası (YYXX) için de doğru; ama R6 "uygulanmadı işaretli → NULL" lafzından sapıyor ve Varsayımlar'da yok.
BLOKLAYAN: 0 · ERTELENEBİLİR: 4
NOKTA NOTU: kabul betiğinin D2 dışı bölümlerini (F0, IZOL) ve 25 mutant çıktısını yeniden koşmadım; mutant iddiası DONE beyanı (UNKNOWN).
```

ŞABLON-VERDICT: PASS

## Bulgular (şablon biçimi)
[ÖNEMLİ] PLAN.md:97,109 (R6/R18): geçmiş tarihli başlangıç. Kanıt (MEASURED, sonda): `kb_ovsync_vaka(h, kb_bugun()-1)` → gün1 `tamamlandi=t seans=1 uygulandi=0`, `_ovsync_asama`=NULL, `_ovsync_pg1_kayma`=NULL; ardından `kb_seans_yap(c,1)` → aşama 1, kayma −1. GnRH1 gerçekte 11-08'de yapıldı, PG1 11-15'te, yani gerçek kayma 0. Sonuç: (1) bayrak açıldığında, geçmiş D0 ile açılmış eski Ovsync vakaları (spec §8 "mevcut 4'lü grup ilk tren") seansları işaretlenene kadar belirsiz kalır. spec §7 + "kısmi başarı yok" kuralı yüzünden, böyle tek bir üye o trenin toptan ertelemesini bütünüyle düşürür (INFERRED, D7 henüz yok). (2) Geç işaretleme, K5 toleransına sahte pay ekler. D2 R6/R18'e lafzen uyuyor (CONFIRMED, mig:113-158), bu yüzden kusur D2'de değil, planda. Dar fix (root ruling, D6/D7 öncesi): ya R6'da "geçmiş tarihli gün (`tamamlanma_tarihi = treatment_date::timestamptz` ve seans açık) = Y, R18 çapası `treatment_date`" kuralı yazılır, ya da göç/D8 adımına "aktif Ovsync vakalarında belirsiz aşama sayımı + sahibe liste" eklenir.
[KÜÇÜK] tests/ovsync_tren_kabul.sql:350: `random()`. Dar fix: deterministik küme.
[KÜÇÜK] mig:56: çapa min/max okuyucuda yok. Dar fix: D8 `ovsync_tren_ayar_guncelle` aralığı uygulasın (D8 brief'ine not).
[KÜÇÜK] mig:139: `YY__` yorumu. Dar fix: report Varsayımlar'a bir satır yeter, kod değişmez.

## Odak maddeleri (şablon 1-7 + brief D2 özel)
1. Gövde türetme: mevcut gövde değişmiyor. Dosyada 12 `CREATE OR REPLACE` var, hepsi yeni ad; tek DDL `cases.ovsync_tren` (CONFIRMED mig:29,34-243). md5 koruması gerekmiyor.
2. md5: uygulanmaz (yeni nesneler).
3. ACL: 12 yardımcının hepsinde `REVOKE ALL … FROM PUBLIC, anon, authenticated` var (CONFIRMED mig:246-257). TR-ACL-1, 12 imza üzerinde `has_function_privilege` ile ölçüyor ve döngüyü `v_n = 12` ile sayıyor; sahte kol yok. İleride çağıracak `gorev_ertele`, `tohumlama_gorev_ertele` ve `vaka_kalan_gunleri_kaydir` SECURITY DEFINER, yani authenticated REVOKE'u bunları kırmaz (CONFIRMED: 20260925100004, 20260923000003, 20260925100001).
4. Bayrak 0: `_ovsync_tren_gunu` kapalı dalda ayar okumadan `GREATEST(kural, bugün_TR)` döndürüyor; `_tren_gunu_mu` false, kilitler RETURN (CONFIRMED mig:91-92,103,211,233). TR-REG-1 PASS.
5. TR tarihi ve hata kodları: CURRENT_DATE yok (MEASURED). `OVSYNC_TREN_AYAR:{anahtar,deger,sebep}` ve `OVSYNC_TREN_EKRANI:{gorev_id|case_id,hayvan_id,tren_gunu}` planla aynı. R1: `to_date` `BEGIN…EXCEPTION WHEN others` içinde, üstüne gidiş-dönüş karşılaştırması var (mig:57-62). 20261131 → TARIH_GECERSIZ (TR-AYAR-N2 assert `NOT LIKE '22008%'` + sebep jsonb'si). Sonda: 1e25 ve −20261112 da P0001 OVSYNC_TREN_AYAR veriyor (MEASURED).
6. `_ic` formülü plan :245 ile birebir; STRICT olduğu için NULL girdi NULL döner; öne çekme ≤2 `_tren_ayar` aralığıyla korunuyor. TR-K1-1 plan değerlerini elle doğruladım: 11-14 → 11-12, 11-15 → 11-19 (INFERRED hesap + PASS). Aşama R6: Y/N/X sınıflaması, 4 gün şartı, `(treatment_date, day_no)` sırası, aktif OVSYNC filtresi. Kayma R18: en geç `uygulama_tamamlandi_at` alınıp `AT TIME ZONE 'Europe/Istanbul'` ile TR gününe çevriliyor; TR-KAYMA-1, UTC oturumunda TR 01:00 durumunu ölçüyor. R5 (a)/(b)/(c) bayraktan bağımsız. Bozuk JSON iki katmanla korunuyor: regex `^\s*\{` ve `EXCEPTION WHEN data_exception` (22P02 json/uuid sınıf 22). `day_id` biçimi gerçek görev üreticisiyle aynı (CONFIRMED ground_truth add_treatment_day_with_sessions `jsonb_build_object('day_id', …)`).
7. Kapsam: diff yalnız 2 yazılabilir dosya + report (MEASURED `git diff --stat`: 257 + 454/−1).

Worker varsayımları:
- Seanssız gün → X: kabul (R6'daki "başka her durum").
- Geçmiş tarihli gün → NULL: R6 lafzına uyuyor ve spec §7 "belirsiz → reddet, baştan başlat öner" ile çelişmiyor. Ancak etkisi D2 kapsamını aşıyor (yukarıdaki ÖNEMLİ). Worker'ın bunu açıkça işaretlemesi doğru.
- Kapalı dalda NULL kural → bugün: plan metni ve `_ovsync_baslat_gorev_kur` ile aynı; açık dalda NULL dönüyor, R9 "kural yok → dokunma" ile uyumlu. Kabul.
- Kayma: belirsiz ya da aktif olmayan vakada NULL — R18'in güvenli genişlemesi, kabul.
- 0..2 sabit aralık: kabul (KÜÇÜK not, D8).
- Kilitte `tren_gunu` kaynağı: kabul; payload yalnız bilgi.
- `kb_tren_ac`'ın PG bayrağını açması: kabul (`_tren_aktif` tanımı gereği).
- `kb_seans_yap` ek parametresi (default'lu): kabul.
- TR-KILIT-0 ek id: kabul.
- Boyut 257/220 (boş ve yorum hariç 216): gerekçeli, kopya gövde yok. Kabul.

OZET sinyal=1
KALİTE: olcum-yok: 1 dosya — dil-desteksiz
KALİTE (göz): 12 fonksiyon tek sorumlu ve kısa; tekrar yalnız 12 REVOKE satırında, planın şart koştuğu biçim. DÜZELT gerektiren kalite bulgusu yok.

## Run kanıtı
1) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3`
rc: 0
```
NOTICE:  PASS TR-KILIT-0: Ovsync görevi tanımı ve kilit yardımcıları
NOTICE:  PASS TR-ACL-1: iç yardımcılar kapalı, tohumlar ve kolon sözleşmede
NOTICE:  OZET: 108 PASS
```
2) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql`
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-c86a2fd0.md
 İzole DB'ler drop edildi: egesut_val_2113596_f5f3fc1e egesut_val_2113596_18f0da01
```
3) `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql`
rc: 0
```
(çıktı yok)
```
4) Sonda (aynı seri + `$TMPDIR/d2rev/probe.sql`, BEGIN/ROLLBACK, kalıcı yazma yok)
```
NOTICE:  PROBE1 gun=1 tarih=2026-11-08 tamamlandi=t seans=1 uygulandi=0
NOTICE:  PROBE1 dun-baslayan asama=<NULL> kayma=<NULL>
NOTICE:  PROBE1b gun#1 seans sonradan isaretlendi -> asama=1 kayma=-1
NOTICE:  PROBE2 capa 1e25 -> P0001|OVSYNC_TREN_AYAR:{… "sebep": "TARIH_GECERSIZ" …}
NOTICE:  PROBE2 capa negatif -> P0001|OVSYNC_TREN_AYAR:{… "sebep": "TARIH_GECERSIZ" …}
NOTICE:  PROBE2 capa 19000101 (min alti) -> <NULL> / {"capa": "1900-01-01", …}
NOTICE:  PROBE2/3 dis hata: 23505 duplicate key value violates unique constraint "protokol_ayar_pkey"
```
(Kabul DB'sinde protokol_ayar PK'si var, bu yüzden çift satır riski yok. PROBE4 benim sonda hatam, D2 ile ilgisiz.)

SORU: R6/R18 için geçmiş D0'lı vakada aşama ve kayma nasıl tanımlanacak? (seçenek A: geçmiş tarihli gün = Y ve kayma çapası = treatment_date; B: lafız aynen kalır, D8 göçü belirsiz vakaları sahibe listeler). D6/D7 brief'inden önce root karar vermeli.

## Kırıntılar
- decision: KALİTE: D2 KABUL; 12 iç yardımcı plan imzalarıyla birebir, sinyal yalnız olcum-yok (dil-desteksiz).
- open_item: geçmiş D0'lı Ovsync vakası → aşama NULL; geç işaretleme kaymaya sahte pay ekliyor (R6/R18 plan boşluğu, D6/D7 öncesi ruling).
- measurement: kabul 108 PASS rc0; db-validate PASS c86a2fd0; CURRENT_DATE 0.
