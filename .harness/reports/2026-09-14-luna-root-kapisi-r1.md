# A6 — Luna ROOT kapısı: R1 tarih seçici revizyonu

Tarih: 2026-09-14
Denetlenen dal: agent/tarih-secici-standardi @ 7d775c4488e11b5ce60181b93700295bb2b874f9
Taban: 46abbc8b6a130deb47d62c06eb6fe3d8fd6f5ecf
Entegrasyon hedefi: agent/entegrasyon-tarih-surum @ c661dfab6c21b5708e7c9284fd969bde2f891394
Güncel main: fda2b9e9b8a3e04445b11ece9a92992eec968340

Bu tur yalnızca root denetimidir. Hedef ürün dalına, main'e, entegrasyon dalına,
DB'ye veya canlı sağlayıcıya yazılmadı; entegrasyon için yalnızca sentetik
merge-tree ölçümü yapıldı. Rapor dosyası bu review dalındaki tek yazımdır.

## 1. DOĞRU — unit kabul kanıtı ve main karşılaştırması

Hedefte istenen detached koşum:

    NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js

Doğrudan çıkış:

    ℹ tests 863
    ℹ pass 862
    ℹ fail 1
    ✖ tests/unit/gecmis-pipeline.test.js:283 — _gmGroupHtml
      AssertionError: assert.ok(dun.includes('DÜN'))
    DIRECT_EXIT=1

Güncel main aynı bilinen kırmızıyı verdi:

    ℹ tests 796
    ℹ pass 795
    ℹ fail 1
    ✖ tests/unit/gecmis-pipeline.test.js:283 — _gmGroupHtml
    MAIN_UNIT_DIRECT_EXIT=1

Entegrasyon dalı da aynı date-bomb ile 858/857/1 verdi. Hedefdeki tek
kırmızı R1 değişikliğinden gelmiyor; js/gecmis.js hedef diff'inde yok.

R1 saf pinleri ayrıca doğrudan ölçüldü:

    11122026       → {"metin":"11.12.2026","hata":null}
    151.12.2026    → {"metin":"151.12.2026","hata":"Gün 1-31 olmalı"}
    05.02.2026abc  → {"metin":"05.02.2026abc","hata":"Rakam girmelisiniz"}
    00             → {"metin":"00","hata":"Gün 1-31 olmalı"}
    13,09,2026     → {"ok":true,"iso":"2026-09-13"}
    13/09/2026     → {"ok":true,"iso":"2026-09-13"}
    31.02.2026     → {"ok":false,"error":"Şubat 2026 28 gün — 31.02.2026 yok"}
    90.01.2026     → {"ok":false,"error":"Ocak 2026 31 gün — 90.01.2026 yok"}
    05.02.2026     → {"ok":true,"iso":"2026-02-05"}

Kaynak/caller kanıtı: js/tarih/tarih.js:137-139 ayraç normalizasyonunu,
:155-164 junk reddini, :174-208 taşma metin korumasını ve :193-196
00 alt sınırını uygular. Üç yüzey de maske bağını kullanır
(js/ui.js:6724,7029, js/forms.js:1858); Uygula öncesi durumsuz maske
kapısı canonical/caseGun için js/ui.js:6914-6921,6772-6779, bcTakvim için
js/forms.js:1745-1752 satırlarında, ortak yeniden hesaplama ise
js/ui.js:7074-7108 aralığındadır.

## 2. DOĞRU — native date literalı ve cache damgası

    rg -n -F 'type="date"' index.html js
    RG_TYPE_DATE_EXIT=1
    stamp_count=23 unique={"20260913-18":23}
    STAMP_17_RG_EXIT=1
    STAMP_16_RG_EXIT=1

Guard sözleşmesindeki bilinçli gizli taşıyıcı istisnası tek noktada kalıyor:
js/ui.js:7176 — el.type = 'date'; literal HTML attribute değildir ve F4
guard'ı bunu ayrı tek-nokta pinler. Runtime kaynakta ek bir date ataması yoktur.
Ortak desktop/mobile stilinin gerçek kaynak sınırı js/ui.js:7045-7062:
desktop 400px, max-width:calc(100vw - 32px), min-width:900px; mobilde
width:100% alt-sheet kuralı korunur. Dropdown ve 40px ok/selector hedefleri
js/ui.js:6983-7012 ve :7045-7046 ile üç yüzeye taşınır.

Owner teslim raporu Playwright 9/9 ve 412×915 pinini bildiriyor; root'un
yerel stub koşumu ise dışa bağlı sağlayıcıya gitmeden şu nedenle başlatılamadı:

    npx playwright test tests/tarih-secici.spec.js --reporter=line
    Error: Cannot find module '@playwright/test'
    PLAYWRIGHT_STUB_DIRECT_EXIT=1

Bu browser yeniden-koşumu ÖLÇÜLEMEDİ sınırıdır; worker/lead raporundaki
9/9 iddiası root'un bağımsız koşum sonucu olarak yükseltilmemiştir. Bu turda
canlı GitHub Pages, Supabase veya başka provider probu yapılmadı.

## 3. DOĞRU — kritik maske düzeltmesi gerçek

git show 7d775c4:js/tarih/tarih.js ve doğrudan Node probe birlikte şunu
kanıtlıyor:

- tarihMaskeUygula('151.12.2026') yazılan metni değiştirmeden hata döndürüyor;
- tarihGirisCoz , /, -, boşluğu . olarak çözüyor;
- 31.02.2026 ve 90.01.2026 ISO'ya dönüşmeden reddediliyor;
- 05.02.2026 yalnızca 2026-02-05 oluyor;
- junk ve 00 maske kapısında kalıyor.

Yanlış-geçerli 15.11.2202 yolunun kapanması, üç Uygula çağırıcısının
maskeHatasi'nı tarihGirisCoz'dan önce kontrol etmesiyle doğrudan kaynakta
görülüyor (js/ui.js:6914-6921,6772-6779; js/forms.js:1745-1752).

## 4. DOĞRU — main temiz, entegrasyon çatışması ölçüldü ve sınırlandırıldı

Main için:

    git merge-tree --write-tree fda2b9e 7d775c4
    ed1317d934e4eaf5e48fdd2fc7460f3b39de9ee9
    MERGE_TREE_fda2b9e_EXIT=0

İstenen entegrasyon dalı için:

    git merge-tree --write-tree c661dfa 7d775c4
    CONFLICT (content): Merge conflict in index.html
    CONFLICT (content): Merge conflict in tests/unit/vaka-toplu-ac.test.js
    MERGE_TREE_c661dfa_EXIT=1

Bu beklenen ortak-dosya çatışmasıdır; R1 dalı main'i sentetik olarak bozmaz,
ancak E1'de otomatik birleşmez. Root entegrasyon yönü:

- index.html: E1/L2'nin js/degisiklikler/* scriptlerini ve mevcut yapısını
  koru; R1'nin bütün yerel kaynakları tek ?v=20260913-18 değerine bump eden
  satırlarını birleştir.
- tests/unit/vaka-toplu-ac.test.js: E1/L2 testlerini koru; R1'nin dropdown,
  maske ve 1..9999 kenar pinlerini ve 20260913-18 beklentilerini kaybetmeden
  iki tarafı birleştir.
- .harness/references/ui-map.md, supabase/, js/gecmis.js ve L2'nin
  js/degisiklikler/* dosyalarına R1 adına dokunma.

Bu turda merge/çatışma çözümü yapılmadı.

## 5. DOĞRU — kapsam ve yazım sınırı

    git diff --stat 46abbc8..7d775c4
    14 files changed, 1583 insertions(+), 103 deletions(-)
    EXACT_MANIFEST_MATCH=1
    SUPABASE_DIFF_EXIT=0
    HISTORY_OR_VERSION_DIFF_EXIT=0
    DIFF_CHECK_EXIT=0

46abbc8..7d775c4 değişen 14 yol, R1 goal manifestiyle birebir aynıdır:
index.html, js/forms.js, js/tarih/tarih.js, js/ui.js, üç test dosyası,
üç .claude/tasks, iki .claude/reviews, bir goal ve bir teslim raporu.
supabase/, js/gecmis.js ve js/degisiklikler/ değişmedi. R1 kod diff'inde
eklenmiş rpc, insert, update, delete veya fetch çağrısı yoktur.
Denetim komutları canlı DB/provider yazımı yapmadı.

## 6. DOĞRU — ertelenenler kabulü engellemiyor

Hedef teslim raporundaki ertelenenler (git show
7d775c4:.harness/reports/2026-09-13-tarih-secici-r1.md | nl -ba | sed -n '60,63p'): maske
ortadan-düzenleme kabalığı, bcTakvim toggle-off sessizliği,
tarihYilKaydir çağrıcısızlığı, manifest dışı ui-map dokümantasyon adayı ve
ayrı _gmGroupHtml date-bomb onarımıdır.

Bunlar bu R1 zarfının beş owner bulgusunu geçersiz kılmıyor: Uygula yolu hatalı
maskeyi reddediyor, toggle sonucu seçim çipinden görülebiliyor, çağrıcısız
yardımcı canlı caller sözleşmesini etkilemiyor, ui-map zarf dışı doküman adayı
olarak beyanlı ve _gmGroupHtml aynı main/integration baseline kırmızısıdır.

## Kapsam sınırı ve sonuç

Hedef goal frontmatter'ı status: done diyor; aynı dosyanın açıklama gövdesinde
eski Status: IN_PROGRESS satırı kalmış. Lifecycle için frontmatter'ı
makinece yetkili kabul ettim; bu belge drift'i ürün kapsamı veya R1 kanıtını
değiştirmiyor ve bu salt-okuma turunda düzeltilmedi.

R1 hedef dalının root denetim kriterleri, bilinen baseline kırmızısı ve E1'deki
iki açık ortak-dosya çatışması dürüstçe ayrıştırılarak karşılandı. Browser
yeniden-koşumu yukarıda ÖLÇÜLEMEDİ olarak bırakıldı; canlı/DB/deploy kabulü
iddia edilmiyor.

SONUÇ: KABUL
