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
const _GM_KATEGORI_TR = { dogum: 'Doğum', tohumlama: 'Tohumlama', hastalik: 'Hastalık', gorev: 'Görev', uygulama: 'Uygulama', islem: 'İşlem' };
const _GM_KATEGORI_EMOJI = { dogum: '🐄', tohumlama: '💉', hastalik: '🏥', gorev: '✅', uygulama: '💊', islem: '🐮' };
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
// sources: {gorev_log:[], tohumlama:[], cases:[], dogum:[], uygulama_log:[], islem_log:[]}
// scope:   {animalId?} — hayvan kartı geçmişi için kaynak bazında mevcut eşleşme kuralları
// Çıktı: eventAt desc sıralı entry listesi; eventAt'i boş kalan satır entry üretmez.
function _gmEntriesFromSources(sources, scope) {
  sources = sources || {};
  scope = scope || {};
  const id = scope.animalId;
  const ctx = _gmUndoCtx(sources);
  const out = [];
  const push = (sourceKey, entryType, rows, match) => {
    (rows || []).forEach(row => {
      if (!row) return;
      if (id && !(match && match(row))) return; // kapsam filtresi (yalnız hayvan kartı)
      if (!_gmPolicyRow(sourceKey, row)) return;
      const eventAt = _gmEventAt(sourceKey, row);
      if (!eventAt) return;
      out.push({
        type: entryType,
        category: entryType,
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
  const bugun = todayKey || _gmTodayKey();
  if (dateKey === bugun) return 'BUGÜN';
  const dun = new Date();
  dun.setDate(dun.getDate() - 1);
  if (dateKey === _gmTodayKey(dun)) return 'DÜN';
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
