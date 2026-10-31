# t5 — Prod apply: iki migration + veri onarımı
job_id: j-20261030T211433Z-ca0079
## Plan maddesi
SAHİP ONAYI (2026-10-31, birebir seçim): "İkisi + veri onarımı". Kapsam yalnız aşağıdaki üç dosya, HEAD f2bb6dd. Sahip doğum kaydı girmeyi bekliyor; hızlı ama adımsız değil.
Sıra (runbook .harness/runbooks/db-migration.md, oku):
1. Yedek: `hayvanlar`, `dogum`, `gorev_log` satırları + `dogum_kaydet`, `gebelik_protokol_kontrol`, `hizli_uygulama` gövdeleri + `uq_hayvanlar_kupe_no` tanımı → repo dışı `$HOME/yedek/prod-yedek-2026-10-31-dogum-kupe/` + manifest sha256. Rollback notu rapora.
2. Dry run: `scripts/db-dry-run.sh` (worktree'de .env yok; t3/t4 raporlarındaki main checkout yöntemi). 42703/42P01/42710 sıfır.
3. Apply, bu sırayla: `supabase/migrations/20261030000001_dogum_kupe_recycle.sql`, `supabase/migrations/20261030100001_protokol_etken_senkron.sql`. Her dosyanın kendi BEGIN/COMMIT'i var mı bak; varsa sarmalama. schema_migrations INSERT her sürüm için, geri oku. Her adımda çıktıyı oku; hata → DUR, sonrakine geçme.
4. Doğrula: `uq_hayvanlar_kupe_no` yok, `hayvanlar_kupe_no_key` var; `dogum_kaydet` gövdesinde COUNT(*)+1 yok; `gebelik_protokol_kontrol` üç etken_kod; `hizli_uygulama` p_occurred_at. md5 ile migration gövdesi eşit.
5. Onarım: `runs/2026-10-30-some-fixes/t4-veri-onarim.sql` postgres rolüyle (salt-okunur rol hata verir, Mgmt API yalnız son SELECT döner; t4 report madde 5: psql varsa `psql -X -v ON_ERROR_STOP=1 -f`; bağlantı .env'de yoksa dosyayı Mgmt API'ye tek istek gönderip önce/sonra SELECT'lerini ayrı oku). Kapsam: etkensiz 9 görevde etken_kod, 906 Rota kapanır, 191 iki görev açılır. ÖNCE sayısının kuru koşudaki 9'a uymaması tek başına alarm değil (review bulgu 6: canlıda ileri gebe eksiği 906×3+207×3=6). Görev satır sayıları beklenenden farklıysa DUR.
6. Sonuç ölçümü: `protokol_eksik_tara` 906/207 satırları; 14 satırdan kalanlar tablo.
7. Doğum akışını prod'da GERÇEK kayıtla DENEME; yalnız SELECT ile ön koşul: sonraki id çakışmaz (uuid), 503/507 için index engeli yok.
Apply'dan sonra `scripts/veri-eslesme-kontrol.py hepsi`. GT regen (adım 6) BU İŞTE YOK: bakiye olarak yaz, sonraki migration sonrası tek seferde koşulacak.

## Model
opus (high)
## Yazılabilir dosyalar
runs/2026-10-30-some-fixes/t5-report.md
$HOME/yedek/prod-yedek-2026-10-31-dogum-kupe/ (repo dışı)
## Boyut bütçesi
Kod değişikliği yok.
## Run
(yukarıdaki komutları birebir rapora ekle)
## Bağımlı
t3, t4
## Review: T1
## Önceden cevaplanmış kararlar
- Prod yazma yetkisi yalnız bu üç dosya için. Başka yazma, push, merge YOK. Muse yok.
- t6 paralel çalışıyor (kod); onun dosyalarına dokunma. Token yazdırma. Geçici dosya mutlak yol $HOME/tmp.
- Kırıntı `gate` + yedek yolu zorunlu.
