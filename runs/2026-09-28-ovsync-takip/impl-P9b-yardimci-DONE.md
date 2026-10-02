# impl-P9b-yardimci-DONE — TAMAM

- **Goal:** G-20260930-OVSYNC-TAKIP-IMPL · **Plan madde:** P9b (yalnız bağımsız parça — plan.md:619-636)
- **GOREV:** runs/2026-09-28-ovsync-takip/impl-P9b-yardimci-GOREV.md
- **Dal:** ovsync-takip (worktree /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip) — değiştirilmedi [CONFIRMED: git branch --show-current → ovsync-takip]
- **Self-repair sayısı:** 0 (tavan 2) [CONFIRMED — kırmızı ilk koşumda beklenen nedenle geldi, yeşil ilk implementasyonda]

## Kabul maddeleri — kanıt

**1. Birim testi yeşil — dört sınır case** [CONFIRMED — `node --test tests/unit/ovsync-takip.test.js`, bu oturumda koşuldu]
- Observed: `tests 7 / pass 7 / fail 0`.
- Dört zorunlu case'in tamamı testte var [OBSERVED — dosya içeriği]:
  - bugün/dün/N gün önce: `2026-09-30T10:00:00Z→bugün`, `2026-09-29T20:30:00Z→dün`, `2026-09-15→15 gün önce`
  - gece yarısı sınırı: `2026-09-29T20:30:00Z` (İstanbul 23:30) → `dün` VE `2026-09-29T21:30:00Z` (İstanbul 00:30) → `bugün` — 1 saatlik gerçek fark, takvim farkı 1
  - UTC sınırı: `2026-09-29T21:30:00Z` = İstanbul 00:30 **ertesi** gün → `bugün` (ilk-10-karakter kesimi `dün` derdi); sınır öncesi `20:59:59Z` → `dün`
  - ileri tarih: `2026-10-05` → `5 gün sonra`
- Test girişleri Z-suffixed (İstanbul sabit UTC+3) — makine TZ'inden bağımsız deterministik [CONFIRMED: test dosyası başlığındaki gerekçe; bu makine TZ=Europe/Istanbul'da da koşuldu]

**2. node --check + git diff --check temiz** [CONFIRMED — her ikisi bu oturumda koşuldu]
- `node --check js/utils/helpers.js` → OK, exit 0 [OBSERVED]
- `git diff --check` → çıktı boş (temiz) [OBSERVED]

**3. Yardımcı saf — durumsuz, DOM/window yok, Node require ile test edilebilir** [CONFIRMED]
- Saf-blok grep'i: `document|window|Date.now|localStorage` kod kullanımı YOK (tek eşleşme sözleşme yorum satırının kendisi) [OBSERVED]
- Test dosyası tarayıcısız `require('../../js/utils/helpers.js')` ile koşuyor; tüm kırmızı/yeşil koşumlar saf Node'da [OBSERVED]
- Fonksiyon parametreli başvuru günü (`bugun?`) alır; verilmezse bugünün İstanbul günü — durumsuz, modül düzeyinde durum yok [CONFIRMED: kod — yalnız `_istanbulGunNo`/`_gunNo` saf dönüştürücüler]

## Kırmızı → Yeşil (TDD)

- **Kırmızı (implementasyondan ÖNCE):** `node --test tests/unit/ovsync-takip.test.js` → `tests 7 / pass 0 / fail 7`; her test `AssertionError [ERR_ASSERTION]: gunFarkiEtiket helpers.js dışa aktarılmalı — actual 'undefined' expected 'function'` ile düştü [OBSERVED]. Eksik-özellik hatası = beklenen kırmızı (test kasıtlı olarak `typeof` iddiasıyla açılıyor ki TypeError değil assertion kırmızısı olsun).
- **Yeşil (implementasyondan sonra):** aynı koşum → `tests 7 / pass 7 / fail 0` [OBSERVED].
- Red-green tersine-kanıt: kırmızı koşum uygulama YOKKEN alındı (test-first), revert-kanıtına gerek bırakmaz [CONFIRMED — sıra: test yazıldı → kırmızı görüldü → helpers yazıldı → yeşil].

## Tam süit (proje koşumu — TDD bitiş kuralı)

`NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit` → `tests 1294 / pass 1291 / fail 3 / skipped 0` [OBSERVED].
3 kırmızının tamamı **ön-bulunan** — HEAD baseline'ında (geçici worktree /home/melik/tmp/p9b-baseline @ 8c91226, benim değişikliklerim yokken) birebir aynı testler kırmızı; worktree incelendi ve kaldırıldı [CONFIRMED]:
1. `tests/unit/vaka-toplu-ac.test.js` — "ay ‹/› : etiket değişir, seçim korunur… (Ekim 2026)" — tarih-duyarlı (bugün 2026-09-30, ay sınırı)
2. `tests/unit/vaka-toplu-ac.test.js` — "gelecek güne tık: başlık güncellenir…" (bc-tarih takvim, ay sınırı)
3. `tests/unit/degisiklikler-etiketler.test.js` — "LUNA-3: canlı DEMO information_schema ↔ harita" — canlı DB bağımlı
Not: NODE_PATH'siz koşumda ek 9 dosya `Cannot find module 'fast-check'` ile dosya-bazlı çöküyor — worktree node_modules eksiği (bilinen ortam tuzağı), bu işle ilgisiz ortamsal gürültü [CONFIRMED].

## Yazılan dosyalar (yazma manifesti birebir — liste dışı yazım YOK)

1. `js/utils/helpers.js` (MODIFY — +61/−1: `gunFarkiEtiket` + `_istanbulGunNo`/`_gunNo` saf dönüştürücüler, SÖZLEŞME yorum bloğu, export listesine `gunFarkiEtiket`) [CONFIRMED: git diff --stat]
2. `tests/unit/ovsync-takip.test.js` (CREATE — 7 test; kalem 11 testleri P9'da aynı dosyaya sıralı eklenecek, dosya başlığında notu var) [CONFIRMED]
3. Bu DONE dosyası (CREATE)

**Dokunulmayanlar (yasaklar):** `js/ui.js` yazılmadı; `fmtTarih` değiştirilmedi (ilk-10-karakter tuzağı yalnız öğrenildi, sözleşme yorumunda işaretlendi); mevcut helpers davranışı bozulmadı (yalnız eklemeli diff; süitteki 3 kırmızı baseline'da da kırmızı = sıfır regresyon); commit ATILMADI; PROD/.ss/main'e dokunulmadı [CONFIRMED: git status — yalnız manifest dosyaları benim imzamla]

## Sözleşme özeti (helpers.js'e işlendi)

`gunFarkiEtiket(tarihISO, bugun?) → 'bugün' | 'dün' | 'N gün önce' | 'N gün sonra'` — Europe/Istanbul yerel takvim günü farkı; Intl `formatToParts` ile gg.aa.yyyy parçaları, iki takvim gününün `Date.UTC` gün-numarası karşılaştırması (UTC-ms bölümü DEĞİL); ileri tarih `N gün sonra`; `bugun?` 'YYYY-MM-DD' ya da gg.aa.yyyy kabul eder, verilmezse bugünün İstanbul günü; ayrıştırılamayan girişte `''`.

## Açık kalem (bilinçli, bu zarfın dışı)

- **ui.js bağlaması YOK** — `_uremeTohumlama` satır deseni :6018'e `${gunFarkiEtiket(t.tarih)}` bağlaması P9'da, tek-yazıcı zincirinde (GOREV manifesti maddesi; plan.md:629-630).
- Demo gözle denetimi ("2025-12-30 · Gebe · 273 gün önce" deseni) P9 kabulüne ait — bağlama sonrası.
