'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const { sqlBlok } = require('./support/sqlBlok.js');
const sql = () => fs.readFileSync(path.join(__dirname, '..', '..', 'supabase/migrations/20261013000004_k8_gorev_senkron.sql'), 'utf8');
test('tamamlama-uygulama-log-koprusu', () => {
  assert.ok(sqlBlok(sql(), 'gorev_tamamla').includes('INSERT INTO public.uygulama_log'));
});
test('iptal-kopru-kurmaz', () => {
  const b = sqlBlok(sql(), 'gorev_tamamla');
  const iptalDal = b.search(/IF p_iptal IS TRUE[\s\S]*?RETURN/);
  const iptalGuard = b.indexOf('IF v_gorev.iptal THEN RETURN');
  assert.ok(iptalDal >= 0 && iptalGuard > iptalDal, 'iptal dalı + iptal guard yerinde');
  assert.ok(b.indexOf('INSERT INTO public.uygulama_log') > iptalGuard, 'köprü iki iptal dönüşünden SONRA');
});
test('cift-yon-senkron-etken-null', () => {
  assert.ok(!sqlBlok(sql(), 'fn_dinle_uygulama').includes('IF NEW.etken_kod IS NOT NULL'));
});
test('scanner-iptal-bastirmaz', () => {
  const b = sqlBlok(sql(), 'protokol_eksik_tara');
  const yerler = [...b.matchAll(/g\.tamamlandi = true/g)];
  assert.ok(yerler.length >= 1, 'scanner gövdesi taşınır');
  for (const y of yerler) assert.match(b.slice(y.index, y.index + 160), /NOT COALESCE\(g\.iptal, false\)/);
});
