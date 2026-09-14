# K1 — Küçük işler paketi (yalnız belge) — TESLİM RAPORU

- Görev zarfı: `/home/melik/egesut-erp1/.ss/tasks/K1-kucuk-isler.md`
- Dal: `agent/kucuk-isler-k1` (base `main`; main bu dalın atası)
- Tarih: 2026-09-14 · Worker: kucuk-isler-k1 (glmf)
- Kapsam: YALNIZ belge. `js/`, `tests/`, `supabase/`, `index.html`,
  geçmiş sekmesi bölümü — dokunulmadı (0 diff).

## Değişen dosyalar (izlenen)

1. `.harness/references/ui-map.md` — kanonik tarih seçici bölümü R1 sonrası
   gerçek duruma çekildi + Toplu vaka bölümündeki ölü `bcTarihTakvimAc`
   anchor'ı gerçeğe (`bcTarihSeciciAc` → kanonik `tekTarihTakvimAc`)
   bağlandı. Geçmiş sekmesi içeriğine dokunulmadı.
2. `.harness/goals/2026/G-20260913-TARIH-SECICI-R1.md` — gövdedeki eski
   `Status: IN_PROGRESS` satırı frontmatter `status: done` ile tutarlı hale
   getirildi (luna A6 drift'i). Frontmatter'a dokunulmadı.

Rapor: `reports/2026-09-14-k1-kucuk-isler.md` (gitignore'da, `git add -f`).
Tahta: `.ss/kucuk-isler-k1-BOARD.md` (commit dışı, untracked).

## ui-map kanonik bölüm — anlatılanlar ve grep -n kanıtları

Her iddia kaynakla doğrulandı (main'deki iki R1 raporu + canlı kaynak):

**Yüzeyler ve bileşen**

- Kanonik tek-tarih bileşeni `tekTarihTakvimAc` →
  `grep -n "function tekTarihTakvimAc" js/ui.js` → `js/ui.js:6856`;
  seçili değerin ayında açılır (deger yoksa bugün) → `js/ui.js:6858-6861`
  ("Açılış görünümü: seçili değer varsa O ay/yıl, yoksa bugün").
- Form alanı bağlama `tarihAlaniBagla` → `js/ui.js:7151`; şema
  `TARIH_ALANLARI` → `js/ui.js:7248`.
- Üç yüzey:
  1. tekTarih → `js/ui.js:6856`.
  2. bcTakvim (çoklu gün, toplu vaka) → `grep -n "function bcTakvimAc"
     js/forms.js` → `js/forms.js:1693`; render `bcTakvimRender` → :1776;
     kapsayıcı `bc-gun-takvim` → :1781; SAF doğrulama `bcTakvimSecimEkle`
     → :1655; pencere [başlangıç, başlangıç+30g] → :1736-1739 yorumu +
     `tarihYilAraligi(baslangic, dFwd(baslangic, 30), …)` → :1823.
  3. caseGunModal → `grep -n "function caseGunModalRender" js/ui.js` →
     `js/ui.js:6651`; "Secili Gunler" çipleri → `js/ui.js:6712`.
- Toplu vaka tedavi tarihi kanonik bileşene delege → `bcTarihSeciciAc`
  gövdesi `js/forms.js:1911-1913` (`tekTarihTakvimAc({…})` çağrısı) +
  `js/utils/handlers.js:228` (`'bc-tarih-takvim': () => bcTarihSeciciAc()`).
- Ay sayfalama 1..9999 kenar reddi (sarma yok): bcTakvim →
  `js/forms.js:1707-1714` (R1 REVİZYON B4); caseGun → `js/ui.js:6760`
  (`if (!(yil >= 1 && yil <= 9999)) return;`).

**El girişi maskesi (üç yüzeyde ortak)**

- Canlı maske `tarihMaskeUygula` →
  `grep -n "function tarihMaskeUygula" js/tarih/tarih.js` → :155;
  ayraç normalizasyonu `[,.\/\-\s]+` → `.` → :138 ve :158.
- Uygula yolu `tarihGirisCoz` → :137 (→ `tarihParse` :72; gün-önce
  regex :76 — mm/dd yorumu YOK, tarih.js:69-71 sözleşme yorumu).
- Taşan/yutulan/kirli metin ASLA yeniden yazılmaz: junk reddi :162-164
  ("Rakam girmelisiniz"), B1a yeniden bölünmeme :177-184, hatalı girişte
  metin korunur :205-208; 00 alt sınırı :193-196.
- Bağ + kapı: `tarihSeciciMaskeBagla` → `js/ui.js:7074`; üç yüzeyde bağ
  → `js/ui.js:6724` (caseGun), `js/ui.js:7029` (tekTarih),
  `js/forms.js:1858` (bcTakvim); Enter=Uygula → `js/ui.js:7094`;
  durumsuz maske kapısı `tarihSeciciMaskeHatasiAl` → `js/ui.js:7105`,
  Uygula `tarihGirisCoz`'dan ÖNCE kontrol → `js/ui.js:6914-6921`
  (tekTarih), `js/ui.js:6771-6779` (caseGun), `js/forms.js:1745-1752`
  (bcTakvim); `inputmode="numeric"` → `js/ui.js:6715,7019` +
  `js/forms.js:1849`; geçerli giriş takvimi o aya atlar →
  `js/ui.js:6946-6950`, `js/forms.js:1771-1773`.

**Ay+yıl dropdown**

- `tarihYilAraligi` → `grep -n "function tarihYilAraligi"
  js/tarih/tarih.js` → :243 (ikisi→[min,max]; tek→±120; hiç→−120..+10
  :248-252). Kullanım: tekTarih → `js/ui.js:6989`; bcTakvim →
  `js/forms.js:1823`; caseGun (min/max'sız beyan) → `js/ui.js:6690`.
- Dropdown select'leri: caseGun → `js/ui.js:6704-6705`
  (`caseGunAySec`/`caseGunYilSec` :6752/:6758); tekTarih →
  `js/ui.js:7010-7011` (`tekTarihTakvimAySec`/`…YilSec` :7114/:7120);
  bcTakvim → `js/forms.js:1721/:1728`. Eski ince yıl-ok satırı kaldırıldı
  (R1 bulgu 1/4 — rapor `.harness/reports/2026-09-13-tarih-secici-r1.md`
  §1/§4).
- ≥40px dokunma hedefi + koyu zemin/açık glif: `_takvimNavStil` →
  `js/ui.js:7045` (`min-width:40px;min-height:40px;background:var(--ink);
  color:var(--card)`), `_takvimSeciciStil` → :7046.

**Yerleşim**

- Ortak idempotent `<style>`: `tarihSeciciStilEnjekte` →
  `js/ui.js:7052`; `@media (min-width:900px)` → :7059; masaüstü 400px
  ortalı kart + `max-width:calc(100vw - 32px)` → :7061; mobil (<900px)
  `width:100%` alt-sheet kuralı değişmedi → :7057
  (`.tarih-modal-kart{…width:100%…}`).

**type="date" yasağı + tek istisna**

- `rg -n -F 'type="date"' index.html js` → 0 eşleşme (bu teslimde yeniden
  ölçüldü: `grep -rc` hepsi 0, exit 1).
- Tek runtime istisnası: `grep -n "el.type = 'date'" js/ui.js` →
  `js/ui.js:7176` (gizli taşıyıcı, `tarihAlaniBagla` içinde; literal HTML
  attribute değildir).
- Guard testleri: `tests/unit/tarih-saf.test.js:756` (type="date" girişi
  yasak), :772 (runtime ataması tek nokta), :787 (takvim-semantikli yeni
  fonksiyon adı beyaz liste), :821 (saf katmanda tarih-saat API yasağı),
  :831 (kaldırılan kopyalar yeniden doğamaz).

## R1 goal gövde tutarsızlığı

`.harness/goals/2026/G-20260913-TARIH-SECICI-R1.md`: frontmatter
`status: done` (:3) ile gövde `Status: IN_PROGRESS` (:44) çelişiyordu
(luna A6 raporu §"Kapsam sınırı ve sonuç" bunu belgeliyor:
`.harness/reports/2026-09-14-luna-root-kapisi-r1.md`). Gövde satırı
`done` olarak revize edildi (kapılış gerekçesiyle); frontmatter'a
dokunulmadı.

## Kontroller (komut + sonuç)

1. Anchor bütünlüğü: ui-map'teki 223 `file:symbol` anchor'ının tamamı
   kaynakta tanımlı —

       python3 -c "…symbol_defined…ui-map.md…"  →  ANCHOR SAYISI: 223, EKSİK: YOK

2. `python3 -m unittest tests.harness.test_patterns` → 10 test,
   **1 FAIL**: yalnız `test_repository_validate_loads_pattern_index`.
   Bu FAIL **önceden var** (baseline; bu daldaki ilk koşumda da 2 FAIL'di).
   Düzenlemeyle `test_every_cited_symbol_anchor_exists_in_current_source`
   **FAIL → PASS** döndü (2 FAIL → 1 FAIL). Kalan FAIL eski goal
   dosyalarının (G-20260910/11/13) güncel şema dışı alanları — bu işin
   kapsamı dışı, raporlanır.
3. `git diff --check` → çıktısız, exit 0 (TEMİZ).
4. `type="date"` taraması → 0 eşleşme (yasak bozulmadı); `el.type = 'date'`
   hâlâ tek nokta (ui.js:7176).
5. Kapsam disiplini: `git status` → yalnız 2 izlenen belge değişikliği;
   `js/`, `tests/`, `supabase/`, `index.html` diff'te YOK.

## Gate kırıntıları

```json
{"type": "gate", "task": "K1-kucuk-isler", "sonuc": "kabul",
 "bulgular": [
  {"id": "B1", "kapsam": "icin", "not": "ui-map'te ölü anchor js/forms.js:bcTarihTakvimAc (R1'in dönüştürdüğü bc tarih yüzeyi) — bcTarihSeciciAc→tekTarihTakvimAc gerçeğiyle değiştirildi; anchor testi FAIL→PASS"},
  {"id": "B2", "kapsam": "disi", "not": "tests/harness baseline: test_repository_validate_loads_pattern_index FAIL (eski goal şemaları G-20260910/11/13) — önceden var, dokunulmadı, sahibe not"},
  {"id": "B3", "kapsam": "disi", "not": "G-20260913-TARIH-SECICI(-R1) frontmatter'ları güncel harness şemasında INVALID_ACCEPTANCE/CHECKPOINT/STOP_CONDITIONS kodları üretiyor (B2'nin aynı baseline'ı) — R1'in kendisinde manifest'liydi, bu turda dokunulmadı"}
 ]}
```

Sonra dur — zarf gereği commit sonrası başka adım yok.
