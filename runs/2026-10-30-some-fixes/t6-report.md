⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Ölü yavru küpesini aynı anne dahil her yolda serbest bırak ve K1 yan etkilerini kapat⟧
sonuc: TAMAM
job_id: j-20261030T211433Z-188dcb
kabul SHA: e4e6de1 (SQL ve belgeler 54cbfe3, JS ve birim e4e6de1)
BOYUT: bütçe migration≈gövdeler+10 · JS≤15 · test≤60 · gerçek migration 203 (gövdeler 187 + başlık/çatı 16) · JS +13/−2 · test +83 (SQL 52, birim 31) | test bütçesi aşıldı: küpe düzenleme yolu brief'te koşullu maddeydi, ölçüm açtığını gösterdi ve T9 eklendi. Migration ek satırı geri alma ve neden açıklaması.

Gelen iş denetimi: 1 bulgu, işi durdurmadı. Brief 3. maddede `hayvan_guncelle` düzeltmesini tarif ediyor, ama aynı red blur kontrolünde de var. Düzeltme ortak fonksiyona yapıldı, bkz. madde 3.

## Yapılanlar

| Madde | Sonuç | Yer |
|---|---|---|
| 1 İkiz guard | Yalnız `dogum.buzagi_id` aktif yavruya bakıyor. Mesaj aynı. Gövdenin kalanı 20261030000001 ile birebir (`diff`: yalnız guard satırları) | `supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql` |
| 2 Eski doğum satırı | Yeni yardımcı `_dogumYavruAksiyon`: `buzagi_id` varsa onu açar, yoksa küpeyle açar | `js/ui.js` |
| 3 Kart düzenleme | Yol açık ve reddediyordu, düzeltildi | aynı migration, `kupe_musait_mi` |
| 4 Belgeler | Domain-rules §5 kuralı ve sahip tarihi; rpc-reference iki not | `.harness/references/domain-rules.md`, `.harness/references/rpc-reference.md` |
| 5 Testler | SQL T7-T9, birim 4 test, damga 26 referans `?v=20261031-01` | `tests/sql/dogum_kupe_recycle_test.sql`, `tests/unit/dogum-kupe-recycle.test.js`, `index.html` |

`tests/sql/dogum_kupe_recycle_prod_fixture.sql` değişmedi.

## Madde 1: guard'ın anlamı

- Aktif yavrunun küpesi aynıysa ilk kontrol zaten `Bu küpe zaten kayıtlı` der (T7c). OBSERVED
- Guard'ın kendi mesajı artık yalnız küpesi sonradan değiştirilmiş aktif yavruda çıkar (T8a). Prod'da böyle satır bugün 0. MEASURED
- `buzagi_id` boş satır engellemez, çünkü yavrusu bilinmiyor; aktif küpe yine ilk kontrole takılır (T8b). Prod'da 83 doğumdan 1'i böyle. MEASURED
- Prod'da 45 doğumun yavrusu çıkmış; bu numaralar artık aynı annede de açıldı. MEASURED

## Madde 3: formun yolu (ölçüm)

Yol açık (OBSERVED, kod okuması; tarayıcıda koşulmadı):
1. `js/ui.js:7235` "Bilgileri Düzenle" düğmesi `durum` koşulu taşımıyor; çıkmış hayvan kartında da var.
2. `js/ui.js openAnimalEdit` `a-kupe`'yi hayvanın küpesiyle dolduruyor.
3. `js/forms.js submitAnimal` `p_kupe_no` ve `p_kisir` yolluyor. `p_kisir` yalnız 18 parametreli sürümde var, istek ona gider.
4. Küpe başkasına verilmişse `İşletme küpesi zaten kayıtlı (aktif)` döner. Kırmızı koşumda T9b bunu verdi. MEASURED

Brief'in saymadığı ikinci red: `a-kupe` blur'u `_kupeKontrolEt` ile aynı `kupe_musait_mi`'yi çağırıyor. Alana tıklayıp çıkınca uyarı yazılıyor ve `submitAnimal` kaydı `Küpe çakışması var` ile baştan kesiyor. Yalnız `hayvan_guncelle` düzeltilseydi bu yol kırık kalırdı, `forms.js` de yazılabilir listede değil. Bu yüzden düzeltme `kupe_musait_mi` içinde: `p_hayvan_id`'nin kendi değişmeyen küpesi denetlenmiyor. `hayvan_guncelle` gövdesi değişmedi.

Yan etki: aktif bir hayvan kendi küpesiyle düzenlenirken "geçmişte kullanılmış" notu artık çıkmaz. Engel değildi, bilgi notuydu. INFERRED (bu dal test edilmedi)

Küpeyi başka aktif hayvanın küpesine çevirmek hâlâ red (T9c), başka hayvan adına sorgu hâlâ müsait değil (T9d).

## Madde 2: davranış notu

Üreme listesindeki satır inline `onclick` yerine `data-action` kullanıyor. Tıklama `js/utils/events.js` document düzeyi delegasyonundan `gm-det` / `gm-kupe` işleyicilerine gider (OBSERVED). `buzagi_id` yoksa `gm-kupe` → `openDetByKupe`, bugünkü davranışla aynı. Bu geçiş `yavru_kupe`'nin ham olarak `onclick`'e girmesini de bitirdi.

Birim testler üretilen özniteliği ölçüyor; tıklamanın kartı açtığı tarayıcıda koşulmadı.

## Dokunulmayanlar

| Konu | Durum | Etiket |
|---|---|---|
| 13 parametreli `hayvan_guncelle` | Filtresiz, ölü hayvan küpesini de reddeder. JS'in tek çağrısı 18 parametreli sürüme gidiyor (atlas: yalnız `submitAnimal`). Dış çağıran bilinmiyor | UNKNOWN |
| `dogum_kaydet` içinde `OR devlet_kupe = p_kupe` | K2 global teklik. Prod'da 1-3 haneli devlet küpesi olan çıkmış hayvan 0, bugün recycle'ı engellemiyor | MEASURED |
| Ground truth | Değişmedi, brief gereği | CONFIRMED |

Sahibe gidebilecek bir ayrıntı: aynı anne 10 gün içinde tekrar doğum kaydederse yeni kayıt aynı olaya bağlanır, ikiz sayılır. Ölü yavru küpesi serbest kaldığı için bu pencere değişmedi, sadece artık bu kayıt da girebilir.

## Ölçülemeyenler

- Prod'a yazılmadı. Salt-okuma sorgu sonucu: t3 canlıda, bu migration canlıda değil (`t6_canlida=false`). MEASURED
- Demo'ya uygulanmadı, UI yürüyüşü yapılmadı. CLAUDE.md UI testi kapısı root'ta.

## Run kanıtı

```
bash ~/egesut-erp1/scripts/db-validate.sh supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql
rc: 0
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-05f568e1.md
 İzole DB'ler drop edildi: egesut_val_tmp egesut_val_tmp
════════════════════════════════════════════════
NOTICE:  database "egesut_val_tmp" does not exist, skipping
```

Parite uyumlu (17.6/17.6). Squawk 2 WARNING: `lock_timeout`, `statement_timeout`. Rapor: `reports/db-validation-05f568e1.md`

SQL koşum sırası, izole `egesut_val_t6`, port 5433 (betik: `~/tmp/t6/sql_kos.sh`, DB iş sonunda silindi). Kırmızı, 20261031000001 öncesi:

```
bash scripts/db-build-baseline.sh --db-name egesut_val_t6 --db-url "$VAL_DB_URL" --json
psql "$URI" -X -q -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_prod_fixture.sql
psql "$URI" -X -q -v ON_ERROR_STOP=1 -f supabase/migrations/20261030000001_dogum_kupe_recycle.sql
psql "$URI" -X -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_test.sql
rc: 3
FAIL T7a ayni anne olu yavru kupesi gecer :: {"ok": false, "mesaj": "Bu küpe bu annenin yavrusu olarak zaten kayıtlı: __T6_Y1"}
FAIL T7b iki dogum satiri kendi buzagisina bagli :: {"ok": false, "mesaj": "Bu küpe bu annenin yavrusu olarak zaten kayıtlı: __T6_Y1"}
FAIL T7c ayni anne aktif yavru kupesi red :: {"ok": false, "mesaj": "Bu küpe bu annenin yavrusu olarak zaten kayıtlı: __T6_Y1"}
PASS T8a aktif yavru ikiz koruma mesaji degismedi
FAIL T8b buzagi_id bos eski satir engellemez :: {"ok": false, "mesaj": "Bu küpe bu annenin yavrusu olarak zaten kayıtlı: __T6_Y3"}
FAIL T9a kendi degismeyen kupesi musait ::
FAIL T9b cikmis hayvan karti duzenlenir :: {"ok": false, "error": "İşletme küpesi zaten kayıtlı (aktif): __T3_OLU_K"}
PASS T9c baska aktif kupeye gecis red
PASS T9d baska hayvanin aktif kupesi musait degil
ERROR:  RED: 6 test FAIL
```

Yeşil:

```
psql "$URI" -X -q -v ON_ERROR_STOP=1 -f supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql
rc: 0
psql "$URI" -X -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_test.sql
rc: 0
PASS T7a ayni anne olu yavru kupesi gecer
PASS T7b iki dogum satiri kendi buzagisina bagli
PASS T7c ayni anne aktif yavru kupesi red
PASS T8a aktif yavru ikiz koruma mesaji degismedi
PASS T8b buzagi_id bos eski satir engellemez
PASS T9a kendi degismeyen kupesi musait
PASS T9b cikmis hayvan karti duzenlenir
PASS T9c baska aktif kupeye gecis red
PASS T9d baska hayvanin aktif kupesi musait degil
NOTICE:  YESIL: 21 test PASS
```

Kırmızıda geçen T8a, T9c, T9d koruma kilitleri; mutantla ölçüldü (MEASURED, betik `~/tmp/t6/mutant.sh`, gerçek migration sonra geri uygulandı, 21 PASS):

| Mutant | Düşen test |
|---|---|
| Guard tamamen kapalı | T8a |
| `kupe_musait_mi` muafiyeti hayvan id'sine bakmadan | T9c, T9d |
| Guard aktif filtresiz (eski davranış) | T7a, T7b, T7c |

Birim, kırmızı (JS değişikliği öncesi):

```
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/dogum-kupe-recycle.test.js
rc: 1
ℹ pass 6
ℹ fail 3
✖ K1 Geçmiş kartı: buzagi_id varsa küpeyi değil doğan buzağıyı açar
✖ K1 Üreme doğum listesi: buzagi_id varsa küpeyi değil doğan buzağıyı açar
✖ K1 Üreme doğum listesi: buzagi_id yoksa bugünkü davranış (küpeyle açar)
```

Birim, yeşil (e4e6de1):

```
ram-ultracode exec --class test --sh 'NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/dogum-kupe-recycle.test.js'
rc: 0
✔ K7 btSerbestYukle: yapıştırılan küpe aktif hayvanı seçer (6.001832ms)
✔ K1 Üreme doğum listesi: buzagi_id varsa küpeyi değil doğan buzağıyı açar (5.234832ms)
✔ K1 Üreme doğum listesi: buzagi_id yoksa bugünkü davranış (küpeyle açar) (4.289736ms)
✔ K1 Geçmiş kartı: buzagi_id varsa küpeyi değil doğan buzağıyı açar (4.108078ms)
✔ K1 Geçmiş kartı: buzagi_id yoksa bugünkü davranış (küpeyle açar) (3.902675ms)
ℹ tests 9
ℹ pass 9
ℹ fail 0
```

Birim, tam süit (çalışma ağacı commit öncesi, içerik e4e6de1 ile aynı; `~/tmp/t6/birim-tam.txt`):

```
node --test tests/unit/*.test.js
rc: 1
ℹ tests 1607
ℹ pass 1601
ℹ fail 5
✖ LUNA-3: canlı DEMO information_schema ↔ harita
✖ EG-7: _erteleKaydet — rpc("gorev_ertele") çağrısı
✖ EG-8: _erteleKaydet — toplam 0 / uyari yok
✖ gelecek güne tık (bc-tarih takvim)
✖ ay ‹/› (bc-tarih takvim)
```

Kalan 5 FAIL, t3 raporundaki 5d3f6a3 tabanı listesiyle ad ad aynı. Bu işte tekrar taban koşumu yapmadım, t3 ölçümüne dayanıyorum. INFERRED

## Kırıntılar

- decision: düzeltme `hayvan_guncelle` yerine `kupe_musait_mi` içinde, blur yolu da aynı fonksiyondan red veriyordu (kayıtlı, workspace `some-fixes`).
- open_item: 20261031000001 prod'a uygulanmadı, UI kapısı root'ta, GT regen bakiyesi buna da uygulanır (kayıtlı).
- assumption: brief'te workspace adı yok, t1/t3 ile aynı `some-fixes` kullanıldı.
- assumption: `buzagi_id` boş eski satır engellemez; yavrusu bilinmiyor, sahip kararı "her yolda serbest".
- Kod keşfi: JS için atlas (`rpc`, `fn`, `etki`). SQL için canlı katalog, salt-okuma. Dize aramalarında grep. gitnexus sorgusu kullanılmadı; `analyze --index-only` koştu, indeks e4e6de1 ile güncel (ölçüldü).
