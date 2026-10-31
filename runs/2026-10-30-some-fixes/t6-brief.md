# t6 — Ölü yavru küpesi tam serbest + K1 yan etkileri
job_id: j-20261030T211433Z-188dcb
## Plan maddesi
SAHİP (2026-10-31, birebir): "sorun o değil ki ölen yavruların küpesini tekrar dolaşıma sokamıyoruz ikizlikle alakası ne anlamadım." Karar: ölü/çıkmış hayvanın küpesi HER yolda serbest; aynı anne dahil. Prod'a uygulama sen yapmıyorsun.
Bağlam: runs/2026-10-30-some-fixes/t3-report.md "Açık notlar" ve goal G-20261030-DOGUM-KUPE-FIX.
1. `dogum_kaydet` ikiz guard'ı (`supabase/migrations/20261030000001_dogum_kupe_recycle.sql:52` civarı): önceki doğumun yavrusu aktif değilse red etme. Yeni migration `supabase/migrations/20261031000001_*.sql`; gövde canlıdan (t5 paralel 20261030000001'i uyguluyor; kaynak olarak bu dosyanın gövdesi, uygulanmış olsun olmasın). Aktif küpe zaten önceki kontrolle reddediliyorsa guard'ı aktif filtreli yap; yazım hatası ikiz koruması aktif yavruda sürsün, mesajı değişmesin.
2. `js/ui.js:8726`, `:9032`: eski doğum satırı küpeyi değil `dogum.buzagi_id`'yi açsın; buzagi_id yoksa bugünkü davranış. (K1 "geçmiş kayıtlar bozulmaz".)
3. `hayvan_guncelle` 18 parametre: küpesi başkasına verilmiş çıkmış hayvanın kartını düzenleme yolu. Formun bu yolu açıp açmadığını kodla ölç. Açıyorsa ve küpe değişmediği halde red oluyorsa aynı migration'da küpe değişmediğinde kontrolü atla. Açmıyorsa dokunma, raporda söyle.
4. `.harness/references/domain-rules.md` §5 "Aynı (anne_id, yavru_kupe)…" satırı: yeni kural + "sahip 2026-10-31" (domain-rules ZORUNLU, aynı tur). `.harness/references/rpc-reference.md` gerekiyorsa.
5. SQL testi: aynı anne + ölü yavru küpesi geçer; aynı anne + aktif yavru küpesi red; `tests/sql/dogum_kupe_recycle_test.sql` genişlet. Red-before kanıtı. Birim: 2. madde için. `?v=` damgası tek değer yeni tarih.

## Model
opus (high)
## Yazılabilir dosyalar
supabase/migrations/20261031000001_*.sql (tek dosya)
js/ui.js
index.html (yalnız ?v=)
.harness/references/domain-rules.md
.harness/references/rpc-reference.md
tests/sql/dogum_kupe_recycle_test.sql
tests/sql/dogum_kupe_recycle_prod_fixture.sql
tests/unit/dogum-kupe-recycle.test.js
reports/db-validation-*.md (git add -f)
runs/2026-10-30-some-fixes/t6-report.md
## Boyut bütçesi
migration ≈ gövde(ler) + 10; JS ≤15 satır; test ≤60 satır.
## Run
bash ~/egesut-erp1/scripts/db-validate.sh <migration yolu>
(SQL testi: t3 report'taki izole DB sırası)
(birim: ram-ultracode exec --class test --sh 'NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/dogum-kupe-recycle.test.js')
## Bağımlı
t3
## Review: T1
## Önceden cevaplanmış kararlar
- Migration 20261030000001'i DEĞİŞTİRME; t5 onu uyguluyor. Ground truth'a DOKUNMA. Prod'a yazma, push, merge yok. Muse yok.
- Commit serbest, git add dosya dosya. Geçici dosya mutlak yol $HOME/tmp.
