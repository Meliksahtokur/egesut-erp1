// tests/unit/hayvan-takip-belge.test.js
// U2 sahip kararlarının belge kilidi (emsal: domain-rules-karar7.test.js): domain-rules §17 ve §20, ui-map, SPEC.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const oku = d => fs.readFileSync(path.join(__dirname, '..', '..', d), 'utf8');
const kurallar = () => oku('.harness/references/domain-rules.md');

/** §20'nin n numaralı maddesi: sonraki madde ya da dosya sonuna kadar, alt satırlar dahil. */
function madde20(n) {
  const bolum = kurallar().split(/^## 20\. /m)[1];
  const m = new RegExp(`^${n}\\. \\*\\*[\\s\\S]*?(?=^\\d+\\. \\*\\*|(?![\\s\\S]))`, 'm').exec(bolum);
  assert.ok(m, `§20.${n} bulunamadı`);
  return m[0];
}

test('HT-B-01: §20.2 Halsizlik hazır sebepler arasında', () => {
  assert.match(madde20(2), /İştahsızlık, Halsizlik, Diğer/);
});

test('HT-B-02: §20.5 Vaka yolu elle, tek düğme, yalnız muayenesi yapılan takibi kapatır', () => {
  const m = madde20(5);
  assert.match(m, /hiçbiri işaretli gelmez, kendiliğinden kapanmaz/, 'eski ilke duruyor');
  assert.match(m, /elle ve açık tek düğme/);
  assert.match(m, /yalnız muayenesi yapılan takibi kapatır/);
  assert.match(m, /öteki takipler yine sorulur/);
});

test('HT-B-03: §20.6 üçüncü sonuç Vaka; sonuçsuz kapanmaz ilkesi korunur', () => {
  const m = madde20(6);
  assert.match(m, /Sonuçsuz kapanmaz/, 'ilke');
  assert.match(m, /`Vaka`/, 'üçüncü sonuç');
  assert.match(m, /yeni vaka ya da hayvanın mevcut aktif vakası/);
  assert.match(m, /görev `tamamlandi`, takip `VAKA`/);
  assert.match(m, /2026-10-31/, 'sahip kararı tarihi');
});

test('HT-B-04: §20.7 bilinen sınırlar için §20.10\'a bağlanır', () => {
  assert.match(madde20(7), /§20\.10/);
});

test('HT-B-05: §17 saat alanı standardı: yardımcı, tek çip seti, iki istisna, boşun anlamı', () => {
  const bolum = kurallar().split(/^## 17\. /m)[1].split(/^## 18\. /m)[0];
  const m = bolum.split(/^### Saat alanı standardı/m)[1];
  assert.ok(m, '§17 alt başlığı yok');
  assert.match(m, /2026-10-31/, 'sahip kararı tarihi');
  for (const s of ['`saatAlaniHtml`', '`HIZLI_SAATLER`', '`devam-ertele-saat`', '`pu-saat`', 'Boşun anlamı değişmez']) {
    assert.ok(m.includes(s), s);
  }
});

test('HT-B-06: ui-map sonuç penceresi üçüncü düğme, aktif vaka listesi, saat yardımcısı', () => {
  const u = oku('.harness/references/ui-map.md');
  for (const s of ['`index.html:ht-so-vaka-ac`', '`index.html:ht-so-vakalar`', '`js/hayvan-takip.js:htAktifVakaHtml`',
    '`js/hayvan-takip-pencere.js:htVakaBagla`', '`js/utils/helpers.js:saatAlaniHtml`', '`js/utils/helpers.js:saatAlanlariKur`']) {
    assert.ok(u.includes(s), s);
  }
});

test('HT-B-07: SPEC U2 kararları eki', () => {
  const ek = oku('docs/plans/2026-10-31-hayvan-takip-SPEC.md').split(/^### U2 kararları/m)[1];
  assert.ok(ek, 'ek yok');
  for (const s of ['Halsizlik', '`saatAlaniHtml`', '`Vaka`', '`hayvan_takip_muayene_vaka`']) assert.ok(ek.includes(s), s);
});
