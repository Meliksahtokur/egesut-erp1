# N4-F3 — Demo e2e'nin bulduğu iki UI hatası (Opus, MUSE-YEDEK)
job_id: j-20261109T172445Z-89a23f

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F3-report.md

## Plan maddesi
PLAN UB4 (Ovsync TAI'de Ertele yok → "Ovsync ekranında düzenle →") ve ana brief F9 (ertele düğmesi YALNIZ ilk ritim günü başlığında). Kaynak bulgular: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/demo/DM1-report.md "## Devam turu".
Worktree: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren). Ana brief kuralları: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-brief.md "Bilinen tuzaklar" (NODE_PATH, ram-ultracode exec, loadExtractedFunction imza koruma, stash/checkout YASAK).

## İş
- H1 (BLOKLAYAN) js/ui.js:2241-2254 `_ovsyncKartKararBaglami`: görev kartının Ovsync kararı Ovsync ekranının kurduğu bağlama (js/ui.js:999) bağımlı → Ovsync ekranı açılmadan Görevler ekranında Ovsync TAI kartında Ertele çiziliyor (MEASURED, demo e2e spec:409-415). Düzeltme: karar görev verisinin kendisinden (`ovsyncTrenGorevMu(t)` — SQL R5 `_ovsync_gorev_mu` aynası, js/ovsync-tren.js) + tren bayrağı (IDB protokol_ayar, mevcut `ovsyncTrenAktif`) ile verilir; Ovsync ekranı bağlamı varsa yalnız ek bilgi (hangi tren) için kullanılır. Bayrak kapalı → eski Ertele birebir. Test (adlı): `Görevler ekranı Ovsync bağlamı yokken Ovsync TAI → düzenle linki, Ertele yok`. Mutant: bağlam koşulunu geri getir → adlı test kırmızı.
- H2 js/ovsync-tren.js:269-276, :325-326: geçen haftanın tren başlığı da aynı tarihli "Tren gününü ertele…" çiziyor (iki düğme). Düzeltme: düğme ekranda tek kez, `ovsyncIlkToptanTarih` ile seçilen X'in İLK geçtiği başlıkta (trenin kendi başlığı). Test: `iki başlık aynı X'i işaret ederken tek ertele düğmesi`. Mutant: tekilleştirmeyi kaldır → kırmızı.
- Demo doğrulaması: yalnız `tests/e2e/ovsync-tren.spec.js` içindeki "görevler ekranı: Ovsync TAI'de Ertele yok" testini (`-g`) demo'da TEK koş (komut: DM1-report e2e koşum satırı, demo ref `vtzqjmazsvurxdeondmi`; başka ref YASAK) → PASS. Diğer 9 test tekrar KOŞULMAZ.

## Model
opus / high (ss-worker-high). MUSE-YEDEK: N4'te Muse 3 tur kullandı (tur1 KISMI, F1 DÜZELT, F2 KISMI); yeni bulgu kuralı gereği Opus.

## Boyut bütçesi
Üretim net ≤ +40 satır.

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ui.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/js/ovsync-tren.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/tests/unit/ovsync-tren-entegrasyon.test.js
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F3-report.md

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -6
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node scripts/etiket-tazelik.mjs 2>&1 | tail -3

## Kabul
- Tam birim suit fail 4 = taban dördü (degisiklikler-etiketler.test.js:88, erteleme-genel-ui.test.js:262, :292, vaka-toplu-ac.test.js:2624); pass > 2382. etiket-tazelik HATALI 15 / DOĞRULANAMADI 4.
- H1/H2 testleri kırmızı→yeşil; iki mutant adlı testte kırmızı (yedekten geri yükleme + cmp IDENTICAL).
- Demo tek test PASS (ham çıktı report'a).
- Commit dosya dosya, `ovsync-tren N4-F3: <özet>`; report da commit; push YOK. Report'ta `## Run kanıtı`.

## Review: T1

## Önceden cevaplanmış kararlar
- Muse çağırma; işi kendin yap. Sunucu/SQL değişmez. Demo verisine test dışı yazma yok.
- `/tmp` yasak; `$HOME/tmp/n4f3/`. Test koşumu kancaya takılırsa `ram-ultracode exec --class test --wait 900 -- bash <betik>`.
