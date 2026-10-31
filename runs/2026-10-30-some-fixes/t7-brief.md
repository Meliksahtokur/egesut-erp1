# t7 — Demo apply + UI kapısı
job_id: j-20261031T035001Z-a78954
## Plan maddesi
Proje CLAUDE.md "UI testi kapısı". Demo açık (ACTIVE_HEALTHY), şema son `20261017100001`. Demo token: `~/egesut-erp1/.env` `SUPABASE_DEMO_REF`, `SUPABASE_DEMO_PAT` (Mgmt API `/database/query`, curl; token yazdırma). PROD'A YAZMA YOK.
1. Demoya sırayla uygula, schema_migrations kaydı ile: `supabase/migrations/20261030000001_dogum_kupe_recycle.sql`, `20261030100001_protokol_etken_senkron.sql`, `20261031000001_olu_yavru_kupe_serbest.sql`. Dosyaların kendi BEGIN/COMMIT'i var, sarmalama.
2. `python3 scripts/veri-eslesme-kontrol.py hepsi` (t5'in ölçemediği `sizinti`). Prod apply sonrası ilk tam koşum; BULGU varsa önceki kombinasyon kümesiyle karşılaştır.
3. Worktree kodunu (HEAD) yerelde `?demo` ile aç (`EGESUT_DEMO`, memory: l4-sahip-yuruyusu-tarif, ui-akis-yuruyusu-zorunlu; worktree NODE_PATH notu). Demo verisine test kaydı yazmak serbest; demo sahip şifresine DOKUNMA, değerini dosyaya yazma. Playwright ile GERÇEK tıklama, her madde ayrı PASS/FAIL + kanıt (ekran görüntüsü + DOM + konsol):
   T1 Erkek doğum, boş küpe (5xx): kayıt düşer, buzağı listede.
   T2 Dişi doğum, boş küpe: kayıt düşer.
   T3 Doğum, ÖLÜ hayvanın küpesi (demo'da bul, başka anne): kayıt düşer, aktif hayvan yeni buzağı.
   T4 Doğum, ölü yavrunun küpesi AYNI anneye: kayıt düşer.
   T5 Doğum, AKTİF hayvan küpesi: red; mesaj "Bir hata oluştu" DEĞİL, küpeyi anlatır.
   T6 T3'teki küpeyi arama: aktif hayvan açılır; tohumlama detayı ve toplu tedavi yapıştırma ölü hayvanı seçmez.
   T7 Eski doğum satırındaki yavru tıklaması: o doğumun buzağısı açılır, yeni küpe sahibi değil.
   T8 Küpesi yeniden verilmiş ölü hayvan kartı: düzenle, kaydet, red yok.
   T9 Görev → uyarı: `ILERI_GEBE` görevi tamamla → Protokol Uyarıları'ndan düşer.
   T10 Uyarı → görev: 💉 Uygula → eşleşen görev Görevler'den düşer. (T9/T10 için hayvan/görev yoksa `gebelik_protokol_kontrol` butonu ile üret; görev etken_kod dolu olsun.)
   T11 Küpe 💡 önerisi erkekte 5xx listesi, konsol hatasız.
4. FAIL: düzeltme yazma; kanıtı raporla.
Rapor başında tablo; ayrıca sahibe verilecek link + liste.
## Model
sonnet (medium)
## Yazılabilir dosyalar
runs/2026-10-30-some-fixes/t7-report.md
runs/2026-10-30-some-fixes/t7-kanit/ (ekran görüntüleri)
## Run
python3 scripts/veri-eslesme-kontrol.py hepsi
(Playwright koşum komutunu rapora birebir ekle)
## Bağımlı
t3, t4, t6
## Review: T0
## Önceden cevaplanmış kararlar
Demo'ya migration uygula, sorma. Prod, push, merge yok. Muse yok. Kod değiştirme yok. Geçici dosya mutlak yol $HOME/tmp. Betiği koşarken `sonuclar.json` ezilmesine dikkat. Tarayıcı işini ram-ultracode kuralıyla koş.
