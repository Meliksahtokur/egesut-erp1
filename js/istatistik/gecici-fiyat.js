// js/istatistik/gecici-fiyat.js
// İstatistik Atölyesi AP1 (T14) — geçici ilaç fiyatı paneli (spec §4.2.4, §4.8, V11).
// Girilen değer yalnız window._atolye.gecici'de yaşar: sayfa yenilenince yoktur, cümleye ve
// kayıtlı grafiğe girmez. Satırlar stat_atolye_seri.fiyat_eksik'ten gelir (SQL otoritedir).
'use strict';

// Son Hesapla'da okunamayan alanlar {stok_id: yazılan metin}: yeniden çizimde alan ve uyarı kaybolmasın. Hesaba girmez.
let _geciciFiyatRed = {};

/**
 * Alan metni → {n: pozitif sayı ya da null, red: uyarı metni ya da null}. Virgül/nokta ondalık; '1.234,5' binlikli.
 * Boş, 0 ve negatif uyarısız atlanır. '1.234' (virgülsüz, üç haneli nokta) bin mi ondalık mı belirsizdir: reddedilir, tahmin edilmez.
 */
function _geciciFiyatCoz(metin) {
  const ham = String(metin ?? '').trim();
  if (!ham || ham.startsWith('-')) return { n: null, red: null };
  if (/^[1-9]\d{0,2}(\.\d{3})+$/.test(ham)) {
    const parca = ham.split('.');
    const ornek = parca.length === 2 ? `${parca.join('')} ya da ${parca.join(',')}` : '1234 ya da 1,234';
    return { n: null, red: `${ham} anlaşılamadı: ${ornek} yazın` };
  }
  const s = /^[1-9]\d{0,2}(\.\d{3})+,\d+$/.test(ham) ? ham.replace(/\./g, '').replace(',', '.') : ham.replace(',', '.');
  const n = /^\d*\.?\d*$/.test(s) ? Number(s) : NaN;
  if (n === 0) return { n: null, red: null };
  return Number.isFinite(n) ? { n, red: null } : { n: null, red: `${ham} anlaşılamadı: 1234 ya da 1,234 yazın` };
}

/**
 * Fiyatı eksik ilaç satırlarının panel HTML'i; dizi boşsa ''. Satırlar vaka_n sırasıyla.
 * @param {Array<{stok_id:string, urun_adi:string, birim:?string, vaka_n:number, gecici_deger:?number}>} fiyatEksik
 * @param {?object} degerler bellekteki değerler: window._atolye.gecici ya da düz {stok_id: sayı}; satırın gecici_deger'ine baskındır.
 */
function geciciFiyatPanelHtml(fiyatEksik, degerler) {
  if (!Array.isArray(fiyatEksik) || !fiyatEksik.length) return '';
  const bellek = (degerler && degerler.ilac_fiyat) || degerler || {};
  const has = (o, k) => Object.prototype.hasOwnProperty.call(o, k);
  const satirlar = [...fiyatEksik]
    .sort((a, b) => (Number(b.vaka_n) || 0) - (Number(a.vaka_n) || 0))
    .map(r => {
      const kayitli = has(bellek, r.stok_id) ? bellek[r.stok_id] : r.gecici_deger;
      // Sayı ekran biçimiyle (virgül) döner: 1.234 noktayla dönseydi sonraki Hesapla onu belirsiz sayardı.
      const deger = has(_geciciFiyatRed, r.stok_id) ? _geciciFiyatRed[r.stok_id]
        : typeof kayitli === 'number' ? String(kayitli).replace('.', ',') : kayitli;
      const birim = r.birim ? ` / ${esc(r.birim)}` : '';
      return `<label class="atolye-fiyat-satir"><span>${esc(r.urun_adi)} · ₺${birim}</span>` +
        `<input type="text" inputmode="decimal" min="0" data-stok-id="${escAttr(r.stok_id)}" value="${escAttr(deger)}"></label>`;
    });
  const uyari = _geciciFiyatRedMetin(fiyatEksik.map(r => _geciciFiyatRed[r.stok_id]));
  return `<div class="atolye-fiyat">` +
    `<div class="atolye-kart-baslik">İlaç birim fiyatı (geçici)</div>` +
    `<div class="atolye-sayac">Bu değerler kaydedilmez; yalnız bu hesapta kullanılır.</div>` +
    satirlar.join('') +
    `<div class="atolye-sayac" data-gecici="uyari"${uyari ? '' : ' hidden'}>${esc(uyari)}</div>` +
    `<div class="atolye-panel-alt">` +
    `<button type="button" class="atolye-btn-ana" data-gecici="hesapla">Hesapla</button>` +
    `<button type="button" class="atolye-eylem" data-gecici="temizle">Temizle</button>` +
    `</div></div>`;
}

function _geciciFiyatRedMetin(hamlar) {
  return hamlar.filter(h => h !== undefined).map(h => _geciciFiyatCoz(h).red).join(' · ');
}

// Uyarı anında yazılır: hesap yanıtı gelmese de (çevrimdışı) kullanıcı atlanan değeri görür.
function _geciciFiyatRedYaz(kok, red) {
  _geciciFiyatRed = red;
  const u = kok.querySelector('[data-gecici="uyari"]');
  if (!u) return;
  u.textContent = _geciciFiyatRedMetin(Object.values(red));
  u.hidden = !u.textContent;
}

/** Panel alanlarını okur → {ilac_fiyat:{<stok_id>: number}}; boş/0/negatif/okunamayan alan girmez (okunamayan: _geciciFiyatRed). */
function geciciFiyatOku(kok) {
  const ilac_fiyat = {};
  if (!kok) return { ilac_fiyat };
  kok.querySelectorAll('input[data-stok-id]').forEach(girdi => {
    const { n } = _geciciFiyatCoz(girdi.value);
    if (n !== null) ilac_fiyat[girdi.dataset.stokId] = n;
  });
  return { ilac_fiyat };
}

/** "Hesapla" / "Temizle". Yeniden çizimde tekrar çağrılabilir: onclick ataması çift hesap başlatmaz. */
function geciciFiyatBagla(kok) {
  if (!kok) return;
  const hesapla = kok.querySelector('[data-gecici="hesapla"]');
  const temizle = kok.querySelector('[data-gecici="temizle"]');
  if (hesapla) {
    hesapla.onclick = () => {
      window._atolye.gecici = geciciFiyatOku(kok);
      const red = {};
      kok.querySelectorAll('input[data-stok-id]').forEach(girdi => {
        if (_geciciFiyatCoz(girdi.value).red) red[girdi.dataset.stokId] = String(girdi.value).trim();
      });
      _geciciFiyatRedYaz(kok, red);
      return kurucuYenile();
    };
  }
  if (temizle) {
    temizle.onclick = () => {
      kok.querySelectorAll('input[data-stok-id]').forEach(girdi => { girdi.value = ''; });
      window._atolye.gecici = { ilac_fiyat: {} };
      _geciciFiyatRedYaz(kok, {});
      return kurucuYenile();
    };
  }
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, { geciciFiyatPanelHtml, geciciFiyatOku, geciciFiyatBagla });
}
