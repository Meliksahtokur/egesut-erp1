// js/degisiklikler/diff.js
// SAF katman (G-20260913-SURUM-GECMISI F3): degisim_log satırlarından alan farkı
// ve işlem özeti üretir. DOM'a dokunmaz; node --test ile test edilir
// (tests/unit/degisiklikler-diff.test.js).

// Anahtar sırasından bağımsız, derin eşitlik için kararlı serileştirme
function _dgKararli(v) {
  if (v === undefined) return 'undefined';
  if (v === null || typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return '[' + v.map(_dgKararli).join(',') + ']';
  return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + _dgKararli(v[k])).join(',') + '}';
}

function _dgNesne(v) {
  return v && typeof v === 'object' && !Array.isArray(v) ? v : null;
}

// diffSatirlari(eski, yeni) -> [{alan, eski, yeni, durum}]
// durum: 'eklendi' | 'silindi' | 'degisti' | 'ayni'
//  - eski yok (INSERT)  → tüm alanlar 'eklendi'
//  - yeni yok (DELETE)  → tüm alanlar 'silindi'
//  - ikisi de var (UPDATE) → alan bazında karşılaştırma; eksik değer null gösterilir
// Sıra: eski satırın alan sırası, ardından yalnız yenide olan alanlar.
function diffSatirlari(eski, yeni) {
  const e = _dgNesne(eski), y = _dgNesne(yeni);
  if (!e && !y) return [];
  const alanlar = [];
  const gorulen = new Set();
  [e, y].forEach(o => {
    if (!o) return;
    Object.keys(o).forEach(k => { if (!gorulen.has(k)) { gorulen.add(k); alanlar.push(k); } });
  });
  return alanlar.map(alan => {
    const eVar = !!e && Object.prototype.hasOwnProperty.call(e, alan);
    const yVar = !!y && Object.prototype.hasOwnProperty.call(y, alan);
    const ev = eVar ? e[alan] : null;
    const yv = yVar ? y[alan] : null;
    let durum;
    if (!eVar) durum = 'eklendi';
    else if (!yVar) durum = 'silindi';
    else durum = _dgKararli(ev) === _dgKararli(yv) ? 'ayni' : 'degisti';
    return { alan, eski: ev, yeni: yv, durum };
  });
}

// islemOzeti(rows) -> {tablo_sayisi, satir_sayisi, islemler:{I,U,D}}
// rows: degisim_log detay kayıtları ({tablo_adi, satir_pk, islem}).
// Aynı satırın aynı tx içindeki birden çok sürümü tek satır sayılır.
function islemOzeti(rows) {
  const liste = Array.isArray(rows) ? rows : [];
  const tablolar = new Set();
  const satirlar = new Set();
  const islemler = { I: 0, U: 0, D: 0 };
  liste.forEach(r => {
    if (!r) return;
    tablolar.add(r.tablo_adi);
    satirlar.add(r.tablo_adi + '|' + _dgKararli(r.satir_pk));
    if (Object.prototype.hasOwnProperty.call(islemler, r.islem)) islemler[r.islem]++;
  });
  return { tablo_sayisi: tablolar.size, satir_sayisi: satirlar.size, islemler };
}

// "3 tablo · 5 satır" özet parçası (başlık çağıranda eklenir)
function ozetMetni(ozet) {
  const o = ozet || {};
  return (o.tablo_sayisi || 0) + ' tablo · ' + (o.satir_sayisi || 0) + ' satır';
}

// Hücre değerini okunur düz metne çevirir (HTML ÜRETMEZ — çağıran esc() uygular).
//  null/undefined → '—' · bool → Evet/Hayır · 'YYYY-MM-DD' → gg.aa.yyyy ·
//  ISO zaman damgası → gg.aa.yyyy SS:DD (İstanbul) · nesne/dizi → JSON
function degerMetni(v) {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'boolean') return v ? 'Evet' : 'Hayır';
  if (typeof v === 'number') return String(v);
  if (typeof v === 'object') return JSON.stringify(v);
  const s = String(v);
  let m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (m) return m[3] + '.' + m[2] + '.' + m[1];
  m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/.exec(s);
  if (m) {
    const d = new Date(s);
    if (!isNaN(d.getTime()) && /(Z|[+-]\d{2}(:?\d{2})?)$/.test(s)) {
      return d.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }).replace(',', '');
    }
    return m[3] + '.' + m[2] + '.' + m[1] + ' ' + m[4] + ':' + m[5];
  }
  return s === '' ? '""' : s;
}

// satir_pk (jsonb) → kısa gösterim: {"id":"a1b2…"} → "a1b2c3d4"
function pkKisa(pk) {
  if (pk === null || pk === undefined) return '—';
  if (typeof pk !== 'object') return String(pk).slice(0, 8);
  const vals = Object.values(pk);
  if (vals.length === 1) return String(vals[0]).slice(0, 8);
  return vals.map(v => String(v).slice(0, 8)).join('/');
}
