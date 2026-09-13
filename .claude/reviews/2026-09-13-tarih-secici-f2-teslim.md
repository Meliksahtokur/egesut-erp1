# W2 — F2 Delivery: tarihAlaniBagla + 15 native input göcü (G-20260913-TARIH-SECICI)

## 1. Branch + final commit

- Branch: `agent/tarih-secici-standardi-W2`
- Code delivery commit: **`416886a`** (feat(tarih): F2 — 5 files)
- Final commit: bu raporu taşıyan commit (rapor kendi SHA'sını içeremez;
  final SHA worker ekran çıktısında bildirilir).

## 2. Changed files (git diff --stat against base `79b104c`)

```text
 index.html                       |  74 +++++++++---------
 js/app.js                        |   6 +-
 js/ui.js                         | 141 +++++++++++++++++++++++++++++++++-
 tests/tarih-secici.spec.js       | 162 +++++++++++++++++++++++++++++++++++++++
 tests/unit/vaka-toplu-ac.test.js |   9 ++-
 5 files changed, 348 insertions(+), 44 deletions(-)
```

Commit dışı bilinçli bırakılan: `.ss/tarih-secici-standardi-W2-BOARD.md`
(worker çalışma panosu; write manifest dışı — W1 uygulamasıyla aynı).

## 3. Test evidence

**Unit** (`node --test tests/unit/*.test.js`):

| Stage | tests | pass | fail |
|---|---|---|---|
| Baseline (F1 merge tabanı, node_modules symlink sonrası) | 824 | 823 | 1 — bilinen kırmızı `gecmis-pipeline.test.js:283` |
| Final (F2 sonrası) | 824 | 823 | 1 — aynı bilinen kırmızı; **yeni kırmızı YOK** |

Review düzeltmeleri sonrası ayrıca yeniden ölçüldü: 823/1 (değişmedi).
Not: reviewer, `gecmis-pipeline:283`'ün bugün kırmızı olmasının nedenini
buldu — `js/gecmis.js` `_gmGroupLabel` DÜN dalında gerçek saati kullanıyor
(sabit fixture yalnız 2026-09-09/10'da yeşil; **F2'den bağımsız date-bomb**,
bkz. §7).

**Playwright** — yeni spec `tests/tarih-secici.spec.js` (4 test; mobil
412×915 hasTouch isMobile + `en-US` locale; demo DB, salt-okunur — form
submit YOK, DB yazımı YOK):

| Koşum | Sonuç |
|---|---|
| **Red-before: taban `79b104c`** (ayrı git worktree, docker playwright v1.58.2, PLAYWRIGHT_DEMO_MODE=1) | **4/4 KIRMIZI** — beklenen nedenlerle: `native date tipi kalmamalı` + `#*-btn` click timeout (takvim/buton yok) |
| **F2 sonrası (`416886a`)** | **4/4 YEŞİL** |

Testler: (1) b-tarih TR takvim açılır, TR ay başlığı (en-US'e rağmen), bugün
hücresi tıklanır, değer ISO + buton etiketi `📅 gg.aa.yyyy`; (2) i-tarih el
girişi `15.07.2026` → ISO `2026-07-15` (mm/dd tuzağı e2e ayağı) + Temmuz'a
geçiş; (3) a-dt change olayı tetiklenir (animal-guncelle yolu) + Temizle
akışı boşaltır; (4) max sınırı — gelecek gün hücresinde onclick yok.

**Regresyon e2e** (aynı ortam, `--retries=0`): `gece-tarih` (3) + `sutten-kes`
(1) + `offline-kuyruk` (2) → **9 passed, 1 skipped** (önceden var olan
veri-bağımlı skip), **0 failed**. `kritik-akis` 2 kırmızı — **taban
`79b104c`'te de aynı 2 test kırmızı** (önceden var olan, veri-bağımlı;
ayrı worktree'de ölçüldü).

**Grep kanıtı** (`grep -c 'type="date"' index.html js/*.js`): **tüm dosyalar
0** (14 index.html girişi `type="text"`'e çevrildi; js/ui.js'teki tek
eski eşleşme 6744'teki YORUM satırıydı — yeniden yazıldı).

## 4. Field migration table

Mimari: **gizli taşıyıcı + görünür buton** (karar D-20260909 kural 1).
Taşıyıcı (= özgün input; id, native `.value` ISO saklama, `.min`/`.max`
yansıması, change olayı korunur) 1×1/opacity:0/pointer-events:none;
`value` property'sine yazıcı kancası (etiket senkronu); runtime tipi
`date` kalır → `modal.js openM`'in boş-tarih-otomatik-doldurma yazıcısı
(`querySelectorAll('input[type=date]')`) ve native sanitizasyon birebir
çalışır. Buton (`#<id>-btn`) özgün class/stil ile aynı yerde görünür;
tık → `tekTarihTakvimAc` (F1 bileşeni). Okuyucu/yazıcı kodunda **hiçbir
değişiklik gerekmedi** (HARD CONSTRAINT sağlandı).

| id | Okuyucu sözleşmesi korundu? | min/max | temizlenebilir | Not |
|---|---|---|---|---|
| k-tarih | ✓ | max: bugun | — | submit 'ileri tarih olamaz' (forms.js:464) |
| i-tarih | ✓ | max: bugun | — | submit kontrolü var (forms.js:323) |
| tr-tarih | ✓ | max: bugun | — | submit kontrolü var (forms.js:413) |
| v-date | ✓ | max: bugun | — | submit kontrolü var (forms.js:2997) |
| bv-tarih | ✓ | max: bugun | — | bulk'ta submit kontrolü YOKTU — tek-aşı kuralıyla hizalandı (**yeni kısıt**, §7/owner) |
| sk-tarih | ✓ (`\|\| bugun()`) | max: bugun | ✓ | submit kontrolü YOKTU — olay tarihi; (**yeni kısıt**, §7/owner) |
| b-tarih | ✓ | max: bugun | — | submit kontrolü var (forms.js:194) |
| a-dt | ✓ | max: bugun | ✓ | ui.js:2976 `.max` yazısı taşıyıcı yansımasıyla canlı; `p_dogum_tarihi \|\| null` boşa izinli |
| ta-tarih | ✓ | — yok — | — | görev hedefi; gelecek meşru |
| td-asi-tarih | ✓ (`\|\| bugun()`) | max: bugun | ✓ | ui.js:5619/5651 dinamik `.max=bugün` yazıları canlı |
| td-rapel-tarih | ✓ | dinamik pencere (parent+14..21; ui.js:5739-41) | ✓ kaldırıldı (review #5) | `.min/.max` dinamik yazıları canlı |
| te-tarih | ✓ | — yok — | — | görev hedefi; gelecek meşru |
| cx-tarih | ✓ | max: bugun | — | çıkış OLAY tarihi; submit kontrolü YOKTU (**yeni kısıt**, §7/owner) |
| geb-tarih | ✓ | max: bugun | — | submit kontrolü var (forms.js:3598) |

Reset noktaları: `app.js:600` defaults ✓ (bağdan geçer, etiket senkron);
gerçek hayvan-form reseti `ui.js:2962` (a-dt clear) ✓; `modal.js openM`
auto-fill ✓ (gece-tarih spec bunu kilitler — yeşil). Zarfın
"`ui.js:7854`" ipucu güncel dosyada ilaç-satırı render'ıdır (tarih alanı
içermez; satır kayması) — yukarıdaki üç gerçek nokta doğrulandı.

## 5. `?v=` stamp state

- Yeni ortak değer: **`20260913-15`** — index.html'deki **23/23** damgalı
  kaynak bu değerde (eski `20260911-14` kalmadı); `manifest.json?v=…`
  dahil.
- Damga muhafız testi (`tests/unit/vaka-toplu-ac.test.js:2168` + manifest
  testi :2488) AYNI değişiklikte güncellendi — kısmi-bump tuzağı yok;
  228/228 yeşil.

## 6. Review note

`bulgu: builtin code-reviewer (subagent) 8 buldu — KRİTİK YOK; 2 ORTA:
(#1) Enter-ileri-navigasyonun görünmez taşıyıcıya odaklanabilmesi →
DÜZELTİLDİ (app.js seçicisine :not([tabindex="-1"])), (#2) cx-tarih/sk-tarih
max kısıtı submit doğrulamasıyla belgeli değil → SAHİBİNE taşındı (goal
metni 'event-style gelecekte olamaz' diyor + RPC'ler kaydı anında
uygular; domain-rules.md güncellemesi F4 kapsamı — bkz. §7); 5 DÜŞÜK:
(#3) muhafız mesaj metni DÜZELTİLDİ, (#5) td-rapel temizlenebilir ölü-sonu
DÜZELTİLDİ (kaldırıldı), (#6) değişmeden change yayılımı DÜZELTİLDİ
(native parite), (#7) buton aria-label/haspopup EKLENDİ, (#8) bağlama-
öncesi-ilk-boya kabul edildi; +1 DÜŞÜK önceden var olan (gecmis date-bomb,
kapsam dışı). Düzeltmeler sonrası unit 823/1 + e2e 9p/1skip/0f yeniden
ölçüldü.`

Review ayrıca sözleşme uyumunu doğruladı: 14 alanın TÜM okuyucu/yazıcıları
(30+ satır) gerçek kod üzerinde tarandı — `.value` sarmalayıcısı + runtime
`type='date'` + holder-min/max önceliğiyle korundu; `form.reset()` yalnız
vaka formunda (tarih alanı yok); FormData/`valueAsDate`/`showPicker`/`cloneNode`
kullanımı yok; XSS — etiket yalnız `textContent`, dinamik innerHTML yok;
F3 yüzeyleri (`bcTakvim*`, `bcTarihTakvim*`, `caseGunModalRender`)
dokunulmadı.

## 7. Open risks / deferred items

1. **Sahibe karar (review #2):** `cx-tarih` (süründen çıkış) ve `sk-tarih`
   (sütten kesme) — daha önce gelecek tarihe izin veriliyordu, F2 ile
   `max=bugun`. Gerekçe: goal metni ("event-style dates must not be in the
   future") + iki RPC de kaydı anında uygular (gelecek tarihli çıkış/kesim
   aktif-hayvan mantığıyla çelişir). `bv-tarih` de aynı gerekçeyle
   tek-aşı (v-date) kuralına hizalandı. domain-rules.md belgelemesi F4;
   sahibi kısıtları istemezse TARIH_ALANLARI'da tek satırlık geri alma.
2. **Önceden var olan kırmızılar (F2 dışı):** unit `gecmis-pipeline:283`
   — reviewer kök nedenini buldu: `js/gecmis.js` `_gmGroupLabel` DÜN
   etiketini gerçek `new Date()`'ten türetiyor, sabit fixture yalnızca
   gerçek tarih 2026-09-09/10 iken yeşil (date-bomb). e2e
   `kritik-akis.spec.js:52/:71` — tabanda da kırmızı (veri-bağımlı).
   İkisi de F4 guard-test öncesi onarım adayı.
3. **`i-tarih` ui.js:8097 setTimeout doldurması** `new
   Date().toISOString()` (UTC) kullanıyor — gece yarısı kayması B4
   örüntüsü; davranış F2'de KORUNDU (dokunulmadı), ayrı düzeltme adayı.
4. **Ortam notları (lead için):** worktree'lerde `node_modules` symlink
   gerekli; Playwright bu makinede yalnız docker
   (`mcr.microsoft.com/playwright:v1.58.2-noble`, sürüm birebir 1.58.2)
   ile koştu — host bağımlılıkları eksik (ICU). tools-bank gitnexus
   indeksi `tekTarihTakvimAc`/`tarihAlaniBagla` için bayat; doğrulama
   LSP + grep ile yapıldı. Blast-radius PreToolUse hook'u için gerçek
   analiz sonrası `/tmp/blast-radius-done` yazıldı (W1 uygulaması).
5. **Bağlama-öncesi ilk boyama (review #8):** init `window.load`'ta
   çalıştığından yavaş bağlantıda 14 alan kısa süre düz `type="text"`
   görünür; kabul edildi.
