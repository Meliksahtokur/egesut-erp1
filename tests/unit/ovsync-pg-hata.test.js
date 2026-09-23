// tests/unit/ovsync-pg-hata.test.js — PLAN P1: PG_KAPI ayrıştırıcı + pencere yuvarlama (P6 aynası)
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

// config.js önce yüklenir (PG_HATA_SOZLUGU global'i errorHandler sandbox'ına extra ile verilir)
const cfg = loadBrowserModule('js/config.js', { expose: ['PG_HATA_SOZLUGU', 'TOHUMLAMA_PENCERELERI', 'pencereYuvarla'] });
const eh = loadBrowserModule('js/utils/errorHandler.js', { extra: { PG_HATA_SOZLUGU: cfg.exposed.PG_HATA_SOZLUGU } });

test('P1: PG_KAPI:BLOCK_PREGNANT kodu sözlükten Türkçe mesaj verir', () => {
  const m = eh.sandbox.getUserMessage(new Error('PG_KAPI:BLOCK_PREGNANT:{"kupe_no":"121"}'));
  assert.match(m, /Gebe inekte PG uygulanamaz/);
  assert.match(m, /121/);
});

test('P1: PG_KAPI:REQUIRE_ACK_PENDING detay alanları dolar', () => {
  const m = eh.sandbox.getUserMessage(new Error('PG_KAPI:REQUIRE_ACK_PENDING:{"kupe_no":"45","tohumlama_tarihi":"2026-09-17","deneme_no":2}'));
  assert.match(m, /Bekliyor/);
  assert.match(m, /45/);
  assert.match(m, /2026-09-17/);
  assert.match(m, /deneme 2/);
});

test('P1: JSON bozuk olsa bile KOD gösterilir (fail-loud, jenerik yok)', () => {
  const m = eh.sandbox.getUserMessage(new Error('PG_KAPI:BLOCK_PREGNANT:{bozuk json'));
  assert.match(m, /Gebe inekte PG/); // sözlükteki kod — JSON olmadan da sablon basilir
});

test('P1: sözlükte olmayan yeni PG_KAPI kodu jeneriğe düşmez', () => {
  const m = eh.sandbox.getUserMessage(new Error('PG_KAPI:YENI_KOD:{}'));
  assert.match(m, /YENI_KOD/);
  assert.ok(!/Bir hata oluştu/.test(m));
});

test('P1: PG_ZAMAN_GECERSIZ / SISTEM_ETKEN_MADDE tanınır', () => {
  assert.match(eh.sandbox.getUserMessage(new Error('PG_ZAMAN_GECERSIZ:{"verilen":"..."}')), /5 dk ileri/);
  assert.match(eh.sandbox.getUserMessage(new Error('SISTEM_ETKEN_MADDE:Dinoprost')), /değiştirilemez/);
});

test('P1: anlamlı Türkçe sunucu mesajı jenerik ile EZİLMEZ (review bulgusu)', () => {
  const m = eh.sandbox.getUserMessage(new Error('Bu hayvan aktif değil.'));
  assert.equal(m, 'Bu hayvan aktif değil.');
});

test('P1: anlamsız kısa mesaj önceki jenerik davranışta kalır', () => {
  assert.match(eh.sandbox.getUserMessage(new Error('xyz')), /Bir hata oluştu/);
});

test('P1: mevcut kalıplar kırılmadı', () => {
  assert.match(eh.sandbox.getUserMessage(new Error('Failed to fetch')), /İnternet/);
});

// ── P6: pencereYuvarla MK1 aynası ────────────────────────────────────────────
const { pencereYuvarla } = cfg.exposed;

test('P6: pencere içinde → değişmez', () => {
  assert.equal(pencereYuvarla('2026-09-24 10:00'), '2026-09-24 10:00');
  assert.equal(pencereYuvarla('2026-09-24 21:00'), '2026-09-24 21:00'); // kapalı aralık sonu
  assert.equal(pencereYuvarla('2026-09-24 09:00'), '2026-09-24 09:00');
});

test('P6: 12:00–18:00 arası → aynı gün 18:00', () => {
  assert.equal(pencereYuvarla('2026-09-24 14:00'), '2026-09-24 18:00');
  assert.equal(pencereYuvarla('2026-09-24 12:01'), '2026-09-24 18:00');
});

test('P6: 21:00 sonrası → ertesi gün 09:00 (ay sonu rollover dahil)', () => {
  assert.equal(pencereYuvarla('2026-09-24 21:01'), '2026-09-25 09:00');
  assert.equal(pencereYuvarla('2026-09-30 22:00'), '2026-10-01 09:00');
});

test('P6: 09:00 öncesi → aynı gün 09:00; asla erkene yuvarlanmaz', () => {
  assert.equal(pencereYuvarla('2026-09-24 06:30'), '2026-09-24 09:00');
});
