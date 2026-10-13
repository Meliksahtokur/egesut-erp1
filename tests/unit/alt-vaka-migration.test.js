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
test('alt-vaka-acilis-bagli', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.match(sql, /ADD COLUMN IF NOT EXISTS kaynak_vaka_id uuid/);
  assert.ok(sqlBlok(sql, 'inaktif_alt_vaka_ac').includes('kaynak_vaka_id'));
});
test('inaktif-erteleme-dogrudan-ertele', () => {
  const ac = sqlBlok(oku('20261013000003_alt_vaka.sql'), 'inaktif_alt_vaka_ac');
  assert.ok(ac.includes('tohumlama_gorev_ertele('), 'açık TAI doğrudan ötelenir');
  assert.ok(!ac.includes('vaka_kalan_gunleri_kaydir'), 'kaydır RPC çağrılmaz');
  assert.ok(!/iptal\s*:?=\s*true/i.test(ac), 'iptal yazılmaz');
});
test('donus-public-ic-ayrimi', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.ok(sqlBlok(sql, 'inaktif_alt_vaka_kapat').includes('_inaktif_alt_vaka_donus_hazirla('));
  const ac = sqlBlok(sql, 'inaktif_alt_vaka_ac');
  assert.ok(!ac.includes('_inaktif_alt_vaka_donus_hazirla(') && !ac.includes("'closed'"), 'aç-RPC kapatmaz');
  assert.ok(!/GRANT[^;]*_inaktif_alt_vaka_donus_hazirla[^;]*TO\s+authenticated/.test(sql), 'iç yardımcı açılmaz');
});
test('vitamin-zincir-kilit', () => {
  const ac = sqlBlok(oku('20261013000003_alt_vaka.sql'), 'inaktif_alt_vaka_ac');
  assert.ok(ac.includes('add_drug_administration('), 'vitamin mevcut ilaç zincirinden');
  assert.match(ac, /p_vitamin_stok_id text DEFAULT NULL/, 'stok.id text (MEASURED), tek değer');
});
test('kisir-zincir-bitir-kilidi', () => {
  const sql = oku('20261013000003_alt_vaka.sql');
  assert.match(sql, /AFTER UPDATE OF kisir ON public\.hayvanlar[\s\S]*?EXECUTE FUNCTION public\._kisir_zincir_bitir\(\)/, 'tek tetik');
  const f = sqlBlok(sql, '_kisir_zincir_bitir');
  assert.ok(f.includes("'ERKEN_KAPANIS'") && f.includes('kaynak_vaka_id'), 'açık alt+ana kapanır');
});
