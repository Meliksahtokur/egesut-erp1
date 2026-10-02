const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const MARKER = 'E2E-UITUR-';
const trGun = n => new Date(Date.now() + 3 * 3600e3 + n * 864e5).toISOString().slice(0, 10);
let db; let S = {};


module.exports = async function globalTeardown() {
  db = createClient(DEMO_URL, DEMO_KEY);
  const { error } = await db.auth.signInWithPassword(DEMO_LOGIN);
  if (error) throw new Error('demo giriş: ' + error.message);
  await temizle();
};

async function temizle() {
  const { data: eski } = await db.from('hayvanlar').select('id').like('kupe_no', MARKER + '%');
  const ids = (eski ?? []).map(h => h.id);
  if (!ids.length) return;
  const TRY = async p => { try { const r = await p; if (r?.error) throw new Error(r.error.message); } catch { /* sıradan devam */ } };
  const { data: caseRows } = await db.from('cases').select('id').in('animal_id', ids);
  const cid = (caseRows ?? []).map(c => c.id);
  if (cid.length) {
    TRY(db.from('treatment_day_uygulamalar').delete().in('case_id', cid));
    TRY(db.from('treatment_days').delete().in('case_id', cid));
  }
  await TRY(db.from('protokol_instance').delete().in('hayvan_id', ids));
  await TRY(db.from('kizginlik_log').delete().in('hayvan_id', ids));
  // pg_application_event: demo authenticated DELETE yetkisi YOK (2026-10-01 ölçüm)
  // → TRY; FK bloklayan hayvanlar aşağıda tek tek denenir
  await TRY(db.from('pg_application_event').delete().in('hayvan_id', ids));
  await TRY(db.from('uygulama_log').delete().in('hayvan_id', ids));
  await db.from('gorev_log').delete().in('hayvan_id', ids);
  await db.from('tohumlama').delete().in('hayvan_id', ids);
  if (cid.length) await TRY(db.from('cases').delete().in('id', cid));
  // hayvanlar TEK TEK: tek pg_event'li hayvan (seed b/k) hepsini bloklamasın;
  // silinemeyenler aktif listelerden/dashboards'dan çekilir (durum=Satildi)
  const kalan = [];
  for (const id of ids) {
    const { error } = await db.from('hayvanlar').delete().eq('id', id);
    if (error) kalan.push(id);
  }
  if (kalan.length) {
    await db.from('hayvanlar').update({ durum: 'Satildi' }).in('id', kalan);
    console.log('[uitur] pg_event-FK bloklu hayvan Satildi birakildi:', kalan.length);
  }
}