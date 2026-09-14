// ═══════════════════════════════════════════════════════
// gecmis.js — Geçmiş sekmesi ortak veri hattı (saf modül)
// normalize → politika filtresi → arama → sınır (cap) → gün gruplama → CSV
// Spesifikasyon: .claude/plans/2026-09-09-gecmis-sekmesi-tasarim.md (rev 2)
//
// Bu modül DOM YAZMAZ (yalnızca string üretir); zenginleştirme birleştirmeleri
// (hastalık adı, ilaç adları, stok adı) ui.js toplama adımında yapılır — buraya
// ham satırlar girer, `data` olduğu gibi çıkar. index.html'de helpers.js ile
// ui.js ARASINA yüklenir.
// ═══════════════════════════════════════════════════════

// ── Sabitler ─────────────────────────────────────────────
// tohumlama sonuç allow-list (canlı şema: non-terminal değer tam olarak 'Bekliyor')
const _GM_TOH_TERMINAL = ['Gebe', 'Boş', 'Doğum Yaptı', 'Abort'];
// ana geçmiş listesinde gösterilen islem_log tipleri (bugünkü davranış)
const _GM_ISLEM_TIPLERI = ['HAYVAN_EKLENDI', 'ABORT_KAYDI', 'KIZGINLIK_KAYDI', 'ASI_KAYDI', 'TOPLU_ILAC'];
// islem geri alma butonunun route edildiği tipler (forms.js islemGeriAl rotasıyla örtüşür;
// ABORT_KAYDI dahil — openIslemDetay da onu geri alınabilir sayar, generic geri_al yolu)
const _GM_UNDO_ISLEM_TIPLERI = ['TOHUMLAMA', 'TOHUMLAMA_GUNCELLENDI', 'HASTALIK_KAYDI', 'VAKA_ACILDI', 'TEDAVI_GUN_EKLENDI', 'ABORT_KAYDI'];
// Karttaki fmtTarihSaat Europe/Istanbul'a çevirir (helpers.js) — CSV ve dateKey
// aynı kuralı izler; aksi halde gece saatlerinde kart/CSV/grup farklı gün gösterir.
const _GM_TZ = 'Europe/Istanbul';
const _GM_IST_GUN = new Intl.DateTimeFormat('en-CA', { timeZone: _GM_TZ, year: 'numeric', month: '2-digit', day: '2-digit' });
const _GM_IST_SAAT = new Intl.DateTimeFormat('tr-TR', { timeZone: _GM_TZ, hour: '2-digit', minute: '2-digit', hour12: false });
// kategori → TR etiket / gün sayacı emojisi (spec C sırası: 🐄 💉 🏥 ✅ 💊 🐮)
// TG1 Faz 1: tek-gün görünümünün yeni kaynak kategorileri de burada tanımlı —
// defter hattı bu kategorilerde entry ÜRETMEZ (aşağıda §C dokunulmazlık testi),
// yalnız gün hattı kullanır; CSV/grup sayacı ortak haritadan okur.
const _GM_KATEGORI_TR = {
  dogum: 'Doğum', tohumlama: 'Tohumlama', hastalik: 'Hastalık', gorev: 'Görev', uygulama: 'Uygulama', islem: 'İşlem',
  asi: 'Aşı', kizginlik: 'Kızgınlık', stok: 'Stok Hareketi', cikis: 'Çıkış', sutten: 'Sütten Kesme', protokol: 'Protokol',
};
const _GM_KATEGORI_EMOJI = {
  dogum: '🐄', tohumlama: '💉', hastalik: '🏥', gorev: '✅', uygulama: '💊', islem: '🐮',
  asi: '💉', kizginlik: '🔴', stok: '📦', cikis: '🚪', sutten: '🍼', protokol: '🩺',
};
const _GM_AYLAR = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _GM_GUNLER = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];

// ── Politika filtresi (spec B tablosu) ───────────────────
// sourceKey: kaynak tablo anahtarı (gorev_log/tohumlama/cases/dogum/uygulama_log/islem_log)
// veya entry tipi (gorev/tohumlama/hastalik/dogum/uygulama/islem) — ikisi de kabul.
function _gmPolicyRow(sourceKey, row) {
  if (!row) return false;
  switch (sourceKey) {
    case 'gorev_log': case 'gorev':
      // tamamlanma tarihi ZORUNLU — hedef_tarih fallback yok (pending sızıntısı kuralı);
      // iptal edilmiş görev "yapılmış iş" değildir (canlı şemada gorev_log.iptal kolonu mevcut)
      return row.tamamlandi === true && !!row.tamamlanma_tarihi && !row.iptal && row.durum !== 'geri_alindi';
    case 'tohumlama':
      // terminal sonuç allow-list; geri alınmış kayıt "yapılmış iş" değil (D11)
      return _GM_TOH_TERMINAL.includes(row.sonuc) && row.durum !== 'geri_alindi';
    case 'cases': case 'hastalik':
      // closed_at şart — dolmayan kapalı vaka geçmişe girmez (veri kalitesi sinyali)
      return row.status === 'closed' && !!row.closed_at;
    case 'islem_log': case 'islem':
      return _GM_ISLEM_TIPLERI.includes(row.tip) && row.durum !== 'geri_alindi';
    default:
      return true; // dogum, uygulama_log — aynen kabul
  }
}

// Klasik görünüm politikası (eski düz-liste davranışı): gorev dışında her şey
// kabul; gorev filtresi (tamamlandi/parent_id) çağıran tarafta _gecmisTumu'ye
// göre satır satır uygulanır. islem yine 5 tip.
function _gmPolicyRowKlasik(sourceKey, row) {
  if (!row) return false;
  if (sourceKey === 'islem_log' || sourceKey === 'islem')
    return _GM_ISLEM_TIPLERI.includes(row.tip);
  return true;
}

// ── Olay zamanı (spec B eventAt sütunu) ──────────────────
function _gmEventAt(sourceKey, row) {
  switch (sourceKey) {
    case 'gorev_log': case 'gorev':
      return row.tamamlanma_tarihi || '';
    case 'tohumlama':
      // created_at yoksa tarih gününü 00:00'a al (sonuç zaman anlamı korunur)
      if (row.created_at) return row.created_at;
      if (!row.tarih) return '';
      return String(row.tarih).includes('T') ? row.tarih : row.tarih + 'T00:00:00';
    case 'cases': case 'hastalik':
      return row.closed_at || '';
    case 'dogum':
      return row.created_at || row.tarih || '';
    case 'uygulama_log': case 'uygulama':
      return row.created_at || row.tarih || '';
    case 'islem_log': case 'islem':
      return row.tarih || row.created_at || '';
    default:
      return '';
  }
}

// dateKey = eventAt'in Europe/Istanbul takvim günü (kart fmtTarihSaat ile aynı kural).
// Z VEYA explicit offset'li (+03:00) damgalar Intl ile çevrilir; timezone'suz
// yerel yazımlar aynen korunur (impl-review-r2: yalnız Z kontrolü +00:00'ı kaçırıyordu).
const _GM_TZ_ESNEK = /(Z|[+-]\d{2}:\d{2})$/;
function _gmDateKey(eventAt) {
  const s = String(eventAt || '');
  if (_GM_TZ_ESNEK.test(s)) {
    try { return _GM_IST_GUN.format(new Date(s)); } catch (e) { /* düşer slice'a */ }
  }
  return s.slice(0, 10);
}

// Klasik modda eski eventAt kuralları (tarih=fallback'li, bekleyen dahil)
function _gmEventAtKlasik(sourceKey, row) {
  switch (sourceKey) {
    case 'gorev_log': case 'gorev':
      return row.tamamlanma_tarihi || row.created_at || row.hedef_tarih || '';
    case 'tohumlama':
      return row.created_at || row.tarih || '';
    case 'cases': case 'hastalik':
      return row.created_at || row.start_date || '';
    case 'dogum':
    case 'uygulama_log': case 'uygulama':
      return row.created_at || row.tarih || '';
    case 'islem_log': case 'islem':
      return row.tarih || row.created_at || '';
    default:
      return '';
  }
}

// ── Olay-günü kuralı — tek-gün görünümü (TG1 Faz 1, rapor §D.c) ──
// Defter dateKey "kayıt anı"nı (created_at/closed_at) esas alır; olay-günü ise
// OLAY'ın kendi tarih kolonunu. İki kural, iki ayrı doğru — dateKey davranışı
// DEĞİŞMEZ. Normalizasyon _gmDateKey ile AYNI disiplini izler (_GM_TZ_ESNEK):
// Z/offset damgalı timestamptz → Europe/Istanbul takvim günü (Intl); date
// kolonu ve timezone'suz yerel yazım → değer aynen (TZ'siz, güvenli).
// Canlı sapma kanıtı (rapor §D.c/§E-13): tohumlama'da 252/282, aşıda 356/381
// satırda created_at günü ≠ olay günü — bu yüzden ayrı kolon haritası şart.
function _gmGunZaman(sourceKey, row) {
  if (!row) return '';
  switch (sourceKey) {
    case 'gorev_log': case 'gorev':
      return row.tamamlanma_tarihi || '';                                   // timestamptz
    case 'tohumlama':
      return row.tarih || '';                                               // date
    case 'tohumlama_sonuc':
      // sonuç kalemi kendi sonuç gününde: Gebe/Boş→kontrol, Abort→abort, Doğum→doğum
      if (row.sonuc === 'Doğum Yaptı') return row.dogum_tarihi || '';
      if (row.sonuc === 'Abort') return row.abort_tarihi || '';
      return row.kontrol_tarihi || '';
    case 'cases': case 'hastalik':
      return row.start_date || '';                                          // date — açılış
    case 'cases_kapanis':
      return row.closed_at || '';                                           // timestamptz — kapanış
    case 'dogum':
      return row.tarih || '';
    case 'uygulama_log': case 'uygulama':
      return row.tarih || '';
    case 'islem_log': case 'islem':
      return row.tarih || row.created_at || '';                             // timestamptz
    case 'vaccination_log': case 'asi':
      return row.vaccination_date || '';                                    // date
    case 'kizginlik_log': case 'kizginlik':
      return row.tarih || '';                                               // date
    case 'stok_hareket':
      return row.tarih || '';                                               // timestamptz
    case 'hayvanlar':
      return row.cikis_tarihi || '';                                        // date — satış/ölüm/kesim
    case 'hayvanlar_sutten':
      return row.suttten_kesme_tarihi || '';                                // date
    case 'protokol_instance': case 'protokol':
      return row.baslangic || '';                                           // date — açılış
    case 'protokol_instance_kapanis':
      return row.kapandi_at || '';                                          // timestamptz — kapanış
    default:
      return '';
  }
}

// SAF olay-günü anahtarı: seçilen günün olaylarını süzmek için tek kapı.
function olayGunu(sourceKey, row) {
  const v = _gmGunZaman(sourceKey, row);
  return v ? _gmDateKey(v) : '';
}

// ── Tek-gün görünümü hattı (TG1 Faz 1) ────────────────────
// _gmEntriesFromSources'tan AYRI hat: politika seti gün görünümüne göre
// gevşetilmiş (rapor §D.c.3) ve 5 yeni kaynak (rapor §B.1) burada işlenir —
// defter hattına bu kaynaklar SIZMAZ. Politika farkları:
//   cases: açık vakanın açılış günü de olaydır (status ne olursa); kapanış
//          ayrı kalem (closed_at TR-günü)
//   tohumlama: Bekliyor dâhil her tohumlama kendi tarihinde; terminal sonuç
//          kendi sonuç gününde AYRI kalem (tohumlama_sonuc)
//   islem_log: gün görünümü TÜM tipleri gösterebilir (defter kürasyonu
//          _GM_ISLEM_TIPLERI ile defterde kalır); geri_alindi yine girmez
//   gorev_log: tamamlanma şartı KALIR (tamamlanma olayı); iptal hariç
// DEDUP öncelik tablosu (zarf md.3 — "islem_log birleşik günlük" aynaları;
// eşleşme yalnız AYNI olay-günü + aynı hayvan/ref içinde baskılar):
//   vaccination_log  > islem_log ASI_KAYDI      (hayvan+gün)
//   kizginlik_log    > islem_log KIZGINLIK_KAYDI(hayvan+gün)
//   hayvanlar_sutten > islem_log SUTEN_KESME    (hayvan+gün)
//   tohumlama        > islem_log TOHUMLAMA      (ref_id BOŞSA hayvan+gün)
//   cases            > islem_log VAKA_ACILDI    (ref_id BOŞSA hayvan+gün)
//   tohumlama        > stok_hareket             (referans_tipi='tohumlama' + id + gün)
// TG1-W3 (luna F1/F2 kesinleştirmesi): ref_id DOLU islem aynasında baskılama
// YALNIZ ref hedefi bulunursa VE olay-günü aynıysa; eşleşmeyen ref'te
// HAYVAN+GÜN fallback'ı UYGULANMAZ (gerçek ayrı olay görünür kalır). Stok
// baskılama yalnız referans_tipi doğrulamasıyla İLGİLİ kaynak ailesinin
// birincil kayıt id'lerine bağlanır — canlıda tek çalışan aile 'tohumlama'
// (tedavi seans stoku referans taşımaz: notlar 'drug_admin:' deseni; aşı
// ailesi goal öncelik tablosunda baskılanmaz); aile dışı/non-stok entry
// id'siyle gün eşleşmesi baskılama ÜRETMEZ. %97 referanssız satır "genel
// stok hareketi" olarak KALIR (rapor §E.3).
function _gmGunEntriesFromSources(sources, scope) {
  sources = sources || {};
  const out = [];
  const ekle = (sourceKey, entryType, row, v) => {
    const eventAt = _gmGunZaman(sourceKey, row);
    if (!eventAt) return;
    out.push({
      type: entryType,
      category: entryType,
      sourceKey,
      eventAt,
      dateKey: _gmDateKey(eventAt),
      olayGunu: _gmDateKey(eventAt),
      undoRef: null, // gün görünümü geri-al butonu üretmez (defter ayrıcalığı)
      data: row,
      ...v,
    });
  };
  const geriDegil = r => r && r.durum !== 'geri_alindi';

  // mevcut 6 kaynak — gün politikasıyla
  (sources.dogum || []).forEach(r => { if (r && r.tarih) ekle('dogum', 'dogum', r); });
  (sources.tohumlama || []).forEach(r => {
    if (!geriDegil(r) || !r.tarih) return;
    ekle('tohumlama', 'tohumlama', r); // Bekliyor dâhil
    if (_GM_TOH_TERMINAL.includes(r.sonuc) && olayGunu('tohumlama_sonuc', r)) ekle('tohumlama_sonuc', 'tohumlama', r);
  });
  (sources.cases || []).forEach(r => {
    if (!r || !r.start_date) return;
    ekle('cases', 'hastalik', r); // açık vakanın açılışı da olaydır
    if (r.status === 'closed' && r.closed_at) ekle('cases_kapanis', 'hastalik', r);
  });
  (sources.gorev_log || []).forEach(r => {
    if (r && r.tamamlandi === true && !!r.tamamlanma_tarihi && !r.iptal && geriDegil(r)) ekle('gorev_log', 'gorev', r);
  });
  (sources.uygulama_log || []).forEach(r => { if (r && r.tarih) ekle('uygulama_log', 'uygulama', r); });
  (sources.islem_log || []).forEach(r => {
    if (geriDegil(r) && (r.tarih || r.created_at)) ekle('islem_log', 'islem', r); // TÜM tipler; dedup baskılar
  });

  // TG1: 5 yeni kaynak (rapor §B.1)
  (sources.vaccination_log || []).forEach(r => { if (r && r.vaccination_date) ekle('vaccination_log', 'asi', r); });
  (sources.kizginlik_log || []).forEach(r => { if (r && r.tarih) ekle('kizginlik_log', 'kizginlik', r); });
  (sources.stok_hareket || []).forEach(r => { if (r && !r.iptal && r.tarih) ekle('stok_hareket', 'stok', r); });
  (sources.hayvanlar || []).forEach(r => {
    if (!r) return;
    if (r.cikis_tarihi && r.cikis_tipi) ekle('hayvanlar', 'cikis', r);
    if (r.suttten_kesme_tarihi) ekle('hayvanlar_sutten', 'sutten', r);
  });
  (sources.protokol_instance || []).forEach(r => {
    if (!r) return;
    if (r.baslangic) ekle('protokol_instance', 'protokol', r);
    if (r.kapandi_at) ekle('protokol_instance_kapanis', 'protokol', r);
  });

  // DEDUP — kazanan kalemlerden baskı kümeleri kurulur, islem/stok baskılanır
  const asiKey = new Set(), kizKey = new Set(), suttenKey = new Set(), tohKey = new Set();
  const tohRefGun = new Set(), vakaRefGun = new Set(), vakaKey = new Set();
  const refId = v => (v === null || v === undefined) ? '' : String(v).trim();
  out.forEach(e => {
    const g = e.olayGunu, r = e.data || {};
    if (e.sourceKey === 'vaccination_log') asiKey.add(r.animal_id + '|' + g);
    else if (e.sourceKey === 'kizginlik_log') kizKey.add(r.hayvan_id + '|' + g);
    else if (e.sourceKey === 'hayvanlar_sutten') suttenKey.add(r.id + '|' + g);
    else if (e.sourceKey === 'tohumlama') { tohKey.add(r.hayvan_id + '|' + g); if (r.id) tohRefGun.add(refId(r.id) + '|' + g); }
    else if (e.sourceKey === 'cases') { vakaKey.add(r.animal_id + '|' + g); if (r.id) vakaRefGun.add(refId(r.id) + '|' + g); }
  });
  const baskili = new Set();
  out.forEach(e => {
    const g = e.olayGunu, r = e.data || {};
    if (e.sourceKey === 'islem_log') {
      if (r.tip === 'ASI_KAYDI' && asiKey.has(r.ana_hayvan_id + '|' + g)) return baskili.add(e);
      if (r.tip === 'KIZGINLIK_KAYDI' && kizKey.has(r.ana_hayvan_id + '|' + g)) return baskili.add(e);
      if (r.tip === 'SUTEN_KESME' && suttenKey.has(r.ana_hayvan_id + '|' + g)) return baskili.add(e);
      // TG1-W3 (luna F1): ref_id DOLU ise yalnız id+gün eşleşmesi baskılar;
      // HAYVAN+GÜN fallback'ı yalnız ref_id BOŞ aynada geçerli.
      if (r.tip === 'TOHUMLAMA') {
        const rid = refId(r.ref_id);
        if (rid ? tohRefGun.has(rid + '|' + g) : tohKey.has(r.ana_hayvan_id + '|' + g)) return baskili.add(e);
      }
      if (r.tip === 'VAKA_ACILDI') {
        const rid = refId(r.ref_id);
        if (rid ? vakaRefGun.has(rid + '|' + g) : vakaKey.has(r.ana_hayvan_id + '|' + g)) return baskili.add(e);
      }
    } else if (e.sourceKey === 'stok_hareket' && refId(r.referans_id)
      && String(r.referans_tipi || '').trim() === 'tohumlama'
      && tohRefGun.has(refId(r.referans_id) + '|' + g)) {
      // TG1-W3 (luna F2): stok baskılama yalnız aile+tipi doğrulamasıyla —
      // tohumlama kaynaklı stok düşüşü, tohumlama kalemi kazanır.
      return baskili.add(e);
    }
  });
  let sonuc = baskili.size ? out.filter(e => !baskili.has(e)) : out;
  // TG1-W3 (luna F9): hayvan kartının gün görünümü kapsamı — defter scope'uyla
  // AYNI kaynak bazlı eşleşme kuralları; stok_hareket hayvansızdır (§E.3),
  // hayvan kapsamında görünmez.
  if (scope && scope.animalId) sonuc = sonuc.filter(e => _gmGunHayvanId(e.sourceKey, e.data || {}) === scope.animalId);
  sonuc.sort((a, b) => b.eventAt.localeCompare(a.eventAt));
  return sonuc;
}

// TG1-W3 (luna F9): gün hattı entry'sinin hayvan referansı — kaynak bazlı
// alan eşlemesi (defter _gmEntriesFromSources scope eşleşmeleriyle paralel).
function _gmGunHayvanId(sourceKey, row) {
  if (sourceKey === 'tohumlama' || sourceKey === 'tohumlama_sonuc') return row.hayvan_id;
  if (sourceKey === 'cases' || sourceKey === 'cases_kapanis') return row.animal_id;
  if (sourceKey === 'dogum') return row.anne_id;
  if (sourceKey === 'islem_log') return row.ana_hayvan_id;
  if (sourceKey === 'vaccination_log') return row.animal_id;
  if (sourceKey === 'hayvanlar' || sourceKey === 'hayvanlar_sutten') return row.id;
  if (sourceKey === 'gorev_log' || sourceKey === 'uygulama_log' || sourceKey === 'kizginlik_log'
    || sourceKey === 'protokol_instance' || sourceKey === 'protokol_instance_kapanis') return row.hayvan_id;
  return null; // stok_hareket — hayvansız (§E.3)
}

// ── Geri alma bağlamı (openTohDet muhafazası, spec E) ─────
// Ham (politika öncesi) kaynaklardan türetilir: TOHUMLAMA islem_log referansları,
// ABORT_KAYDI muhafazaları ve hayvan başına SON tohumlama id'si.
function _gmUndoCtx(sources) {
  const islemRefByTohId = {};
  const abortGuardedByTohId = {};
  (sources.islem_log || []).forEach(l => {
    if (!l || l.durum === 'geri_alindi' || !l.ref_id) return;
    if (l.tip === 'TOHUMLAMA') islemRefByTohId[l.ref_id] = l.id;
    else if (l.tip === 'ABORT_KAYDI') abortGuardedByTohId[l.ref_id] = true;
  });
  const latestTohIdByAnimal = {};
  (sources.tohumlama || []).slice()
    .sort((a, b) => (String(b.tarih || '').localeCompare(String(a.tarih || ''))) ||
                    (String(b.created_at || '').localeCompare(String(a.created_at || ''))))
    .forEach(t => {
      if (t && t.hayvan_id && !latestTohIdByAnimal[t.hayvan_id]) latestTohIdByAnimal[t.hayvan_id] = t.id;
    });
  return { islemRefByTohId, abortGuardedByTohId, latestTohIdByAnimal };
}

// ── Entry üretimi (normalize + politika) ─────────────────
// sources: {gorev_log:[],tohumlama:[],cases:[],dogum:[],uygulama_log:[],islem_log:[]}
// scope:   {animalId?} — hayvan kartı geçmişi için kaynak bazında mevcut eşleşme kuralları
// opts:    {mode:'defter'|'klasik', tumu:boolean} — klasik mod eski davranışı geri getirir
// Çıktı: eventAt desc sıralı entry listesi; eventAt'i boş kalan satır entry üretmez.
function _gmEntriesFromSources(sources, scope, opts) {
  sources = sources || {};
  scope = scope || {};
  opts = opts || {};
  const klasik = opts.mode === 'klasik';
  const id = scope.animalId;
  const ctx = _gmUndoCtx(sources);
  const out = [];
  const push = (sourceKey, entryType, rows, match) => {
    (rows || []).forEach(row => {
      if (!row) return;
      if (id && !(match && match(row))) return; // kapsam filtresi (yalnız hayvan kartı)
      if (klasik) {
        if (sourceKey === 'gorev_log' || sourceKey === 'gorev') {
          // iptal edilen iş hiçbir görünümde listelenmez
          if (row.iptal) return;
          // eski default: tamamlandı VE parent'sız; "Tümü" açıkken ikisi de kalkar
          if (!opts.tumu && !(row.tamamlandi === true && !row.parent_id)) return;
        }
        if (!_gmPolicyRowKlasik(sourceKey, row)) return;
      } else if (!_gmPolicyRow(sourceKey, row)) return;
      const eventAt = klasik ? _gmEventAtKlasik(sourceKey, row) : _gmEventAt(sourceKey, row);
      if (!eventAt) return;
      out.push({
        type: entryType,
        category: entryType,
        sourceKey, // TG1: kaynak tablo anahtarı açık taşınır — type↔sourceKey birebir
                   // DEĞİL (cases→hastalik, islem_log→islem); tip'ten geri çözüm YASAK.
        eventAt,
        dateKey: _gmDateKey(eventAt),
        undoRef: _gmUndoRef(entryType, row, ctx),
        data: row,
      });
    });
  };
  push('dogum', 'dogum', sources.dogum, r => r.anne_id === id);
  push('tohumlama', 'tohumlama', sources.tohumlama, r => r.hayvan_id === id);
  push('cases', 'hastalik', sources.cases, r => r.animal_id === id);
  push('gorev_log', 'gorev', sources.gorev_log, r => r.hayvan_id === id);
  push('uygulama_log', 'uygulama', sources.uygulama_log, r => r.hayvan_id === id);
  push('islem_log', 'islem', sources.islem_log, r => r.ana_hayvan_id === id);
  out.sort((a, b) => b.eventAt.localeCompare(a.eventAt));
  return out;
}

// ── undoRef türetimi (spec E — önceden hesaplanır, genel kural YOK) ──
function _gmUndoRef(type, data, ctx) {
  ctx = ctx || {};
  if (type === 'islem') {
    if (!data.id || !_GM_UNDO_ISLEM_TIPLERI.includes(data.tip)) return null;
    return { kind: 'islem', id: data.id };
  }
  if (type === 'tohumlama') {
    if (!data.id) return null;
    // abort muhafazası: hayvanın son üreme olayı abort ise buton yok (openTohDet kuralı)
    if (ctx.abortGuardedByTohId && ctx.abortGuardedByTohId[data.id]) return null;
    // islem_log referansı varsa o id ile geri alınır
    const refId = ctx.islemRefByTohId && ctx.islemRefByTohId[data.id];
    if (refId) return { kind: 'islem', id: refId };
    // Doğrudan toh: silme yolu YALNIZCA sonucu 'Bekliyor' olan SON kayıtta
    // (üretim guard'ı openTohDet — terminal sonuçlu kayıt asla doğrudan silinmez;
    // politika Bekliyor'u geçmişe almadığından pratikte bu yol üretilmez)
    if (data.sonuc === 'Bekliyor') {
      const son = ctx.latestTohIdByAnimal && ctx.latestTohIdByAnimal[data.hayvan_id];
      if (son && son === data.id) return { kind: 'toh', id: data.id };
    }
    return null;
  }
  return null; // gorev / hastalik / dogum / uygulama → buton yok
}

// onclick attribute değeri için minik kaçış (helpers.js'e bağımlılık yok)
function _gmAttr(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/'/g, '&#39;')
    .replace(/"/g, '&quot;').replace(/</g, '&lt;');
}

// Geri al butonu — kart içeriği İÇİNE kardeş buton olarak girer (spec E);
// overrideOc dış onclick'ini etkilemez. ref yok/çevrimdışı → buton YOK (D10/D13).
// Değerler dataset'te taşınır (this.dataset deseni — helpers.js:90-96 kuralı:
// entity-escape edilmiş değer inline JS string'ine asla konmaz; onclick sabit stringdir).
function _gmUndoButtonHtml(ref, opts) {
  if (!ref || (opts && opts.offline)) return '';
  return `<button type="button" data-kind="${_gmAttr(ref.kind)}" data-id="${_gmAttr(ref.id)}" style="margin-top:6px;font-size:.66rem;font-weight:700;padding:3px 10px;border-radius:8px;border:1.5px solid var(--red);background:transparent;color:var(--red)" onclick="event.stopPropagation();gmUndoClick(this.dataset.kind,this.dataset.id)">↩ Geri Al</button>`;
}

// ── Cap + gün gruplama + sayaçlar (spec C, D12) ──────────
function _gmCap(entries, n) {
  const hepsi = entries || [];
  return { visible: hepsi.slice(0, n || 300), total: hepsi.length };
}

// Görünen dilimden tarih bazlı sıralı gruplar; sayaçlar YALNIZ o grubun
// görünen kayıtlarından sayılır (yalnız mevcut kategori anahtarları).
function _gmGroup(visible) {
  const gruplar = [];
  const indeks = {};
  (visible || []).forEach(e => {
    let g = indeks[e.dateKey];
    if (!g) {
      g = indeks[e.dateKey] = { dateKey: e.dateKey, entries: [], counters: {} };
      gruplar.push(g);
    }
    g.entries.push(e);
    g.counters[e.category] = (g.counters[e.category] || 0) + 1;
  });
  return gruplar;
}

// Yerel bugünün YYYY-MM-DD anahtarı (Date UTC dönüşümü değil, takvim alanı)
function _gmTodayKey(d) {
  const t = d || new Date();
  const p = x => String(x).padStart(2, '0');
  return t.getFullYear() + '-' + p(t.getMonth() + 1) + '-' + p(t.getDate());
}

function _gmGroupLabel(dateKey, todayKey) {
  // TG1 todayKey sözleşmesi (zarf md.4): todayKey = GERÇEK bugün; DÜN bu
  // günden türetilir — sistem saatinden ayrı olarak ASLA. Enjekte edilen
  // todayKey (testler, tek-gün görünümü) gerçek saatten önceliklidir; tek-gün
  // görünümü seçili günü todayKey'e GEÇİRMEZ (seçili gün vurgusu ayrı yüzeydedir).
  const bugun = todayKey || _gmTodayKey();
  if (dateKey === bugun) return 'BUGÜN';
  const parcaBugun = String(bugun).split('-').map(Number);
  if (parcaBugun.length === 3 && parcaBugun.every(n => !isNaN(n))) {
    // Date gün-arithmetiği ay/yıl devrini doğru yapar (31→1, Aralık→Ocak)
    const dun = new Date(parcaBugun[0], parcaBugun[1] - 1, parcaBugun[2] - 1);
    if (dateKey === _gmTodayKey(dun)) return 'DÜN';
  }
  const parca = String(dateKey).split('-');
  const d = new Date(Number(parca[0]), Number(parca[1]) - 1, Number(parca[2]));
  if (isNaN(d.getTime())) return dateKey;
  return d.getDate() + ' ' + _GM_AYLAR[d.getMonth()] + ' ' + _GM_GUNLER[d.getDay()];
}

// Gün bölümü — native <details> (D12). entryHtmlFn ui.js kart üreticisidir.
function _gmGroupHtml(group, entryHtmlFn, opts) {
  opts = opts || {};
  const acik = opts.open !== false;
  const sayac = Object.keys(_GM_KATEGORI_EMOJI)
    .filter(k => group.counters && group.counters[k])
    .map(k => `<span>${_GM_KATEGORI_EMOJI[k]} ${group.counters[k]}</span>`)
    .join('');
  const kartlar = (group.entries || []).map(e => entryHtmlFn(e)).join('');
  return `<details class="gm-gun"${acik ? ' open' : ''} style="margin-bottom:10px">
  <summary style="cursor:pointer;list-style:none;display:flex;align-items:baseline;gap:10px;padding:7px 2px;user-select:none;flex-wrap:wrap">
    <span style="font-weight:800;font-size:.76rem;color:var(--ink);letter-spacing:.02em">${_gmGroupLabel(group.dateKey, opts.todayKey)}</span>
    <span style="display:flex;gap:9px;font-size:.66rem;color:var(--ink3);flex-wrap:wrap">${sayac}</span>
  </summary>
  ${kartlar}
</details>`;
}

// ── Arama (spec A: _gecmisSearchText semantiği) ──────────
// helpers.js'teki trLower ile aynı kural — modül bağımsızlığı için yerel kopya.
function _gmTrLower(s) {
  return String(s).replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

// Çok terimli AND araması; entry.searchText ui.js toplama adımında doldurulur.
function _gmSearch(entries, q) {
  const terimler = _gmTrLower(q || '').trim().split(/\s+/).filter(Boolean);
  const hepsi = entries || [];
  if (!terimler.length) return hepsi.slice();
  return hepsi.filter(e => {
    const s = e.searchText || e._s || '';
    return terimler.every(t => s.includes(t));
  });
}

// ── CSV üretimi (spec D — WYSIWYG görünen dilim üzerinden) ──
// HTML etiketlerini at, boşlukları topla (kart alt metinlerinden düz metin).
function _gmStripTags(s) {
  return String(s == null ? '' : s)
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function _gmCsvEscape(v) {
  let s = String(v == null ? '' : v);
  // formül enjeksiyonu koruması: = + - @ ile başlayan metin alanlarına ' öneki
  if (/^[=+\-@]/.test(s)) s = "'" + s;
  return /[";\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

function _gmCsvTarih(eventAt) {
  return _gmDateKey(eventAt).split('-').reverse().join('.');
}

function _gmCsvSaat(eventAt) {
  const s = String(eventAt || '');
  if (_GM_TZ_ESNEK.test(s)) {
    try { return _GM_IST_SAAT.format(new Date(s)); } catch (e) { return ''; }
  }
  return s.length > 10 && s.includes('T') ? s.slice(11, 16) : '';
}

// visible: _gmCap sonucu görünen dilim; meta: {kupe,detay,ek,hekim,tip} — her biri (entry)=>string.
function _gmCsv(visible, meta) {
  const m = meta || {};
  const satirlar = ['Tarih;Saat;Kategori;Küpe;Detay;Ek Bilgi;Hekim;Tip'];
  (visible || []).forEach(e => {
    const h = fn => _gmCsvEscape(_gmStripTags(typeof fn === 'function' ? fn(e) : ''));
    satirlar.push([
      _gmCsvEscape(_gmCsvTarih(e.eventAt)),
      _gmCsvEscape(_gmCsvSaat(e.eventAt)),
      _gmCsvEscape(_GM_KATEGORI_TR[e.category] || e.category || ''),
      h(m.kupe),
      h(m.detay),
      h(m.ek),
      h(m.hekim),
      h(m.tip),
    ].join(';'));
  });
  return '\uFEFF' + satirlar.join('\r\n') + '\r\n';
}

// İndirgeme — yalnız ana sekme görünümündeki görünen dilim (D7). ui.js her
// render'da globalThis._gmCsvCtx = {visible, meta} günceller.
function _gmDownloadCsv() {
  const ctx = globalThis._gmCsvCtx;
  if (!ctx || !ctx.visible || !ctx.visible.length) return;
  const csv = _gmCsv(ctx.visible, ctx.meta);
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'egesut-gecmis-' + _gmTodayKey() + '.csv';
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
