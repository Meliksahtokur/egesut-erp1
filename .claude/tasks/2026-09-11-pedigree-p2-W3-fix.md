# W3-fix — luna F1 + F2: eksik test kapsamı + stub fixture kontratı

Bağımsız luna review (`.claude/reviews/2026-09-11-pedigree-p2-lead-review.md`):

- **F1 [fake-arm, major]:** goal G3d "adapter/style/view/controller unit testleri
  yeşil" diyor; diff'te yalnız `pedigree-adapter.test.js` var. Controller/view/style
  testi yok; `stub-backend.js`'e eklenen RPC çağrı sayaçlarını HİÇBİR test iddia
  etmiyor (`tests/support/app.js` import etmiyor) — sayaçlar ölü alet.
- **F2 [fake-arm, major]:** stub fixture P1 kontratını ihlal ediyor:
  `PED_GD`/`PED_GGD` `farm_animal` ama `farm_animal_id: null` (üretim invariant'ı:
  farm düğümde NOT NULL — foundation migration'ı 46-50). `pedigreeFixtureForNode()`
  yalnız `focus`'u değiştirip grafı aynı bırakıyor; bilinmeyen hayvan id sessizce
  odak grafiğe düşüyor. Controller (242-249) kind+id ikilisiyle farm açtığı için
  şekilsiz düğümler external sheet'e yönleniyor — yanlış yönlendirme test ediliyor.

## Düzeltmeler

1. **F2 — stub kontratı:** fixture düğümleri kontrat-şekilli olsun (farm düğümlere
   gerçekçi `farm_animal_id`, external'lar kendi alanlarıyla); `pedigreeFixtureForNode`
   **yeniden merkezlesin** (istenen odak için anlamlı bir alt graf — en azından odak
   değişince düğüm/kenar kümesi değişsin); bilinmeyen hayvan id **sessiz fallback
   değil** açık hata/boş-sonuç dönsün (RPC kontratındaki davranışla uyumlu biçimde).
2. **F1 — test kapsamı (G3d):** eksik birim testleri yaz:
   - `pedigree-view.test.js`: init/destroy yaşam döngüsü, layout konfigürasyonunun
     (breadthfirst) cytoscape'a iletilmesi — `window.cytoscape` stub'ıyla,
   - `pedigree-style.test.js`: stil konfigurasyonunda focus/farm/external ayrımı
     (selektör/özellik varlık ve ayrışması), tema token uyumu,
   - `pedigree-controller.test.js`: lazy aktivasyon (Soy ilk aktive olmadan RPC yok),
     stale-response guard (`_detOpenId`), farm node → openDet yönlendirmesi,
     external node → sheet, **+2 kuşak** parametre değişimi, rozet davranışı,
   - sayaçlar artık iddialı: en az bir controller testi stub-backend sayaçlarını
     doğrulamalı (ilk aktivasyon 1 RPC, tekrar 0 — cache hit yolu dahil).
3. Mevcut adapter testlerin korunur; F2 düzeltmesi mevcut testlerin varsayımlarını
   kırıyorsa testleri yeni kontrata göre güncelle (sessizce atma, güncelle).

## Kabul

- `npm run test:unit` → yeni testler yeşil + mevcut suite regresyonsuz
  (known-red gecmis-pipeline hariç). Çıktı özeti teslim notunda.
- Teslim notunda subagent review notu (şerit kuralı).

## Sınırlar

- `tests/support/stub-backend.js` + `tests/unit/pedigree-*.test.js` (+ gerekirse
  `tests/support/app.js`'e sayaç export'u). `js/` ürün koduna yalnız F2 gerçekten
  ürün tarafında bir kusursa dokun — önce stub tarafını düzelt, ürün değişikliği
  gerekçesiz olmasın. `index.html` DAMGASI DOKUNMA (?v= lead kararı).
- RPC/migration (W1), pedigree-api.js (W2) DOKUNMA. PROD YASAK.

## Teslim

- `idle/pedigree-p2-W3` üzerine yeni commit. Kırıntı: merkezî
  `/home/melik/egesut-erp1/.crumbs/pedigree-p2-w3.jsonl`.
