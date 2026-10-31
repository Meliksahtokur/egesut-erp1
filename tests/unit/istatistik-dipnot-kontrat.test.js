'use strict';
// Kontrat: görünür uyarı (S4) sunucunun dipnot metnine köke bağlı (grafikDipnotAyir). Metin migration'da değişirse
// uyarı sessizce kapalı Ayrıntı'ya düşerdi; bu test metni gerçek SQL'den okur. Yapıya bağlanır, metin köküne değil:
// M4 = ilaç kırılımı koşullu dipnot, M5 = v_dip_son. Daha yeni bir migration fonksiyonu yenilerse o okunur.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const KOK = path.join(__dirname, '..', '..');
const GOC = path.join(KOK, 'supabase', 'migrations');
vm.runInThisContext(fs.readFileSync(path.join(KOK, 'js/istatistik/cumle.js'), 'utf8'), { filename: 'cumle.js' });
const { grafikDipnotAyir } = require(path.join(KOK, 'js/istatistik/grafik.js'));

const dosya = fs.readdirSync(GOC).filter(f => f.endsWith('.sql')).sort()
  .filter(f => fs.readFileSync(path.join(GOC, f), 'utf8').includes('v_dip_son :=')).pop();
const sql = fs.readFileSync(path.join(GOC, dosya), 'utf8');

function yakala(desen, ad) {
  const m = desen.exec(sql);
  assert.ok(m, `${ad} dipnotu ${dosya} içinde bulunamadı`);
  return m[1];
}

const ORTUSME = yakala(/v_kir = 'ilac'[\s\S]*?THEN\s+v_dip_on := v_dip_on \|\| '([^']+)'::text/, 'M4');
const GOZLEM = yakala(/v_dip_son := ARRAY\['([^']+)'\]/, 'M5');
// Kalan tüm v_dip_on dipnotları: görünür satıra sızmamalı.
const OTEKI = [...sql.matchAll(/v_dip_on := v_dip_on \|\| (?:format\()?'([^']+)'/g)].map(m => m[1]).filter(d => d !== ORTUSME);

test('kontrat_kaynak_son_migration', () => {
  assert.strictEqual(dosya, '20261017000002_stat_atolye_seri.sql', 'fonksiyon yenilendiyse bu satır bilinçli güncellenir');
  assert.ok(OTEKI.length >= 6, `öteki dipnotlar okunmadı: ${OTEKI.length}`);
});

for (const durum of ['tamam', 'kontrast_yok']) {
  test(`kontrat_iki_uyari_gorunur_${durum}`, () => {
    const { uyari, kalan } = grafikDipnotAyir({ dipnot: [...OTEKI, ORTUSME, GOZLEM] }, durum);
    assert.strictEqual(uyari, `${ORTUSME} ${GOZLEM}`);
    assert.deepStrictEqual([...kalan], OTEKI, 'öteki dipnotlar Ayrıntı\'da, uyarı tekrarlanmaz');
  });
}

test('kontrat_cizilmeyen_kartta_uyari_yok', () => {
  const { uyari, kalan } = grafikDipnotAyir({ dipnot: [ORTUSME, GOZLEM] }, 'fiyat_yok');
  assert.strictEqual(uyari, '');
  assert.deepStrictEqual([...kalan], [ORTUSME, GOZLEM]);
});
