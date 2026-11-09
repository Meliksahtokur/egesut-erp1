⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D2: tren çekirdeği (ayar tohumları, cases.ovsync_tren, tren günü/aşama/kayma/K10 iç yardımcıları) + kabul bölümü⟧
sonuc: TAMAM

## Gelen iş denetimi
- Bulgu 1 (MEASURED): Brief kabulü "PLAN.md D2 'Etki' maddesindeki çağıranlar" diyor, ama PLAN.md D2 bölümünde (satır 236-266) Etki maddesi yok. D2 yalnız yeni nesne ekliyor: mevcut fonksiyon gövdesi değişmiyor, imza değişmiyor. Etki kanıtını bunun yerine tek dokunulan mevcut nesne olan `cases` tablosu (yeni kolon) üzerinden verdim (aşağıda).
- Bulgu 2 (MEASURED): D1 report'unun Bulgu 1'i doğru çıktı. Plan `ON CONFLICT` diyor, ama db-validate baseline'ında protokol_ayar PK'si yok. D1 emsaline uyup tohumları `INSERT … SELECT … WHERE NOT EXISTS` ile yazdım.
- Diğer: bulgu yok. PLAN.md (Global Constraints, R1–R20, N1, D2, Kapı tur 2), ortak.md, progress.md RL-1..RL-9 ve D1 report/review okundu. domain-rules §5/§18 ile çelişki yok. build.sh koşulmadı (RL-9).

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql` (yeni dosya)
  - Ayar tohumları (insert-eksikse):
    - `ovsync_tren_aktif` 0 bool 0..1
    - `ovsync_tren_capa` 20261112, birimi YYYYMMDD, aralık 20260101..20991231
    - `ovsync_tren_one_cekme_gun` 2, aralık 0..2
    - `ovsync_pg_erteleme_tolerans_gun` 1, aralık 0..2
  - `ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS ovsync_tren date` + COMMENT (R3).
  - 12 iç yardımcı, imza/ad/hata kodları plandaki gibi:
    - `_ovsync_tren_aktif()`: `_ovsync_pg_aktif()` açık **ve** ayar = 1.
    - `_ovsync_tren_ayar()`: döner `{capa, one_cekme, tolerans}`. Eksik ya da geçersiz ayarda `OVSYNC_TREN_AYAR:{anahtar, deger, sebep}` atar; sebep kodları `EKSIK`, `TAMSAYI_DEGIL`, `ARALIK_DISI`, `TARIH_GECERSIZ`. `to_date` çağrısı `BEGIN…EXCEPTION WHEN others` içinde ve sonucu gidiş-dönüş karşılaştırmasıyla da denetleniyor (R1).
    - `_ovsync_tren_gunu_ic(date,date,int,date)`: IMMUTABLE STRICT, plandaki formül.
    - `_ovsync_tren_gunu(date)`: bayrak kapalıyken `GREATEST(kural, bugün_TR)` döner ve ayarı hiç okumaz.
    - `_ovsync_tren_gunu_mu(date)`
    - `_ovsync_asama(uuid)` (R6): her günü Y/N/X olarak sınıflar; desen 0 = NNNN, 1 = YNNN, 2 = YY__; gün sayısı ≠ 4 ya da başka bir desen NULL; aktif OVSYNC vakası değilse NULL.
    - `_ovsync_pg1_kayma(uuid)` (R18): PG1 günü − (gün#1 seanslarının en geç `uygulama_tamamlandi_at` anının TR günü + 7). Aşama 1/2 dışında NULL.
    - `_ovsync_ic_ac()`, `_ovsync_ic_mi()`
    - `_ovsync_gorev_mu(uuid)` (R5 a/b/c): bayraktan bağımsız. `aciklama` yalnız `~ '^\s*\{'` iken jsonb'ye çevriliyor ve bu çevirme `EXCEPTION WHEN data_exception` içinde; bozuk JSON → false.
    - `_ovsync_kilit_gorev(uuid)`, `_ovsync_kilit_vaka(uuid)`: `OVSYNC_TREN_EKRANI:{gorev_id|case_id, hayvan_id, tren_gunu}`.
  - ACL: 12 yardımcının hepsinde `REVOKE ALL … FROM PUBLIC, anon, authenticated`.
  - Dosyada `CURRENT_DATE` yok; TR günü `(now() AT TIME ZONE 'Europe/Istanbul')::date` ile alınıyor.
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql`
  - D2 ek yardımcıları ilk savepoint'ten önce:
    - `kb_tren_ac(p_capa)`: aktif=1 + çapa; Ovsync-PG bayrağını da 1 yapar.
    - `kb_tren_kapat()`
    - `kb_ovsync_vaka(p_hayvan, p_d0)`: `create_case` + `tedavi_sablon_uygula(p_baslangic_tarihi)`.
    - `kb_seans_yap(p_case, p_gun_sira, p_uygulanmadi DEFAULT false)`
    - Ek olarak `kb_hata(sql)` (döner: SQLSTATE|mesaj).
  - Yeni bölüm "K1/K2/AYAR/AŞAMA/ACL". F0 bölümü değişmedi.
  - TR-IZOL-1'e fixture sızıntısı ölçümü eklendi (D1 KÜÇÜK-1): (a)'da `kb_hayvan()` kuruluyor ve var olduğu doğrulanıyor; (b)'de `count(*) FROM hayvanlar WHERE id LIKE 'KB-%'` = 0.

## Test id → PASS (MEASURED, ~/tmp/ovsync-tren-db/d2-yesil.txt)
Her id en az bir `kb_ok` ile koşuyor. Toplam OZET **108 PASS**: D1'in 24'ü (IZOL'e +2 eklendi) + D2'nin 82'si.
| id | kapsam |
|---|---|
| TR-K1-1 | 4 plan değeri (11-12 / 11-19 / 11-19 / 11-19) + NULL kural → NULL |
| TR-K2-N1 | 11-15 ≠ 11-12; öne çekme 1 iken 11-14 → 11-19 |
| TR-K1-2 | 10 rastgele kural: ritimde, ≥bugün, ≥kural−2, ilk uygun tren; açık trende `_ovsync_tren_gunu_mu` çapa±7k true, diğerleri ve NULL false |
| TR-TZ-1 | `_ic` yalnız p_bugun'a bağlı; açık trende `_ovsync_tren_gunu(k)` = `_ic(k,…,kb_bugun())` |
| TR-REG-1 | bayrak 0: +5 → +5, −3 → bugün; çapa günü tren değil; çapa satırı silinmişken hata yok; pg bayrağı 0 iken tren kapalı |
| TR-AYAR-N1 | sağlam ayar objesi; çapa satırı silinince `_tren_gunu` ve `_tren_gunu_mu` → `OVSYNC_TREN_AYAR {anahtar ovsync_tren_capa, sebep EKSIK}` |
| TR-AYAR-N2 | 20261131 → `OVSYNC_TREN_AYAR` TARIH_GECERSIZ (22008 değil); 20261301 → hata; 20261100 (to_date sessizce 11-01 döner) → gidiş-dönüş karşılaştırması yakalar |
| TR-AYAR-N4 | 20261112.5 → hata; tolerans −1 → hata; öne çekme 3 → hata |
| TR-KAYMA-1 | 0 / −1 / PG1 +1 → 1 / aşama 0 → NULL / aşama 2 → 0 / belirsiz → NULL / GnRH1 TR 01:00 (UTC'de dün) ve oturum TimeZone=UTC → 0 |
| TR-ASAMA-0/1/2 | 0 / 1 / 2 |
| TR-ASAMA-N | gün#1 uygulanmadı → NULL; gün#2 var gün#1 yok → NULL; kapalı vaka (önce 0 doğrulandı) → NULL; açık günde uygulanmadı seans → NULL; Mastit vakası / olmayan id → NULL |
| TR-K10-GUC | false → `_ovsync_ic_ac()` → true; sonraki senaryoda false |
| TR-KILIT-0 (ek) | R5 tablosu: OVSYNC_BASLAT, Ovsync TAI, Ovsync TEDAVI_SEANS/GUN → true; Ovsync dışı TAI, ILAC, Mastit TEDAVI_GUN, bozuk/düz aciklama, olmayan id → false. Kilit: bayrak 0 → sessiz; açık → `OVSYNC_TREN_EKRANI` payload; ILAC/Mastit muaf; iç bayrakla aşılır |
| TR-ACL-1 | 12 yardımcı × anon/authenticated EXECUTE false; 4 tohum değer/birim/min/max; `cases.ovsync_tren date NULL` |
| TR-IZOL-1 | (mevcut) + KB- fixture sızıntısı 0 |

Mutant denetimi (MEASURED): 25 mutant, **25/25 öldü**. Betik `~/tmp/ovsync-tren-db/mutant.py`, çıktı `~/tmp/ovsync-tren-db/d2-mutant-son.txt`.
- İlk turda 5 mutant sağ kaldı; testler güçlendirilince öldüler:
  - gidiş-dönüş karşılaştırması kaldırıldı
  - aşama N'de uygulanmadı göz ardı edildi
  - aşamanın aktif filtresi kaldırıldı
  - kaymada aşama filtresi kaldırıldı
  - kapalı dalda `gunu_mu`
- Sonradan eklenen 2 mutant da öldü: kaymada TR yerine UTC günü, kayma yalnız aşama 1.
- Mutant listesinin geri kalanı: mod7 negatif, öne çekme yok, STRICT yok, kapalı dal yok, pg bağımlılığı yok, EXCEPTION yok, trunc yok, aralık yok, Y seanssız, sıra, kaymada planlı gün, ic_mi sabit, güvenli parse yok, (b) koşulsuz, kilitte iç yok, kilit vakada aile yok, ACL eksik, tohum 3.

## Etki (değişen mevcut nesne yalnız `cases`, yeni kolon)
- Yeni fonksiyon adlarının hiçbiri önceden yok (MEASURED: pg_proc'ta `_ovsync%` = 5 eski ad, çakışma yok). Hiçbir mevcut gövde ya da imza değişmedi, md5 koruması da gerekmedi (CONFIRMED: dosyada `CREATE OR REPLACE` yalnız 12 yeni ad).
- `cases%ROWTYPE` kullanan iki fonksiyon var: `protokol_iptal`, `vaka_kalan_gunleri_kaydir` (MEASURED: pg_proc taraması). Kolon eklendikten sonra ikisi de gerçek OVSYNC vakada çalıştı (MEASURED: `~/tmp/ovsync-tren-db/etki.sql`):
  - kaydır → `{"ok": true, "tasinan_gun_satiri": 4, …}`
  - iptal → `{"ok": true, "kapanan_seans": 4, …}`
  - kolon NULL kaldı.
- `cases` view'ları (`treatment_timeline`, `v_stat_*`) kolon listesini oluşturuldukları anda dondurur; eklenen kolon onları kırmaz (INFERRED).
- JS: atlas `tablo cases`, 38 kullanım. Yalnız select/okuma/tazeleme var, `cases`'e insert/update yazan JS yok. Pull ile gelen fazladan alan IndexedDB'de zararsız kalır (OBSERVED atlas; INFERRED zararsızlık).

## Run kanıtı

Kırmızı (D2 migration'ı yok, test-önce). Komut: `( echo 'BEGIN;'; cat …001… supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql …`
rc: 3 (MEASURED, `~/tmp/ovsync-tren-db/d2-kirmizi.txt`; F0 + IZOL PASS, ardından:)
```
ERROR:  function public._ovsync_tren_gunu_ic(unknown, unknown, integer, unknown) does not exist
SATIR 1: v := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12',...
SORGU:  v := public._ovsync_tren_gunu_ic('2026-11-14', '2026-11-12', 2, '2026-11-09')
BAĞLAM:  PL/pgSQL function inline_code_block line 4 at assignment
```

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-KILIT-0: Ovsync görevi tanımı ve kilit yardımcıları
NOTICE:  PASS TR-ACL-1: iç yardımcılar kapalı, tohumlar ve kolon sözleşmede
NOTICE:  OZET: 108 PASS
```

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-c86a2fd0.md
 İzole DB'ler drop edildi: egesut_val_2071048_4542f015 egesut_val_2071048_ecf56494
════════════════════════════════════════════════
```
- Ara durum (MEASURED): ilk iki koşum rc=2 INCONCLUSIVE döndü. Neden yalnız `B.sema-uyum`: statik çözücü önce `unnest(ARRAY…) k(anahtar)`, sonra `CROSS JOIN LATERAL` desenini çözemedi. Raporlar: `~/egesut-erp1/reports/db-validation-7ad62c26.md`, `~/egesut-erp1/reports/db-validation-4c0d8c36.md`; o koşumlarda C1 ve C2 PASS'ti.
- `_ovsync_tren_ayar`'ı FOREACH ile, `_ovsync_asama`'yı GROUP BY + LEFT JOIN ile yeniden yazdım; davranış aynı (108 PASS, 25/25 mutant) ve db-validate PASS verdi.

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## Kabul
- `OZET: 108 PASS`; listelenen her TR-* id'si ≥1 kb_ok ile koşuyor. MEASURED
- db-validate exit 0 PASS (RL-8 biçimi). MEASURED
- CURRENT_DATE grep'i boş. MEASURED (test dosyasında yalnız iki yorum satırında geçiyor)
- Etki: kırılma yok (yukarıda). MEASURED + INFERRED
- Commit `0426ce2` "ovsync-tren L-DB D2: tren çekirdeği (…)". Dosyalar dosya dosya `git add` edildi; `git diff --cached --stat` = yalnız 2 dosya (710 ekleme, 1 silme). Push yok. MEASURED

BOYUT: bütçe 220 · gerçek 257 · dosyanın tamamı 257 satır; boş ve yorum satırı hariç 216. Aşan kısım başlık/ROLLBACK yorumu, R-referanslı açıklama yorumları, 4 tohumun açıklama metni ve 12 REVOKE satırı; kopya gövde yok.

## Varsayımlar
- Varsayım (seanssız gün): seansı olmayan gün Y ya da N sayılmaz, X olur. Böyle bir gün aşamayı NULL yapar. Şablonun her gününde seans var.
- Varsayım (geçmiş tarihli günler, D6/D7'ye not): `add_treatment_day_with_sessions` geçmiş tarihli günü `tamamlandi=true` ama seansları açık bırakarak kuruyor. Bu R6'ya göre X sayılır. Yani geçmiş başlangıçla açılıp seansları işaretlenmemiş Ovsync vakası belirsiz (NULL) çıkar ve D6 `OVSYNC_ASAMA_BELIRSIZ` görür. R6 metnine birebir uydum; spec'i değiştirmedim.
- Varsayım (`_ovsync_tren_gunu` kapalı dalı): plan metniyle birebir `GREATEST(p_kural, bugün)`. Bu yüzden NULL kural → bugün; bugünkü `_ovsync_baslat_gorev_kur:81` ile aynı. Açık dal `_ic` STRICT olduğundan NULL döner.
- Varsayım (`_ovsync_pg1_kayma`): R18 "GnRH1 yapılmamışsa NULL" diyor. Ben ek olarak aşama belirsiz (NULL) ve aktif OVSYNC olmayan vaka için de NULL döndürüyorum (aşama ∈ {1,2} filtresi).
- Varsayım (`_ovsync_tren_ayar` aralığı): öne çekme ve tolerans için 0..2 sabit kontrol; tohumun min/max değeriyle aynı. Satır min/max'ı okunmuyor. Tren ayarı protokol_ayar_guncelle ile genişletilirse bu kontrol güncellenmeli (D8 notu).
- Varsayım (kilit payload'ı `tren_gunu`): OVSYNC_BASLAT için görevin `hedef_tarih`'i; diğer Ovsync görevleri ve vaka için aktif OVSYNC vakanın `ovsync_tren`'i (NULL olabilir).
- Varsayım (`kb_tren_ac`): tren `_ovsync_pg_aktif()`'e bağlı olduğu için Ovsync-PG bayrağını da 1 yapar.
- Varsayım (`kb_seans_yap`): TR-ASAMA-N için `p_uygulanmadi boolean DEFAULT false` parametresi eklendi; plan imzasıyla uyumlu.
- Varsayım (TR-KILIT-0): plan listesi dışında ek test id'si. Brief'in istediği `_ovsync_gorev_mu` güvenli parse'ını ve kilit yardımcılarını ölçüyor; D5'in TR-K10-* testlerinin yerine geçmez.

## Kırıntılar
- measurement (767f9c96cc02): OZET 108 PASS, 25/25 mutant öldü, db-validate PASS c86a2fd0, commit 0426ce2.
- assumption (5ddf415442aa): seanssız gün ve geçmiş tarihli gün → aşama NULL; D6/D7 bunu bilmeli.
- assumption (9237db09fe53): `_tren_gunu` kapalı dalda GREATEST; kayma filtresi; 0..2 aralığı; kilit `tren_gunu` kaynağı.
- gate env-mismatch (56d0c85ca55f): db-validate B statik çözücüsü LATERAL ve `unnest … k(alias)` desenlerinde INCONCLUSIVE veriyor. D3–D8 yazarları bu iki desenden kaçınmalı (ya da lead B'nin kabul politikasını belirlemeli).
- open_item: D6/D7'nin `_ovsync_asama` tüketicileri, geçmiş başlangıçlı vakada X (belirsiz) sonucunu hesaba katmalı. Gerekirse R6 yorumu için root'a ruling sorusu.
- Not: gitnexus analyze koşulmadı (ortak.md: kulvar sonunda lead koşar). Atlas `tablo cases` sorgusu HEAD ağacında yapıldı; JS bu dalda değişmedi.

## D2-EK
sonuc: TAMAM · commit `9aba75e` "ovsync-tren L-DB D2-EK: R6-EK aşama tanımı (root SORU-3)". İki dosya dosya dosya stage edildi; `git diff --cached --stat` = yalnız 2 dosya. Push yok. (MEASURED)

Root SORU-3 / R6-EK ve RL-10 (progress.md) uygulandı, aynı migration dosyasında; yeni migration açılmadı.

### Değişen mantık

**`_ovsync_asama` gün sınıfları:**
| Sınıf | Koşul |
|---|---|
| Y (yapıldı) | gün `tamamlandi` ve seanslar ya hepsi uygulanmış ya da hiçbiri uygulanmamış ve hiçbirinde uygulanmadı işareti yok (geriye tarihli kayıt) |
| N (yapılmadı) | hiç seans uygulanmamış ve (gün tamamlanmamış ya da uygulanmadı işaretli seans var) |
| X (belirsiz) | diğer her durum: kısmi seans, seansı uygulanmış ama kapanmamış gün, seanssız gün |

Desen kuralları değişmedi: NNNN → 0, YNNN → 1, YY__ → 2; başka bir desen ya da gün sayısı ≠ 4 → NULL.

**`_ovsync_pg1_kayma` çapası:**
- Seansı işaretli gün: GnRH1 seanslarının en geç işaret anının TR günü.
- Seansı işaretsiz gün: `treatment_date`.
- `LEAST` yok.

### Testler
- Yeni senaryolar:
  - TR-R6EK-1: D0 = bugün−3 → aşama 1, kayma 0. D0 = bugün−8 → aşama 2, kayma 0. Fixture'ın geçmiş günü `tamamlandi` ve seansı işaretsiz olduğu da ayrıca doğrulanıyor.
  - TR-R6EK-2: D0 = bugün−2, seans bugün işaretli → kayma −2.
  - TR-R6EK-3: GnRH1 uygulanmadı → 0 ve kayma NULL. PG1 uygulanmadı → 1. Açık çok seanslı günde yalnız uygulanmadı → 0.
- Güncellenen senaryolar:
  - TR-ASAMA-N fixture'ı kısmi seansa taşındı: `kb_seans_ekle` ile gün#1'e ikinci seans eklenip yalnız biri uygulanıyor → beklenen yine NULL.
  - TR-ASAMA-N'ye yeni NULL vakaları: gün sayısı 3, seansları uygulanmış ama gün kapanmamış, seanssız tamamlanmış gün.
  - TR-KAYMA-1'in belirsiz fixture'ı da kısmi PG1 gününe taşındı.
- Kırmızı (MEASURED): eski D2 gövdesi (`git show 0426ce2:…002`) + yeni testler → rc 3, `FAIL TR-R6EK-1: beklenen D0 = bugün−3: aşama 1, kayma 0 (çapa = D0) gerçek` (`~/tmp/ovsync-tren-db/d2ek-kirmizi.txt`).
- Mutant denetimi (MEASURED, `~/tmp/ovsync-tren-db/d2ek-mutant.txt`, seri 001..003): 30 mutantın 29'u öldü. Yeni 6 mutantın hepsi öldü:
  - işaretsiz Y yok
  - Y'de uygulanmadı koşulu yok
  - N'de uygulanmadı yok
  - kısmi gün N sayılıyor
  - çapada COALESCE yok
  - çapa LEAST
- Sağ kalan tek mutant `asama-Y-seanssiz` eşdeğer mutant: seanssız günde LEFT JOIN `s.n` değerini NULL yapıyor, bu yüzden `s.n > 0` koşulu kaldırılsa da gün X kalıyor. Davranış farkı yok (INFERRED, gövde okuması; "seanssız → NULL" assert'i iki gövdede de PASS).
- D3 testleri bozulmadı (TR-ETKI-D3 / TR-ACL-D3 PASS).

### Run kanıtı
1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-ETKI-D3: eski arg sayılı çağıranlar çalışır
NOTICE:  PASS TR-ACL-D3: yeni imza ACL
NOTICE:  OZET: 176 PASS
```
2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-3814ba03.md
```
3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-b96432c2.md
```
4)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

BOYUT: bütçe 220 · gerçek 257 → 261 · D2-EK net +4 satır (yorum + Y/N koşulları; 11 eklendi, 7 değişti); aşım gerekçesi D2 bölümünde.

Varsayım: seanssız gün (seans satırı yok) yine belirsiz sayılıyor. R6-EK'teki "seanslarının hiçbiri tamamlanmamış" koşulunu boş küme için doğru saymadım. Uygulanmadı işaretli ve hiç uygulanan seansı olmayan gün, gün kapanmış olsun olmasın yapılmadı sayılıyor.

### Kırıntılar (D2-EK)
- measurement: 9aba75e, OZET 176, 30 mutantın 29'u öldü (1 eşdeğer), db-validate 002/003 PASS.
- assumption: seanssız gün = X; uygulanmadı + hiç uygulanan yok = N.
- Not: PLAN.md'ye R6-EK'nin işlenmesi root'un DONE notunda (progress.md); bu tur zarf dışı.
