# N4-R — N4 UI kulvar sonu tek review (T1) + bağımsız doğrulama
job_id: j-20261109T145420Z-7aff49

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-R-review.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren (dal ovsync-tren)
base: fb41bbf
head: f5a61ea
Diff: `git diff fb41bbf f5a61ea -- js/ index.html tests/unit/ovsync-tren.test.js tests/unit/ovsync-tren-entegrasyon.test.js` (runs/ kayıtları kapsam dışı).

## Plan maddesi
PLAN N4 UB1–UB5 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md :476-551) + ROOT RULING'ler:
- ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-brief.md
- ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/ui/N4-F1-brief.md
Yürütücü report'ları: aynı klasörde N4-report.md, N4-F1-report.md. Veri sözleşmesi (RPC alan otoritesi): UB-sozlesme-report.md.

## Odak (reviewer)
1. Doğruluk: her ROOT RULING maddesi (BOŞLUK-1..5, F1–F15, D1, D3(ii)) kodda doğru mu — report'taki dosya:satır tablolarını nokta-kontrol et, RPC alan adları sözleşme raporuyla birebir mi (uydurma alan = DÜZELT).
2. Bayrak kapalı: her kancada eski yol birebir mi (kopya fonksiyon değil, tek erken dal).
3. Offline: K8 ve tren eylemleri kuyruğa yazmıyor mu; cdKaydirAc OVSYNC offline eski kaydır'a düşmüyor mu.
4. Güvenlik: innerHTML'e giden kullanıcı/sunucu metni `esc`'li mi (küpe no, hata metni, not).
5. Kalite: BOYUT +1065 (bütçe 1000) — tekrar/ölü kod/gereksiz sargı var mı (`_ovsyncV5Sargili`/`_ovsyncV5KancaKur` sargı deseni, `_ovsyncK8GunAd` vs `_ovsyncTrenTarihAd`); sahip UI kuralı: vurgu yalnız yazı rengi, satır zemini/şerit/krem panel yok (index.html style + ui.js).
6. Testler mutantla anlamlı mı (m1–m8); bayat/yanlış-pozitif test var mı.
Bulgu biçimi: `[KRİTİK|ÖNEMLİ|KÜÇÜK] dosya:satır — sorun — KANIT: (komut → beklenen ≠ görülen | dosya:satır + ihlal edilen kural) — dar fix`. KANIT'siz = ÖNERİ.
Verdict: `KABUL | ÇALIŞIR ama DÜZELT (kalite) | DÜZELT | RED`. Tek tur.

## Run (verifier koşar; reviewer en az birini kendisi koşar)
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/*.test.js 2>&1 | tail -8
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && NODE_PATH=~/egesut-erp1/node_modules node scripts/etiket-tazelik.mjs 2>&1 | tail -25; echo rc=$?
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && git diff --numstat fb41bbf f5a61ea -- js/api.js js/ui.js js/forms.js js/ovsync-tren.js index.html manifest.json

## Kabul (verifier, kriter başına PASS/FAIL/INCONCLUSIVE + komut çıktısı)
K1 tam suit `fail 4` ve fail edenler tam olarak: degisiklikler-etiketler.test.js:88, erteleme-genel-ui.test.js:262, :292, vaka-toplu-ac.test.js:2624; pass ≥ 2359.
K2 etiket-tazelik HATALI 15 / DOĞRULANAMADI 4 ve liste N4-F1-report'taki 19 kalemle aynı (satır no kayması hariç).
K3 diff yalnız şu dosyalar: js/api.js, js/ui.js, js/forms.js, js/ovsync-tren.js, index.html, tests/unit/ovsync-tren.test.js, tests/unit/ovsync-tren-entegrasyon.test.js (+ runs/**).
K4 index.html'de `?v=` değerlerinin hepsi `20261110-1` (yorum satırı hariç) ve `js/ovsync-tren.js` `js/ui.js`'ten önce.
K5 m8 yeniden: N4-F1-report'taki m8 mutantını bir yedek kopyada uygula (yerinde değil: `cp js/ui.js $HOME/tmp/n4r/ui.js.bak` → değiştir → koş → geri `cp`; `cmp` IDENTICAL), adlı test kırmızı.
K6 `grep -n "toISOString().slice(0, *10)" ` yeni eklenen satırlarda yok (`git diff fb41bbf f5a61ea -- js/ | grep '^+' | grep -c toISOString`).

## Review: T1
## Model
reviewer: sonnet (ss-reviewer) · verifier: sonnet (ss-verifier)
## Yazılabilir dosyalar
(salt-okuma; raporlar inline döner, root dosyaya yazar)
## Önceden cevaplanmış kararlar
- N4-brief ve N4-F1-brief ROOT RULING'leri bağlayıcı; RPC genişletmeme kararı bulgu değildir. Taban 4 kırmızı test ve etiket-tazelik rc=1 taban borcudur, bulgu değil. `_ovsyncK8GunAd` birleştirmesi kapsam dışı kabul edildi.
- Kod değiştirme, commit atma. `/tmp` yasak; `$HOME/tmp/n4r/`.
