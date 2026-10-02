# e2e triyaj DONE — ovsync-takip.spec.js 12/12

Kanıt dizini: /home/melik/egesut-erp1/runs/2026-10-02-ovsync-sonrasi/e2e-triyaj-kanit/ (loglar A1 B1 A2 B2 D1 F1 F2, *.olc, spec-fix.diff)
Düzeltilen dosya (worktree, commit YOK): /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/tests/e2e/ovsync-takip.spec.js (+9 satır)

## 1) A/B tablosu (aynı demo DB; A=`git archive ffdc342`, B=`git archive 626e3ee`; ikisinde de 626e3ee'nin düzeltilmiş spec'i; ayrı port 8201/8202; seri)
| Koşum | Ağaç | Sonuç | Kırmızılar |
|---|---|---|---|
| A1 | ffdc342 | 11/12 | T-20 |
| B1 | 626e3ee | 10/12 | T-01, T-20 |
| A2 | ffdc342 | 10/12 | T-01, T-20 |
| B2 | 626e3ee | 10/12 | T-01, T-20 |
| D1 | 626e3ee + tanı (3 sn bekleme + IDB dökümü) | 12/12 | — |
| F1 | worktree + spec düzeltmesi | 12/12 | — |
| F2 | worktree + spec düzeltmesi | 12/12 | — |

Her koşum sonrası `E2E-% Aktif` = 0 [OBSERVED olc.cjs: A1,B1,A2,B2,F1,F2 hepsi `E2E-% AKTIF 0`].

## 2) T-84/T-85 timeout — ürün regresyonu DEĞİL
- 4 A/B koşumunun hepsinde (A1,B1,A2,B2: iki ağaçta ikişer) T-84/T-85 ve T-03/T-50 PASS; F1/F2'de de PASS [OBSERVED].
- Önceki w2/w3 timeout'ları yalnız çalışma ağacında, koşum sırasında ui.js/demo.js düzenlenirken ve demo'ya 20261002000002 uygulanırken görülmüştü [CONFIRMED k3-TB6-DONE.md §A/B]. Şimdi (ağaç sabit, migration demo'da kalıcı) 626e3ee'de tekrarlanmıyor → geçici ortam/ağaç-kayması [INFERRED]. TB-2/TB-3/TB-5 değişikliklerinden regresyon kanıtı yok; bisect gereksiz (koşul "yalnız B'de kırmızı" sağlanmadı).

## 3) T-01/T-20 — kök neden: TEST bekleme koşulu eksik (ürün değil)
- Belirti: `devamSeciciAc` içinde `#ureme-body .hist-row` "E2E-TAKIP-PW-b" 10 sn'de görünmüyor, sayfada "Arama sonucu yok". Hem ffdc342 hem 626e3ee'de (A1/A2/B1/B2) → ürün farkı değil.
- Kanıt [OBSERVED D1.log]: Üreme sekmesine girip arama yapıldığında t=0 ve t=3 sn'de IDB `tohumlama` toplam 0 ve `hayvanlar` boş, state.animals 0 — ilk pull bitmemiş. `_uremeTohumlama` (ui.js:~7944) listeyi `idbGetAll('tohumlama')` + `getState('animals')`'dan kurar [CONFIRMED]; ikisi dolmadan filtre boş döner. Pull tamamlanınca satır görünür (D1'de 3 sn ekstra bekleme ile 12/12).
- Neden "flake": pull süresi koşumdan koşuma değişiyor; bazen 10 sn'lik görünürlük beklemesinin içine sığıyor (A1: T-01 geçti), bazen sığmıyor. Teste hayvanın IDB'ye düştüğü anı bekleme koşulu hiç konmamıştı (aynı kalıp `idbGorevBekle` muayene akışlarında vardı).
- Düzeltme (uygulandı): `devamSeciciAc` başında seed `tohId` + `hayvanId`'nin IDB'de (tohumlama + hayvanlar) görünmesine kadar `expect.poll` (45 sn). Diff: `e2e-triyaj-kanit/spec-fix.diff`:

```diff
+  await expect.poll(async () => page.evaluate(async ([tid, hid]) => {
+    if (!window.idbGetAll) return false;
+    const t = (await window.idbGetAll('tohumlama')).some(x => x && x.id === tid);
+    const h = (await window.idbGetAll('hayvanlar')).some(x => x && x.id === hid);
+    return t && h;
+  }, [S[ad].tohId, S[ad].hayvanId]), { timeout: 45000, intervals: [500, 2000] }).toBe(true);
```
- Sonuç: F1 ve F2 ardışık 12/12 [OBSERVED].

## Ürün gözlemi (düzeltme yok, raporlu)
- İlk açılışta IDB pull > 3 sn sürüyor; pull bitene kadar Üreme/Tohumlama listesi "Arama sonucu yok" gösteriyor (boş IDB ≠ gerçekten sonuç yok; "yükleniyor" ayrımı yok). Gerçek kullanıcı etkisi UNKNOWN; ürün değişikliği kapsam dışı.

## Kurallar
Yalnız demo DB; prod dokunulmadı; git add/commit yok; /tmp kullanılmadı (çalışma ~/tmp/triyaj); sunucular kapatıldı. İç review (code-reviewer, yalnız git diff, tek tur): "birleştirilebilir". Önerilen opsiyonel sağlamlaştırma (uygulanmadı, 2 tur yeşil sonrası dokunulmadı): poll callback'ine try/catch→false (navigasyonda context-destroyed). Seed beforeAll'da, sayfa açılışından önce → "pull tetiklenmez" riski yok; poll 45 sn < test timeout 60 sn.
E2E aktif ölçümü son: `E2E-% AKTIF 0` (3 satır: TAKIP-PW b Satıldı [FK nedeniyle bilinçli kalıntı], 2 UITUR Satildi).

SONUC: YESIL_12
