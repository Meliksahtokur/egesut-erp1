// tests/unit/ovsync-seans-panel.test.js — C4 (cila2): K8 ovsync seans sunumu GERİ ALINDI
// Sahip: "ovsync seansları ui sabahkinden farklı … ana listeye monte etmişler, ben böyle
// bir şey istemedim; sabahki yeterli" → e205302+4fbd2db sunumu 1f01e8b hâline döndü.
// Bu dosya eskiden K8 sunumunu kilitliyordu; artık GERİ DÖNÜŞÜ kilitler.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const { loadExtractedFunction } = require('./support/loadModule.js');

const _rozetTopla = loadExtractedFunction('js/ui.js', '_rozetTopla');
const src = fs.readFileSync('js/ui.js', 'utf8');

test('C4-1: _rozetTopla 2 kaynağa döndü — 3. argÜman (seans sayısı) yok sayılır', () => {
  assert.strictEqual(_rozetTopla(3, 2), 5);
  assert.strictEqual(_rozetTopla(3, 2, 4), 5, 'K8 3-kaynak çağrısı bilinçli olarak yok sayılır');
  assert.strictEqual(_rozetTopla(0, 0), 0);
});

test('C4-2: panelde "🧪 Ovsync Seansları" bölümü ve yardımcıları YOK (kaynak kilidi)', () => {
  assert.ok(!src.includes('_ovSeansBolumHtml'), 'bölüm yardımcısı yok');
  assert.ok(!src.includes('_ovSeansSatirHtml'), 'satır yardımcısı yok');
  assert.ok(!src.includes('_dkInsanOkur'), 'dk-okuyucu yardımcısı yok');
  assert.ok(!/Ovsync Seansları/.test(src), 'bölüm başlığı UI kaynağında yok');
  assert.ok(!/rpc\('ovsync_seans_uyarilari'/.test(src), 'UI artık RPC çağırmıyor (RPC DB\'de kalır)');
});

test('C4-3: protokol paneli montajı 1f01e8b hâli — 4 bölüm (ovHtml ilk, seansHtml yok)', () => {
  const ix = src.indexOf('function _showProtokolEkran');
  const govde = src.slice(ix, src.indexOf('function _showProtokolDetay', ix));
  assert.ok(govde.includes('${ovHtml}${eksikHtml}${yakHtml}${tamHtml}'), 'montaj sırası: ov → eksik → yaklaan → tam');
  assert.ok(!govde.includes('seansHtml'), 'seans bölümü montajda yok');
});

test('C4-4: bildirimKontrol 1f01e8b hâli — parent_id\'siz, bugün+yarın, T08:00 sabiti', () => {
  const ix = src.indexOf('async function bildirimKontrol');
  const govde = src.slice(ix, src.indexOf('async function bildirimAc', ix));
  assert.ok(govde.includes('!g.parent_id&&(g.hedef_tarih===bugunStr||g.hedef_tarih===yarin)'),
    'yalnız parent_id\'siz görevler, bugün+yarın penceresi');
  assert.ok(govde.includes("T08:00:00"), 'hedef saati sabiti geri döndü');
  assert.ok(!govde.includes('_seansMi') && !govde.includes('gecKey') && !govde.includes('_gecSayi'),
    'K8 seans/gecikme kolları yok');
  assert.ok(!govde.includes('JSON.parse(g2.aciklama'), '4fbd2db gövde JSON çözümü yok');
  assert.ok(govde.includes('body:g2.aciklama||\'\''), 'gövde ham açıklama');
});
