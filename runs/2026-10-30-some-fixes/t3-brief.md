# t3 — Doğum/küpe fix implementasyonu
job_id: j-20261030T182454Z-1378dc
## Plan maddesi
Goal: .harness/goals/2026/G-20261030-DOGUM-KUPE-FIX.md
Teşhis (oku, tekrar ölçme): runs/2026-10-30-some-fixes/t1-report.md
Önce: .harness/references/domain-rules.md §1, §5; skill code-change-precheck, db-validation, test-driven-development-obra.

1. Migration (tek dosya): `DROP INDEX IF EXISTS public.uq_hayvanlar_kupe_no;` + `dogum_kaydet` CREATE OR REPLACE — canlı gövdeden birebir (`~/tmp/t1diag/dogum_kaydet__9154.sql`, migration öncesi canlıdan yeniden çekip fark olmadığını doğrula), yalnız id üretimi `gen_random_uuid()::text`. Eski 14 parametreli `hayvan_ekle` overload'undaki COUNT+1'e DOKUNMA, raporda not et (ölü olup olmadığını canlıda kısaca ölç: pg_stat_user_functions varsa).
   ÖNCE (salt-okuma canlı SELECT) kanıtla: `uq_hayvanlar_kupe_no`'ya FK bağlı mı (pg_constraint.conindid), migration'larda/JS'te `ON CONFLICT (kupe_no)` veya PostgREST `on_conflict=kupe_no` var mı, kod `H` öneki/`H000` biçimine bağımlı mı (SQL+JS+tests). Herhangi biri çıkarsa DUR → SORU.
2. Ground truth `99999999999999_ground_truth.sql`: index satırını çıkar. `tests/sql/dogum_buzagi_id_test.sql:91` yorumunu düzelt.
3. Hata metni: `js/api.js:46` jenerik ezilmesini gider; küpe çakışması (`hayvanlar_kupe_no_key`) için kullanıcıya küpeyi anlatan metin. Birim test gerçek `rpc()` yolundan geçsin.
4. K1 etkisi: `kupe_no ===` / `.find` okuma yollarını (raporda 13 site; `js/ui.js:15301 openInsemSafe` dahil) atlas+Read ile tara. Aynı küpe biri Ölü biri Aktif iken ölü hayvana düşen her yolu `hayvanByKupeRef` (K7) ile düzelt; zaten yalnız aktif listeden okuyan ya da bilinçli tarihçe olanları dokunmadan bırak, tablo halinde raporla. Canlı SQL'deki `kupe_no` eşleşmeleri (`_kisir_ovsync_guard`, `_dogum_buzagi_backfill`, tarama yap) için de aynı sınıflama; sorun varsa aynı migration'a ekle, gövdeler canlıdan.
5. `?v=` damgası kuralı: memory/`project-egesut-teslim-mekanigi` (tek değer; damga testleri).

## Model
opus (high)
## Yazılabilir dosyalar
Goal "Write manifest" bölümü aynen. Liste dışına yazma. Rapor: runs/2026-10-30-some-fixes/t3-report.md
## Boyut bütçesi
migration ≈ dogum_kaydet gövdesi + 3 satır; JS ≤60 satır; test ≤120 satır. Aşarsan gerekçe.
## Run
scripts/db-validate.sh <migration yolu>
(tests/sql senaryosu: ölü küpe doğum geçer / aktif küpe red / DELETE sonrası doğum geçer — db-validate ortamında ya da yerel PG'de koşan komutu kendin belirle ve bu listeyi rapora ekle)
(birim süit komutu: package.json'dan; worktree NODE_PATH notu memory'de)
## Bağımlı
t1
## Review: T2
## Önceden cevaplanmış kararlar
- A+B aynı migration (root kararı). id = gen_random_uuid()::text (hayvan_ekle ile aynı).
- Prod'a YAZMA yok, push/merge yok; commit serbest (git add dosya dosya). Muse yok.
- Demo DB'ye Mgmt token yetkisi yok; db-validate yeterli, demo apply root'ta.
- Eski overload temizliği, `b-cins` onchange ve ui_logs telemetri bu işin dışı (yalnız rapora not).
- t2 paralel koşuyor (görev-protokol, salt-okuma); onun dosyalarına dokunma.
