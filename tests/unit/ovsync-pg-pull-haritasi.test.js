// tests/unit/ovsync-pg-pull-haritasi.test.js — PLAN P2: RPC_TABLES pull setleri
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

// api.js createClient stub ister (api.test.js kalıbı)
const api = loadBrowserModule('js/api.js', {
  expose: ['RPC_TABLES'],
  extra: { supabase: { createClient: () => ({ from: () => { throw new Error('stub'); }, rpc: () => { throw new Error('stub'); }, auth: {} }) } },
});
const T = api.exposed.RPC_TABLES;

const icerir = (rpc, tab) => assert.ok(T[rpc]?.includes(tab), `${rpc} → ${tab} eksik`);

test('P2: bulk_ilac gorev_log çeker (S-4 toplu PG yolu)', () => icerir('bulk_ilac', 'gorev_log'));
test('P2: tohumlama_kaydet cases + seanslar + islem_log çeker (S-7)', () => {
  for (const t of ['cases', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log']) icerir('tohumlama_kaydet', t);
  icerir('planli_tohumlama_kaydet', 'cases');
});
test('P2/R3.2: sonuc/abort yolları gorev_log çeker', () => {
  for (const r of ['tohumlama_sonuc_gebe', 'tohumlama_sonuc_bos', 'tohumlama_abort']) icerir(r, 'gorev_log');
});
test('P2: yeni RPC satırları kayıtlı; salt-okuma RPC\'ler haritada DEĞİL (dolu dizi invariantı)', () => {
  for (const r of ['start_first_service_protocol', 'tohumlama_gorev_ertele', 'ilk_tohumlama_zamanlayici']) {
    assert.ok(Array.isArray(T[r]) && T[r].length, `${r} RPC_TABLES'te yok/boş`);
  }
  assert.ok(!('pg_uyari_kontrol' in T), 'salt-okuma RPC haritada olmamalı');
  assert.ok(!('ovsync_baslat_uyarilari' in T), 'salt-okuma RPC haritada olmamalı');
});
test('P2: yeni Ovsync/PG RPC pull setlerinde protokol_instance yok (devrilmiş fikir)', () => {
  const yeni = ['start_first_service_protocol', 'tohumlama_gorev_ertele', 'ilk_tohumlama_zamanlayici'];
  for (const r of yeni) assert.ok(!T[r].includes('protokol_instance'), `${r} → protokol_instance var`);
});
