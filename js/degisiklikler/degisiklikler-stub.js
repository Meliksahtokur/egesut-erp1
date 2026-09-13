// js/degisiklikler/degisiklikler-stub.js
// ═══ GEÇİCİ KONTRAT-ŞEKİLLİ STUB (G-20260913-SURUM-GECMISI, W2) ═══════════
// W1 (F1+F2 DB) merge edilene kadar js/api.js'teki 4 wrapper'ı AYNI imzayla
// ezer: rpcGeriAlmaBiletiAl, rpcDegisimListele, rpcDegisimOnizle, rpcDegisimGeriAl.
// Dönüş gövdeleri goal'deki "Frozen contract — F2 RPC surface" jsonb şekilleridir;
// ok:false gövdesi rpc() ile aynı biçimde Error(.data) olarak fırlatılır.
// Precedent: idle/pedigree-p2-W3 kontrat-şekilli stub.
//
// SÖKÜM (tek nokta): index.html'deki
//   <script src="js/degisiklikler/degisiklikler-stub.js?v=…"></script>
// satırını ve bu dosyayı sil. Başka hiçbir dosya bu modüle referans vermez
// (sayfa yalnız window.DEGISIM_STUB bayrağıyla "stub veri" bandı gösterir).
// Demo test şifresi: demo1234
(function () {
  'use strict';
  window.DEGISIM_STUB = true;

  const SIFRE = 'demo1234';
  const biletler = {};           // bilet → {olusturma, son}
  let log = null;                // degisim_log satırları (stub bellek)
  let txMeta = {};               // txid → {baslik, kaynak}
  let sonId = 0;
  let sonTxid = 9100;

  function uuid() {
    return (crypto && crypto.randomUUID) ? crypto.randomUUID()
      : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => (Math.random() * 16 | 0).toString(16));
  }
  function dakikaOnce(dk) { return new Date(Date.now() - dk * 60000).toISOString(); }
  function klon(v) { return v == null ? v : JSON.parse(JSON.stringify(v)); }

  // Gerçek demo hayvanlarını kullan (ekran görüntüsü gerçekçi olsun); yoksa sahte
  function hayvanlar() {
    const L = (typeof getState === 'function' && getState('animals')) || [];
    const aktif = L.filter(a => a && a.durum === 'Aktif');
    const a = aktif[0] || { id: 'aaaaaaaa-0000-4000-8000-000000000001', kupe_no: '136', durum: 'Aktif', grup: 'Sağmal' };
    const b = aktif[1] || { id: 'aaaaaaaa-0000-4000-8000-000000000002', kupe_no: '4019', devlet_kupe: 'TR350000004019', durum: 'Aktif' };
    const c = aktif[2] || { id: 'aaaaaaaa-0000-4000-8000-000000000003', kupe_no: '212', durum: 'Aktif' };
    return [a, b, c];
  }

  function ekle(txid, zaman, tablo, pk, islem, eski, yeni, kaynak) {
    const degisen = islem === 'U'
      ? Object.keys(Object.assign({}, eski, yeni)).filter(k => JSON.stringify(eski[k]) !== JSON.stringify(yeni[k]))
      : null;
    const teknik = ['updated_at', 'guncelleme'];
    log.push({
      id: ++sonId, txid: String(txid), zaman, tablo_adi: tablo, satir_pk: { id: pk }, islem,
      eski: klon(eski), yeni: klon(yeni), degisen_alanlar: degisen,
      teknikal_mi: !!(degisen && degisen.length && degisen.every(k => teknik.includes(k))),
      kaynak: klon(kaynak),
    });
  }

  function tohumla() {
    if (log) return;
    log = []; txMeta = {};
    const [A, B, C] = hayvanlar();
    const app = { rol: 'authenticated', jwt_sub: 'demo-kullanici', jwt_role: 'authenticated', app_name: 'egesut-web', istemci_etiketi: 'dogum_kaydet' };
    const yavruId = uuid(), dogumId = uuid(), g1 = uuid(), g2 = uuid(), g3 = uuid(), uId = uuid(), shId = uuid();
    let z;

    // 9001 — Doğum kaydı (3 tablo · 5 satır)
    z = dakikaOnce(35); txMeta['9001'] = { baslik: 'Doğum kaydı' };
    ekle(9001, z, 'dogum', dogumId, 'I', null, { id: dogumId, anne_id: A.id, tarih: z.slice(0, 10), yavru_cins: 'Dişi', yavru_kupe: '777', dogum_tipi: 'Normal', dogum_kg: 38 }, app);
    ekle(9001, z, 'hayvanlar', yavruId, 'I', null, { id: yavruId, kupe_no: '777', cinsiyet: 'Dişi', irk: A.irk || 'Simental', dogum_tarihi: z.slice(0, 10), anne_id: A.id, grup: 'Buzağı', durum: 'Aktif' }, app);
    ekle(9001, z, 'hayvanlar', A.id, 'U', { id: A.id, kupe_no: A.kupe_no, tohumlama_durumu: 'Gebe', grup: A.grup || 'Kuru' }, { id: A.id, kupe_no: A.kupe_no, tohumlama_durumu: 'Boş', grup: 'Sağmal' }, app);
    ekle(9001, z, 'gorev_log', g1, 'I', null, { id: g1, hayvan_id: yavruId, gorev_tipi: 'Buzağı kontrol', hedef_tarih: z.slice(0, 10), tamamlandi: false }, app);
    ekle(9001, z, 'gorev_log', g2, 'I', null, { id: g2, hayvan_id: A.id, gorev_tipi: 'Doğum sonrası kontrol', hedef_tarih: z.slice(0, 10), tamamlandi: false }, app);

    // 9002 — Uygulama dışı toplu küpe düzeltmesi (adli senaryo)
    z = dakikaOnce(300); txMeta['9002'] = { baslik: 'Hayvan güncelleme' };
    ekle(9002, z, 'hayvanlar', B.id, 'U',
      { id: B.id, kupe_no: '4019', devlet_kupe: B.devlet_kupe || 'TR350000004019', updated_at: dakikaOnce(9000) },
      { id: B.id, kupe_no: '51', devlet_kupe: 'TR350000000051', updated_at: z },
      { rol: 'postgres', jwt_sub: null, jwt_role: null, app_name: 'psql', istemci_etiketi: null });

    // 9003 — Sürüden çıkış (satış); sonra 9005 aynı satırı değiştirdi → çakışma
    z = dakikaOnce(240); txMeta['9003'] = { baslik: 'Sürüden çıkış' };
    ekle(9003, z, 'hayvanlar', C.id, 'U',
      { id: C.id, kupe_no: C.kupe_no, durum: 'Aktif', cikis_tarihi: null, cikis_tipi: null, satis_fiyati: null },
      { id: C.id, kupe_no: C.kupe_no, durum: 'Satıldı', cikis_tarihi: z.slice(0, 10), cikis_tipi: 'Satıldı', satis_fiyati: 42000 },
      Object.assign({}, app, { istemci_etiketi: 'hayvan_cikis' }));

    // 9004 — İlaç uygulaması + stok hareketi (stok aynı tx'te → plana girer)
    z = dakikaOnce(120); txMeta['9004'] = { baslik: 'İlaç uygulaması' };
    ekle(9004, z, 'uygulama_log', uId, 'I', null, { id: uId, hayvan_id: A.id, etken_kod: 'OKSI', doz: 10, birim: 'ml', rota: 'IM', tarih: z.slice(0, 10) }, app);
    ekle(9004, z, 'stok_hareket', shId, 'I', null, { id: shId, stok_id: 'stok-oksi', tur: 'Çıkış', miktar: 10, referans_tipi: 'uygulama_log', referans_id: uId }, app);

    // 9005 — Çıkan hayvana not (9003'ü çakışmaya sokar)
    z = dakikaOnce(200); txMeta['9005'] = { baslik: 'Hayvan notu' };
    ekle(9005, z, 'hayvanlar', C.id, 'U', { id: C.id, notlar: null }, { id: C.id, notlar: 'Alıcı: <b>Yılmaz</b> çiftliği' }, app);

    // 9006 — Görev silme
    z = dakikaOnce(90); txMeta['9006'] = { baslik: 'Görev silme' };
    ekle(9006, z, 'gorev_log', g3, 'D', { id: g3, hayvan_id: B.id, gorev_tipi: 'Aşı', hedef_tarih: z.slice(0, 10), tamamlandi: false, iptal: false }, null, app);
  }

  function hata(kod, detay) { return detay ? { ok: false, hata: kod, detay } : { ok: false, hata: kod }; }

  // rpc() ile aynı ok:false davranışı (js/api.js rpc)
  async function cagir(uret) {
    await new Promise(r => setTimeout(r, 120));
    tohumla();
    const data = uret();
    if (data && data.ok === false) {
      const err = new Error(data.mesaj || 'İşlem başarısız');
      err.data = data;
      throw err;
    }
    return data;
  }

  function txSatirlari(txid) { return log.filter(r => r.txid === String(txid)); }
  function hayvanRef(r, hid) {
    return [r.eski, r.yeni].some(o => o && (o.id === hid && r.tablo_adi === 'hayvanlar' || o.hayvan_id === hid || o.anne_id === hid || o.animal_id === hid));
  }
  function istanbulGun(iso) {
    return new Date(iso).toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
  }

  function listele(f) {
    f = f || {};
    if (f.txid != null && f.txid !== '') {
      return { ok: true, detay: true, kayitlar: klon(txSatirlari(f.txid)) };
    }
    const txler = [...new Set(log.map(r => r.txid))];
    let gruplar = txler.map(tx => {
      const rows = txSatirlari(tx);
      const ozet = islemOzeti(rows);
      return {
        txid: tx,
        ilk_zaman: rows[0].zaman,
        ozet: Object.assign({}, ozet, { baslik: (txMeta[tx] && txMeta[tx].baslik) || 'Değişiklik' }),
        kaynak: klon(rows[0].kaynak),
        _rows: rows,
      };
    });
    if (f.hayvan_id) {
      gruplar = gruplar.filter(gr => gr._rows.some(r => hayvanRef(r, f.hayvan_id)));
    }
    if (f.tablo) gruplar = gruplar.filter(gr => gr._rows.some(r => r.tablo_adi === f.tablo));
    if (f.islem) gruplar = gruplar.filter(gr => gr._rows.some(r => r.islem === f.islem));
    if (f.baslangic) gruplar = gruplar.filter(gr => istanbulGun(gr.ilk_zaman) >= f.baslangic);
    if (f.bitis) gruplar = gruplar.filter(gr => istanbulGun(gr.ilk_zaman) <= f.bitis);
    gruplar.sort((a, b) => b.ilk_zaman.localeCompare(a.ilk_zaman));
    const adet = Math.max(1, Math.min(200, parseInt(f.adet, 10) || 50));
    const sayfa = Math.max(1, parseInt(f.sayfa, 10) || 1);
    const dilim = gruplar.slice((sayfa - 1) * adet, sayfa * adet).map(gr => { delete gr._rows; return gr; });
    return { ok: true, kayitlar: klon(dilim), toplam: gruplar.length, sayfa, adet };
  }

  // Lead contract update: pk is SCALAR for single-column PKs, OBJECT for
  // composite; optional hedef.txid targets that tx's change, otherwise the
  // row's/field's LATEST change.
  function pkEslestir(satirPk, hedefPk) {
    if (hedefPk !== null && typeof hedefPk === 'object') {
      return !!satirPk && typeof satirPk === 'object' &&
        Object.entries(hedefPk).every(([k, v]) => JSON.stringify(satirPk[k]) === JSON.stringify(v));
    }
    if (satirPk && typeof satirPk === 'object') {
      const vals = Object.values(satirPk);
      return vals.length === 1 && String(vals[0]) === String(hedefPk);
    }
    return String(satirPk) === String(hedefPk);
  }

  function hedefSatirlari(hedef, seviye) {
    if (!hedef || typeof hedef !== 'object') return { hata: 'GECERSIZ_HEDEF' };
    if (seviye === 'islem') {
      if (!hedef.txid) return { hata: 'GECERSIZ_HEDEF' };
      const rows = txSatirlari(hedef.txid);
      return rows.length ? { rows } : { hata: 'HEDEF_BULUNAMADI' };
    }
    if (!hedef.tablo || hedef.pk == null) return { hata: 'GECERSIZ_HEDEF' };
    let hepsi = log.filter(r => r.tablo_adi === hedef.tablo && pkEslestir(r.satir_pk, hedef.pk));
    if (!hepsi.length) return { hata: 'HEDEF_BULUNAMADI' };
    if (hedef.txid != null && hedef.txid !== '') {
      hepsi = hepsi.filter(r => r.txid === String(hedef.txid));
      if (!hepsi.length) return { hata: 'HEDEF_BULUNAMADI' };
    }
    if (seviye === 'alan') {
      if (!hedef.alan) return { hata: 'GECERSIZ_HEDEF' };
      hepsi = hepsi.filter(r => r.islem === 'U' && (r.degisen_alanlar || []).includes(hedef.alan));
      if (!hepsi.length) return { hata: 'GECERSIZ_HEDEF' };
    }
    return { rows: [hepsi[hepsi.length - 1]] };
  }

  function onizle(hedef, seviye) {
    if (!['alan', 'satir', 'islem'].includes(seviye)) return hata('GECERSIZ_SEVIYE');
    const h = hedefSatirlari(hedef, seviye);
    if (h.hata) return hata(h.hata);
    const rows = h.rows;
    const planIds = new Set(rows.map(r => r.id));
    const plan = rows.slice().reverse().map((r, i) => {
      const alanlar = seviye === 'alan' ? [hedef.alan] : (r.islem === 'U' ? r.degisen_alanlar : Object.keys(r.eski || r.yeni || {}));
      const yapilacak = r.islem === 'I' ? 'Satır silinecek (ekleme geri alınır)'
        : r.islem === 'D' ? 'Satır geri eklenecek'
        : alanlar.length + ' alan eski değerine dönecek';
      return { sira: i + 1, tablo: r.tablo_adi, pk: r.satir_pk.id, islem: r.islem, alanlar, eski: klon(r.eski), yeni: klon(r.yeni), yapilacak };
    });
    const cakismalar = [];
    rows.forEach(r => {
      log.filter(s => s.id > r.id && !planIds.has(s.id) && s.tablo_adi === r.tablo_adi && s.satir_pk.id === r.satir_pk.id)
        .forEach(s => {
          if (seviye === 'alan' && !(s.degisen_alanlar || []).includes(hedef.alan)) return;
          cakismalar.push({ tablo: s.tablo_adi, pk: s.satir_pk.id, alan: seviye === 'alan' ? hedef.alan : undefined, neden: 'Hedeften sonra değişti (txid ' + s.txid + ')' });
        });
    });
    const bagimliliklar = [];
    rows.filter(r => r.islem === 'I' && r.tablo_adi === 'hayvanlar').forEach(r => {
      log.filter(s => s.tablo_adi === 'gorev_log' && s.yeni && s.yeni.hayvan_id === r.satir_pk.id)
        .forEach(s => bagimliliklar.push({ tablo: 'gorev_log', pk: s.satir_pk.id, iliski: 'hayvan_id', etki: planIds.has(s.id) ? 'KADEMELI' : 'ENGEL' }));
    });
    const stok_uyari = [];
    rows.filter(r => r.tablo_adi === 'uygulama_log').forEach(r => {
      const ayniTx = rows.some(s => s.tablo_adi === 'stok_hareket');
      if (!ayniTx) stok_uyari.push({ stok_id: 'stok-oksi', metin: 'Bu uygulamanın stok hareketi plana dahil değil; stok elle düzeltilmeli.' });
    });
    const engeller = [];
    if (cakismalar.length) engeller.push('Çakışma: hedef satır sonradan değişmiş (' + cakismalar.length + ' kayıt). Önce sonraki değişikliği geri alın.');
    if (bagimliliklar.some(b => b.etki === 'ENGEL')) engeller.push('Bağımlı alt kayıt var; önce onu geri alın.');
    return {
      ok: true, seviye, hedef: klon(hedef), plan, cakismalar, bagimliliklar, stok_uyari,
      geri_alinabilir: engeller.length === 0, engeller,
    };
  }

  function biletAl(sifre) {
    if (sifre !== SIFRE) return hata('SIFRE_HATALI');
    const bilet = uuid();
    const olusturma = new Date();
    const son = new Date(olusturma.getTime() + 3600 * 1000);
    biletler[bilet] = { olusturma, son };
    return { ok: true, bilet, olusturma: olusturma.toISOString(), son_gecerlilik: son.toISOString(), kalan_sn: 3600 };
  }

  function geriAl(hedef, seviye, bilet, gerekce) {
    const b = biletler[bilet];
    if (!b) return hata('BILET_GECERSIZ');
    if (b.son.getTime() <= Date.now()) return hata('BILET_SURESI_DOLMUS');
    const on = onizle(hedef, seviye);           // plan UYGULAMA ANINDA yeniden hesaplanır
    if (on.ok === false) return on;
    if (on.cakismalar.length) return hata('CAKISMA', { cakismalar: on.cakismalar });
    if (!on.geri_alinabilir) return hata('BAGIMLILIK_ENGELI', { bagimliliklar: on.bagimliliklar });
    const tx = ++sonTxid, z = new Date().toISOString();
    txMeta[String(tx)] = { baslik: 'Geri alma' };
    const kaynak = { rol: 'authenticated', jwt_sub: 'demo-kullanici', jwt_role: 'authenticated', app_name: 'egesut-web', istemci_etiketi: 'degisim_geri_al', geri_alma: { bilet, gerekce: gerekce || null } };
    on.plan.forEach(p => {
      if (p.islem === 'I') ekle(tx, z, p.tablo, p.pk, 'D', p.yeni, null, kaynak);
      else if (p.islem === 'D') ekle(tx, z, p.tablo, p.pk, 'I', null, p.eski, kaynak);
      else {
        const e = {}, y = {};
        p.alanlar.forEach(k => { e[k] = p.yeni[k]; y[k] = p.eski[k]; });
        e.id = y.id = p.pk;
        ekle(tx, z, p.tablo, p.pk, 'U', e, y, kaynak);
      }
    });
    return { ok: true, geri_alma_txid: String(tx), uygulanan_adim: on.plan.length };
  }

  // ── AYNI İMZA ile js/api.js wrapper'larını ez ──
  window.rpcGeriAlmaBiletiAl = (sifre) => cagir(() => biletAl(sifre));
  window.rpcDegisimListele   = (filtre = {}) => cagir(() => listele(filtre || {}));
  window.rpcDegisimOnizle    = (hedef, seviye) => cagir(() => onizle(hedef, seviye));
  window.rpcDegisimGeriAl    = (hedef, seviye, bilet, gerekce = null) => cagir(() => geriAl(hedef, seviye, bilet, gerekce));
})();
