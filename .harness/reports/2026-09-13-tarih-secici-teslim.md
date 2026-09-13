# Teslim Raporu — G-20260913-TARIH-SECICI (tek kanonik tarih seçici standardı)

**Dal:** `agent/tarih-secici-standardi` · **Base:** `621f12a` · **Durum:** TAMAM — kapanışta (2026-09-13)

Not: Owner görev dosyası rapor yolunu `reports/…` istedi; `reports/` gitignore'da olduğu için (`.gitignore:122`) repo'nun izlenen rapor yüzeyi `.harness/reports/` kullanıldı. Root relocate edebilir.

## Faz başı commit SHA'ları

| Faz | Kim | Worker teslim | Lead merge | Kanıt |
|---|---|---|---|---|
| F1 | W1 (glmf) | `73a6a40` + rapor `ff70ebd` (dal -W1) | `c220b0f` | lead mekanik 824/823/1; subagent denetim KABUL (4 DÜŞÜK; 3'ü F3/F4'e taşındı, odak UX owner) |
| F2 | W2 (glmf) | `416886a` + rapor `e462b2a` (dal -W2) | `6dda32f` | lead mekanik 824/823/1 + type="date"=0; subagent denetim KABUL (1 ORTA→F3, 3 DÜŞÜK) |
| F3 | W3 (glmf) | `243e0ae` + rapor `529f467` (dal -W3) | `56da4a6` | codex denetim (0837fa8): 7 madde TEMİZ, 2 DÜŞÜK (yorum satırı lead dokunuşuyla giderildi `f12e8b5`) |
| F4 | LEAD (root emriyle) | `1702126` + luna çözümleri + rapor (bu dal) | kapanış `merge:` commit'i | luna (codex max, f7ce14e): KRİTİK 0, ORTA 7, DÜŞÜK 1 → 6 düzeltildi, 1 beyan |

## Kabul kriterleri (root yeniden ölçecek)

1. **`type="date"` sayısı 0** — `grep -rn 'type="date"' index.html js/` → ürün kodunda 0 eşleşme (tek kalan eşleşme muhafız testinin kendi regex metnidir: `tests/unit/tarih-saf.test.js:523`). Bilinçli istisna: gizli taşıyıcının runtime `.type='date'` ataması (js/ui.js TEK nokta — modal.js auto-fill kancası; muhafız tüm js/ ağacında toplam=1'e pinli).
2. **Unit suite yeşil** — `node --test tests/unit/*.test.js` → **836/835/1**; tek kırmızı `_gmGroupHtml` (`gecmis-pipeline`), base `621f12a`'da da kırmızıydı. Kök neden (luna + W2/W3 review'ları): `js/gecmis.js:_gmGroupLabel` gerçek `new Date()`'ten DÜN türetiyor — **date-bomb**, bu paketin kapsamı dışı, onarım adayı.
3. **Saf katman testleri** — `tests/unit/tarih-saf.test.js` 40 test: elle giriş parse (geçerli/geçersiz/2 hane yıl/mm/dd tuzağı `05.02.2026`→`2026-02-05`), yıl değişimi, min/max, ay-grid çekirdeği (1970 öncesi dahil; Hinnant), kapaliGun/temizlenebilir DOM davranışı (F1 carry-over), F4 muhafızları (block-comment soyucu + Date.now + type="date" özyinelemeli tarama + taşıyıcı istisna pini + ad-aileri beyaz listesi). **Red-before kanıtı:** `.claude/reviews/2026-09-13-tarih-secici-f4-red-before.log` (3 enjeksiyon → FAIL; geri alınca yeşil).
4. **Playwright** — `tests/tarih-secici.spec.js` (W2): mobil 412×915 hasTouch + `en-US` locale; b-tarih/a-dt/i-tarih TR takvim açar, kaydedilen değer ISO doğru; **red-before kanıtlı** (taban `79b104c`'te 4/4 KIRMIZI, F2 sonrası 4/4 YEŞİL); demo-gate (`PLAYWRIGHT_DEMO_MODE` + storageState), sıfır DB yazımı (submit yok). Regresyon e2e: gece-tarih + sutten-kes + offline-kuyruk 9 passed/1 skipped/0 failed; kritik-akis 2 kırmızı tabanda da kırmızı (önceden var olan, veri-bağımlı).
5. **Çoklu modallar davranış değişmedi** — bcTakvim (W13 fix) ve caseGunModalRender ortak çekirdeğe geçti; codex F3 denetimi: 1900-2100 2.412 ay karşılaştırmasında eski `Date` matematiğine karşı 0 sapma (eski kod 1-3 yıl aralığında YANLIŞTI — yeni çekirdek düzeltiyor); 3 davranış delta'sı beyanlı (açılış ayı = değerin ayı; aralık-dışı tık sessiz; Onayla min/max yeniden doğrulaması — iyileştirme). W13 modal testleri yeşil; unit 836/835/1.
6. **Bu rapor** — dolduruldu (SHA'lar, grepler, testler, riskler).

## Grep kanıtları (kapanış, lead ölçümü — kendi dalında)

- `type="date"` (index.html + js/): **0** (ürün kodu)
- `bcTarihTakvim`: **0** ürün/test kodunda (tek eşleşme muhafız testinin kendi regex metni)
- `?v=` damga: **23× `20260913-16`** TEK değer (script 22 + manifest.json link)
- F4 runtime dokunuşu (ui.js UTC fix) → damga güncel değerle uyumlu; ayrı bump gerekmedi (damga F3'te `20260913-16`'ya alınmıştı, F4 commit'leri aynı paket içinde)

## Test çıktıları (lead bağımsız ölçümler)

- F1 sonrası: 824/823/1 · F2 sonrası: 824/823/1 · F3 sonrası: 831/830/1 · F4+luna sonrası: **836/835/1** — tümü tek kırmızı = bilinen date-bomb; sıfır regresyon.
- Playwright (worker ölçümü, docker `mcr.microsoft.com/playwright:v1.58.2-noble`): red-before 4/4 → 4/4 yeşil; regresyon 9p/1s/0f.

## Kalan riskler / açık kalemler (owner)

1. **cx-tarih/sk-tarih `max=bugun` + bv-tarih tek-aşı hizası** — davranış değişikliği, OWNER ONAYI bekliyor (domain-rules §17; istenmezse `TARIH_ALANLARI`'nda tek satır geri alma).
2. **`gecmis` date-bomb onarımı** — bilinen kırmızının kök nedeni `_gmGroupLabel` gerçek saat; paket dışı, ayrı iş.
3. **El girişi odak kaybı** (hata re-render'ında; yazılan metin korunur) — nit UX, owner kararı.
4. **Guard statik sınırları** (luna BULGU-7 beyanı): string-içi gizli ihlal ve isimsiz closure kopyası statik muhafızı aşar; isim-beyaz-listesi + çekirdek-çağrı pinleri pratik engel, %100 kanıt değil.
5. **E2e `kritik-akis` 2 kırmızı** — tabanda da kırmızı (önceden var olan, veri-bağımlı); paket dışı.

## Altyapı notları (root)

- `ss-wait` bekleyicileri bu oturumda **5 kez** low-memory kill yendi (RAM 20/30Gi + swap 30/64Gi doluyken); `report-on-branch` ölçütüyle elle git kontrolü + stop-hook döngüsü kullanıldı.
- `ss-worker-codex` pty ister ("stdin is not a terminal") — claude koltuğundan codex koltuğu `superset workspaces create --agent <codex-uuid>` ile açıldı (aynı sonuç).
- `superset agents list --local` eski kısa agent id'sini tanımadı; tam UUID gerekli.
- Manifest satır-içi yorum tuzağı: harness parser'ı `key  # yorum` formunu eleman metnine katıyor → MANIFEST_VIOLATION; tüm manifest yorumları kaldırıldı (kök fix).
- W2 worktree kalıntısı: `agent/tarih-secici-standardi-W2` klasörü Playwright docker'ının root-sahipli `test-results/.last-run.json` yüzünden tam silinemedi (git kaydı düştü); temizlik root tarafında (sudo/docker).
- PreToolUse blast-radius hook'u: GitNexus indeksi bayat (`openAnimalEdit` bulunamadı) → gerçek analiz LSP findReferences ile yapıldı; hook `/tmp/blast-radius-done` işareti analiz sonrası yazıldı.

## Root hasat haritası (teslimde neler nerede)

| Öğe | Yer | Not |
|---|---|---|
| Paket dalı | `agent/tarih-secici-standardi` (bu dal) | main'e DOKUNULMADI; push yok |
| Goal kaydı | `.harness/goals/2026/G-20260913-TARIH-SECICI.md` | frontmatter `report:` bu dosya; kapanışta status done |
| Faz teslim raporları | `.claude/reviews/2026-09-13-tarih-secici-f{1,2,3,4}-teslim.md` | dalda commit'li |
| F3 denetim + luna raporları | `.claude/reviews/2026-09-13-tarih-secici-{f3-denetim,luna-review}.md` | `agent/tarih-secici-denetim` dalından kapanış merge'iyle geldi |
| Kırıntılar | `.crumbs/tarih-secici-standardi.jsonl` (worktree, gitignored) | hasatta kopyalanmalı |
| Lead board | `.ss/tarih-secici-standardi-BOARD.md` (worktree, local) | çalışma aracı, kanıt değil |
| Worker çalışma dalları | `agent/tarih-secici-standardi-W1..W3` + `agent/tarih-secici-denetim` | root kapatır (lead SİLMEZ); W2 workspace kalıntı klasörü yukarıda |
| Owner görev zarfı | `/home/melik/egesut-erp1/.ss/tasks/L1-tarih-secici-standardi.md` (workspace DIŞI) | ana checkout'ta |
