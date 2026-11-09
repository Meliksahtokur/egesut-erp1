// js/ovsync-tren.js — Ovsync treni: saf HTML/karar yardımcıları (PLAN 2026-11-09 N3/UA1).
//
// Kaynaklar: spec docs/plans/2026-11-09-ovsync-tren/design.md (K1–K11, §6), plan R3–R7/R13/R15/R18,
// sahip onaylı mockup'lar runs/2026-11-09-ovsync-tren/mockup/ (metinler ve sınıflar `_tren-yeni.css`).
//
// Sözleşme:
//  - Tarayıcıda klasik <script> olarak yüklenir; tüm fonksiyonlar global. esc/escAttr helpers.js'ten gelir.
//  - DOM'a ve RPC'ye dokunan tek fonksiyon ovsyncTrenSor'dur ve bağımlılıklarını argümanla alır.
//  - Tarih hesabı yalnız parametre olarak gelen ISO günle (bugunIso, sunucunun TR "bugün"ü) yapılır;
//    sistem saatine/saat dilimine bakılmaz (gece 00:00–03:00 TR'de UTC bir gün geride kalır).
//  - Aksiyon düğmeleri satır içi onclick taşımaz: `data-ovt-aksiyon="<AD>"` + `data-*` parametreleri
//    (bağlama UB3/UB4'te tek delegated dinleyici; DUZENLE → ovsyncEkranindaDuzenle).
//    Aksiyon adları: VAZGEC, BASLAT, TOPTAN, ONAYLA, ERTELE, SONRAKI_TREN, PG48,
//    BASTAN, DEVAM, DUZENLE. Seçenekler: `data-secim` (TREN/BAGIMSIZ; toptan satırında PG48/BASTAN + data-case),
//    N seçici `data-n`.
//  - Renk: vurgu yalnız yazı renginde; satır zemini/sol şerit yok (sahip kuralı).

const _OVT_GUN_KISA = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'];
const _OVT_GUN_UZUN = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];
const _OVT_AY = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
// Kısaltma okunuşuna göre bulunma eki (mockup 1a: "Per 19 Kas'ta").
const _OVT_AY_EK = ["'da", "'ta", "'ta", "'te", "'ta", "'da", "'de", "'da", "'de", "'de", "'ta", "'da"];
// Tren gününe (D0) göre bugünün işi — Ovsync şablonu D0/D7/D8/D9 18:00/D10 (R3: etiket her kaymada güncellenir).
const _OVT_TREN_IS = { 0: 'başlangıç günü', 7: 'PG günü', 8: '2. PG günü', 9: '2. GnRH günü', 10: 'tohumlama günü' };

// ── Tarih yardımcıları (yalnız UTC aritmetiği; ISO 'YYYY-MM-DD') ──────────────

/**
 * ISO günü (YYYY-MM-DD…) epoch gün sayısına çevirir; geçersiz tarih → null.
 * @param {string} iso Tarih.
 * @returns {number|null} Gün numarası.
 */
function _ovtGunNo(iso) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso == null ? '' : iso));
  if (!m) return null;
  const ms = Date.UTC(+m[1], +m[2] - 1, +m[3]);
  const d = new Date(ms);
  if (d.getUTCMonth() !== +m[2] - 1 || d.getUTCDate() !== +m[3]) return null;
  return Math.round(ms / 86400000);
}
/**
 * Gün numarasını ISO güne çevirir.
 * @param {number} n Gün numarası.
 * @returns {string} 'YYYY-MM-DD'.
 */
function _ovtIso(n) {
  const d = new Date(n * 86400000);
  return d.getUTCFullYear() + '-' + String(d.getUTCMonth() + 1).padStart(2, '0') + '-' + String(d.getUTCDate()).padStart(2, '0');
}
/**
 * ISO güne k gün ekler.
 * @param {string} iso Tarih.
 * @param {number} k Gün.
 * @returns {string|null} Yeni ISO gün; geçersiz girdi → null.
 */
function _ovtGunEkle(iso, k) {
  const n = _ovtGunNo(iso);
  return n == null ? null : _ovtIso(n + k);
}
/**
 * b − a (gün).
 * @param {string} a Başlangıç ISO.
 * @param {string} b Bitiş ISO.
 * @returns {number|null} Fark; geçersiz girdi → null.
 */
function _ovtFark(a, b) {
  const x = _ovtGunNo(a), y = _ovtGunNo(b);
  return (x == null || y == null) ? null : y - x;
}
/**
 * "Per 19 Kas" biçimi; geçersiz tarih ham metniyle döner (sessiz boş yok).
 * @param {string} iso Tarih.
 * @returns {string} Kısa gün adı + gün + ay.
 */
function _ovtGunAd(iso) {
  const n = _ovtGunNo(iso);
  if (n == null) return iso == null || iso === '' ? 'tarih yok' : String(iso);
  const d = new Date(n * 86400000);
  return _OVT_GUN_KISA[d.getUTCDay()] + ' ' + d.getUTCDate() + ' ' + _OVT_AY[d.getUTCMonth()];
}
/**
 * "Per 19 Kas'ta" (bulunma ekli).
 * @param {string} iso Tarih.
 * @returns {string} Ekli kısa tarih.
 */
function _ovtGunAdEk(iso) {
  const n = _ovtGunNo(iso);
  if (n == null) return _ovtGunAd(iso);
  return _ovtGunAd(iso) + _OVT_AY_EK[new Date(n * 86400000).getUTCMonth()];
}
/**
 * Haftanın gün adı ("Perşembe").
 * @param {string} iso Tarih.
 * @returns {string} Uzun gün adı; geçersiz → ''.
 */
function _ovtHaftaGunu(iso) {
  const n = _ovtGunNo(iso);
  return n == null ? '' : _OVT_GUN_UZUN[new Date(n * 86400000).getUTCDay()];
}
/**
 * "01.12" biçimi.
 * @param {string} iso Tarih.
 * @returns {string} Gün.ay.
 */
function _ovtGunAy(iso) {
  const p = String(iso || '').slice(0, 10).split('-');
  return p.length === 3 ? p[2] + '.' + p[1] : String(iso || '');
}
/**
 * Değeri metin olarak HTML-escape eder (0 sayısı kaybolmaz).
 * @param {*} v Değer.
 * @returns {string} Escape edilmiş metin.
 */
function _ovtE(v) {
  return esc(v == null ? '' : String(v));
}
/**
 * Bozuk veri bildirimi: geri çağırım varsa o, yoksa console.error (sessiz geçiş yok).
 * @param {Object} k Seçenekler ({hata}).
 * @param {string} mesaj Mesaj.
 * @param {*} veri İlgili kayıt.
 * @returns {void}
 */
function _ovtHataBildir(k, mesaj, veri) {
  if (k && typeof k.hata === 'function') { k.hata(mesaj, veri); return; }
  console.error('[ovsync-tren] ' + mesaj);
}

// ── Bayrak ve K8 "Trene bin" sorusu ──────────────────────────────────────────

/**
 * Tren davranışı açık mı: `ovsync_tren_aktif` = 1 ve `ovsync_pg_kurallari_aktif` = 1.
 * @param {Array<{anahtar:string, deger:*}>} ayarlar protokol_ayar satırları.
 * @returns {boolean} İkisi de 1 ise true.
 */
function ovsyncTrenAktif(ayarlar) {
  if (!Array.isArray(ayarlar)) return false;
  const deger = (a) => { const r = ayarlar.find(x => x && x.anahtar === a); return r ? Number(r.deger) : NaN; };
  return deger('ovsync_tren_aktif') === 1 && deger('ovsync_pg_kurallari_aktif') === 1;
}

/**
 * K8 sorusu gerekli mi (R4): tren açık ve tren günü bugün değil.
 * @param {Object} onizleme ovsync_tren_onizle dönüşü.
 * @param {string} [bugunIso] TR bugünü; yoksa onizleme.bugun.
 * @returns {boolean} Soru modalı açılmalı mı.
 */
function ovsyncTrenSoruGerekli(onizleme, bugunIso) {
  if (!onizleme || onizleme.aktif !== true || !onizleme.tren_gunu) return false;
  const bg = bugunIso || onizleme.bugun;
  return String(onizleme.tren_gunu).slice(0, 10) !== String(bg || '').slice(0, 10);
}

/**
 * K8 modal içeriği (mockup 1a): "🚆 Trene bin" ön seçili, "Bağımsız başlat — bugün".
 * İsteğe bağlı alanlar (RPC dışında çağıranın eklediği): kupe_no, kural_tarihi, uye_kupeler.
 * @param {Object} onizleme ovsync_tren_onizle dönüşü (+ isteğe bağlı alanlar).
 * @returns {string} Modal HTML'i (m-title + m-body).
 */
function ovsyncTrenSoruHtml(onizleme) {
  const o = onizleme || {};
  const kupe = (o.kupe_no != null && o.kupe_no !== '') ? String(o.kupe_no) : '';
  const tren = o.tren_gunu, bugun = o.bugun;
  const secenek = (secim, on, ust, alt) => '<div data-secim="' + secim + '" role="radio" aria-checked="' + (on ? 'true' : 'false') + '"'
    + ' style="border:1.5px solid var(--card3);border-radius:12px;padding:12px 13px;margin-bottom:9px;cursor:pointer">'
    + '<div class="ovs-radyo' + (on ? ' on' : '') + '" style="padding:0;font-size:.95rem"><i></i>' + ust + '</div>'
    + '<div style="font-size:.74rem;color:var(--ink3);margin-top:5px;padding-left:24px;line-height:1.45">' + alt + '</div></div>';

  let h = '<div class="m-title">▶ Ovsync başlat' + (kupe ? ' — ' + _ovtE(kupe) : '') + '</div><div class="m-body">';
  const ustSatir = [];
  if (o.kural_tarihi) ustSatir.push('Kural günü ' + _ovtGunAd(o.kural_tarihi));
  if (_ovtHaftaGunu(tren)) ustSatir.push('tren her ' + _ovtHaftaGunu(tren));
  if (ustSatir.length) h += '<div style="font-size:.76rem;color:var(--ink3);margin-bottom:12px">' + _ovtE(ustSatir.join(' · ')) + '</div>';

  const sayi = (o.uye_sayisi != null && o.uye_sayisi !== '') ? ' (' + _ovtE(o.uye_sayisi) + ' hayvan)' : '';
  const trenAlt = [];
  if (Array.isArray(o.uye_kupeler) && o.uye_kupeler.length) trenAlt.push('Bu trende: ' + _ovtE(o.uye_kupeler.map(String).join(' · ')) + '.');
  const fark = _ovtFark(bugun, tren);
  trenAlt.push((kupe ? _ovtE(kupe) + ' ' : '') + _ovtE(_ovtGunAdEk(tren)) + ' onlarla birlikte başlar'
    + (fark != null && fark > 0 ? ' (' + fark + ' gün sonra)' : '') + '. Erteleme gerekirse hepsi tek işlemle ertelenir.');
  h += secenek('TREN', true, '🚆 Trene bin — ' + _ovtE(_ovtGunAd(tren)) + sayi, trenAlt.join(' '));
  h += secenek('BAGIMSIZ', false, 'Bağımsız başlat — bugün',
    'Bugün ' + _ovtE(_ovtGunAd(bugun)) + ' başlar. Trene sayılmaz; toptan ertelemeye girmez, kendi satırından düzenlenir.');
  h += _ovtVazgecOnaySatiri('<button class="btn btn-g" data-ovt-aksiyon="BASLAT" style="flex:1">Başlat</button>', 6) + '</div>';
  return h;
}

/**
 * Vazgeç + onay/onay-dışı tek eylem satırı (F15: iki kopya tek yardımcı).
 * Döndürülen div kapanmaz; çağıran gövde kapatmasını ekler.
 * @param {string} onayHtml Onay düğmesi HTML'i.
 * @param {number} marginTop Üst boşluk (px).
 * @returns {string} Satır HTML'i.
 */
function _ovtVazgecOnaySatiri(onayHtml, marginTop) {
  return '<div style="display:flex;gap:8px;margin-top:' + marginTop + 'px">'
    + '<button class="btn btn-o" data-ovt-aksiyon="VAZGEC" style="flex:1;margin-top:0">Vazgeç</button>'
    + onayHtml + '</div>';
}

/**
 * K8 akışı: çevrimdışı → "İnternet yok" + null (rpc yok, kuyruğa yazılmaz); bayrak kapalı → eski yol;
 * tren günü bugün → modal yok (R4); aksi modal sorulur.
 * @param {Object} p Parametreler.
 * @param {string} p.hayvanId Hayvan id (ovsync_tren_onizle p_hayvan_id).
 * @param {boolean} p.online Yalnız `true` çevrimiçi sayılır (fail-closed).
 * @param {Function} p.rpc (ad, params) → Promise<veri | {data, error}>.
 * @param {Function} p.toast (mesaj) → void.
 * @param {Function} p.acModal (html, onizleme) → Promise<'TREN'|'BAGIMSIZ'|null>.
 * @param {boolean} [p.aktif] Yerel bayrak bilgisi; `false` → rpc'siz eski yol.
 * @returns {Promise<{secim:'TREN'|'BAGIMSIZ', tarih:string|null}|null>} null = başlatma yapılmaz.
 */
async function ovsyncTrenSor(p) {
  const o = p || {};
  const toast = typeof o.toast === 'function' ? o.toast : function () {};
  if (o.aktif === false) return { secim: 'TREN', tarih: null };
  if (o.online !== true) { toast('İnternet yok'); return null; }
  let veri;
  try {
    let r = await o.rpc('ovsync_tren_onizle', { p_hayvan_id: o.hayvanId == null ? null : o.hayvanId });
    if (r && typeof r === 'object' && 'error' in r && 'data' in r) {
      if (r.error) throw r.error;
      r = r.data;
    }
    veri = r;
  } catch (e) {
    toast(ovsyncTrenHataMetni(e));
    return null;
  }
  if (!veri || typeof veri !== 'object') { toast('Tren bilgisi alınamadı — Ovsync başlatılmadı.'); return null; }
  if (veri.aktif === false) return { secim: 'TREN', tarih: null };
  if (veri.aktif !== true || _ovtGunNo(veri.tren_gunu) == null || _ovtGunNo(veri.bugun) == null) {
    toast('Tren günü hesaplanamadı — Ovsync başlatılmadı.');
    return null;
  }
  if (!ovsyncTrenSoruGerekli(veri, veri.bugun)) return { secim: 'TREN', tarih: veri.tren_gunu };
  let secim;
  try {
    secim = await o.acModal(ovsyncTrenSoruHtml(veri), veri);
  } catch (e) {
    toast(ovsyncTrenHataMetni(e));
    return null;
  }
  if (secim === 'TREN') return { secim: 'TREN', tarih: veri.tren_gunu };
  if (secim === 'BAGIMSIZ') return { secim: 'BAGIMSIZ', tarih: veri.bugun };
  return null;
}

// ── Ovsync takip ekranı: tren başlıkları ve gruplama ─────────────────────────

/**
 * Trenin bugünkü işi (D0 göre gün farkı): başlangıç / PG / 2. PG / 2. GnRH / tohumlama; yoksa ''.
 * @param {string} trenGunu Tren (D0) günü.
 * @param {string} bugunIso TR bugünü.
 * @returns {string} İş etiketi.
 */
function _ovtTrenBugunIs(trenGunu, bugunIso) {
  const f = _ovtFark(trenGunu, bugunIso);
  return (f != null && Object.prototype.hasOwnProperty.call(_OVT_TREN_IS, f)) ? _OVT_TREN_IS[f] : '';
}

/**
 * Toptan erteleme tarihi X (R7): trenin bugün ya da sonra gelen ilk ritim günü — D0 (ovsync_tren = X)
 * ya da D7 (ovsync_tren = X−7). Ritim dışı ya da işi geçmiş tren → null.
 * @param {Object} tren ovsync_tren_listele trenler[] öğesi.
 * @param {string} [bugunIso] TR bugünü.
 * @returns {string|null} X (ISO) ya da null.
 */
function ovsyncToptanTarih(tren, bugunIso) {
  if (!tren || tren.ritim_disi || _ovtGunNo(tren.tren_gunu) == null) return null;
  const t = String(tren.tren_gunu).slice(0, 10);
  if (_ovtGunNo(bugunIso) == null) return t;
  if (_ovtFark(bugunIso, t) >= 0) return t;
  const d7 = _ovtGunEkle(t, 7);
  return _ovtFark(bugunIso, d7) >= 0 ? d7 : null;
}

function _ovtRitimDisiNot(tren) {
  const t = tren || {};
  const nedenler = [];
  const ekle = (v) => {
    const s = String(v == null ? '' : v).trim();
    if (s && nedenler.indexOf(s) < 0) nedenler.push(s);
  };
  ekle(t.ritim_disi_neden);
  (Array.isArray(t.uyeler) ? t.uyeler : []).forEach(u => { if (u && typeof u === 'object') ekle(u.ritim_disi_neden); });
  const kural = 'Toptan ertelemeye girmez; kendi satırından düzenlenir.';
  return nedenler.length ? 'Ritim dışı (' + nedenler.join(' · ') + '). ' + kural : 'Ritim dışı. ' + kural;
}

/**
 * İlk toptan erteleme tarihi (F9/UB-ekler 6): bugünden itibaren üyesi olan ilk ritim
 * günü. "Tren gününü ertele…" düğmesi yalnız bu tarihin başlığında çizilir (UB3).
 * @param {Object|null} trenVeri ovsync_tren_listele dönüşü.
 * @param {string} [bugunIso] TR bugünü.
 * @returns {string|null} İlk X (ISO) ya da null.
 */
function ovsyncIlkToptanTarih(trenVeri, bugunIso) {
  const tv = trenVeri && typeof trenVeri === 'object' ? trenVeri : {};
  const liste = Array.isArray(tv.trenler) ? tv.trenler : [];
  let ilk = null;
  liste.forEach(t => {
    const x = ovsyncToptanTarih(t, bugunIso);
    if (x != null && (ilk == null || x < ilk)) ilk = x;
  });
  return ilk;
}

/**
 * N4-F3 H2: "Tren gününü ertele…" düğmesini taşıyan TEK başlık. Geçen haftanın D7'si bu haftanın
 * D0'ına denk gelince iki başlık aynı X'i işaret eder; düğme X'in kendi treninde (tren_gunu = X),
 * o tren listede yoksa X'i işaret eden ilk trende çizilir.
 * @param {Object|null} trenVeri ovsync_tren_listele dönüşü.
 * @param {string} [bugunIso] TR bugünü.
 * @returns {string|null} Düğmeli başlığın tren_gunu (ISO) ya da null.
 */
function ovsyncToptanBaslikTreni(trenVeri, bugunIso) {
  const x = ovsyncIlkToptanTarih(trenVeri, bugunIso);
  if (x == null) return null;
  let ilkEslesen = null;
  for (const t of trenVeri.trenler) {
    if (ovsyncToptanTarih(t, bugunIso) !== x) continue;
    const g = String(t.tren_gunu).slice(0, 10);
    if (g === x) return g;
    if (ilkEslesen == null) ilkEslesen = g;
  }
  return ilkEslesen;
}

/**
 * N4-F4 Y2 iş etiketi: üyelerin sonraki_is en erken günü bugünse "bugün: <iş>", değilse
 * "<Gün gg Ay>: <iş>" (aynı gün farklı işler " + " ile). Hiçbir üyede sonraki_is yoksa eski
 * D0 gün farkı kuralı (yalnız bugünse). Bilinmeyen tür ham koduyla yazılır (sessiz yok).
 * @param {Object} tren {tren_gunu, uyeler[{sonraki_is:{tarih,tur}}]}.
 * @param {string} bugunIso TR bugünü.
 * @returns {{bugun:boolean, metin:string}|null} Etiket ya da null.
 */
function ovsyncTrenIsEtiketi(tren, bugunIso) {
  const ADI = { GNRH1: 'başlangıç günü', PG1: 'PG günü', PG2: '2. PG günü', GNRH2: '2. GnRH günü', TAI: 'PG+48 tohumlama' };
  const t = tren || {};
  let enErken = null, isler = [];
  (Array.isArray(t.uyeler) ? t.uyeler : []).forEach(u => {
    const si = u && u.sonraki_is && typeof u.sonraki_is === 'object' ? u.sonraki_is : null;
    if (!si || _ovtGunNo(si.tarih) == null) return;
    const g = String(si.tarih).slice(0, 10);
    const ad = Object.prototype.hasOwnProperty.call(ADI, si.tur) ? ADI[si.tur] : String(si.tur == null ? 'iş' : si.tur);
    if (enErken == null || g < enErken) { enErken = g; isler = []; }
    if (g === enErken && isler.indexOf(ad) < 0) isler.push(ad);
  });
  if (enErken == null) {
    const eski = _ovtTrenBugunIs(t.tren_gunu, bugunIso);
    return eski ? { bugun: true, metin: 'bugün: ' + eski } : null;
  }
  const bugun = !!bugunIso && enErken === String(bugunIso).slice(0, 10);
  // S2: iş tarihi TR bugününden önceyse "gecikmiş · " öneki (yalnız yazı rengi amber, zemin yok).
  const gecikmis = !!bugunIso && enErken < String(bugunIso).slice(0, 10);
  return { bugun: bugun, gecikmis: gecikmis, metin: (gecikmis ? 'gecikmiş · ' : '') + (bugun ? 'bugün' : _ovtGunAd(enErken)) + ': ' + isler.join(' + ') };
}

/**
 * Tren başlığı (mockup 2a/2b):"Tren · Per 19 Kas · 4 hayvan · bugün: PG günü" + "Tren gününü ertele…".
 * Ritim dışı: "ritim dışı" etiketi, ertele düğmesi yok, açıklama notu. Çevrimdışı: ertele düğmesi yok.
 * @param {Object} tren {tren_gunu, ritim_disi, uyeler[]}.
 * @param {string} bugunIso TR bugünü.
 * @param {boolean} [online=true] false → ertele düğmesi çizilmez.
 * @returns {string} Başlık HTML'i.
 */
function ovsyncTrenBaslikHtml(tren, bugunIso, online, ilkTarih) {
  const t = tren || {};
  const n = Array.isArray(t.uyeler) ? t.uyeler.length : 0;
  let ad = 'Tren · ' + _ovtE(_ovtGunAd(t.tren_gunu)) + ' · <span class="ovs-tren-sayi">' + n + ' hayvan</span>';
  if (t.ritim_disi) ad += ' · <span class="ovs-tren-ritimdisi">ritim dışı</span>';
  const ie = ovsyncTrenIsEtiketi(t, bugunIso);
  if (ie) ad += ' · <span class="' + (ie.bugun ? 'ovs-tren-bugun' : ie.gecikmis ? 'ovs-tren-is ovs-tren-gecikmis" style="color:var(--amber)' : 'ovs-tren-is') + '">' + _ovtE(ie.metin) + '</span>';
  let x = online === false ? null : ovsyncToptanTarih(t, bugunIso);
  if (x != null && ilkTarih !== undefined && String(x) !== String(ilkTarih)) x = null;
  const btn = x ? '<button class="ovs-tren-ertele" data-ovt-aksiyon="TOPTAN" data-tarih="' + escAttr(x) + '">Tren gününü ertele…</button>' : '';
  let h = '<div class="ovs-tren-bas"><span class="ovs-tren-ad">' + ad + '</span>' + btn + '</div>';
  if (t.ritim_disi) {
    h += '<div class="ovs-tren-not">' + _ovtE(_ovtRitimDisiNot(t)) + '</div>';
  }
  return h;
}

/**
 * S1 satırlarını tren üyeliğine göre gruplar (eşleme hayvan_id). Trenler tren_gunu artan sırada,
 * sunucunun döndürdüğü her tren için bir grup (satırı olmasa da — başlık/ertele girişi kaybolmaz).
 * @param {Array} satirlar ovsync_takip_listele S1 satırları.
 * @param {Object|null} trenVeri ovsync_tren_listele dönüşü.
 * @returns {{gruplar:Array<[string, Array, Object]>, bagimsiz:Array, tekil:Array}} Gruplar.
 */
function ovsyncTrenGrupla(satirlar, trenVeri) {
  const liste = Array.isArray(satirlar) ? satirlar.filter(Boolean) : [];
  const tv = trenVeri && typeof trenVeri === 'object' ? trenVeri : {};
  const trenler = (Array.isArray(tv.trenler) ? tv.trenler : []).filter(t => t && t.tren_gunu)
    .slice().sort((a, b) => (String(a.tren_gunu) < String(b.tren_gunu) ? -1 : String(a.tren_gunu) > String(b.tren_gunu) ? 1 : 0));
  const uyelik = new Map();
  trenler.forEach((t, i) => (Array.isArray(t.uyeler) ? t.uyeler : []).forEach(u => {
    if (u && u.hayvan_id != null && !uyelik.has(String(u.hayvan_id))) uyelik.set(String(u.hayvan_id), i);
  }));
  const bag = new Set();
  (Array.isArray(tv.bagimsizlar) ? tv.bagimsizlar : []).forEach(u => { if (u && u.hayvan_id != null) bag.add(String(u.hayvan_id)); });
  const gruplar = trenler.map(t => [t.tren_gunu, [], t]);
  const bagimsiz = [], tekil = [];
  liste.forEach(s => {
    const id = s.hayvan_id == null ? null : String(s.hayvan_id);
    if (id != null && uyelik.has(id)) gruplar[uyelik.get(id)][1].push(s);
    else if (id != null && bag.has(id)) bagimsiz.push(s);
    else tekil.push(s);
  });
  return { gruplar: gruplar, bagimsiz: bagimsiz, tekil: tekil };
}

// ── Toptan erteleme (K7) ─────────────────────────────────────────────────────

function _ovtSecimGecerli(u, s) {
  if (!u || u.sonuc !== 'SECIM' || u.case_id == null) return null;
  const v = (s || {})[u.case_id];
  return (v === 'PG48' || v === 'BASTAN') ? v : null;
}

/**
 * Onay açık mı: plan dolu, her üye KAYAR/BASTAN ya da SECIM + geçerli seçim (PG48/BASTAN).
 * Bilinmeyen sonuç ya da boş plan → kapalı (fail-closed).
 * @param {Object} plan ovsync_tren_ertele_onizle dönüşü.
 * @param {Object} secimler {case_id: 'PG48'|'BASTAN'}.
 * @returns {boolean} Onay düğmesi açık mı.
 */
function ovsyncToptanOnayAcikMi(plan, secimler) {
  if (!plan || !Array.isArray(plan.uyeler) || !plan.uyeler.length) return false;
  const s = secimler || {};
  return plan.uyeler.every(u => {
    if (!u) return false;
    if (u.sonuc === 'KAYAR' || u.sonuc === 'BASTAN') return true;
    if (u.sonuc === 'SECIM') return _ovtSecimGecerli(u, s) != null;
    return false;
  });
}

/**
 * Toptan önizleme satırı (mockup 3a/3b).
 * @param {Object} u Plan üyesi.
 * @param {Object} s Seçimler.
 * @param {string} yeniTren Plan yeni_tren.
 * @returns {string} Satır HTML'i.
 */
function _ovtOnSatir(u, s, yeniTren) {
  const asamaEt = { 0: 'aşama 0 · başlamadı', 1: 'aşama 1 · 1. uygulama yapıldı', 2: 'aşama 2 · PG yapıldı' }[u.asama] || 'aşama belirsiz';
  let sonuc, sinif, neden = '', radyo = '';
  if (u.sonuc === 'KAYAR') {
    sonuc = 'kayar → ' + _ovtGunAd(u.yeni_tarih); sinif = 'ovs-kayar';
  } else if (u.sonuc === 'BASTAN') {
    sonuc = 'baştan başlar → ' + _ovtGunAd(u.yeni_tarih || yeniTren); sinif = 'ovs-bastan';
    neden = 'PG erteleme payı yetmiyor. Vaka kapanır, yeni trende yeniden başlar.';
  } else if (u.sonuc === 'SECIM') {
    const sec = _ovtSecimGecerli(u, s);
    if (sec === 'PG48') { sonuc = 'tohumla → ' + (u.yeni_tarih ? _ovtGunAd(u.yeni_tarih) : 'PG1 + 48 s'); sinif = 'ovs-kayar'; }
    else if (sec === 'BASTAN') { sonuc = 'baştan başlar → ' + _ovtGunAd(yeniTren); sinif = 'ovs-bastan'; }
    else { sonuc = 'seçim gerekli'; sinif = 'ovs-secim'; neden = 'PG yapıldı, ertelenemez. Seçin:'; }
    const r = (on, kod, metin) => '<div class="ovs-radyo' + (on ? ' on' : '') + '" data-case="' + escAttr(u.case_id) + '" data-secim="' + kod + '"><i></i>' + _ovtE(metin) + '</div>';
    radyo = r(sec === 'PG48', 'PG48', "(a) PG1 + 48 s'te tohumla") + r(sec === 'BASTAN', 'BASTAN', '(b) Baştan başlat → ' + _ovtGunAd(yeniTren) + ' treni');
  } else if (u.sonuc == null) {
    sonuc = 'Aşama belirsiz — Baştan başlat'; sinif = 'ovs-secim';
    neden = 'Aşama belirlenemedi; toptan işleme girmez.';
    radyo = '<button class="ovs-aksiyon" data-ovt-aksiyon="BASTAN" data-case="' + escAttr(u.case_id == null ? '' : u.case_id) + '">Baştan başlat</button>';
  } else {
    sonuc = 'bilinmeyen sonuç: ' + String(u.sonuc); sinif = 'ovs-secim';
  }
  return '<div class="ovs-on-satir"><div class="ovs-on-ust"><span><span class="ovs-on-kupe">' + _ovtE(u.kupe_no) + '</span> '
    + '<span class="ovs-on-asama">' + _ovtE(asamaEt) + '</span></span><span class="ovs-on-sonuc ' + sinif + '">' + _ovtE(sonuc) + '</span></div>'
    + (neden ? '<div class="ovs-on-neden">' + _ovtE(neden) + '</div>' : '') + radyo + '</div>';
}

/**
 * Toptan erteleme modalı (mockup 3a/3b): N seçici 1–7, hayvan başına önizleme, ritim satırı, tek onay.
 * Üyelerde tren alanı (tren_gunu/ovsync_tren) varsa tren başlıklarıyla gruplanır; yoksa düz liste.
 * @param {Object} plan {tren, yeni_tren, uyeler[], ileri_gorevler[]}.
 * @param {Object} secimler {case_id: 'PG48'|'BASTAN'}.
 * @param {string} [bugunIso] TR bugünü ("Bugünün Ovsync işleri" için).
 * @returns {string} Modal HTML'i.
 */
function ovsyncToptanOnizlemeHtml(plan, secimler, bugunIso) {
  const p = plan || {};
  const s = secimler || {};
  const uyeler = Array.isArray(p.uyeler) ? p.uyeler.filter(Boolean) : [];
  const n = _ovtFark(p.tren, p.yeni_tren);
  const trenOf = (u) => u.tren_gunu || u.ovsync_tren || null;
  const trenSet = [...new Set(uyeler.map(trenOf).filter(Boolean))].sort();
  const kim = (bugunIso && String(p.tren).slice(0, 10) === bugunIso) ? 'Bugünün' : _ovtGunAd(p.tren);

  let h = '<div class="m-title">🚆 Tren gününü ertele — ' + _ovtE(_ovtGunAd(p.tren)) + '</div><div class="m-body">';
  h += '<div style="font-size:.76rem;color:var(--ink3);margin-bottom:10px">' + _ovtE(kim + ' Ovsync işleri: ' + uyeler.length + ' hayvan'
    + (trenSet.length ? ', ' + trenSet.length + ' tren' : '') + '. Kaç gün?') + '</div>';
  h += '<div style="display:flex;gap:6px;flex-wrap:wrap">';
  for (let i = 1; i <= 7; i++) h += '<button class="ovs-cip' + (i === n ? ' on' : '') + '" data-n="' + i + '">+' + i + '</button>';
  h += '</div>';
  if (trenSet.length) {
    trenSet.forEach(t => {
      const is = _ovtTrenBugunIs(t, bugunIso);
      h += '<div class="ovs-on-grup">' + _ovtE('Tren · ' + _ovtGunAd(t) + (is ? ' — bugün ' + is : '')) + '</div>';
      uyeler.filter(u => trenOf(u) === t).forEach(u => { h += _ovtOnSatir(u, s, p.yeni_tren); });
    });
    const trensiz = uyeler.filter(u => !trenOf(u));
    if (trensiz.length) {
      h += '<div class="ovs-on-grup">Tren bilgisi yok</div>';
      trensiz.forEach(u => { h += _ovtOnSatir(u, s, p.yeni_tren); });
    }
  } else {
    uyeler.forEach(u => { h += _ovtOnSatir(u, s, p.yeni_tren); });
  }
  if (_ovtGunNo(p.yeni_tren) != null) {
    h += '<div class="ovs-bilgi-satir">🔁 Ritim kalıcı kayar: tren günü bundan sonra her <b style="color:var(--ink)">'
      + _ovtE(_ovtHaftaGunu(p.yeni_tren)) + '</b> (sonraki: ' + _ovtE(_ovtGunAd(_ovtGunEkle(p.yeni_tren, 7))) + ').</div>';
  }
  const ileri = Array.isArray(p.ileri_gorevler) ? p.ileri_gorevler.length : 0;
  if (ileri) h += '<div class="ovs-bilgi-satir" style="color:var(--ink3)">Ayrıca ' + ileri + ' ileri başlatma görevi yeni ritme taşınır.</div>';
  const eksik = uyeler.filter(u => u.sonuc === 'SECIM' && _ovtSecimGecerli(u, s) == null).length;
  if (eksik) h += '<div class="ovs-bilgi-satir" style="font-weight:700;color:var(--red2)">' + eksik + ' hayvan için (a) ya da (b) seçin.</div>';
  const belirsiz = uyeler.filter(u => u && u.sonuc == null).length;
  if (belirsiz) h += '<div class="ovs-bilgi-satir" style="font-weight:700;color:var(--red2)">' + belirsiz
    + ' hayvanın aşaması belirsiz — satırdaki Baştan başlat ile çözülmeden onay açılmaz.</div>';
  const acik = ovsyncToptanOnayAcikMi(p, s);
  h += _ovtVazgecOnaySatiri('<button class="btn btn-g" style="flex:1" data-ovt-aksiyon="ONAYLA"' + (acik ? '' : ' disabled')
    + '>Onayla (' + uyeler.length + ' hayvan)</button>', 12);
  h += '<div style="font-size:.66rem;color:var(--ink3);text-align:center;margin-top:8px">Tek işlem: biri işlenemezse hiçbiri değişmez, düşen hayvan ve nedeni yazılır.</div></div>';
  return h;
}

// ── K10: Görevler ekranı ─────────────────────────────────────────────────────

/**
 * R5 "Ovsync görevi" tanımının JS eşi (SQL `_ovsync_gorev_mu`, TR-K10-9 tablosu):
 * OVSYNC_BASLAT; TOHUMLAMA_PLANLI + hayvanın aktif OVSYNC vakası; TEDAVI_GUN/TEDAVI_SEANS + aciklama.day_id
 * aktif OVSYNC vakanın günü. Diğer her tip false. Bozuk aciklama → hata bildirilir (sessiz değil), false
 * (sunucu kilidi yine korur).
 * @param {Object} t Görev satırı {id, gorev_tipi, hayvan_id, aciklama}.
 * @param {{hayvanIdSet:Set, gunIdSet:Set, hata?:Function}} k Aktif OVSYNC hayvanları ve gün id'leri.
 * @returns {boolean} Ovsync görevi mi.
 */
function ovsyncTrenGorevMu(t, k) {
  if (!t || typeof t !== 'object') return false;
  const kk = k || {};
  const tip = t.gorev_tipi;
  if (tip === 'OVSYNC_BASLAT') return true;
  if (tip === 'TOHUMLAMA_PLANLI') return !!(kk.hayvanIdSet && typeof kk.hayvanIdSet.has === 'function' && kk.hayvanIdSet.has(t.hayvan_id));
  if (tip === 'TEDAVI_GUN' || tip === 'TEDAVI_SEANS') {
    let obj = null;
    const a = t.aciklama;
    if (a && typeof a === 'object') obj = a;
    else if (typeof a === 'string' && /^\s*\{/.test(a)) {
      try { obj = JSON.parse(a); }
      catch (e) {
        _ovtHataBildir(kk, 'Görev açıklaması okunamadı (görev ' + (t.id == null ? '?' : t.id) + ', ' + tip + '): ' + (e && e.message ? e.message : e), t);
        return false;
      }
    }
    const gun = obj && typeof obj === 'object' ? obj.day_id : null;
    return gun != null && !!(kk.gunIdSet && typeof kk.gunIdSet.has === 'function' && kk.gunIdSet.has(gun));
  }
  return false;
}

/**
 * Ovsync ekranına geçer ve odak hayvanı bırakır (UB3 ilgili trene kaydırır).
 * @param {string|null} hayvanId Hayvan id.
 * @returns {void}
 */
function ovsyncEkranindaDuzenle(hayvanId) {
  if (typeof window !== 'undefined' && window) window._ovsyncOdakHayvan = hayvanId == null || hayvanId === '' ? null : hayvanId;
  if (typeof goTo === 'function') goTo('ovsync');
}

/**
 * Görev satırında "Ertele" yerine bağlantı (mockup 5a).
 * @param {Object} t Görev satırı.
 * @returns {string} Düğme HTML'i.
 */
function ovsyncDuzenleLinkHtml(t) {
  const id = t && t.hayvan_id != null ? t.hayvan_id : '';
  return '<button class="ovs-duzenle-link" data-ovt-aksiyon="DUZENLE" data-hayvan="' + escAttr(id) + '">Ovsync ekranında düzenle →</button>';
}

/**
 * Çoklu kaydırma sonucu notu (mockup 5b): "⏭ N Ovsync görevi atlandı (küpeler) · Ovsync ekranı →".
 * @param {Object} sonuc vaka_kalan_gunleri_kaydir_coklu dönüşü ({ovsync_atlanan:[…]}).
 * @returns {string} HTML; atlanan yoksa ''.
 */
function ovsyncCokluAtlananNot(sonuc) {
  const l = sonuc && Array.isArray(sonuc.ovsync_atlanan) ? sonuc.ovsync_atlanan.filter(Boolean) : [];
  if (!l.length) return '';
  const kupeler = [...new Set(l.map(x => x.kupe_no).filter(v => v != null && v !== '').map(String))];
  return '<div style="display:flex;justify-content:space-between;align-items:center;gap:8px;padding:8px 4px 2px;font-size:.78rem">'
    + '<span style="color:var(--ink);font-weight:700">⏭ ' + l.length + ' Ovsync görevi atlandı'
    + (kupeler.length ? ' <span style="color:var(--ink3);font-weight:600">(' + _ovtE(kupeler.join(', ')) + ')</span>' : '') + '</span> '
    + '<button class="ovs-duzenle-link" style="font-size:.78rem" data-ovt-aksiyon="DUZENLE" data-hayvan="">Ovsync ekranı →</button></div>';
}

// ── K11 geç tamamlama, aşama aksiyonları ─────────────────────────────────────

/**
 * Geç tamamlama uyarı içeriği (mockup 7b). Kayıt alınmıştır; karar kullanıcının.
 * Bilinmeyen kod da görünür uyarı üretir (sessiz yok).
 * @param {Object|null} uyari seans_tamamla dönüşü ovsync_uyari {kod, gecikme_gun, oneri, case_id, kupe_no?}.
 * @returns {string} Sheet içeriği; uyarı yoksa ''.
 */
function ovsyncGecTamamlamaUyariHtml(uyari) {
  if (!uyari || typeof uyari !== 'object') return '';
  const devam = '<button class="btn btn-o" data-ovt-aksiyon="DEVAM">Devam et (protokol sürsün)</button>';
  const govde = (m) => '<div style="font-size:.8rem;color:var(--ink2);line-height:1.5">' + m + '</div>';
  if (uyari.kod !== 'PG1_TOLERANS_ASILDI') {
    return '<div style="font-weight:800;font-size:1rem;margin-bottom:8px;color:var(--amber)">⚠️ Ovsync uyarısı: ' + _ovtE(uyari.kod == null ? 'kod yok' : uyari.kod) + '</div>'
      + govde('Kayıt alındı.') + devam;
  }
  const g = uyari.gecikme_gun != null ? String(uyari.gecikme_gun) + ' gün' : 'geç';
  const kupe = uyari.kupe_no != null && uyari.kupe_no !== '' ? '<b style="color:var(--ink)">' + _ovtE(uyari.kupe_no) + '</b> · ' : '';
  let h = '<div style="font-weight:800;font-size:1rem;margin-bottom:8px;color:var(--amber)">⚠️ PG1 ' + _ovtE(g) + ' geç — baştan başlat önerilir</div>';
  h += govde(kupe + 'PG planlanan günden ' + _ovtE(g) + ' sonra yapıldı. Kayıt alındı, protokol şu an devam ediyor.');
  h += '<div style="font-size:.8rem;color:var(--ink2);line-height:1.5;margin-top:8px">Öneri: Ovsync\'i baştan başlat — hayvan sonraki trene biner.</div>';
  if (uyari.case_id != null && uyari.case_id !== '') {
    h += '<button class="btn btn-b" style="margin-top:14px" data-ovt-aksiyon="BASTAN" data-case="' + escAttr(uyari.case_id) + '">🔁 Baştan başlat → trene bin</button>';
  }
  return h + devam;
}

/**
 * Tekil ertele N aralığı (F3, UB4 sheet'i kullanır): aşama 1 → 1..pg_pay;
 * tren günü olmayan bağımsız aşama 0 → 1..7; diğer (trende aşama 0, aşama 2,
 * belirsiz, paysız aşama 1) → null (N seçici yok).
 * @param {Object} uye {asama, pg_pay?, tren_gunu?|ovsync_tren?}.
 * @returns {{min:number, max:number}|null} Aralık ya da null.
 */
function ovsyncTekErteleAraligi(uye) {
  if (!uye || typeof uye !== 'object') return null;
  if (uye.asama === 1) {
    const pay = uye.pg_pay == null ? null : Number(uye.pg_pay);
    if (pay == null || !isFinite(pay) || pay < 1) return null;
    return { min: 1, max: Math.floor(pay) };
  }
  if (uye.asama === 0 && uye.tren_gunu == null && uye.ovsync_tren == null) return { min: 1, max: 7 };
  return null;
}

/**
 * Ovsync kartı aşama düğmeleri (mockup 2a/2b): 0 → sonraki trene aktar; 1 → PG'yi ertele (pay dolduysa
 * baştan başlat); 2 → PG1+48 s tohumla + baştan başlat (kaydırma yok); belirsiz → baştan başlat.
 * F3: aşama 0 hedef tarihi yalnız ritim içinde gösterilir (ritim dışında tarihsiz etiket).
 * Çevrimdışı → '' (spec §6).
 * @param {Object} uye {hayvan_id, case_id, asama, sonraki_is?, pg_pay?, tren_gunu?|ovsync_tren?}.
 * @param {boolean} online Yalnız true çevrimiçi sayılır.
 * @param {string} [bugunIso] TR bugünü ("PG bugün" etiketi için).
 * @returns {string} `<div class="ovs-asama">` HTML'i ya da ''.
 */
function ovsyncAsamaAksiyonHtml(uye, online, bugunIso) {
  if (online !== true || !uye || typeof uye !== 'object') return '';
  const btn = (aksiyon, metin, anaHayvan) => {
    const c = 'data-case="' + escAttr(uye.case_id == null ? '' : uye.case_id) + '"';
    const hv = 'data-hayvan="' + escAttr(uye.hayvan_id == null ? '' : uye.hayvan_id) + '"';
    return '<button class="ovs-aksiyon" data-ovt-aksiyon="' + aksiyon + '" ' + (anaHayvan ? hv + ' ' + c : c + ' ' + hv) + '>' + _ovtE(metin) + '</button>';
  };
  const et = (m) => '<span class="ovs-asama-etiket">' + _ovtE(m) + '</span>';
  const parca = [];
  if (uye.asama === 2) {
    parca.push(et('PG yapıldı · erteleme yok:'), btn('PG48', "PG1 + 48 s'te tohumla"), btn('BASTAN', 'Baştan başlat'));
  } else if (uye.asama === 1) {
    const pay = uye.pg_pay == null ? null : Number(uye.pg_pay);
    if (pay != null && isFinite(pay) && pay <= 0) {
      parca.push(et('PG payı doldu:'), btn('BASTAN', 'Baştan başlat → trene bin'));
    } else {
      const si = uye.sonraki_is && uye.sonraki_is.tarih ? String(uye.sonraki_is.tarih).slice(0, 10) : '';
      const ne = si ? (bugunIso && si === bugunIso ? ' bugün' : ' ' + _ovtGunAy(si)) : '';
      parca.push(et('PG' + ne + ':'), btn('ERTELE', "PG'yi ertele" + (pay != null && isFinite(pay) ? ' · en çok +' + pay + ' gün' : ''), true));
    }
  } else if (uye.asama === 0) {
    const tren = uye.tren_gunu || uye.ovsync_tren || null;
    const ritimDisi = uye.ritim_disi === true
      || (uye.ritim_disi_neden != null && String(uye.ritim_disi_neden).trim() !== '');
    if (_ovtGunNo(tren) != null && !ritimDisi) parca.push(et('Başlamadı:'), btn('SONRAKI_TREN', 'Sonraki trene aktar → ' + _ovtGunAd(_ovtGunEkle(tren, 7)), true));
    else if (_ovtGunNo(tren) != null) parca.push(et('Başlamadı:'), btn('SONRAKI_TREN', 'Sonraki trene aktar', true));
    else parca.push(et('Başlamadı:'), btn('ERTELE', 'Başlangıcı ertele…', true));
  } else {
    parca.push(et('Aşama belirsiz:'), btn('BASTAN', 'Baştan başlat'));
  }
  return '<div class="ovs-asama">' + parca.join(' ') + '</div>';
}

// ── 🔔 Faz 0: doğum sonrası PG hatırlatma ─────────────────────────────────────

/**
 * 🔔 panel bölümü (mockup 7a): d2/d25 satırları; kapatma aksiyonu yok.
 * @param {Array<{hayvan_id, kupe_no, dogum_tarihi, gun}>} satirlar dogum_sonrasi_pg_hatirlatma().satirlar.
 * @returns {string} Bölüm HTML'i; satır yoksa ''.
 */
function dogumPgHatirlatmaHtml(satirlar) {
  const l = Array.isArray(satirlar) ? satirlar.filter(Boolean) : [];
  if (!l.length) return '';
  let h = '<div style="font-weight:800;font-size:.8rem;margin:14px 0 6px;color:var(--ink)">💉 Doğum sonrası PG hatırlatma (' + l.length + ')</div>';
  l.forEach(s => {
    h += '<div class="arow" style="margin-bottom:6px;padding:8px 10px;cursor:default"><div style="flex:1">'
      + '<div style="font-weight:700;font-size:.8rem">' + _ovtE(s.kupe_no == null ? '?' : s.kupe_no)
      + ' <span class="ovs-mavi" style="font-size:.7rem;font-weight:700">· doğumun ' + _ovtE(s.gun == null ? '?' : s.gun) + '. günü</span></div>'
      + '<div style="font-size:.7rem;color:var(--ink3)">PG hatırlatması · doğum ' + _ovtE(_ovtGunAd(s.dogum_tarihi)) + '</div></div></div>';
  });
  h += '<div style="font-size:.68rem;color:var(--ink3);margin-top:2px">Yalnız hatırlatma — uygulamak isterseniz hayvana PG\'yi her zamanki gibi girin.</div>';
  return h;
}

// ── Hata metinleri ───────────────────────────────────────────────────────────

const _OVT_HATA = {
  OVSYNC_TREN_EKRANI: (d) => 'Bu Ovsync görevi yalnız Ovsync ekranından düzenlenir' + (d.tren_gunu ? ' (tren ' + _ovtGunAd(d.tren_gunu) + ')' : '')
    + '. Görevler ekranında yalnız yapıldı/yapılmadı işaretlenir.',
  OVSYNC_ASAMA1_TOLERANS: (d) => 'PG en çok ' + (d.tolerans == null ? '?' : d.tolerans) + ' gün ertelenebilir'
    + (d.mevcut_kayma != null ? ' (şimdiye kadar ' + d.mevcut_kayma + ' gün kaydı, istenen +' + (d.istenen == null ? '?' : d.istenen) + ')' : '')
    + '. Daha fazlası için Ovsync\'i baştan başlatın.',
  OVSYNC_ASAMA2_ERTELEME_YOK: () => 'PG yapıldı, bu aşamada erteleme yok: PG1 + 48 s\'te tohumlayın ya da Ovsync\'i baştan başlatın.',
  OVSYNC_ASAMA_BELIRSIZ: () => 'Ovsync aşaması belirlenemedi (uygulama kayıtları tutarsız); baştan başlatmanız önerilir.',
  OVSYNC_TREN_SECIM_EKSIK: (d) => (Array.isArray(d.eksik) ? d.eksik.length + ' hayvan' : 'Bazı hayvanlar') + ' için (a) PG1 + 48 s tohumla ya da (b) baştan başlat seçilmedi; hiçbir şey değişmedi.',
  OVSYNC_TREN_ERTELE_DUSTU: (d, derinlik) => {
    const l = Array.isArray(d.dusenler) ? d.dusenler.filter(Boolean) : [];
    const liste = l.map(x => (x.kupe_no != null && x.kupe_no !== '' ? x.kupe_no : (x.hayvan_id == null ? '?' : x.hayvan_id)) + (x.sebep ? ' (' + _ovtSebepCoz(x.sebep, derinlik) + ')' : '')).join(', ');
    return 'Tren ertelenemedi, hiçbir hayvan değişmedi.' + (liste ? ' İşlenemeyen: ' + liste + '.' : ' İşlenemeyen hayvan listesi gelmedi.');
  },
  OVSYNC_TREN_AYAR: (d) => 'Ovsync treni ayarı eksik ya da geçersiz'
    + (d.anahtar ? ' (' + d.anahtar + (d.deger != null ? ' = ' + d.deger : '') + (d.sebep ? ', ' + d.sebep : '') + ')' : '') + '. Tren ayarını düzeltin; işlem yapılmadı.',
  OVSYNC_PG48_TAI_YOK: () => 'PG1 + 48 s tohumlaması yapılamaz: hayvanın PG\'ye bağlı açık tohumlama görevi yok.',
  OVSYNC_PG48_GECMIS: () => 'PG1 + 48 s tohumlama anı geçmiş; Ovsync\'i baştan başlatın.',
  OVSYNC_GOREV_ACILAMADI: (d) => 'Ovsync başlatma görevi açılamadı' + (d.sebep ? ' (' + d.sebep + ')' : '') + '; işlem geri alındı.',
  OVSYNC_TREN_KAPALI: () => 'Ovsync treni kapalı — bu işlem yalnız tren açıkken yapılır.',
  OVSYNC_TREN_N_GECERSIZ: () => 'Erteleme günü 1 ile 7 arasında olmalı.',
  OVSYNC_TREN_GUNU_DEGIL: (d) => (d.sebep === 'ONCEKI_TREN_VAR' && d.ilk_tren
    ? 'Önce ' + _ovtGunAd(d.ilk_tren) + ' treni ertelenmeli.' : 'Seçilen tarih bir tren günü değil.'),
  GECMIS_TARIH: (d) => 'Geçmiş bir tarih seçildi'
    + (d.tarih ? ' (' + _ovtGunAd(d.tarih) + (d.bugun ? ', bugün ' + _ovtGunAd(d.bugun) : '') + ')' : '')
    + '; gelecek bir tren günü seçin.',
  OVSYNC_TREN_UYELIK_YOK: (d) => 'Bu hayvan tren üyesi değil'
    + (d.d0 ? ' (tren ' + _ovtGunAd(d.d0) + ')' : '') + '; işlem yapılmadı.',
  OVSYNC_BASTAN_HEDEF_GECERSIZ: (d) => 'Baştan başlatma hedefi geçersiz'
    + (d.hedef ? ' (' + _ovtGunAd(d.hedef) + (d.en_erken ? ', en erken ' + _ovtGunAd(d.en_erken) : '') + ')' : '')
    + '; işlem geri alındı.',
  OVSYNC_PG48_SEANS_KAPANMADI: () => 'PG1 + 48 s tohumlaması yapılamadı: açık seans kapanmadı; seansı kapatıp yeniden deneyin.',
  OVSYNC_VAKA_ACILAMADI: (d) => 'Ovsync vakası açılamadı' + (d.sebep ? ' (' + d.sebep + ')' : '') + '; işlem geri alındı.',
  OVSYNC_SABLON_BELIRSIZ: () => 'Ovsync şablonu belirlenemedi; işlem yapılmadı.',
  OVSYNC_SABLON_UYGULANAMADI: () => 'Ovsync şablonu uygulanamadı; işlem geri alındı.',
  OVSYNC_HASTALIK_BELIRSIZ: () => 'Hastalık kaydı belirlenemedi; işlem yapılmadı.',
  OVSYNC_TAI_OLUSMADI: () => 'Tohumlama görevi oluşturulamadı; işlem geri alındı.',
  OVSYNC_SECIM_KISIR: () => 'Kısır hayvana Ovsync işlemi yapılamaz.',
  OVSYNC_SECIM_TABAN_YOK: () => 'Uygun Ovsync tabanı bulunamadı; işlem yapılmadı.',
  OVSYNC_SECIM_ERKEN: (d) => 'Ovsync için erken'
    + (d.kural_gun ? ' (kural günü ' + _ovtGunAd(d.kural_gun) + (d.kalan_gun != null ? ', ' + d.kalan_gun + ' gün kaldı' : '') + ')' : '') + '.',
  OVSYNC_ERKEN: (d) => 'Ovsync başlatmak için erken'
    + (d.hedef_tarih ? ' (hedef ' + _ovtGunAd(d.hedef_tarih) + (d.kalan_gun != null ? ', ' + d.kalan_gun + ' gün kaldı' : '') + ')' : '') + '.',
  OVSYNC_BASLAT_PARAMETRE: () => 'Ovsync başlatma parametresi geçersiz; işlem yapılmadı.',
  TAKIP_ACIK: (d) => 'Açık takip muayenesi varken Ovsync başlatılamaz'
    + (d.muayene_tarihi ? ' (' + _ovtGunAd(d.muayene_tarihi) + (d.muayene_saat ? ' ' + d.muayene_saat : '') + ')' : '') + '.',
  GOREV_BULUNAMADI: () => 'Görev bulunamadı; işlem yapılmadı.',
  GOREV_TIPI_UYUMSUZ: () => 'Görev tipi bu işleme uygun değil; işlem yapılmadı.',
  OZELLIK_KAPALI: () => 'Bu özellik kapalı; işlem yapılmadı.',
  OVSYNC_TREN_BOS: () => 'Bu tren gününde ertelenecek hayvan yok.',
  OVSYNC_VAKA_YOK: () => 'Bu hayvanın açık Ovsync kaydı yok.',
  OVSYNC_ASAMA2_DEGIL: () => 'PG1 + 48 s tohumlama yalnız PG\'si yapılmış (aşama 2) hayvanda seçilebilir.',
  OVSYNC_BASTAN_BASLATILAMADI: (d) => 'Ovsync baştan başlatılamadı' + (d.yeniden_not ? ': ' + d.yeniden_not : '') + '; işlem geri alındı.',
};

function _ovtSebepCoz(sebep, derinlik) {
  const s = typeof sebep === 'string' ? sebep : String(sebep == null ? '' : sebep);
  const dz = typeof derinlik === 'number' ? derinlik : 0;
  if (dz >= 3 || !/\b[A-Z][A-Z0-9_]{2,}\b/.test(s)) return s;
  if (s.indexOf('OVSYNC_TREN_ERTELE_DUSTU') >= 0) return s;
  return _ovtHataMetniImpl(s, dz + 1);
}

function _ovtHataMetniImpl(ham, derinlik) {
  if (!ham) return 'Bilinmeyen hata (ayrıntı yok).';
  const s = String(ham);
  let kod = null;
  for (const t of s.matchAll(/\b([A-Z][A-Z0-9_]{2,})\b/g)) {
    if (Object.prototype.hasOwnProperty.call(_OVT_HATA, t[1])) { kod = t[1]; break; }
  }
  if (!kod) return ham;
  let d = {};
  let bozuk = null;
  const govde = s.slice(s.indexOf(kod) + kod.length).replace(/^\s*:\s*/, '').trim();
  if (govde) {
    try {
      const j = JSON.parse(govde);
      if (j && typeof j === 'object') d = j; else bozuk = govde;
    } catch (x) { bozuk = govde; }
  }
  let t = _OVT_HATA[kod](d, derinlik);
  if (bozuk != null) t += ' (ayrıntı okunamadı: ' + bozuk + ')';
  return t;
}

/**
 * Ovsync treni RPC hatalarını kullanıcı metnine çevirir ('KOD:{json}' biçimi). Bilinmeyen kod → ham mesaj;
 * bozuk JSON → metin + ham ayrıntı (sessiz yok).
 * @param {*} e Error, {message}, {error:{message}} ya da metin.
 * @returns {string} Kullanıcı metni (asla boş değil).
 */
function ovsyncTrenHataMetni(e) {
  let ham = '';
  if (typeof e === 'string') ham = e;
  else if (e && typeof e === 'object') ham = String(e.message || (e.error && e.error.message) || e.details || '');
  return _ovtHataMetniImpl(ham, 0);
}
