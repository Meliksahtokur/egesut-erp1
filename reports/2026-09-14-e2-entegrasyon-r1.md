# E2 — R1 entegrasyon çakışma çözümü raporu (glmf worker)

- **Tarih:** 2026-09-14
- **Dal:** `agent/entegrasyon-tarih-surum` (worktree `1dddb562`)
- **Merge:** root başlattı (`agent/tarih-secici-standardi` @ `7d775c4`), çakışmada durdu; merge'u **ben başlatmadım** — yalnız çözdüm ve tamamladım.
- **Merge commit:** `ab8aed7` — `git commit --no-edit`, root'un hazır mesajı: *"merge: R1 tarih seçici revizyonu (entegrasyon, root; luna A6 KABUL)"*

## Çözülen dosyalar ve hangi taraftan ne alındı

### 1. `index.html` (1 hunk, script listesi)
- **HEAD (L2/E1) tarafı:** `js/degisiklikler/etiketler.js`, `js/degisiklikler/diff.js`, `js/degisiklikler/degisiklikler.js` script etiketleri (pedigree-controller ile app.js arasındaki sırayla) **KORUNDU** — R1 tarafında bu üç etiket yoktu (`git show agent/tarih-secici-standardi:index.html | grep -c degisiklikler` → 0).
- **R1 tarafı:** `?v=20260913-18` damgası **KORUNDU**.
- **Birleşim:** HEAD'in 25 satırlık liste yapısı (degisiklikler dahil) + tüm satırlarda R1'in `20260913-18` damgası.
- Çakışma dışı bölge zaten `-18`'di (ör. satır 11 `manifest.json?v=20260913-18`). `-16`/`-17` kalıntısı index.html'de **0**.

### 2. `tests/unit/vaka-toplu-ac.test.js` (2 hunk)
- **Hunk-1 (damga tarihçesi yorumu, ~satır 2291):** iki tarafın satırları **union** — HEAD'in iki `-16` satırı (F3 kopya birleşmesi + surum-gecmisi F3) + R1'in `-17` (F3 kopya birleşmesi) ve `-18` (R1 revizyon) satırları, 4 yorum satırı olarak korundu.
- **Hunk-2 (manifest damga + eski-damga listesi, ~satır 2640):**
  - Beklenti R1'den: `manifest.json?v=20260913-18`.
  - Eski-damga listesi **union** (19 eleman): R1'in `20260913-17`'si + HEAD'in `20260913-16`'sı (ikisi de artık eski) + HEAD'in R1 listesinde olmayan `20260911-14`'ü; geri kalan ortak.
  - `'20260913-17','20260913-16','20260913-15','20260911-14','20260911-13','20260909-12',…,'20260907-4'`

### Dokunulmayanlar (zarf şartı)
`.harness/references/ui-map.md`, `supabase/`, `js/gecmis.js`, `js/degisiklikler/*` — R1 adına hiçbirine dokunulmadı. DB yazımı yok. `git merge`/`git merge --abort` çalıştırılmadı.

## Kabul ölçümleri (zarfın 5 kriteri)

1. **`git diff --check`** → `TEMIZ` (çıkıtsız). Çakışma işareti grep'i:
   `grep -rn '^<<<<<<<\|^>>>>>>>\|^=======$' index.html js tests .harness` → **boş** (exit 1).
2. **`grep -c 'type="date"' index.html` → 0.** `?v=` dağılımı: `26 × ?v=20260913-18` (25 script etiketi + 1 manifest linki; artan 1 eşleşme satır 2307'deki `<!-- ?v= damgası: … -->` bakım yorumudur, attribute değil). Tek değer ✓.
3. **Unit suite:** `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js`
   → `tests 885 · suites 57 · pass 884 · fail 1`
   Tek kırmızı: `tests/unit/gecmis-pipeline.test.js:283 _gmGroupHtml` — `assert.ok(dun.includes('DÜN'))` — bilinen main-baseline date-bomb (E1'den beri aynı, dokunulmadı). E1 857P/1F idi → +27 R1 testi geldi (884P), beklentiyle uyumlu.
4. **Merge commit:** `git commit --no-edit` → `ab8aed7`, mesaj root'un hazır mesajı. `MERGE_HEAD` kalktı, çalışma ağacı temiz (yalnız `.ss/` board dosyası untracked).
5. **Rapor:** bu dosya — `git add -f reports/2026-09-14-e2-entegrasyon-r1.md`, ayrı commit, mesajda `E2`.

## Ek not
- Bayat damga taraması: `js/ui.js` içindeki iki `20260913-16:` satırı `?v=` damgası değil, satır-içi tarihçe yorumudur (değişikliğin hangi turda yapıldığını anlatır) — kod davranışını etkilemez, dokunulmadı.
- Merge commit'i root'un hazır mesajıyla atıldığı için mesaja worker imzası eklenmedi (`--no-edit` şartı).

**Sonuç:** 5/5 kabul ölçüldü ve geçti. Sonraki adım root'a ait (push / main birleştirme / final test). Worker durdu.
