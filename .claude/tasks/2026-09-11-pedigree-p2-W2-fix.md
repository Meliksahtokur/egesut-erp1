# W2-fix — demo kapısı bulguları: cache hit-path + meta.cached

Lead demo kapısı (G5) canlı ölçümü iki bulgu çıkardı — İKİSİ DE `js/pedigree/pedigree-api.js`
yüzeyinde. Zarfta 3 adım var, hepsi dar.

## Ölçülen kanıt (lead paneinde, 2026-09-11)

1. Aynı hayvan 3 kez açıldı → `performance` kaynak sayacı 3 kez
   `/rest/v1/rpc/pedigree_subgraph_for_animal` gösterdi. Cache hit-path hiç çalışmıyor:
   network-first ("RPC koşulsuz denenir") kurmuşsun. Plan Task 4 kabul kilidi
   "**ikinci erişim cache'ten**" ve goal G5 "**zaten açılmış görünüm memory cache'ten**"
   online durumda karşılanmıyor (yalnız offline fallback var — o çalışıyor ✓).
2. W3'ün kontrolcüsü önbellek rozetini `meta.cached` sinyalinden bekliyor; RPC meta'sında
   (W1 kontratı: ancestor_depth/descendant_depth/truncated) ve wrapper dönüşünde `cached`
   yok → rozet asla yanmaz (ölü sinyal).

## Düzeltmeler

1. **Cache-first hit-path:** anahtar cache'te SICAK ve invalidate edilmemişse ağ çağrısı
   YAPMA, cache'teki payload'ı döndür. Ağ yalnız cache miss'te denenir. Offline fallback
   semantiği aynen kalır (miss + ağ hatası → açık "Sunucuya ulaşılamıyor" — bu bugün
   doğru çalışıyor, bozma). Full-flush invalidation yüzeyin zaten var — değiştirme.
2. **`meta.cached` mührü:** cache'ten servis edilen payload'ın `meta.cached` alanını
   `true` olarak işaretle (wrapper katmanında; RPC/W1 migration'a DOKUNMA). Ağdan
   gelenlerde alan ya yok ya `false` — tutarlı olsun.
3. **Testlerle kilitle:** (a) ikinci erişim ağ çağrısı atmıyor (stub sayaçla: ilk çağrı
   1, ikinci erişim hâlâ 1); (b) cache-servisli payload'da `meta.cached===true`, ağ
   payload'unda `false`/yok; (c) invalidate sonrası yeniden ağ; (d) offline miss hâlâ
   açık hata. Mevcut testlerinle uyumsuz kalan VARSAYIM davranış testlerini yeni ölçüme
   göre güncelle (network-first artık kabul değil).

## Kabul

- `npm run test:unit` → yeşil + mevcut suite regresyonsuz (known-red gecmis-pipeline hariç).
- Teslim notunda: değişen davranışın tek paragraf özeti + subagent review notu (bulgu yok /
  bulgu listesi — şerit kuralı aynen geçerli).

## Sınırlar

- Yalnız `js/pedigree/pedigree-api.js` + `tests/unit/pedigree-{api,cache}.test.js`.
- RPC/migration (W1), frontend (W3), index.html, vendor DOKUNMA.
- PROD YASAK.

## Teslim

- `idle/pedigree-p2-W2` üzerine yeni commit (rebase gerekmez; lead merge eder).
- Kırıntı: `/home/melik/egesut-erp1/.crumbs/pedigree-p2-w2.jsonl` (merkezî dosya — bu kez
  oraya yaz; önceki turdaki kırıntılarını lead merkezî depoya kopyaladı, sapma kapandı).
