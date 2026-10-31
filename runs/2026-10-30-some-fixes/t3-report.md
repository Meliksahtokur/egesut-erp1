⟦ss-sub model=opus effort=high rol=ss-worker-high iş=Doğum id çakışması, K1 index'i, hata metni ve K7 okuma yollarını düzelt⟧
sonuc: TAMAM
job_id: j-20261030T182454Z-1378dc
kabul SHA: 1006d57 (SQL 563ed82, JS 82c0926, test kilidi 1006d57; arada t4 commit'i 5d394d2 var)
BOYUT: bütçe migration≈gövde+3 · JS≤60 · test≤120 · gerçek migration 168 satır (gövde 149 + başlık 19) · JS +11/−12 · test 88 birim + 104 SQL + 79 fixture | SQL fixture üretilmiş prod kataloğu olduğu için test bütçesi aşıldı; aynadan index/trigger/default gelmiyor, fixture'sız recycle ölçülemez.

Gelen iş denetimi: 2 bulgu, ikisi de işi durdurmadı.
1. `scripts/db-validate.sh` worktree'de doğrudan koşmuyor: dosya modu 100644, `.env` worktree'de yok. Main checkout'taki birebir aynı betikten koşuldu (`diff -q` fark vermedi).
2. Baseline aynası constraint-free: index, trigger, default yok. Recycle yalnız prod kataloğu fixture'ı ile ölçülebildi.

## Yapılanlar

| Madde | Sonuç | Yer |
|---|---|---|
| A: id üretimi | `v_buzagi_id := gen_random_uuid()::text`, gövdenin kalanı canlıyla birebir (`diff`: yalnız satır 68 ve bitiş `;`) | `supabase/migrations/20261030000001_dogum_kupe_recycle.sql` |
| B: index | `DROP INDEX IF EXISTS public.uq_hayvanlar_kupe_no` | aynı migration |
| Ground truth | yalnız index satırı çıktı | `supabase/migrations/99999999999999_ground_truth.sql` |
| Test yorumu | `dogum_buzagi_id_test.sql:91` düzeltildi | `tests/sql/dogum_buzagi_id_test.sql` |
| Hata metni | `hayvanlar_kupe_no_key` için küpeyi anlatan metin; `_ERR_MAP`'in tüm metinleri noktayla bitiyor | `js/api.js` |
| Kilit testi | `migration-sira-kilidi` ground truth'u muaf tutuyor, **bkz. review notu** | `tests/unit/migration-sira-kilidi.test.js` |
| K7 | `openInsemSafe`, `btSerbestYukle` artık `hayvanByKupeRef` kullanıyor | `js/ui.js` |
| Damga | 26 referans `?v=20261030-01`, tek değer (ölçüldü) | `index.html` |

Hata metni düzeltmesini `:46` ile sınırlamadım. Aynı tablodaki 6 metin daha aynı nedenle jenerik metne eziliyordu, goal maddesi 3 de genel. `api.test.js` ve `ovsync-api.test.js` beklentileri buna göre güncellendi. Metni birebir karşılaştıran üretim kodu yok (grep).

## Review notu: kilit testini gevşettim

Brief'in istediği ground truth düzenlemesi `migration-sira-kilidi` testini kırdı (`eski migration Modify/Delete YOK`). Testi GT'den muaf tuttum: GT tarihçe değil canlı şema aynası ve runbook'la güncelleniyor, sonraki GT yenilemesi de aynı testi kırardı. Bir koruma testini değiştirdiğim için T2 özellikle baksın. Alternatif: GT satırını geri alıp apply sonrası regen'e bırakmak.

Mutant (MEASURED): taban öncesi `20260924000001` değiştirilince test FAIL verdi, dosya geri alındı. İlk denemem taban sonrası bir dosyadaydı ve kilidin kapsamı dışında kaldığı için PASS verdi, geçersiz sayıldı.

## Ön kanıtlar (migration öncesi, salt-okuma canlı)

| Soru | Sonuç | Etiket |
|---|---|---|
| Kayıtlı gövde canlıyla aynı mı | fark yok, canlıdan yeniden çekildi | MEASURED |
| Index'e FK bağlı mı | `pg_constraint.conindid` 0 satır, `pg_depend` boş | MEASURED |
| `ON CONFLICT (kupe_no)` / `on_conflict=kupe_no` | migration, JS, test, script: yok | OBSERVED |
| `H` önek bağımlılığı | JS/test/script: yok. Canlı SQL'de yalnız üreticiler var (`dogum_kaydet`, 14 parametreli `hayvan_ekle`, ilgisiz `hekim_ekle`). Prod'da zaten 143 uuid + 33 `H` id birlikte yaşıyor | MEASURED |
| Eski `hayvan_ekle` overload'u ölü mü | `track_functions=none`, `pg_stat_user_functions` boş. Ölçülemedi, dokunulmadı | UNKNOWN |

Durdurma koşullarının hiçbiri çıkmadı.

## K7 sınıflaması: JS

Eski kayıtlarda `hayvan_id` yerine küpe tutan satır: `tohumlama`, `gorev_log`, `dogum.anne_id`, `hayvanlar.anne_id`, `cases`, `vaccination_log`, `uygulama_log`, `kizginlik_log`, `islem_log` için canlıda **0** (MEASURED). Küpesi başka hayvanın id'sine eşit satır da 0. Bu yüzden `id===x || kupe_no===x` deseni FK ile çağrıldığında yalnız doğru hayvana düşer.

| Yer | Girdi | Karar |
|---|---|---|
| `js/ui.js openInsemSafe` | küpe | **Düzeltildi**: ölü hayvanın tohumlamasına bakıyordu |
| `js/ui.js btSerbestYukle` | yapıştırılan küpe | **Düzeltildi**: toplu tedaviye ölü hayvanı seçiyordu. Brief'in saydığı örnekler dışında bulundu |
| `js/ui.js:7625,7639 openDet` | id/küpe | Dokunulmadı: zaten aktif öncelikli |
| `js/ui.js:8182 hayvanByKupeRef` | küpe | K7'nin kendisi |
| `js/gecmis.js:160`, `js/ui.js:8959,8974,9149,9362` | FK, Geçmiş etiketi | Dokunulmadı: FK |
| `js/ui.js:7998,8030,8607,14616` | FK | Dokunulmadı: FK |
| `js/ui.js:5158-5159` | `gebeSet` sıralaması | Dokunulmadı: küme id taşıyor, küpe kolu boşa düşüyor |
| `js/config.js:172 bosKupeOner` | yalnız Aktif | Dokunulmadı |
| `js/ui.js:15131,15197` | `!==`, yalnız gösterim | Dokunulmadı |
| `js/ui.js:8726`, `:9032` | geçmiş doğum satırı `yavru_kupe` | Dokunulmadı, **bkz. açık not 1** |

## K7 sınıflaması: canlı SQL

Tüm public fonksiyon ve view gövdelerinde `kupe_no|yavru_kupe|buzagi_kupe` tarandı (MEASURED). Çoğu `id` üzerinden okuma. Küpe ile eşleşenler:

| Fonksiyon | Davranış | Karar |
|---|---|---|
| `_kisir_ovsync_guard` | `ORDER BY (durum='Aktif') DESC` | Sorun yok |
| `asistan_hayvan_detay` | `ORDER BY (durum='Aktif') DESC` | Sorun yok |
| `kupe_musait_mi` | aktif filtreli | Sorun yok |
| `_dogum_buzagi_backfill` | birden çok adayda `cok-aday` sayıp NULL bırakır | Sorun yok, ölüye yazmaz |
| `dogum_kaydet:25` | aktif filtreli | Sorun yok |
| `dogum_kaydet:36` ikiz guard | filtresiz | **bkz. açık not 2** |
| `hayvan_guncelle` (13 parametre) | filtresiz, daha sıkı | Dokunulmadı |
| `hayvan_guncelle` (18 parametre) | `kupe_musait_mi` | **bkz. açık not 3** |

View'larda `kupe_no` yalnız seçim listesinde, küpe üzerinden join yok (OBSERVED). `supabase/functions` küpeyi yalnız `asistan_hayvan_detay` ile çözüyor.

Migration'a SQL eki gerekmedi.

## Açık notlar

Hiçbiri doğumu engellemiyor. Üçü de K1 ilk kez işleyince görünür olacak.

1. **Eski doğum satırından yeni buzağıya gidiş.** `js/ui.js:8726` ve `:9032` geçmiş doğumdaki yavru küpesini `openDetByKupe` ile açıyor. Yeni 503 doğunca eski doğum satırındaki 503 tıklaması ölü buzağıyı değil yeni buzağıyı açar. K7 bunu kural olarak söylüyor, o yüzden değiştirmedim. `dogum.buzagi_id` dolu olduğundan küçük bir düzeltmeyle doğru buzağı açılabilir.
2. **İkiz guard'ı ile K1 çelişkisi.** Aynı anne, ölmüş yavrusunun küpesini yeni yavrusuna veremez, RPC `Bu küpe bu annenin yavrusu olarak zaten kayıtlı` der. Domain-rules §5 bu reddi açıkça istiyor, §1 K1 ise serbest bırakıyor. Davranışa dokunmadım, mesaj net, kullanıcı başka numara seçer. Prod'da 45 çıkmış buzağının doğum kaydı var, yani durum gerçekten yaşanabilir.
3. **Çıkmış hayvan kartı düzenleme.** 18 parametreli `hayvan_guncelle` küpe değişmese de `kupe_musait_mi` soruyor. Küpesi yeniden verilmiş ölü hayvanın kartı düzenlenirken formdan küpe gelirse `İşletme küpesi zaten kayıtlı (aktif)` ile reddedilir. Formun çıkmış hayvanda bu yolu açıp açmadığını koşmadım (INFERRED).
4. **Eski `hayvan_ekle` overload'u** hâlâ `COUNT+1` taşıyor. Brief gereği dokunulmadı. JS'in tek çağrısı 15 parametreli sürüme gidiyor.
5. **`ui_logs` ve `b-cins onchange`** kapsam dışı, t1 notu geçerli.

## Ölçülemeyenler

- Demo'ya uygulanmadı, UI yürüyüşü yapılmadı. CLAUDE.md UI testi kapısı root'ta.
- Prod'da gerçek doğum denenmedi.
- Baseline'da FK yok. Bu yüzden `tests/sql/dogum_buzagi_id_test.sql` T3a (FK SET NULL) migration öncesi ve sonrası aynı şekilde FAIL veriyor. Migration'dan kaynaklanmıyor; diğer testleri geçiyor.

## Run kanıtı

```
bash ~/egesut-erp1/scripts/db-validate.sh supabase/migrations/20261030000001_dogum_kupe_recycle.sql
rc: 0
════════════════════════════════════════════════
 SONUÇ: PASS
 Rapor: ~/egesut-erp1/scripts/../reports/db-validation-80e8956d.md
 İzole DB'ler drop edildi: egesut_val_tmp egesut_val_tmp
════════════════════════════════════════════════
```

Parite uyumlu (17.6/17.6). Squawk 3 WARNING: `DROP INDEX` için concurrently ve timeout önerileri. 176 satırlık tablo ve transaction içi çalışma nedeniyle kabul edildi. Rapor: `reports/db-validation-80e8956d.md`

SQL koşum sırası (izole `egesut_val_t3`, port 5433):

```
bash scripts/db-build-baseline.sh --db-name egesut_val_t3 --db-url "$VAL_DB_URL" --json
psql "$URI" -X -q -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_prod_fixture.sql
psql "$URI" -X -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_test.sql
rc: 3
FAIL T1 olu kupeyle dogum :: 23505 duplicate key value violates unique constraint "uq_hayvanlar_kupe_no"
PASS T2 aktif kupe red
FAIL T3 iki aktif ayni kupe DB red :: uq_hayvanlar_kupe_no
FAIL T4 geri aktife alma cakisma red :: yok
FAIL T5 DELETE sonrasi dogum gecer :: 23505 duplicate key value violates unique constraint "hayvanlar_pkey"
FAIL T6a uq_hayvanlar_kupe_no yok ::
PASS T6b hayvanlar_kupe_no_key var
ERROR:  RED: 5 test FAIL

psql "$URI" -X -q -v ON_ERROR_STOP=1 -f supabase/migrations/20261030000001_dogum_kupe_recycle.sql
rc: 0
psql "$URI" -X -v ON_ERROR_STOP=1 -f tests/sql/dogum_kupe_recycle_test.sql
rc: 0
PASS T1a olu kupeyle dogum gecer
PASS T1b ayni kupe iki satirda (olu+aktif)
PASS T1c yeni buzagi aktif ve kupeli
PASS T1d buzagi id uuid bicimli
PASS T1e dogum.buzagi_id ayni transaction baglandi
PASS T1f gorev sayisi 8 anne + 7 buzagi
PASS T2 aktif kupe red
PASS T3 iki aktif ayni kupe DB red
PASS T4 geri aktife alma cakisma red
PASS T5 DELETE sonrasi dogum gecer
PASS T6a uq_hayvanlar_kupe_no yok
PASS T6b hayvanlar_kupe_no_key var
NOTICE:  YESIL: 12 test PASS
```

Kırmızıda T1 kök neden B'yi, T5 kök neden A'yı prod'daki hata adıyla yeniden üretiyor.

Birim, kırmızı (5d3f6a3 JS kopyası, `redtree`):

```
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/dogum-kupe-recycle.test.js
rc: 1
ℹ pass 0
ℹ fail 5
rpc yolu → 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.'
openInsemSafe → actual [ 'h-olu' ], expected [ 'h-aktif' ]
btSerbestYukle → actual [ 'h-olu' ]
```

Birim, tam süit (82c0926 + kilit testi, `ram-ultracode exec --class test` içinden):

```
NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js
rc: 1
ℹ tests 1603
ℹ pass 1598
ℹ fail 5
✖ LUNA-3: canlı DEMO information_schema ↔ harita
✖ EG-7: _erteleKaydet — rpc("gorev_ertele") çağrısı
✖ EG-8: _erteleKaydet — toplam 0 / uyari yok
✖ gelecek güne tık (bc-tarih takvim)
✖ ay ‹/› (bc-tarih takvim)
```

Yeni testin 5'i de PASS. **Kalan 5 FAIL bu işten değil** (MEASURED): 5d3f6a3 ağacında aynı 5 test FAIL veriyor. O koşumda 2 FAIL daha vardı (`MUT-ALT-VAKA-KALINTI`, `migration-sira-kilidi`). Kopya ağaçta `.git` yok; ikincisinin hatası bu (`Could not access 'HEAD'`), birincisinin nedenine bakmadım. İkisi de çalışma ağacında geçiyor. LUNA-3 demo DB'ye bağlanamıyor (`tenant/user not found`).

## Güvenlik notu

LUNA-3 hata çıktısı demo DB bağlantı dizesini parolasıyla stdout'a basıyor. `git grep` parolayı izlenen dosyalarda bulmadı, yani commit'te yok. Çıktı scratchpad'de kaldı. Değeri buraya yazmadım.

## Kırıntılar

- assumption: brief'te workspace adı yok, t1 ile aynı `some-fixes` kullanıldı.
- Ortam: `egesut_val_t3` önce yanlışlıkla ayna kümesinde (yerel PG 18) kuruldu, aynı turda silindi. Aynaya başka dokunulmadı. Doğrulama motorundakini iş sonunda sildim.
- Kod keşfi: JS için atlas (taze, 5d3f6a3) ve `etki`. SQL için canlı katalog. Dize aramalarında grep. gitnexus sorgusu kullanılmadı; `analyze --index-only` 82c0926 için tamamlandı; 1006d57 için iki deneme de bitmedi (zaman aşımı, kuyruk). İndeks bir test commit'i geride.
