const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
const MARKER = 'E2E-UITUR-';
const trGun = n => new Date(Date.now() + 3 * 3600e3 + n * 864e5).toISOString().slice(0, 10);
let db; let S = {};

const HAYVAN = { a:1,b:2,b1:3,b2:4,b3:5,b4:6,b5:7,b6:8,b7:9,c:10,c2:11,e:12,f:13,h:14,i:15,
  k:16,m:17,q:18,r:19,s4:20,w:21,y:22,z:23,p:24,pz:25,pe:26,g:27 };
const TOH_NO = { a:1,b:2,c:3,c2:4,e:5,f:6,h:7,i:8,k:9,m:10,q:11,s4:12,w:13,y:14,z:15,p:16,pz:17,pe:18,i2:19,p2:20,g:21,r:22 };
const GOREV_NO = { c:1,c2:2,h:3,i:4,q:5,m:6,e:7,b:8,r:9,p:10,pz:11,pe:12,g:13 };
const BASLAT_NO = { r:1,b1:2,b2:3,b3:4,b4:5,b5:6,b6:7,b7:8 };


module.exports = async function globalSetup() {
    db = createClient(DEMO_URL, DEMO_KEY);
    const { error } = await db.auth.signInWithPassword(DEMO_LOGIN);
    if (error) throw new Error(`demo giriş başarısız: ${error.message}`);
    await temizle(); // önceki koşum kalıntısı
  
    const uuid = (blok, n) => `e2e00000-0000-4${blok}00-8000-${String(n).padStart(12, '0')}`;
    const hayvanEkle = async ad => {
      const id = uuid('a', HAYVAN[ad]);
      const kupe = MARKER + ad;
      // idempotent: sabit id — var olan satır yeniden kullanılır (pg_application_event
      // DELETE yetkisi olmadığından pg'li hayvanlar tur arası kalabilir)
      const { data: got } = await db.from('hayvanlar').select('id').eq('id', id);
      if (!got?.length) {
        const { error: e1 } = await db.from('hayvanlar').insert({
          id, kupe_no: kupe, cinsiyet: 'Dişi', durum: 'Aktif',
          dogum_tarihi: trGun(-500), grup: 'Sağmal (Laktasyonda)',
        });
        if (e1) throw new Error(`seed hayvan ${ad}: ${e1.message}`);
      } else {
        await db.from('hayvanlar').update({ durum: 'Aktif' }).eq('id', id);
      }
      S[ad] = { kupe, hayvanId: id };
    };
    const tohEkle = async (ad, gunOffset, sonuc = 'Bekliyor') => {
      const id = uuid('b', TOH_NO[ad]);
      const { data, error: e2 } = await db.from('tohumlama').insert({
        id, hayvan_id: S[ad].hayvanId, tarih: trGun(gunOffset), sonuc,
        deneme_sayisi: 1, denemeler: [],
      }).select('id').single();
      if (e2) throw new Error(`seed toh ${ad}: ${e2.message}`);
      S[ad].tohId = data.id;
      return data.id;
    };
    const gorevEkle = async (ad, tip, gunOffset, ekstra = {}) => {
      const id = uuid('c', GOREV_NO[ad]);
      const { data, error: e3 } = await db.from('gorev_log').insert({
        id, hayvan_id: S[ad].hayvanId, gorev_tipi: tip,
        aciklama: MARKER + ad, hedef_tarih: trGun(gunOffset),
        tamamlandi: false, iptal: false,
        kaynak: ekstra.kaynak ?? ('TAKIP:' + (S[ad].tohId ?? 'E2E')),
        ...(ekstra.createdGun ? { created_at: new Date(Date.now() + 3 * 3600e3 + ekstra.createdGun * 864e5).toISOString() } : {}),
        ...(ekstra.saat ? { hedef_saat: ekstra.saat } : {}),
      }).select('id').single();
      if (e3) throw new Error(`seed görev ${ad}: ${e3.message}`);
      S[ad].gorevId = data.id;
      return data.id;
    };
    const baslatGorevEkle = async (ad, gunOffset) => {
      const id = uuid('d', BASLAT_NO[ad] ?? 90);
      const { data, error: e4 } = await db.from('gorev_log').insert({
        id, hayvan_id: S[ad].hayvanId, gorev_tipi: 'OVSYNC_BASLAT',
        aciklama: MARKER + ad, hedef_tarih: trGun(gunOffset),
        tamamlandi: false, iptal: false, kaynak: 'ILK-TOH-DUVE-UITUR-' + ad,
      }).select('id').single();
      if (e4) throw new Error(`seed baslat ${ad}: ${e4.message}`);
      S[ad].baslatId = data.id;
      return data.id;
    };
    const takipGorevEkle = async (ad, saat, createdGun) => {
      const id = uuid('e', GOREV_NO[ad] + 40);
      const { data, error: e5 } = await db.from('gorev_log').insert({
        id, hayvan_id: S[ad].hayvanId, gorev_tipi: 'TAKIP_MUAYENE',
        aciklama: MARKER + ad, hedef_tarih: trGun(7), hedef_saat: saat,
        tamamlandi: false, iptal: false, kaynak: 'TAKIP:' + S[ad].tohId,
        ...(createdGun ? { created_at: new Date(Date.now() + 3 * 3600e3 + createdGun * 864e5).toISOString() } : {}),
      }).select('id').single();
      if (e5) throw new Error(`seed takip ${ad}: ${e5.message}`);
      S[ad].takipId = data.id;
      return data.id;
    };
    const pgGecmisiEkle = async ad => {
      const TRY = async p => { try { await p; } catch { /* temizlik */ } };
      TRY(db.from('gorev_log').delete().eq('hayvan_id', S[ad].hayvanId));
      TRY(db.from('tohumlama').delete().eq('hayvan_id', S[ad].hayvanId));
      TRY(db.from('pg_application_event').delete().eq('hayvan_id', S[ad].hayvanId));
      TRY(db.from('uygulama_log').delete().eq('hayvan_id', S[ad].hayvanId));
      const { data: stok, error: es } = await db.from('stok').select('id,birim').eq('urun_adi', 'PGs (alke)').limit(1).single();
      if (es || !stok) throw new Error('seed PG stoğu bulunamadı (PGs (alke))');
      S.pgStokId = stok.id;
      const { data: res, error: er } = await db.rpc('hizli_uygulama', {
        p_hayvan_id: S[ad].hayvanId, p_stok_id: stok.id, p_doz: 5,
        p_birim: stok.birim || 'ml', p_rota: 'IM', p_notlar: MARKER + 'pg-gecmis',
      });
      if (er) throw new Error(`seed hizli_uygulama ${ad}: ${er.message}`);
      if (res && res.ok === false) throw new Error(`seed hizli_uygulama ${ad} reddi: ${res.mesaj}`);
    };
  
    for (const ad of Object.keys(HAYVAN)) await hayvanEkle(ad);
    await tohEkle('a', -45);
    await pgGecmisiEkle('b');
    await tohEkle('b', 0);
    await takipGorevEkle('b', '09:00:00');
    for (const ad of ['b1','b2','b3','b4','b5','b6','b7']) await baslatGorevEkle(ad, 1);
    await tohEkle('c', -45);
    await gorevEkle('c', 'GEBELIK_KONTROL', -5, { kaynak: 'GEBELIK-KONTROL-' + S.c.tohId, createdGun: -5 });
    await tohEkle('c2', -45);
    await gorevEkle('c2', 'GEBELIK_KONTROL', -5, { kaynak: 'GEBELIK-KONTROL-' + S.c2.tohId });
    await tohEkle('e', 0);
    await takipGorevEkle('e', '08:00:00');
    await tohEkle('f', 0);
    await tohEkle('h', -20, 'Boş');
    await takipGorevEkle('h', '07:30:00', -20);
    await tohEkle('i', -45, 'Boş');
    await takipGorevEkle('i', '06:30:00', -45);
    await tohEkle('k', 0);
    await tohEkle('m', 0);
    await takipGorevEkle('m', '09:30:00');
    await tohEkle('q', 0);
    await takipGorevEkle('q', '10:00:00');
    await baslatGorevEkle('r', 0);
    await tohEkle('r', 0);
    await takipGorevEkle('r', '11:00:00');
    await tohEkle('s4', -30, 'Boş');
    {
      const { data: diz } = await db.from('diseases').select('id').limit(1);
      if (!diz?.length) throw new Error('seed diseases boş');
      const cid = uuid('f', 1);
      const { error: ec } = await db.from('cases').insert({
        id: cid, animal_id: S.s4.hayvanId, disease_id: diz[0].id,
        start_date: trGun(-30), status: 'closed',
        closed_at: new Date(Date.now() + 3 * 3600e3 - 1 * 864e5).toISOString(),
        protocol_family: 'OVSYNC',
      });
      if (ec) throw new Error('seed s4 case: ' + ec.message);
      S.s4.caseId = cid;
      for (let d = 1; d <= 4; d++) {
        const { error: ed } = await db.from('treatment_days').insert({
          case_id: cid, day_no: d, treatment_date: trGun(-30 + (d - 1) * 7),
        });
        if (ed) throw new Error('seed s4 gun: ' + ed.message);
      }
    }
    await tohEkle('w', -38);
    await tohEkle('y', 0);
    await tohEkle('z', -4);
    await tohEkle('p', 0);
    await tohEkle('pz', 0);
    await tohEkle('pe', 0);
    await tohEkle('g', 0);
  fs.writeFileSync('/agents/fixture-state.json', JSON.stringify(S));
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