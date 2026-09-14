# E4 — Entegrasyon: TG1+U1 merge çakışma çözümü (teslim raporu)

- **Tarih:** 2026-09-14
- **İş:** `.ss/tasks/E4-entegrasyon-u1-cakisma.md` zarfı
- **Dal:** `agent/entegrasyon-tarih-surum` · Merge: `agent/tarihe-git-faz1` (TG1 + U1 Geçmiş UX, `19a2633`) → L1+L2+R1+TG1 (`c76fa31`)
- **Merge commit:** `0ba4d61` — `merge: TG1+U1 Gecmis UX → entegrasyon — damga 20260914-05, unit 938/938/0` (ebeveynler: `c76fa31` + `19a2633`)
- `git merge` / `git merge --abort` çalıştırılmadı; merge root tarafından başlatılmış haldeydi, yalnız çakışmalar çözülüp `git commit` ile bitirildi.

## 1. Çakışma çözümleri

Zarfta beklenen 2 dosya çıktı; başka dosya çakışmadı. Toplam 5 hunk (index.html'de 2, testte 3).

### 1.1 `index.html` — manifest linki (hunk 1/2, satır ~11)

- **HEAD:** `manifest.json?v=20260914-03` · **U1:** `manifest.json?v=20260914-04`.
- **Çözüm:** Tek satır `manifest.json?v=20260914-05`.

### 1.2 `index.html` — yerel script bloğu (hunk 2/2, satır ~2336)

- **HEAD (entegrasyon):** 25 script satırı, damga `-03` — U1 listesinden ekstra olarak
  `js/degisiklikler/etiketler.js`, `js/degisiklikler/diff.js`, `js/degisiklikler/degisiklikler.js` (L2) içeriyor.
- **U1:** 22 script satırı, damga `-04` — degisiklikler modülleri yok; dosya listesi HEAD'in alt kümesi
  (U1 tarafında yeni script satırı yok — satır-satır karşılaştırmayla doğrulandı).
- **Çözüm:** İki tarafın birleşimi = HEAD'in 25 satırlık listesi; tüm damgalar `20260914-05`'e çekildi.
  Böylece L2'nin Değişiklikler modülleri **ve** U1'in script seti korunmuş oldu.
- **Çakışma dışı doğrulama:** U1'in Geçmiş filtre/çip yapısı otomatik birleşmiş bölgede sağlam
  (`gecmis-filtre-satir` satır 757, `gecmis-tarihe-git` 750, `gecmis-gorunum-toggle` 736,
  `gecmis-tumu-wrap` 730); L2'nin `Log → Değişiklikler` satırı (`go-degisiklikler`, satır 823) ve
  `#pg-degisiklikler` sayfası (satır 835) duruyor.

### 1.3 `tests/unit/vaka-toplu-ac.test.js` — `it()` başlığı (hunk 1/3)

- İki taraf yalnız damga farklıydı (-03 / -04). **Çözüm:** `…her yerel script ?v=20260914-05 damgalı`.

### 1.4 `tests/unit/vaka-toplu-ac.test.js` — damga geçmişi yorumu + `damgasiz` filtresi (hunk 2/3)

- HEAD tarafında `-03` yorum satırı, U1 tarafında `-04` yorum satırı vardı.
- **Çözüm:** İki yorum satırı da korundu + bu merge için yeni satır eklendi:
  - `// 20260914-03: E3 entegrasyon — TG1 faz1 (tarihe-git) R1 entegrasyonuyla birleşti; …`
  - `// 20260914-04: U1 geçmiş UX — tek etiket haritası + dataset delegasyonu + katlama + gün özeti çipleri`
  - `// 20260914-05: E4 entegrasyon — TG1+U1 (Geçmiş UX) merge; damga tek değere çekildi` **(yeni)**
- `damgasiz` filtre regex'i `/\?v=20260914-05$/` oldu. Diğer kod satırları iki tarafta özdeşti.

### 1.5 `tests/unit/vaka-toplu-ac.test.js` — manifest damga-pin testi (hunk 3/3)

- **Çözüm:** Beklenen damga `manifest.json?v=20260914-05`.
- `eski` listesi = iki tarafın birleşimi (HEAD üst küme: `20260913-18`, `20260913-16`, `20260911-14`
  HEAD'deydi, korundu) + artık eskiyen iki damga başa eklendi: `20260914-04` (U1), `20260914-03` (E3).
  Tam liste: `20260914-04,-03,-02,-01, 20260913-18,-17,-16,-15, 20260911-14,-13, 20260909-12…-1,
  20260908-1, 20260907-4`.
- İki tarafın diğer tüm test eklemeleri korundu (değiştirilmedi).

## 2. Kabul ölçümleri (kendim ölçtüm)

| Kriter | Komut | Sonuç |
|---|---|---|
| Damga tek değer | `grep -o '?v=[0-9-]*' index.html \| sort \| uniq -c` | `26 ?v=20260914-05` + `1 ?v=` (yorumdaki çıplak `?v=` — zarfça hariç) ✅ |
| Çakışma işareti 0 | `grep -c '^<<<<<<<\|^>>>>>>>' index.html tests/unit/vaka-toplu-ac.test.js` | `index.html:0`, `tests/unit/vaka-toplu-ac.test.js:0` ✅ |
| Unit 0 fail | `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js` | **938 pass / 938 total / 0 fail** (suites 57, ~1.4 s) ✅ |
| `type="date"` 0 | `grep -rn 'type="date"' index.html js/` | eşleşme yok (exit=1 → 0 adet) ✅ |
| `go-degisiklikler` duruyor | `grep -n 'go-degisiklikler' index.html` | `index.html:823` ✅ |
| Playwright | — | **KOŞULMADI** (sahip kuralı) ✅ |
| Beyazlık/çakışma artığı | `git diff --check` | temiz (exit=0) ✅ |

Not: Unit çalıştırma worktree'de `node_modules` olmadığı için ana checkout'un `NODE_PATH`'i kullanıldı
(E3'teki gibi). `reports/` gitignore'da olduğundan rapor `git add -f` ile ayrı commitlendi.
