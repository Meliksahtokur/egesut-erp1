# E1 — Entegrasyon raporu: L1 (tarih seçici) + L2 (sürüm geçmişi) tek dalda

- Worker: entegrasyon-tarih-surum (glmf worker koltuğu) · 2026-09-13
- Zarf: `/home/melik/egesut-erp1/.ss/tasks/E1-entegrasyon-tarih-surum.md`
- Dal: `agent/entegrasyon-tarih-surum` — zincir `0601e63 (main) → 8a91839 (L2 merge, ROOT) → 598a180 (L1 merge, çakışma çözümü worker'da)`
- Merge yetkisi: worker koltuğunda `git merge` izin katmanınca reddediliyor (2 ölçüm; soru `d9cbdf30`); root cevabı ile merge'ler ROOT tarafından yapıldı, worker çakışma çözümü + tamamlama yaptı. Öncül karar: ask `e4b9de71` (2026-09-11, aynı engel).

## 1. Merge yapısı

```
598a180 merge: L1 tek global tarih seçici (entegrasyon, root; çakışmalar worker'da)
  parents: 8a91839 + 46abbc8          ← 2-parent merge commit (git log --format=%P kanıtı)
8a91839 merge: L2 sürüm geçmişi + diff arayüzü (entegrasyon, root)
  parents: 0601e63 + b2c2bfa
```

- L2 = `agent/surum-gecmisi-diff` @ `b2c2bfa` — temiz birleşti (root).
- L1 = `agent/tarih-secici-standardi` @ `46abbc8` — 3 dosya çakışmalı; çözüm aşağıda.

## 2. Çakışma çözümleri (dosya dosya)

### index.html — 2 blok
| Blok | HEAD (L2) tarafı | L1 tarafı | Karar |
|---|---|---|---|
| 1 (script bölgesi, auth.js…ui.js arası) | boş | `js/tarih/tarih.js` script'i | **L1 korunur** — yükleme sözleşmesi helpers→tarih→ui→forms |
| 2 (pedigree…app.js arası) | 3 `js/degisiklikler/*` script'i | boş | **L2 korunur** — degisiklikler app.js'ten önce |

Sonuç: iki dalın işlevi de ayakta; yük sırası kanıtlandı:
`2317 js/tarih/tarih.js → 2318 js/ui.js → 2319 js/forms.js … 2328-2330 js/degisiklikler/* → 2331 js/app.js`.

### .harness/references/ui-map.md — 1 blok
Base'deki "Canonical date selection" maddelerini L1 **yeniden yazmıştı** (tarihAlaniBagla / direct single-date / shared pure core / bilinen istisna), L2 ise eski maddeleri koruyup arkaya tüm "js/degisiklikler/" bölümünü eklemişti. Karar: **L1'in yeni maddeleri + L2'nin degisiklikler bölümü** (eski maddeler L1 tarafından süperseed edildiği için düşürüldü — içeriği L1 metninde yaşıyor).

### tests/unit/vaka-toplu-ac.test.js — 2 blok
- Damga-tarihçesi yorumları: **birleşim** — L1'in `20260913-15` + `20260913-16 (F3 kopya birleşmesi)` satırları ve L2'nin `20260913-16 (surum-gecmisi F3)` satırı, üçü de korundu.
- Eski-damga listesi: **birleşim** — `['20260913-15','20260911-14','20260911-13','20260909-12',…]` (zarfın verdiği listeyle birebir; L2'nin `-14` girişi + L1'in `-15` girişi, ortak kuyruk tek).

### js/ui.js (zarfta sayılmayan 4. kesişim dosyası — otomatik birleşti)
Farklı bölgeler: L2 `_detOzetHtml` (~2615, `dg-hayvan-degisiklikleri` guard'lı buton), L1 `openAnimalEdit`/`caseGunModalRender` (~2973/~6651). Birleşme sonrası iki tarafın içeriği de dosyada (grep: 1 + 3 hit).

## 3. Kabul ölçümleri (zarf adım 2-4)

**Adım 2 — çakışma işareti + damga:**
- `grep -rn '^<<<<<<<\|^>>>>>>>' index.html js/ tests/ .harness/` → **0 satır** (tüm repo taraması da boş).
- `grep -o '?v=[0-9a-z.-]*' index.html | sort | uniq -c` → **26× `?v=20260913-16`** + 1× bare `?v=` (bakım-notu yorumu, src değil).
- Eski damga taraması (`?v=20260913-15`, `?v=20260911-14` index.html/js/tests) → **0** (yalnız testin eski-damga listesinde geçer, olması gereken yer).

**Adım 3 — tam unit suite:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
- **857 pass / 1 fail / 57 suite / 0 skipped** (duration ~1.4 s).
- Tek kırmızı: `_gmGroupHtml` (`tests/unit/gecmis-pipeline.test.js:301`, `assert.ok(dun.includes('DÜN'))`) — **main baseline'ında da kırmızı olan date-bomb** (merge öncesi baseline koşumunda da tek kırmızı aynı test, gözlemlendi). Başka kırmızı YOK.

**Adım 4 — duman:**
- İki modülün script'leri index.html'de: `js/tarih/tarih.js` + 3× `js/degisiklikler/*` ✓ (yukarıda, 2317/2328-2330).
- Değişiklikler sayfası tarih filtresi kanonik bileşen: `js/degisiklikler/degisiklikler.js:455` → `tekTarihTakvimAc({` (kod okuması; modül başlığında da sözleşme satırı, :9). Modülün kendi unit'leri merge sonrası suite'te yeşil: `degisiklikler-diff.test.js`, `degisiklikler-etiketler.test.js` (857P içinde).

## 4. Sınırlar / notlar
- `git merge` worker koltuğunda izinli değil — merge'ler root'ta yapıldı (soru `d9cbdf30`); bu raporun kapsamı: çakışma çözümü + tamamlama + kabul ölçümleri.
- main'e dokunulmadı, push yapılmadı. Sahibin final testi bu dalın lokal sunucusunda.
- Yeni özellik/yeniden düzenleme yok; DB/migration dokunulmadı.
