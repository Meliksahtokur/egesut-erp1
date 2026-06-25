// Sort comparator testi — plan gereği atlandı (karar kapısı)
// Gerekçe: js/ui.js'te 11+ inline `.sort((a,b)=>...)` kullanımı var,
// comparator çıkarmak yüksek refactor riski taşır (her kullanım ayrı şema).
// Plan: "Comparator inline ve çıkarmak riskliyse bu testi atla, kullanıcıya not düş."
// Refactor kararı: gelecekte modülerleşme planında (jsconfig cross-file sonrası) ele alınabilir.
//
// Şu an placeholder test — dosyayı tutmak için. Tüm gerçek karşılaştırma ui.js'te inline.
const test = require('node:test');
const assert = require('node:assert');

test('sort: placeholder (atlandı, plan kararı)', () => {
  // Boş test dosyası commit edilmesin diye placeholder
  assert.ok(true, 'comparator refactor LSP modülerleşmesine bırakıldı');
});
