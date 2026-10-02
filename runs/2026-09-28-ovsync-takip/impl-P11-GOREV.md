# impl-P11 — GOREV zarfı: Birim test kapanışı — kalan boşluklar + kapsama matrisi sahipliği

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P11** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:660-683` (MADDE DRIFT KAPISI: yalnız P11)
- **Önkoşul:** P4–P10 tamamı (P10 çağrı noktaları finalize olduktan sonra bu zarf koşar).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P11-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P11-DONE.md`

## Halihazırda teslim (yeniden yazma — yalnız DONE'da referansla)

Envanter (mimar ölçümü 2026-09-30 23:20, grep kanıtlı):
- RPC_TABLES invariant + H8 (40P01/55P03 mesaj + retry-YOK) → `tests/unit/ovsync-api.test.js:62,197`
- Eşik-sızıntısı (21/50/55 yalnız esikler akışı) → `tests/unit/ovsync-render.test.js:639`
- Kalem 12 sınır caseleri → P9b-yardımcı (`gunFarkiEtiket` 7/7, `ovsync-takip.test.js` içinde)
- Offline etiket / sessiz boş YOK → `tests/unit/ovsync-gezinti.test.js` (P5/P6)
- Kırmızı iskeletler P4-P10'da madde içi TDD ile teslim (P11'in "önce yazılır" hükmü maddeler arası dağıtıldı — kabul planın kendi bagimlilik satırıyla uyumlu).

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `tests/unit/ovsync-takip.test.js` (MODIFY — **D3 secim-tablo senkron kilidi**: yeni test)
2. `tests/unit/ovsync-api.test.js` (MODIFY — invalidate envanter NOKTALAR listesine P9/P10 çağrı noktaları; `:269` testi açıkça "P9/P10 çağrıları buraya düşecek" diyor)
3. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P11-DONE.md` (create)

## Görev

1. **D3 — secim-tablo senkron testi (plan.md:674 birebir):**
   `_muayeneSecimleri('GEBELIK_KONTROL')` = {GEBE, OVSYNC, PG, TAKIP, ERTALE};
   `_muayeneSecimleri('TAKIP_MUAYENE')` = {GEBE, OVSYNC, PG, ERTALE} (TAKIP yok).
   Test, migration dosyasındaki (`supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql`)
   DB CASE metnini OKUYARAK kilitler — iki kaynak (UI yardımcısı ↔ migration CASE) arası
   birebirlik; migration metni değişirse test kırılmalı. Kaynak okuma deseni:
   `tests/unit/ovsync-api.test.js` içindeki dosya-okuma testlerinden (fs.readFileSync + REPO kökü).
2. **Invalidate envanter genişletmesi:** `ovsync-api.test.js:269` NOKTALAR listesine
   P9'un teslim ettiği çağrı noktaları (ovsyncBaslat/protokolIptal zaten listede;
   P9'un yeni noktaları: muayene sonuç akışı → `tohumlamaBosVeDevam` çağıran ui.js/forms.js
   yüzeyleri, `_pgKapiBosAtaUygula` gövdesi) + P10'un teslim ettiği noktalar
   (impl-P10-DONE.md'den envanter çıkarılır — TAKIP_ACIK catch'leri invalidate
   üretmezse listeye GİRMEZ; yalnız gerçek `_ovsyncTakipInvalidate` çağıran yüzeyler).
   Listenin genişletilmesi grep-kanıtlı olacak; DONE'da nokta→dosya:satır tablosu.
3. **Kapsama matrisi sahipliği (plan.md:681 kabul):** plan.md:725+ tablosunun
   T-01..T-73 satırlarını DONE'da katman sahipliği özetine çevir (DB/PW/UNIT/İNSAN
   sayıları + P11'e düşen satırların yeşil kanıt dosyaları). Yeni artefakt DOSYA YOK —
   DONE bölümü olarak.
4. Tüm süit yeşil: `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/`
   (1357→1383'ten sonra P10'un ekledikleriyle; 3 pre-existing kırmızı hariç yeni kırmızı YOK).

## Kabul ölçütleri

1. D3 testi yeşil VE migration-CASE okuyarak kilitliyor (test gövdesinde fs.readFileSync kanıtı).
2. Invalidate envanter listesi P9/P10 sonrası kaynakla senkron; her nokta grep-kanıtlı.
3. Kapsama matrisi özeti DONE'da; T bazında katman + sahipli P + kanıt dosyası.
4. Tam süit: yeni kırmızı yok (3 pre-existing hariç); `node --check` değişen JS; `git diff --check` temiz.

## Yasaklar

- js/ kaynak dosyalarına yazma (yalnız test dosyaları); mevcut yeşil testleri bozma;
  migration dosyasına dokunma; commit atma; PROD; `.ss/`, `main`; sessiz varsayılan;
  2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P11-DONE — TAMAM|KISMI|BLOKE` · D3 kanıtı (test çıktısı + migration satırı) ·
invalidate nokta tablosu · kapsama matrisi özeti · tam süit çıktısı · açık kalem.
