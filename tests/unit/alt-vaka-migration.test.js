// tests/unit/alt-vaka-migration.test.js
'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const { sqlBlok } = require('./support/sqlBlok.js');
const MIGDIR = path.join(__dirname, '..', '..', 'supabase/migrations');
const oku = (d) => fs.readFileSync(path.join(MIGDIR, d), 'utf8');
test('mevcut-erteleme-iptalsiz-oteler [kilit]', () => {
  const g = oku('20260925100001_vaka_kalan_gunleri_kaydir.sql');
  assert.ok(g.includes('PERFORM public.tohumlama_gorev_ertele('));
  assert.ok(!/iptal\s*=\s*true/i.test(g));
});
test('hastalik-gunu-disease-id [kilit]', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.match(sql, /ADD COLUMN disease_id uuid/, 'gün treatment_days satırıdır');
  assert.ok(sql.includes('treatment_days_disease_id_fkey'), 'diseases FK niyeti');
});
test('hastalik-gunu-tekil [kilit]', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.match(sql, /CREATE UNIQUE INDEX treatment_days_hastalik_gun_uniq\s+ON public\.treatment_days\(case_id, disease_id, treatment_date\) WHERE disease_id IS NOT NULL/, 'kısmi unique: ikinci çağrı mevcut günü döner');
});
test('hastalik-gunu-tek-rpc [kilit]', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.equal(sql.split('CREATE FUNCTION public.ovsync_hastalik_gunu_ekle(').length - 1, 1, 'tek imza');
  const f = sqlBlok(sql, 'ovsync_hastalik_gunu_ekle');
  assert.ok(f.includes('add_drug_administration('), 'ilaç mevcut zincirden');
  assert.ok(f.includes('tohumlama_gorev_ertele('), 'açık TAI doğrudan ötelenir');
  assert.ok(!f.includes('vaka_kalan_gunleri_kaydir'), 'kaydır RPC çağrılmaz');
  assert.ok(!/iptal\s*:?=\s*true/i.test(f), 'iptal yazılmaz');
  assert.ok(/GRANT EXECUTE[^;]*ovsync_hastalik_gunu_ekle[^;]*TO authenticated/.test(sql), 'public RPC açıktır');
  assert.ok(/REVOKE ALL[^;]*ovsync_hastalik_gunu_ekle[^;]*FROM PUBLIC, anon/.test(sql), 'anon kapalıdır');
});
// K10-UI2: yukarıdaki hastalık-günü DDL kilitleri (disease-id + kısmi unique
// + tek RPC) modelin kendisini pinler; ayrı-vaka yokluğu buradan okunur
// (kalıntı literali taşımayan kilitler).
test('kisir-zincir-yeni-kriter [kilit]', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.match(sql, /AFTER UPDATE OF kisir ON public\.hayvanlar[\s\S]*?EXECUTE FUNCTION public\._kisir_zincir_bitir\(\)/, 'tek tetik');
  const f = sqlBlok(sql, '_kisir_zincir_bitir');
  assert.ok(f.includes("'ERKEN_KAPANIS'") && f.includes('_vaka_ovsync_mu(alt.id)'), 'açık OVSYNC yedek-tanımla kapanır');
  assert.equal(sql.split('CREATE OR REPLACE FUNCTION public._vaka_ovsync_mu(').length - 1, 1, 'ölçüt tek yerdedir');
  assert.ok(!f.includes('kaynak' + '_vaka_id'), 'ayrı-vaka dalı yok (yeni kriter)');
  assert.ok(/REVOKE ALL[^;]*_kisir_zincir_bitir\(\)[^;]*FROM PUBLIC, anon, authenticated/.test(sql), 'iç yardımcı kapalıdır');
});
