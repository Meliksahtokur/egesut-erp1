⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D7 tren listesi + toptan erteleme⟧
sonuc: TAMAM

BOYUT: bütçe 400 · gerçek 361 · bütçe içinde (007 yeni dosya 345 satır + 006 dar fix +16 satır; test hariç)
commit: 9dc700c (`ovsync-tren L-DB D7: …`). 3 dosya, dosya dosya stage edildi; `git diff --cached --stat` = 3 dosya, +940/−5 (CONFIRMED).

## Gelen iş denetimi
Bloklayan bulgu yok. Okuduklarım: brief, ortak.md, progress.md (RL-1..RL-12, SORU-1..3 cevapları, R6-EK, SÖZLEŞME EKİ),
PLAN.md (Global Constraints, R1–R20, N1, D6, D7, Kapı tur 2), D6-report, D6-review-report (KÜÇÜK 006:439-445), UA1-report
sapmalar 1–7, `js/ovsync-tren.js` (toptan/liste tüketicileri), 002/003/004/005/006 gövdeleri (hedefli).
Plan notu: PLAN.md D7'de ayrı bir "Etki" maddesi yok. Etkiyi yeni RPC'lerin ve değişen `ovsync_bastan_baslat` dönüşünün tüketicileri üzerinden ölçtüm (aşağıda).

## Yapılan
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql` (yeni, 345 satır, yalnız yeni nesne → md5 koruması gerekmez)
  - `_ovsync_tren_uye_vaka(case, tolerans)` (iç): liste ve plan üye satırının tek tanımı. Alanlar:
    - `hayvan_id, kupe_no, case_id, gorev_id, asama, ovsync_tren`;
    - `sonraki_is{tarih, saat, tur}`: tur GNRH1/PG1/PG2/GNRH2; bütün günler bittiyse açık TAI;
    - `pg_pay`: aşama 1'de `tolerans − _ovsync_pg1_kayma`, ham değer (kırpma yok); diğer aşamalarda NULL;
    - `pg1_zaman`: gün#2'nin bütün seansları uygulandıysa en geç uygulanma anı; aksi NULL.
  - `ovsync_tren_listele()` STABLE SECDEF → `{ok, aktif, capa, bugun, trenler:[{tren_gunu, ritim_disi, uyeler}], bagimsizlar, ileri_sayisi}`.
    - Trenler üyelerden gruplanarak doğar (K3: üyesiz tren yok).
    - Açık OVSYNC_BASLAT görevi yalnız hedefi ≤ bugün+28 ise listede; ötesi `ileri_sayisi`'na gider (R16).
    - Ritim dışı trende üyeye `ritim_disi_neden` eklenir (`'PG +k gün'`; kayma 0 ise `'tren ritmi değişti'`). Ritimdeki üyede alan NULL.
    - Bayrak 0 → `{aktif:false}` ve boş listeler.
  - `_ovsync_tren_ertele_plan(p_tarih, p_n)` (iç, yazmaz), R7 kümesi:
    - üye sınıfları: (i) hedefi X olan açık görev, (ii) `ovsync_tren = X`, (iii) `ovsync_tren = X−7`;
    - karar: aşama 0 → KAYAR; aşama 1 → `N ≤ pg_pay` (yani kayma + N ≤ tolerans, R18) ise KAYAR, aksi BASTAN; aşama 2 → SECIM;
    - hata sırası: `OVSYNC_TREN_KAPALI`, `OVSYNC_TREN_N_GECERSIZ`, `GECMIS_TARIH`, `OVSYNC_TREN_GUNU_DEGIL`, `OVSYNC_TREN_BOS`;
    - ek alanlar: `ileri_gorevler` (R9; kuralı olmayan görev `kural_yok:true` ile işaretlenir), `tren_sayisi`, `dokunulmaz{bagimsiz, ritim_disi}`.
  - `ovsync_tren_ertele_onizle(p_tarih, p_n)` = `{ok} || plan`. Yazma yapmaz (TR-K7-ONIZLE md5 ile ölçüldü).
  - `ovsync_tren_ertele(p_tarih, p_n, p_secimler)` sırası:
    - `_ovsync_ic_ac` → advisory kilit → plan (eski ritimle kurulur);
    - `OVSYNC_TREN_SECIM_EKSIK{eksik:[case_id]}` kontrolü, yazmadan önce;
    - çapa `to_char(X+N,'YYYYMMDD')` olarak yazılır;
    - her üye ayrı bir `BEGIN … EXCEPTION` alt bloğunda, hayvan `FOR NO KEY UPDATE` ile kilitlenip aşama yeniden okunduktan sonra işlenir:
      - KAYAR görev → `gorev_ertele`;
      - KAYAR vaka → `vaka_kalan_gunleri_kaydir` (etiket bu fonksiyonun içinde artar, RL-1; burada ayrıca artırılmaz);
      - BASTAN → `ovsync_bastan_baslat`; PG48 → `ovsync_pg48_tohumla` (D6 RPC'leri; K6 a/b dışlaması RL-12 toptanda da geçerli);
    - ileri görevler R9 ile `gorev_ertele` üzerinden yeniden hedeflenir;
    - herhangi bir düşüş → `OVSYNC_TREN_ERTELE_DUSTU{tren, n, dusenler:[{hayvan_id, kupe_no, case_id, sebep, oneri?}]}`. Çapa dahil her şey geri alınır;
    - aşaması belirsiz üyenin düşüş satırına `oneri:'BASTAN_BASLAT_YA_DA_SEANS_ISARETLE'` eklenir (R6-EK);
    - başarıda `islem_log` `OVSYNC_TREN_ERTELE` (eski/yeni çapa snapshot'ı) yazılır; dönüş `{ok, tren, yeni_tren, islenen, ileri_gorevler}`.
  - ACL: üç RPC'de `REVOKE ALL … FROM PUBLIC, anon` ve `GRANT … TO authenticated, service_role`; iki iç yardımcı `authenticated` dahil kapalı.
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql` (D6 review KÜÇÜK, +16/−5)
  - `ovsync_bastan_baslat` başlamayan dalında (basladi=false) iptal ettiği PG TAI id'lerini `RETURNING` ile toplar.
  - Dönüşe `iptal_tai:[uuid]` eklenir. Başlayan dalda aynı alan start'ın `pg_gorev_iptal`'inden doldurulur, böylece alan iki dalda da var.
  - `islem_log` kayıtları değiştirilemez (`_islem_log_immutable_guard`, MEASURED). Bu yüzden PROTOKOL_IPTAL kaydı güncellenemedi; yeni bir satır yazılıyor: `OVSYNC_BASTAN_BEKLIYOR` (payload `{case_id, yeni_gorev_id, hedef_tarih, iptal_tai}`; start yolundaki `pg_gorev_iptal` kalıbı).
- `~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/tests/ovsync_tren_kabul.sql` (+579)
  - D7 yardımcıları ilk savepoint'ten önce eklendi: `kb_liste_uye`, `kb_plan_uye`, `kb_capa`, `kb_ozet` (md5), `kb_k7_fixture`.
  - Yeni "BÖLÜM D7": 16 senaryo bloğu.
  - TR-K6-B1 aşama 2 alt senaryosuna iki `iptal_tai` assert'i eklendi. Önceki bölümlerin içeriğine dokunulmadı.

## Test id → PASS (MEASURED, `~/tmp/ovsync-tren-db/d7/yesil.txt`; OZET 456 = önceki 366 + 90)
| id | kapsam | sonuç |
|---|---|---|
| TR-K3-1 | Hiçbir trende boş üye listesi yok. KB trenleri tam olarak {bugün−7, bugün, bugün+7}; boş ritim günü bugün+14 listede yok | PASS |
| TR-LISTE-1 | Üç tren (D0, D7, görev treni) ve bağımsız; `sonraki_is.tur` GNRH1/PG1/PG2/GNRH1; görev üyesinde gorev_id dolu, case_id NULL; her hayvan tek kez görünüyor | PASS |
| TR-LISTE-2 | Hedefi bugün+40 olan görev: `ileri_sayisi` +1 ve listede yok. Hedefi bugün+28 olan görev listede (sınır). Bayrak 0 → `aktif:false` | PASS |
| TR-K7-1 | Görevler X+1. D7 vakasının gün#1'i sabit, gün#2..4 +1, etiket X−7 → X−6 (tek sayım). Çapa X+1. Önizleme `yeni_tarih` = gerçek (3 üye). `islem_log` OVSYNC_TREN_ERTELE eski/yeni çapayla yazıldı. Listede görev X+1 treninde | PASS |
| TR-K7-2 | +3: aşama 1 vaka IPTAL; yeni görev hedefi X+3 ve önizleme ile aynı; görevler X+3; çapa X+3 | PASS |
| TR-K7-3 | Aşama 2 vaka önizlemede SECIM (yeni_tarih NULL). Seçimsiz ve geçersiz seçimle → `OVSYNC_TREN_SECIM_EKSIK{eksik:[case_id]}`. md5 özeti, çapa ve görev değişmedi | PASS |
| TR-K7-4 | PG48: vaka aktif, kalan seanslar uygulanmadı, PG TAI açık. BASTAN: vaka IPTAL, PG TAI kapandı, yeni görev X+1 | PASS |
| TR-K7-5 | `OVSYNC_TREN_ERTELE_DUSTU`, 2 düşen: aşama 1 vakası (TAI geçmişte → sebep GECMIS_TARIH, öneri yok) ve belirsiz vaka (sebep OVSYNC_ASAMA_BELIRSIZ, `oneri: BASTAN_BASLAT_YA_DA_SEANS_ISARETLE`). Sorunsuz görev listede değil. md5 özeti, çapa, görev, vaka günleri ve etiket önceki halinde. Önizlemede belirsiz üyenin sonucu NULL | PASS |
| TR-K7-6 | Bağımsız (K9) vaka kümede değil; günleri ve NULL etiketi değişmedi | PASS |
| TR-K7-7 | X+7 hedefli ileri görev önizlemede ve gerçekte X+8 oldu, GOREV_ERTELE soyu var | PASS |
| TR-K7-KISMI | +1: yapılan vaka aşama 1, KAYAR, yeni tarih PG1 bugün+8; yapılmayan aşama 0, KAYAR, bugün+1. +3: yapılan BASTAN (bugün+3), yapılmayan KAYAR (bugün+3) | PASS |
| TR-K7-HAFTA2 | Dört vakanın etiketi X+1. `onizle(X+8,1)` dördünü de içeriyor (ikisi aşama 1, etiket X+1). Liste dördünü tek bir X+1 başlığında, ritimde gösteriyor | PASS |
| TR-K7-TOL | (1) Ritim dışı aşama 1 vaka bugün+7 kümesinde yok. (2) Tek hayvan +1, ardından toptan +1 (çapa X+1) → `onizle(X+8,1)` BASTAN, pg_pay 0 | PASS |
| TR-K7-RITIM | Ritim dışı etiket (bugün+1) kendi başlığında, `ritim_disi:true` ve tek üyeyle | PASS |
| TR-K7-N1 | Önizleme ve ertelemede p_n=8 ve 0 → `OVSYNC_TREN_N_GECERSIZ` | PASS |
| TR-K7-N2 | Ritim dışı tarih → `OVSYNC_TREN_GUNU_DEGIL`; geçmiş tarih → `GECMIS_TARIH`; üyesiz tren → `OVSYNC_TREN_BOS`; bayrak 0 → `OVSYNC_TREN_KAPALI`; çapa değişmedi | PASS |
| TR-K7-ONIZLE | İki önizleme sonrası `kb_ozet` md5 aynı (gorev_log, treatment_days, seanslar, cases, protokol_ayar, islem_log sayısı) | PASS |
| TR-K9-N1 (D7) | K9 sonrası hayvan `bagimsizlar`'da ve yalnız bir kez görünüyor | PASS |
| TR-EK-LISTE | pg_pay: aşama 1 → 1; kayma −1 → 2; ritim dışı +1 → 0; ham −1 (kırpma yok). Aşama 0/2 → NULL. `pg1_zaman` aşama 2'de now() ±1 dk, aşama 0/1'de NULL. `ritim_disi_neden` 'PG +1 gün' / 'PG +2 gün'; ritimdeki üyede NULL | PASS |
| TR-EK-ONIZLE-2 | Üyede `ovsync_tren` (görev X, vaka X−7), `tren_sayisi` 2, `dokunulmaz` {bagimsiz:2, ritim_disi:1} (asimetrik). `pg_pay`/`pg1_zaman` alanları var; aşama 1'de pg_pay 1. Dokunulmazlar kümede değil | PASS |
| TR-ACL-4 | 3 RPC: anon kapalı, authenticated ve service_role açık, SECDEF. 2 iç yardımcı: anon ve authenticated kapalı. 5 imza, overload yok | PASS |
| TR-K6-B1 (D6 fix) | basladi=false: dönüşte `iptal_tai=[PG TAI]`, `islem_log` OVSYNC_BASTAN_BEKLIYOR payload'ında da aynı. basladi=true: `iptal_tai` = start'ın `pg_gorev_iptal`'i | PASS |

## Mutant denetimi (MEASURED, `~/tmp/ovsync-tren-db/d7/mutant.txt`, betik `~/tmp/ovsync-tren-db/d7gen/mutant.py`)
**23/24 öldü.** Kapsanan mutantlar:
- çapa yazılmıyor; etiket çift sayılıyor; tolerans `<`; (iii) sınıfı yok;
- DUSTU raise yok; öneri yok; seçim kontrolü yok; ileri görev yok; 28 gün filtresi yok;
- ritim_disi hep false; pg_pay ters; pg_pay kırpılıyor; dokunulmaz ters; pg1_zaman gün#1'den;
- BASTAN eski çapayla; ritim_disi_neden yanlış; tur kayık; tren_sayisi yanlış;
- RPC anon'a açık; N üst sınırı 8; bağımsızlar boş;
- D6 islem_log yok; D6 iptal_tai boş.

İlk turda 3 mutant yaşadı. İkisi için test sıkılaştırıldı:
- ham pg_pay −1 fixture'ı eklendi;
- dokunulmaz sayıları asimetrik yapıldı (2/1).

Hâlâ yaşayan 1 mutant: iç yardımcının `authenticated` REVOKE'u silinmiş hali. Kabul DB'sinde Supabase varsayılan yetkisi yok, bu yüzden ölçülemiyor (D4/D5/D6 ile aynı açık kalem, DM1).

## Etki
- Değişen tek mevcut nesne `ovsync_bastan_baslat`. İmzası aynı; dönüşe yalnız `iptal_tai` anahtarı eklendi, kırıcı değil.
- `ovsync_bastan_baslat` çağıranları:
  - DB tarafında: yalnız yeni `ovsync_tren_ertele` (grep, migration dizini).
  - JS tarafında: çağrı yok. atlas `rpc ovsync_bastan_baslat` → 0 fn (CONFIRMED). Bu dalın js/ farkı yalnız `js/ovsync-tren.js` (`git diff --stat b9542b1..HEAD -- js/`, OBSERVED); orada bu adlar yalnız JSDoc'ta geçiyor.
- Sözleşme tüketicisi UA1 `js/ovsync-tren.js`. Kabul DB'sinde gerçek RPC çıktısı üretilip modüle verildi (MEASURED, `~/tmp/ovsync-tren-db/d7/probe-js.txt`):
  - `ovsyncTrenBaslikHtml` "Tren · Pzt 2 Kas · 2 hayvan · bugün: PG günü" çizdi;
  - `ovsyncToptanOnizlemeHtml` "3 hayvan, 2 tren" çizdi; tren grupları `ovsync_tren` ile kuruldu (UA1 sapma 4 kapandı);
  - `ovsyncToptanOnayAcikMi` seçimsiz false, seçimli true döndü;
  - `ovsyncTrenHataMetni(OVSYNC_TREN_SECIM_EKSIK)` doğru metni verdi.
- Regresyon `ovsync_pg_kabul.sql` (D4 scratch kopyası, seri 002–007, D5/D6 tarifi): **OZET 482 PASS**, `BOLUM 1-bayrak0: 31 PASS`. İkisi de D8a tabanına eşit (MEASURED, `~/tmp/ovsync-tren-db/d7/pgk.txt`).

## Varsayımlar (plan boşlukları, gerekçeli; hiçbiri spec'i değiştirmiyor)
1. **Toptan BASTAN yeni_tarih** — *tur 2'de RL-15 ile DEĞİŞTİ (aşağıda `## D7 tur 2`).*
   - Tur 1 değeri `ovsync_bastan_baslat`'ın yeni çapayla verdiği hedefti (`_ovsync_tren_gunu(kural)`).
   - DÜZELTME (review MEASURED): bu yalnız X − bugün < 7 − N iken X+N verir; "X bugünse her zaman X+N" ifadesi YANLIŞTI —
     X=bugün, N=7 ve X=bugün+3, N=4'te hedef bugün çıkıyor ve D6 RPC aynı işlemde başlatıyordu (`basladi:true`).
   - Tur 2: hedef her zaman yeni tren X+N (kural daha geçse K2 ile kuraldan), `ovsync_bastan_baslat(..., p_hedef)` ile; başlatma yok.
2. **Belirsiz aşamalı üye önizlemede `sonuc: NULL`** (plan enum'unda yok).
   - UA1 bu satırı "bilinmeyen sonuç" diye gösteriyor ve onayı kapalı tutuyor.
   - Ertelemede üye düşer: `dusenler` satırına R6-EK önerisi eklenir.
   - Aşama 1 olup kayması hesaplanamayan üye de belirsiz sayılır (D6 ile aynı).
3. Alt blokta hayvan kilitlenir ve aşama yeniden okunur. Plan ile işlem arasında aşama değiştiyse üye belirsiz olarak düşer; sessizce yanlış dala gitmez.
4. **İleri görev yeniden hedeflemesi** de üyelerle aynı alt blok kalıbında. Düşerse `dusenler`'e `gorev_id` ile girer.
   - `ileri_gorevler` yalnız değişen görevleri listeler.
   - Kuralı olmayan görev `yeni:null, kural_yok:true` ile listelenir ve dokunulmaz.
5. **`dokunulmaz` tanımı:** X'te herhangi bir `treatment_days` satırı olan ama kümeye girmeyen aktif OVSYNC vakaları. Etiket NULL → bağımsız; etiket dolu → ritim dışı.
6. **`ritim_disi_neden` metinleri:**
   - vaka: kayma ≠ 0 → `'PG ±k gün'`, değilse `'tren ritmi değişti'`;
   - görev: `'gecikmiş başlangıç'` ya da `'başlangıç ritim dışı'`.
7. **Liste kapsamı:** 28 gün sınırı yalnız açık OVSYNC_BASLAT görevlerine uygulanır; aktif vakalar her zaman listelenir.
   - Geçmiş hedefli (gecikmiş) görevler kendi tarihli treninde görünür; ritim dışıysa öyle etiketlenir.
   - Listede üye satırına `ovsync_tren` da eklendi (salt ekleme; UA1 `tren_gunu||ovsync_tren` okuyor).
8. **Yeni `islem_log` tipleri:** `OVSYNC_TREN_ERTELE` (planın istediği) ve `OVSYNC_BASTAN_BEKLIYOR` (D6 fix; islem_log değiştirilemediği için ayrı satır). JS islem_log tipini adla çizmiyor (grep), bilinmeyen tip sorunu yok.
9. **db-validate statik Faz B** `IS DISTINCT FROM x.eski` ve `FROM jsonb_array_elements` desenlerini tablo referansı sanıyor (ilk koşum INCONCLUSIVE, `db-validation-58511ab9.md`). Çözüm: `IS DISTINCT FROM (x.eski)` ve `pg_catalog.jsonb_array_elements`; anlam aynı, ikinci koşum PASS.

## Kırıntılar
- measurement: OZET 456 PASS; db-validate 007 PASS (`ed7f7e8c`), 006 PASS (`99f58982`); mutant 23/24; pg_kabul seri 002–007 482/31 = taban; commit 9dc700c (ss-crumbs yazıldı).
- assumption: toptan BASTAN yeni_tarih = D6 RPC'nin yeni çapayla hedefi (çoğu durumda X+N) (ss-crumbs yazıldı).
- assumption: belirsiz üye önizlemede `sonuc` NULL, ertelemede düşer ve öneri alır (ss-crumbs yazıldı).
- open_item: Toptan erteleme sonrası bazı vakalar yeni çapada ritim dışı kalıyor: `ovsync_tren > X` olanlar (ileri D0'lı, V3 yolu) ve X−14 sınıfı (aşama 2 kuyruğu). R7 yalnız açık OVSYNC_BASLAT'ı yeniden hedefliyor (plan lafzı); bu vakalar listede "ritim dışı" başlığında görünür. INFERRED, kod okuması; UB3 ya da root kararı (ss-crumbs yazıldı).
- open_item (devralınan): Kabul DB'sinde Supabase varsayılan yetkisi yok. İç yardımcıların `authenticated` REVOKE'u ve anon varsayılanı ölçülemiyor → DM1 `has_function_privilege` (ss-crumbs yazıldı).
- open_item (D6'dan devralınan, kapandı): basladi=false dalında açık kalan PG TAI'nin izi artık dönüşte ve islem_log'da (TR-K6-B1).
- Kod keşfi: atlas `rpc ovsync_bastan_baslat` kullanıldı (0 fn). gitnexus kullanılmadı: worktree indeksli değil (UA1/D6 ile aynı). `analyze` koşulmadı (ortak.md: lead kulvar sonunda koşar).

## Run kanıtı
Kırmızı (testler önce yazıldı). İki ayrı koşum:
- (a) 006 HEAD gövdesiyle (`git show HEAD:…006…`), 007 yok. Ham çıktı `~/tmp/ovsync-tren-db/d7/kirmizi-006.txt`, rc: 3:
```
ERROR:  FAIL TR-K6-B1: beklenen basladi=false: iptal_tai = [PG TAI] dönüşte ve islem_log payload'ında gerçek {"ok": true, "basladi": false, "hedef_tarih": "2026-11-12", "yeni_case_id": null, "yeni_gorev_id": "93c3db05-5ec8-4061-ab92-316f074d645e", "kapanan_case_id": "06262f9b-39dd-4eac-9d4a-90969398903d"}
```
- (b) 006 düzeltilmiş, 007 yok. Ham çıktı `~/tmp/ovsync-tren-db/d7/kirmizi-007.txt`, rc: 3:
```
ERROR:  function public.ovsync_tren_listele() does not exist
İPUCU:  No function matches the given name and argument types. You might need to add explicit type casts.
SORGU:  v_l := public.ovsync_tren_listele()
BAĞLAM:  PL/pgSQL function inline_code_block line 15 at assignment
```

1)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-EK-ONIZLE-2: aşama 1 pg_pay
NOTICE:  PASS TR-ACL-4: D7 ACL
NOTICE:  OZET: 456 PASS
```

2)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
```
rc: 0
```
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-ed7f7e8c.md
 İzole DB'ler drop edildi: egesut_val_293491_ae3e6dee egesut_val_293491_f4a0c0cd
════════════════════════════════════════════════
```
(006 ek koşum, aynı betik, priors 001–005: rc: 0, `SONUÇ: PASS`, `db-validation-99f58982.md`.)

3)
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

## D7 tur 2
⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D7 tur 2 RL-14..17⟧
sonuc: TAMAM

Kapsam: D7-brief `## Devam` 5 maddesi + lead mesajı (TR-K7-ILK-GELECEK). Review: D7-review-report.md:15-19. Ruling'ler progress.md RL-14..RL-17.
Gelen iş denetimi: bulgu 1 — RL-15'in lafzi formülü `_ic(GREATEST(kural, X+1), X+N, öne_çekme, bugün)` öne çekme 2 iken N ≥ 6'da
X+N değil X'i verir (ör. X=bugün, N=7 → bugün); ruling'in kendi "(= X+N)" sonucuyla çelişir → Varsayım T2-1 (aşağıda), MEASURED mutant M2.

### Yapılanlar
1. **RL-14** (007): `_ovsync_tren_ertele_plan` → `ileri_vakalar:[{case_id, hayvan_id, kupe_no, eski, yeni}]` (`ovsync_tren > X`, aşama 0,
   aktif OVSYNC; eski/yeni = etiket, yeni = eski+N). `ovsync_tren_ertele` her birini hayvan kilidi + aşama 0 yeniden kontrolüyle
   `vaka_kalan_gunleri_kaydir(case, N)` ile kaydırır (etiket RL-1 ile orada artar); hata → `dusenler` (kısmi başarı yok). Dönüş ve
   islem_log payload'ında `ileri_vakalar`. Assert **TR-K7-ILERI**.
2. **RL-15** (006 + 007): `ovsync_bastan_baslat(p_case_id, p_bagimsiz, p_not, p_hedef date DEFAULT NULL)` — p_hedef verilirse yeni
   görev `gorev_ertele` ile o tren gününe yeniden hedeflenir; p_hedef kendi hedefinden erken / tren günü değil / bağımsızla birlikte →
   `OVSYNC_BASTAN_HEDEF_GECERSIZ:{case_id, hedef, en_erken, bagimsiz}`. Toptan BASTAN plan `yeni_tarih` = p_hedef = X+N; X+N > bugün →
   aynı işlemde başlatma yok. Mevcut çağrılar (3 argümanlı) değişmez (DEFAULT). TR-ACL-3 imzası `(uuid,boolean,text,date)`.
   **TR-K7-2** X=bugün,N=7 ve X=bugün+3,N=4 varyantları (önizleme X+N, islenen X+N + `basladi:false`, tek açık görev X+N, yeni vaka yok, çapa X+N).
3. **RL-16** (007): plan başında `[bugün, X)` aralığında üyeli ritim günü (açık OVSYNC_BASLAT hedefi, etiket, etiket+7) varsa
   `OVSYNC_TREN_GUNU_DEGIL:{tarih, sebep:'ONCEKI_TREN_VAR', ilk_tren}` (önizleme + erteleme). **TR-K7-N3** (iii/i/ii sınıfları,
   özet md5 değişmez, ilk tren pozitif kontrol) + lead isteği **TR-K7-ILK-GELECEK** (çapa bugün+2: X'e önizleme/ertele başarılı,
   X+7 → ONCEKI_TREN_VAR ilk_tren X).
4. **RL-17** (007): (iii) sınıfında (`ovsync_tren < X`, yani X−7) aşama 0 üye → `BASTAN` (RL-15 hedefi). **TR-K7-GECIKMIS**
   (+ p_hedef doğrulamasının 3 red dalı).
5. **KÜÇÜK**: `_ovsync_pg1_kayma` `_ovsync_tren_uye_vaka` içinde satır başına bir kez (iç `_kayma` anahtarı listele/plan/bağımsızlar
   dönüşünden çıkarılır); `ovsync_tren_ertele_onizle` KAPALI payload'ında `rpc:'ovsync_tren_ertele_onizle'` (TR-K7-N2 assert).

### RL-16 sonucu değişen mevcut assert'ler (anlam korunur; liste)
- TR-K7-TOL(2): `onizle(bugün+8)` → `onizle(bugün+1)` (vaka etiketi bugün+1 treninin (ii) üyesi; karar aynı: aşama 1, BASTAN, pg_pay 0).
- TR-K7-HAFTA2: `onizle(X+8)` artık ONCEKI_TREN_VAR (ilk_tren X+1) assert'i; dördün kümesi `onizle(X+1)` ile ölçülür.
- TR-EK-ONIZLE-2: fixture X=bugün+8 → X=bugün+1 (kb_geri ile etiket X−7 ve ritim dışı vaka); tüm beklenenler aynı (tren_sayisi 2, dokunulmaz {2,1}).
- TR-K7-N2: OVSYNC_TREN_BOS hiç üyeli tren yokken ölçülür (görev sonradan kurulur).

### Varsayım T2-1 (RL-15 formülü)
- Uygulanan: `_ovsync_tren_gunu_ic(GREATEST(kural, X + 1 + öne_çekme), X+N, öne_çekme, bugün)` → kural ≤ X+N+öne_çekme iken tam X+N;
  kural daha geçse K2 ile kuraldan (D6 tek-hayvan hedefiyle aynı ya da sonrası; p_hedef ≥ en_erken doğrulaması bunu garanti eder).
- Gerekçe: lafzi `GREATEST(kural, X+1)` öne çekmeyi X+1 tabanına da uygular → N ≥ 6'da X'e geri çekilir. MEASURED: mutant M2 (lafzi) →
  `FAIL TR-K7-2: … X=2026-11-09 N=7 … "yeni_tarih": "2026-11-09"`. Spec değişmez; ruling'in yazılı sonucu (X+N) uygulanır.
- Varsayım T2-2: RL-14 ileri vakalar ritim dışı etiketliler dahil (`ovsync_tren > X` lafzı); +N çapa ile aynı kaydığı için göreli konumları korunur.

### Etki (çağıranlar)
- `ovsync_bastan_baslat`: atlas `rpc ovsync_bastan_baslat` → 0 fn (OBSERVED; atlas main HEAD'e kurulu); `grep -rn` js/ index.html → 0.
  SQL çağıranları: 007 (yeni 4. argüman) ve kabul testleri (3 argümanlı, DEFAULT ile çalışıyor — 488 PASS).
- Toptan RPC dönüşleri yalnız EKLEME (`ileri_vakalar`); yeni hata sebebi `ONCEKI_TREN_VAR` mevcut kod `OVSYNC_TREN_GUNU_DEGIL` altında.
  js/ovsync-tren.js:318 yalnız önizleme dönüşünü belgeliyor → UI açık kalemi (ss-crumbs open_item; UB3 root notu).
- Regresyon `ovsync_pg_kabul.sql` (scratch `pgk-d4imza.sql`, seri 002–007): OZET 482 PASS, BOLUM 1-bayrak0 31 PASS (taban ile eşit; MEASURED).

### Kırmızı (test-önce, eski 006/007 ile; her yeni test ayrı izole koşum, `$HOME/tmp/ovsync-tren-db/red-*.sql`)
```
tam koşum: ERROR:  FAIL TR-K7-2: beklenen X=2026-11-09 N=7 önizleme: BASTAN → X+N gerçek {... "yeni_tarih": "2026-11-09", "ovsync_tren": "2026-11-02"}
v2: ERROR:  FAIL TR-K7-2: beklenen X=2026-11-12 N=4 önizleme: BASTAN → X+N gerçek {"asama": 1, "sonuc": "BASTAN", ...
gecikmis: ERROR:  FAIL TR-K7-GECIKMIS: beklenen önizleme: aşama 0 (iii) → BASTAN X+1 (geçmiş tarih yok) gerçek {"asama": 0, "sonuc": "KAYAR", ...
ileri: ERROR:  FAIL TR-K7-ILERI: beklenen önizleme ileri_vakalar: X+7 → X+9 (+N), kümede değil gerçek <yok>
n2: ERROR:  FAIL TR-K7-N2: beklenen önizleme KAPALI payload rpc ovsync_tren_ertele_onizle (KÜÇÜK) gerçek P0001|OVSYNC_TREN_KAPALI:{"rpc": "ovsync_tren_ertele", "tarih": "2026-11-09"}
n3: ERROR:  FAIL TR-K7-N3: beklenen ovsync_tren_ertele_onizle(2026-11-16) → ONCEKI_TREN_VAR, ilk_tren bugün gerçek <NULL>
ilk: ERROR:  FAIL TR-K7-ILK-GELECEK: beklenen ovsync_tren_ertele_onizle(X+7) → ONCEKI_TREN_VAR, ilk_tren X gerçek <NULL>
hafta2: ERROR:  FAIL TR-K7-HAFTA2: beklenen onizle(X+8,1) → ONCEKI_TREN_VAR, ilk_tren X+1 gerçek farklı
ek2: NOTICE:  PASS TR-EK-ONIZLE-2: önizleme sözleşme eki   (fixture yeniden kurgusu; eski kodda da geçer — beklenen)
```

### Mutantlar (hepsi öldü, MEASURED)
```
M2 RL-15 lafzi taban (p_tarih + 1): FAIL TR-K7-2: beklenen X=2026-11-09 N=7 önizleme: BASTAN → X+N ...
M3 RL-16 kapısında etiket+7 yok:    FAIL TR-K7-N3: beklenen ovsync_tren_ertele_onizle(2026-11-16) → ONCEKI_TREN_VAR ... gerçek <NULL>
M4 RL-17 yok (aşama 0 hep KAYAR):  FAIL TR-K7-GECIKMIS: ... gerçek {"asama": 0, "sonuc": "KAYAR", ...
M5 p_hedef verilmez:               FAIL TR-K7-2: beklenen X=2026-11-09 N=7 islenen: BASTAN X+N, basladi false gerçek {... "basladi": true, ...
```

### Yeni/değişen TR id → PASS satırı (tam koşum)
```
NOTICE:  PASS TR-K7-2 (RL-15): X=bugün N=7 → X+N
NOTICE:  PASS TR-K7-2 (RL-15): X=bugün+3 N=4 → X+N
NOTICE:  PASS TR-K7-GECIKMIS: (iii) aşama 0 → BASTAN
NOTICE:  PASS TR-K7-ILERI: ileri vakalar +N
NOTICE:  PASS TR-K7-N1/TR-K7-N2: doğrulama
NOTICE:  PASS TR-K7-N3: önceki tren kapısı
NOTICE:  PASS TR-K7-ILK-GELECEK: gelecekteki ilk tren
NOTICE:  PASS TR-K7-HAFTA2: ertesi hafta toptan dördünü görür
NOTICE:  PASS TR-K7-TOL(2): birikimli tolerans toptanda
NOTICE:  PASS TR-EK-ONIZLE-2: önizleme sözleşme eki
NOTICE:  PASS TR-ACL-3: D6 ACL
```

## Run kanıtı
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
```
rc: 0
```
NOTICE:  PASS TR-EK-ONIZLE-2: aşama 1 pg_pay
NOTICE:  PASS TR-ACL-4: D7 ACL
NOTICE:  OZET: 488 PASS
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-885f5013.md
 İzole DB'ler drop edildi: egesut_val_622089_bdf8c052 egesut_val_622089_3a2007ca
```
006 değişti → db-validate 006 (--priors 001..005):
```
bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
```
rc: 0
```
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-c9299608.md
 İzole DB'ler drop edildi: egesut_val_631166_d2ccc5a9 egesut_val_631166_fa11e26c
```
```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql
```
rc: 0
```
(çıktı yok)
```

BOYUT: bütçe 400 · gerçek 441 · tur 1 361 + tur 2 80 (007 +62/−21, 006 +18/−5; RL-14 döngüsü + RL-16 kapısı + p_hedef doğrulaması ruling kaynaklı yeni yüzey). 007 dosyası 386 satır.

## Kırıntılar (tur 2)
- assumption: RL-15 tabanı X+1+öne_çekme (lafzi formül N≥6'da X'e döner; mutant M2 MEASURED).
- decision: ovsync_bastan_baslat p_hedef (006), OVSYNC_BASTAN_HEDEF_GECERSIZ.
- open_item: UI — ONCEKI_TREN_VAR + ileri_vakalar (UB3 root notu).

Commit: a9e4ff5 (006 + 007 + kabul.sql; dosya dosya stage, `git diff --cached --stat` 3 dosya +270/−49)

