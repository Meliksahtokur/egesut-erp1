// js/degisiklikler/degisiklikler.js
// "Değişiklikler" sayfası (G-20260913-SURUM-GECMISI F3): txid bazlı liste,
// filtreler, satır satır diff, biletli geri al akışı.
//
// Kalıplar (icat değil, yeniden kullanım):
//  - Sayfa: index.html .pg + app.js goTo(pg) — sayfa yükleyici burada, goTo'ya dokunulmaz.
//  - Aksiyonlar: js/utils/events.js registerActions (data-action delegasyonu) — MODAL-ROUTER-01.
//  - Modallar: js/utils/modal.js openM/closeM + .mo[data-action=mclose-overlay] (örnek: m-not / openNotModal).
//  - Tarih: js/ui.js tekTarihTakvimAc({baslik, deger, onSec}); gösterim fmtTarih (gg.aa.yyyy).
//  - Çevrimdışı: js/forms.js submitCikis guard'ı (navigator.onLine → toast 'İnternet bağlantısı gerekli')
//    + js/gecmis.js _gmUndoButtonHtml (offline iken geri-al düğmesi gösterilmez).
//  - XSS: tüm dinamik metin esc(), tüm attribute escAttr(); jsonb hedefler attribute'a
//    YAZILMAZ — bellekteki _dg.hedefler dizisine indeksle erişilir.
// Hata gövdesi: rpc() ok:false → Error, e.data.hata (F2 frozen contract kodu).

const DG_BILET_ANAHTAR = 'ege_geri_alma_bileti';
const DG_ADET = 50;
const DG_HATA_METNI = {
  SIFRE_HATALI: 'Şifre hatalı.',
  SIFRE_AYARLI_DEGIL: 'Sahip şifresi henüz ayarlanmamış (kurulum adımı gerekli).',
  BILET_GECERSIZ: 'Geri alma bileti geçersiz — şifreyle yeniden alın.',
  BILET_SURESI_DOLMUS: 'Geri alma biletinin süresi doldu — şifreyle yeniden alın.',
  CAKISMA: 'Bu olaydan sonra başka değişiklikler var — aşağıdaki zincir önerisini kullanabilirsin.',
  BAGIMLILIK_ENGELI: 'Bu kayıt bağımlı alt kayıtlar içeriyor — önce onları geri alman gerekiyor (aşağıda listelendi).',
  HEDEF_BULUNAMADI: 'Hedef bulunamadı (sistem kurulmadan önceki değişiklikler geri alınamaz).',
  GECERSIZ_SEVIYE: 'Geçersiz geri alma seviyesi.',
  GECERSIZ_HEDEF: 'Geçersiz hedef (alan seviyesi yalnız güncellemelerde geçerlidir).',
  ZINCIR_COK_UZUN: 'Zincir 100 adımı aşıyor — Değişiklikler listesinden adımları tek tek geri al.',
};
// HEDEF_BULUNAMADI detay.neden → insan dilli + yönlendirmeli metin (W1 §5)
const DG_NEDEN_METNI = {
  SATIR_YOK: 'Bu kayıt artık mevcut değil — geri alınamaz.',
  LOG_YOK: "Bu olay değişiklik takibi kurulmadan önce yapılmış — geri alınamaz. Kaydı hayvan kartından elle düzeltebilirsin.",
  ZAMAN_ESLESME_YOK: 'Bu olay kayıtla eşleşemedi (geç girilmiş olabilir). Değişiklikler sayfasından günü seçip işlemi oradan geri al.',
};
const DG_SEVIYE_METNI = { alan: 'Alanı geri al', satir: 'Satırı geri al', islem: 'İşlemi geri al', zincir: 'Zincir olarak geri al' };

const _dg = {
  filtre: {},            // {baslangic, bitis, tablo, islem, hayvan_id}
  hayvanKupe: '',        // hayvan filtresinin gösterim etiketi
  kayitlar: [],
  toplam: 0,
  sayfa: 1,
  detayTxid: null,
  detay: [],
  tumAlanlar: false,
  hedefler: [],          // [{hedef, seviye, etiket}] — attribute'a jsonb yazmamak için
  rehberHedefler: [],    // rehber satır tokenları — hedefler'den AYRI (önizleme kapanınca
                         // detayın kendi tokenları geçersiz kalmasın)
  bekleyen: null,        // önizlemesi açık {hedef, seviye, etiket, baglam}
  sonuc: null,           // uygulama sonrası {adim, txid, etiket} — ⟲ kısayolu
  gurultu: { uydis: false },  // liste: uygulama-dışı kartlar göster? (varsayılan GİZLİ)
  detayTeknik: false,    // tx detay: teknikal satırlar göster? (varsayılan GİZLİ)
  yukleniyor: false,
  zamanlayici: null,
};

function _dgHataMetni(e) {
  const kod = e && e.data && e.data.hata;
  const neden = e && e.data && e.data.detay && e.data.detay.neden;
  if (kod === 'HEDEF_BULUNAMADI' && neden && DG_NEDEN_METNI[neden]) return DG_NEDEN_METNI[neden];
  if (kod && DG_HATA_METNI[kod]) return DG_HATA_METNI[kod];
  return (e && e.message) || 'İşlem başarısız';
}
// Engel metni + yönlendirme butonları (zarf D — insan dilli, bağlantılı).
// Hata yolu: e.data.detay.neden; önizleme yolu: neden null → genel metin.
function _dgEngelKutusu(metin, hedef) {
  const butonlar = [];
  if (hedef && hedef.tablo === 'hayvanlar' && hedef.pk)
    butonlar.push(`<button type="button" class="dg-link" data-action="dg-git-hayvan" data-hid="${escAttr(String(hedef.pk))}">🐄 Hayvan kartını aç</button>`);
  butonlar.push('<button type="button" class="dg-link" data-action="dg-git-degisiklikler">📂 Değişiklikler\'den seç</button>');
  return `<div class="dg-uyari">⚠️ ${esc(metin)}</div><div class="dg-not">${butonlar.join(' ')}</div>`;
}
function _dgCevrimici() { return navigator.onLine !== false; }

// ── Bilet (1 saat; sessionStorage — sekme kapanınca biter) ──────────
function _dgBiletOku() {
  try {
    const raw = sessionStorage.getItem(DG_BILET_ANAHTAR);
    if (!raw) return null;
    const b = JSON.parse(raw);
    if (!b || !b.bilet || !b.son_gecerlilik || new Date(b.son_gecerlilik).getTime() <= Date.now()) {
      sessionStorage.removeItem(DG_BILET_ANAHTAR);
      return null;
    }
    return b;
  } catch (_) { return null; }
}
function _dgBiletYaz(b) {
  try {
    // Süre istemci saatinden kalan_sn ile hesaplanır (sunucu son_gecerlilik'i ile
    // cihaz saati kaymış olabilir); sunucu yine de her kullanımda doğrular.
    const son = b ? new Date(Date.now() + (Number(b.kalan_sn) > 0 ? Number(b.kalan_sn) : 3600) * 1000).toISOString() : null;
    if (b) sessionStorage.setItem(DG_BILET_ANAHTAR, JSON.stringify({ bilet: b.bilet, son_gecerlilik: son }));
    else sessionStorage.removeItem(DG_BILET_ANAHTAR);
  } catch (_) { /* depolama kapalı → bilet yalnız bu işlemde kullanılır */ }
}
function _dgBiletKalanDk(b) {
  return b ? Math.max(0, Math.ceil((new Date(b.son_gecerlilik).getTime() - Date.now()) / 60000)) : 0;
}
function _dgBiletGostergesi() {
  const el = document.getElementById('dg-bilet');
  if (!el) return;
  const b = _dgBiletOku();
  el.innerHTML = b
    ? `<span class="dg-rozet dg-rozet-g" title="Geri alma bileti">🔓 Bilet: ${_dgBiletKalanDk(b)} dk</span> <button type="button" class="dg-link" data-action="dg-bilet-birak">Bırak</button>`
    : '<span class="dg-rozet" title="Geri almak için sahip şifresi istenir">🔒 Bilet yok</span>';
}

// ── Sayfa girişi ────────────────────────────────────────────────────
async function degisikliklerAc(onFiltre) {
  if (onFiltre) {
    _dg.filtre = Object.assign({}, onFiltre.filtre || {});
    _dg.hayvanKupe = onFiltre.hayvanKupe || '';
  }
  _dg.detayTxid = null;
  await goTo('degisiklikler');
  _dgSayfaCiz();
  _dgZamanlayiciBaslat();
  await degisikliklerYukle(1);
}

// Bilet kalan süre göstergesi: sayfa görünürken 30 sn'de bir tazelenir
function _dgZamanlayiciBaslat() {
  if (_dg.zamanlayici) clearInterval(_dg.zamanlayici);
  _dg.zamanlayici = setInterval(() => {
    if (getState('currentPage') !== 'degisiklikler') { clearInterval(_dg.zamanlayici); _dg.zamanlayici = null; return; }
    _dgBiletGostergesi();
  }, 30000);
}

// Tarayıcı geri/ileri ile #degisiklikler'e dönüş: app.js popstate goTo'yu çağırır
// ama bu sayfanın yükleyicisi goTo'da yok (app.js manifest dışı) → burada tamamlanır.
window.addEventListener('popstate', e => {
  const st = e.state || {};
  if (st.pg !== 'degisiklikler' || st.det || st.modal) return;
  setTimeout(() => {
    if (getState('currentPage') !== 'degisiklikler') return;
    if (!document.querySelector('#dg-root .dg-filtre')) { _dgSayfaCiz(); degisikliklerYukle(1); }
    else _dgBiletGostergesi();
    _dgZamanlayiciBaslat();
  }, 0);
});

// Hayvan detayından: filtre ön-dolu (js/ui.js _detOzetHtml → data-action dg-hayvan-degisiklikleri)
function degisikliklerHayvanIcin(hayvanId, kupe) {
  if (typeof closeDet === 'function') closeDet();
  return degisikliklerAc({ filtre: { hayvan_id: hayvanId }, hayvanKupe: kupe || '' });
}

function _dgSayfaCiz() {
  const root = document.getElementById('dg-root');
  if (!root) return;
  const f = _dg.filtre;
  const tablolar = tabloSecenekleri();
  const islemBtn = (kod, etiket) =>
    `<button type="button" class="fs-btn${(f.islem || '') === kod ? ' on' : ''}" data-action="dg-islem" data-islem="${escAttr(kod)}">${esc(etiket)}</button>`;
  root.innerHTML = `
    ${window.DEGISIM_STUB ? '<div class="dg-stub">🧪 Önizleme verisi (stub) — gerçek RPC\'ler W1 merge\'ünde bağlanır</div>' : ''}
    <div id="dg-cevrimdisi" class="dg-uyari"${_dgCevrimici() ? ' hidden' : ''}>📴 Çevrimdışı — değişiklik geçmişi ve geri alma internet gerektirir.</div>
    <div class="dg-bas">
      <div class="sh-title">🧾 Değişiklikler</div>
      <div id="dg-bilet"></div>
    </div>
    <div class="dg-filtre">
      <div class="dg-satir">
        <input id="dg-hayvan" class="fi" placeholder="Hayvan küpesi" autocomplete="off" value="${escAttr(_dg.hayvanKupe)}" data-keydown="dg-hayvan-enter">
        <button type="button" class="fs-btn" data-action="dg-hayvan-uygula">Ara</button>
        ${f.hayvan_id ? '<button type="button" class="fs-btn" data-action="dg-hayvan-temizle" title="Hayvan filtresini kaldır">✕</button>' : ''}
      </div>
      <div class="dg-satir">
        <button type="button" class="fs-btn" data-action="dg-tarih" data-uc="baslangic">📅 ${f.baslangic ? esc(fmtTarih(f.baslangic)) : 'Başlangıç'}</button>
        <button type="button" class="fs-btn" data-action="dg-tarih" data-uc="bitis">📅 ${f.bitis ? esc(fmtTarih(f.bitis)) : 'Bitiş'}</button>
        ${f.baslangic || f.bitis ? '<button type="button" class="fs-btn" data-action="dg-tarih-temizle" title="Tarih aralığını kaldır">✕</button>' : ''}
      </div>
      <div class="dg-satir">
        <select id="dg-tablo" class="fi" data-change="dg-tablo">
          <option value="">Tüm tablolar</option>
          ${tablolar.map(t => `<option value="${escAttr(t.kod)}"${f.tablo === t.kod ? ' selected' : ''}>${esc(t.etiket)}</option>`).join('')}
        </select>
      </div>
      <div class="dg-satir">
        ${islemBtn('', 'Hepsi')}${islemBtn('I', '＋ Ekleme')}${islemBtn('U', '✎ Güncelleme')}${islemBtn('D', '🗑 Silme')}
      </div>
      <div class="dg-not">Sürüden çıkarma (satış/ölüm/kesim) hayvan güncellemesi olarak listededir.</div>
    </div>
    <div id="dg-liste"></div>`;
  _dgBiletGostergesi();
}

async function degisikliklerYukle(sayfa) {
  const liste = document.getElementById('dg-liste');
  if (!liste) return;
  _dg.detayTxid = null;
  if (!_dgCevrimici()) {
    liste.innerHTML = '<div class="empty-s">📴 Çevrimdışıyken değişiklik listesi alınamaz.</div>';
    return;
  }
  _dg.sayfa = sayfa || 1;
  if (_dg.sayfa === 1) liste.innerHTML = '<div class="loader"><div class="spin"></div></div>';
  _dg.yukleniyor = true;
  try {
    const filtre = Object.assign({}, _dg.filtre, { sayfa: _dg.sayfa, adet: DG_ADET });
    Object.keys(filtre).forEach(k => { if (filtre[k] === '' || filtre[k] == null) delete filtre[k]; });
    const r = await rpcDegisimListele(filtre);
    const yeni = (r && r.kayitlar) || [];
    _dg.kayitlar = _dg.sayfa === 1 ? yeni : _dg.kayitlar.concat(yeni);
    _dg.toplam = (r && r.toplam) || _dg.kayitlar.length;
    _dgListeCiz();
  } catch (e) {
    const hataHtml = `<div class="empty-s">⚠️ ${esc(_dgHataMetni(e))}</div>`;
    if (_dg.sayfa > 1 && _dg.kayitlar.length) {     // yüklü listeyi koru, hatayı altına ekle
      _dg.sayfa -= 1;
      _dgListeCiz();
      liste.insertAdjacentHTML('beforeend', hataHtml);
    } else liste.innerHTML = hataHtml;
  } finally {
    _dg.yukleniyor = false;
  }
}

function _dgKaynakMetni(k) {
  if (!k || typeof k !== 'object') return '—';
  const parca = [];
  if (k.geri_alma) parca.push('↩ geri alma');
  if (k.app_name) parca.push(k.app_name);
  if (k.istemci_etiketi) parca.push(k.istemci_etiketi);
  if (!k.app_name && k.rol) parca.push(k.rol);
  return parca.join(' · ') || '—';
}
// (eskiden _dgUygulamaDisi — L4-W2'de SAF katmana taşındı: diff.js dgUygulamaDisiMi)

function _dgListeCiz() {
  const liste = document.getElementById('dg-liste');
  if (!liste) return;
  if (!_dg.kayitlar.length) {
    liste.innerHTML = '<div class="empty-s">Bu filtrelerle değişiklik yok.</div>';
    return;
  }
  // Gürültü (zarf B): uygulama-dışı kartlar varsayılan GİZLİ + "Uygulama dışı (N)"
  // çipi (U1 çip deseni); sayaç FİLTRE ÖNCESİ toplamı verir.
  const ayirici = dgGurultuAyir(_dg.kayitlar, r => dgUygulamaDisiMi(r.kaynak));
  const gurunen = _dg.gurultu.uydis ? _dg.kayitlar : ayirici.gorunen;
  const cipler = ayirici.gizliSayi
    ? `<button type="button" class="gm-cip${_dg.gurultu.uydis ? ' on' : ''}" data-action="dg-gurultu-cip">Uygulama dışı (${esc(String(ayirici.gizliSayi))})${_dg.gurultu.uydis ? ' ✕' : ''}</button>`
    : '';
  const kartlar = gurunen.map(k => {
    const o = k.ozet || {};
    const isl = o.islemler || {};
    const rozet = (kod, sinif) => isl[kod] ? `<span class="dg-rozet ${sinif}">${esc(kod)} ${esc(String(isl[kod]))}</span>` : '';
    const dis = dgUygulamaDisiMi(k.kaynak);
    return `<div class="dg-kart" role="button" data-action="dg-tx-ac" data-txid="${escAttr(String(k.txid))}">
      <div class="dg-kart-ust">
        <span class="dg-baslik">${esc(o.baslik || 'Değişiklik')}</span>
        <span class="dg-zaman">${esc(fmtTarihSaat(k.ilk_zaman))}</span>
      </div>
      <div class="dg-kart-alt">
        <span>${esc(ozetMetni(o))}</span>
        ${rozet('I', 'dg-rozet-g')}${rozet('U', 'dg-rozet-a')}${rozet('D', 'dg-rozet-r')}
      </div>
      <div class="dg-kaynak${dis ? ' dg-kaynak-dis' : ''}">${dis ? '⚠️ uygulama dışı · ' : ''}${esc(_dgKaynakMetni(k.kaynak))}</div>
    </div>`;
  }).join('');
  const dahaFazla = _dg.kayitlar.length < _dg.toplam
    ? `<button type="button" class="btn btn-o" data-action="dg-daha">Daha fazla (${esc(String(_dg.toplam - _dg.kayitlar.length))})</button>` : '';
  liste.innerHTML = `<div class="dg-sayac">${esc(String(_dg.toplam))} işlem</div>${cipler ? '<div class="gm-cip-satir">' + cipler + '</div>' : ''}${kartlar || (_dg.kayitlar.length ? '<div class="dg-not">Gürültü filtresinde görünür kayıt yok — çipi açabilirsin.</div>' : '')}${dahaFazla}`;
}

// ── İşlem detayı: satır satır diff ──────────────────────────────────
function _dgHedefKaydet(hedef, seviye, etiket) {
  _dg.hedefler.push({ hedef, seviye, etiket });
  return _dg.hedefler.length - 1;
}
function _dgPk(satirPk) {
  // Lead sözleşme güncellemesi (goal 3674e62): p_hedef.pk tek-kolon PK'da SKALER
  // değer (uuid/text/sayı), composite PK'da NESNE {pkkolon: deger}. Gösterim
  // pkKisa ile satir_pk'dan okunur.
  if (satirPk && typeof satirPk === 'object' && !Array.isArray(satirPk)) {
    const k = Object.keys(satirPk);
    if (k.length === 1) return satirPk[k[0]];
    return JSON.parse(JSON.stringify(satirPk));
  }
  return satirPk == null ? null : satirPk;
}
function _dgGeriAlBtn(hedef, seviye, etiket, kucuk) {
  if (!_dgCevrimici() || !hedef) return '';        // _gmUndoButtonHtml offline kalıbı
  const i = _dgHedefKaydet(hedef, seviye, etiket);
  return `<button type="button" class="dg-geri${kucuk ? ' dg-geri-k' : ''}" data-action="dg-geri-al" data-hi="${i}" title="${escAttr(DG_SEVIYE_METNI[seviye])}">↩${kucuk ? '' : ' ' + esc(DG_SEVIYE_METNI[seviye])}</button>`;
}

async function degisiklikTxAc(txid) {
  const liste = document.getElementById('dg-liste');
  if (!liste || !txid) return;
  if (!_dgCevrimici()) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  _dg.detayTxid = String(txid);
  _dg.detayTeknik = false;   // teknikal satırlar her detay açılışında varsayılan GİZLİ
  liste.innerHTML = '<div class="loader"><div class="spin"></div></div>';
  try {
    const r = await rpcDegisimListele({ txid: String(txid) });
    if (_dg.detayTxid !== String(txid)) return;
    _dg.detay = (r && r.kayitlar) || [];
    _dgDetayCiz();
  } catch (e) {
    liste.innerHTML = `<button type="button" class="dg-link" data-action="dg-liste-don">‹ Listeye dön</button><div class="empty-s">⚠️ ${esc(_dgHataMetni(e))}</div>`;
  }
}

// Hayvan referansı alanlarında UUID yerine küpe göster (yalnız gösterim; js/ui.js hayvanByKupeRef)
const DG_HAYVAN_REF_ALANLARI = ['hayvan_id', 'animal_id', 'anne_id', 'ana_hayvan_id'];
function _dgDegerMetni(tablo, alan, v) {
  const metin = degerMetni(v);
  const ref = (DG_HAYVAN_REF_ALANLARI.includes(alan) || (tablo === 'hayvanlar' && alan === 'id')) && typeof v === 'string';
  if (!ref || typeof hayvanByKupeRef !== 'function') return metin;
  const h = hayvanByKupeRef(v);
  const kupe = h && (h.kupe_no || h.devlet_kupe);
  return kupe ? `${kupe} (${v.slice(0, 8)})` : metin;
}

function _dgDetayCiz() {
  const liste = document.getElementById('dg-liste');
  if (!liste) return;
  _dg.hedefler = [];
  // NOT: _dg.detayTeknik BURADA sıfırlanmaz — çip aç-kapa yeniden render çağırır;
  // sıfırlama yalnız YENİ detay açılışında yapılır (degisiklikTxAc).
  const rows = _dg.detay;
  const ozet = islemOzeti(rows);
  const kaynak = rows[0] && rows[0].kaynak;
  const listeOzeti = (_dg.kayitlar.find(k => String(k.txid) === _dg.detayTxid) || {}).ozet;
  // Gürültü (zarf B): teknikal satırlar varsayılan GİZLİ + "Teknik (N)" çipi
  const teknikAyir = dgGurultuAyir(rows, dgTeknikMi);
  const gorunen = _dg.detayTeknik ? rows : teknikAyir.gorunen;
  const teknikCip = teknikAyir.gizliSayi
    ? `<button type="button" class="gm-cip${_dg.detayTeknik ? ' on' : ''}" data-action="dg-teknik-cip">Teknik (${esc(String(teknikAyir.gizliSayi))})${_dg.detayTeknik ? ' ✕' : ''}</button>`
    : '';
  const satirHtml = gorunen.map(r => {
    const tablo = r.tablo_adi;
    const pk = _dgPk(r.satir_pk);
    const farklar = diffSatirlari(r.eski, r.yeni)
      .filter(d => r.islem !== 'U' || _dg.tumAlanlar || d.durum !== 'ayni')
      .filter(d => _dg.tumAlanlar || !dgAlanBosMu(d));   // boş değer satırı gizli
    const sirali = dgAlanSirala(tablo, farklar.map(d => d.alan));
    const siraliFarklar = sirali.map(a => farklar.find(d => d.alan === a)).filter(Boolean);
    const islemSinif = r.islem === 'I' ? 'dg-rozet-g' : r.islem === 'D' ? 'dg-rozet-r' : 'dg-rozet-a';
    const alanlar = siraliFarklar.map(d => {
      let deger;
      if (d.durum === 'eklendi') deger = `<span class="dg-yeni">${esc(_dgDegerMetni(tablo, d.alan, d.yeni))}</span>`;
      else if (d.durum === 'silindi') deger = `<span class="dg-eski">${esc(_dgDegerMetni(tablo, d.alan, d.eski))}</span>`;
      else if (d.durum === 'degisti') deger = `<span class="dg-eski">${esc(_dgDegerMetni(tablo, d.alan, d.eski))}</span> <span class="dg-ok">→</span> <span class="dg-yeni">${esc(_dgDegerMetni(tablo, d.alan, d.yeni))}</span>`;
      else deger = `<span class="dg-ayni">${esc(_dgDegerMetni(tablo, d.alan, d.yeni))}</span>`;
      const alanBtn = r.islem === 'U' && d.durum === 'degisti' && pk != null
        ? _dgGeriAlBtn({ tablo, pk, alan: d.alan, txid: _dg.detayTxid }, 'alan', `${tabloEtiketi(tablo)} · ${alanEtiketi(tablo, d.alan)}`, true) : '';
      return `<div class="dg-alan dg-${escAttr(d.durum)}">
        <span class="dg-alan-ad" title="${escAttr(d.alan)}">${esc(alanEtiketi(tablo, d.alan))}</span>
        <span class="dg-alan-deger">${deger}</span>${alanBtn}
      </div>`;
    }).join('');
    const satirBtn = pk != null ? _dgGeriAlBtn({ tablo, pk, txid: _dg.detayTxid }, 'satir', `${tabloEtiketi(tablo)}`) : '';
    // satır pk (ham teknik değer) yalnız katlı teknik blokta
    const teknikKucuk = `<details class="dg-teknik dg-teknik-s"><summary>Teknik ▸</summary><div class="dg-not">${esc(pkKisa(r.satir_pk))}${r.teknikal_mi ? ' · teknik satır' : ''}</div></details>`;
    return `<div class="dg-satir-kart">
      <div class="dg-satir-bas">
        <span class="dg-rozet ${islemSinif}">${esc(islemEtiketi(r.islem))}</span>
        <b>${esc(tabloEtiketi(tablo))}</b>
      </div>
      ${alanlar || '<div class="dg-not">Görünür alan farkı yok.</div>'}
      ${satirBtn}
      ${teknikKucuk}
    </div>`;
  }).join('');
  // işlem dili başlık (S4): "Görev tamamlandı — 14.09 17:25 · 4019" kalıbı;
  // ham tx YALNIZ teknik katlamada. ozet.baslik zaten işlem dilli (L2 listele).
  const baslikMetni = (listeOzeti && listeOzeti.baslik) || 'İşlem';
  const islemBtn = _dgGeriAlBtn({ txid: _dg.detayTxid }, 'islem', 'İşlemi geri al');
  const teknikDetay = `<details class="dg-teknik"><summary>Teknik ayrıntı ▸</summary>
      <div class="dg-not">tx: ${esc(_dg.detayTxid)}</div>
      ${kaynak ? `<div class="dg-not">Kaynak: ${esc(JSON.stringify(kaynak))}</div>` : ''}
    </details>`;
  liste.innerHTML = `
    <button type="button" class="dg-link" data-action="dg-liste-don">‹ Listeye dön</button>
    <div class="dg-detay-bas">
      <div class="dg-baslik">${esc(baslikMetni)}</div>
      <div class="dg-not">${esc(rows[0] ? fmtTarihSaat(rows[0].zaman) : '')} · ${esc(ozetMetni(ozet))} · ${esc(_dgKaynakMetni(kaynak))}</div>
      ${kaynak && kaynak.geri_alma && kaynak.geri_alma.gerekce ? `<div class="dg-not">Gerekçe: ${esc(kaynak.geri_alma.gerekce)}</div>` : ''}
      ${teknikCip ? '<div class="gm-cip-satir">' + teknikCip + '</div>' : ''}
      <label class="dg-not dg-tum"><input type="checkbox" data-change="dg-tum-alanlar"${_dg.tumAlanlar ? ' checked' : ''}> Değişmeyen alanları da göster</label>
      ${islemBtn}
      ${teknikDetay}
    </div>
    ${satirHtml || '<div class="empty-s">' + (teknikAyir.gizliSayi ? 'Görünür kayıt yok — Teknik çipini açabilirsin.' : 'Bu işlemde kayıt yok.') + '</div>'}`;
}

// ── L4-W2: TEK geri-al girişi (önizleme → bilet → uygula → sonuç) ────
// dgGeriAlAkisi(hedef, seviye, baglam) — TÜM yüzeyler (Geçmiş kartı, hayvan
// kartı, işlem detay paneli, vaka/görev/protokol/sütten/tohumlama detayları,
// Değişiklikler) BURAYA gelir. baglam = {olayEtiketi, zaman, kim} (işlem dili).
async function dgGeriAlAkisi(hedef, seviye, baglam) {
  if (!_dgCevrimici()) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  if (!hedef) { toast('⚠️ Bu olay için geri alma hedefi çözülemedi — Değişiklikler sayfasından deneyin', true); return; }
  const b = baglam || {};
  const etiket = _gmIslemBaslikSatiri(b);
  _dg.bekleyen = { hedef, seviye: _dgSeviyeTamamla(hedef, seviye), etiket, baglam: b };
  await dgOnizleGoster();
}

// islem_log/geçmiş entry'sinden giriş: çözücü (_gmGeriAlHedef, js/gecmis.js TEK
// kaynak) hedefi kurar; seviye hedefin şeklinden türetilir. null hedef → buton
// üretilmemiş olmalıydı; çağrıldıysa yönlendirme mesajı (çıkımaz yok).
function dgGeriAlFromEntry(entry, seviye) {
  const hedef = _gmGeriAlHedef(entry);
  if (!hedef) { toast('⚠️ Bu olay için geri alma hedefi çözülemedi — Değişiklikler sayfasından deneyin', true); return null; }
  const s = seviye || (hedef.txid ? 'islem' : 'satir');
  return dgGeriAlAkisi(hedef, s, _gmGeriAlBaglam(entry));
}

function _dgSeviyeTamamla(hedef, seviye) {
  if (seviye === 'zincir') return 'zincir';
  if (hedef && hedef.alan) return 'alan';
  if (seviye === 'alan' || seviye === 'satir' || seviye === 'islem') return seviye;
  return hedef && hedef.txid ? 'islem' : 'satir';
}

async function dgOnizleGoster() {
  const h = _dg.bekleyen;
  if (!h) return;
  const govde = document.getElementById('dg-onizle-govde');
  const baslik = document.getElementById('dg-onizle-baslik');
  const onayBtn = document.getElementById('dg-onizle-onay');
  const fg = document.querySelector('#m-dg-onizle .fg');
  if (baslik) baslik.textContent = (h.seviye === 'zincir' ? '🔗 Zincir geri al — ' : '↩ ') + h.etiket;
  if (onayBtn) { onayBtn.hidden = false; onayBtn.textContent = h.seviye === 'zincir' ? '🔗 Zinciri Geri Al' : '↩ Geri Almayı Uygula'; }
  if (fg) fg.hidden = false;
  if (govde) govde.innerHTML = '<div class="loader"><div class="spin"></div></div>';
  const gerekce = document.getElementById('dg-gerekce'); if (gerekce) gerekce.value = '';
  _dgEngelGoster('');
  _dgOnayDurumu(false);
  openM('m-dg-onizle');
  try {
    const on = await rpcDegisimOnizle(h.hedef, h.seviye);
    if (_dg.bekleyen !== h) return;
    _dg.rehberHedefler = [];   // rehber satır düğmeleri için token kaydı (hedefler'e DOKUNMA — detayın tokenları canlı kalmalı)
    if (govde) govde.innerHTML = _dgOnizleHtml(on, h);
    if (on.geri_alinabilir) _dgOnayDurumu(true);
    else if (on.sirali_rehber && on.sirali_rehber.length) _dgEngelGoster('');  // rehber modu — çıkımaz yok
    else if ((on.cakismalar || []).length) _dgEngelGoster('');                 // zincir önerisi konuşur
    else _dgEngelGoster(_dgEngelKutusu('Bu işlem şu koşullarda geri alınamaz — aşağıdaki yönlendirmeleri izleyebilirsin.', h.hedef));
  } catch (e) {
    if (govde) govde.innerHTML = `<div class="dg-not">Önizleme alınamadı: ${esc(_dgHataMetni(e))}</div>`;
    _dgEngelGoster(_dgEngelKutusu(_dgHataMetni(e), h.hedef));
  }
}

function _dgOnayDurumu(acik) {
  const btn = document.getElementById('dg-onizle-onay');
  if (btn) { btn.disabled = !acik; btn.style.opacity = acik ? '' : '.45'; }
}
function _dgEngelGoster(icerikHtml) {
  const eng = document.getElementById('dg-onizle-engel');
  if (eng) { eng.innerHTML = icerikHtml || ''; eng.hidden = !icerikHtml; }
}

// Çakışma satırı — İNSAN DİLLİ (ham pk/UUID YOK): zaman · tablo · alanlar · işlem
function _dgCakismaSatiri(c) {
  const parca = [];
  if (c && c.zaman) parca.push(fmtTarihSaat(c.zaman));
  parca.push(c && c.tablo ? tabloEtiketi(c.tablo) : 'Değişiklik');
  if (c && Array.isArray(c.degisen_alanlar) && c.degisen_alanlar.length)
    parca.push(c.degisen_alanlar.map(a => alanEtiketi(c.tablo, a)).join(', '));
  if (c && c.islem) parca.push(islemEtiketi(c.islem));
  return parca.join(' · ');
}

// Zincir önerisi (sahibin 3-4-5 akışı): çakışma artık blok DEĞİL öneri
function _dgZincirOnerisiHtml(on) {
  const n = (on.cakismalar || []).length;
  if (!n) return '';
  const liste = on.cakismalar.map(c => `<div class="dg-not">${esc(_dgCakismaSatiri(c))}</div>`).join('');
  return `<div class="dg-blok dg-blok-a" data-test="dg-zincir-oneri"><div class="dg-blok-bas">🔗 Bu olaydan sonra ${esc(String(n))} değişiklik daha var</div>
    ${liste}
    <button type="button" class="btn btn-g" data-action="dg-zincir-oner" style="margin-top:6px">🔗 Zincir olarak geri al — ${esc(String(n))} olay birlikte</button></div>`;
}

// Zincir plan kartı (bağımlı adımlar işaretli — K1)
function _dgZincirKartHtml(p) {
  const zaman = p && p.zaman ? fmtTarihSaat(p.zaman) : '';
  const bagimli = !!(p && (p.bagimli || p.bagimli_adim));
  return `<div class="dg-plan">
      <span class="dg-rozet">${esc(String((p && p.sira) || ''))}</span>
      <b>${esc(p && p.tablo ? tabloEtiketi(p.tablo) : 'Değişiklik')}</b>${zaman ? ' <span class="dg-zaman">' + esc(zaman) + '</span>' : ''}
      ${bagimli ? '<span class="dg-rozet dg-rozet-a">bağımlı adım — bu geri almaya bağlı</span>' : ''}
      <div class="dg-not">${esc((p && p.yapilacak) || (p && p.islem ? islemEtiketi(p.islem) : ''))}</div>
    </div>`;
}

// Sıralı rehber (K1 — çıkımaz engel YOK): SAF hazırlık — en yeni önce,
// 1..N numara; zamansız satır sonda kendi sırasında. DOM yazmaz (testli).
function _dgRehberHazirla(siraliRehber) {
  const liste = (Array.isArray(siraliRehber) ? siraliRehber : []).filter(r => r && r.hedef);
  const damgalilar = liste.filter(r => r.zaman).sort((a, b) => String(b.zaman).localeCompare(String(a.zaman)));
  const damgasizlar = liste.filter(r => !r.zaman);
  return damgalilar.concat(damgasizlar).map((r, i) => ({
    no: i + 1,
    hedef: r.hedef,
    zaman: r.zaman || '',
    ozet: r.ozet || '',
    neden: r.neden_dahil_degil || '',
  }));
}

function _dgRehberBloku(siraliRehber) {
  const rehber = _dgRehberHazirla(siraliRehber);
  if (!rehber.length) return '';
  const satirlar = rehber.map((r, i) => {
    const baslik = r.ozet || (r.hedef && r.hedef.tablo ? tabloEtiketi(r.hedef.tablo) : 'Değişiklik');
    const zaman = r.zaman ? fmtTarihSaat(r.zaman) : '';
    _dg.rehberHedefler.push({ hedef: r.hedef, seviye: 'islem', etiket: baslik });
    return `<div class="dg-plan"><b>${esc(String(r.no))}. ${zaman ? 'önce ' : ''}</b>${esc(baslik)}${zaman ? ' <span class="dg-zaman">' + esc(zaman) + '</span>' : ''}${r.neden ? ' <span class="dg-not">(' + esc(r.neden) + ')</span>' : ''}
      <button type="button" class="dg-geri" data-action="dg-rehber-geri-al" data-hi="${i}">↩ Geri Al</button></div>`;
  }).join('');
  return `<div class="dg-blok dg-blok-a" data-test="dg-rehber"><div class="dg-blok-bas">🧭 Otomatik zincir kurulamadı — şu sırayla TEK TEK geri al</div>${satirlar}</div>`;
}

// Teknik ayrıntı katlaması (plan §5): tx/pk/kaynak YALNIZ burada — görünürde asla
function _dgTeknikDetayHtml(hedef, on) {
  const satirlar = [];
  if (hedef && hedef.txid) satirlar.push(['Hedef txid', String(hedef.txid)]);
  if (hedef && hedef.tablo) satirlar.push(['Hedef kayıt', hedef.tablo + ' · ' + pkKisa(hedef.pk)]);
  if (hedef && hedef.zaman) satirlar.push(['Hedef zaman', String(hedef.zaman)]);
  if (on && on.kaynak) satirlar.push(['Kaynak', JSON.stringify(on.kaynak)]);
  if (!satirlar.length) return '';
  return `<details class="dg-teknik"><summary>Teknik ayrıntı ▸</summary>${satirlar.map(([k, v]) => `<div class="dg-not">${esc(k)}: ${esc(v)}</div>`).join('')}</details>`;
}

function _dgOnizleHtml(on, h) {
  h = h || _dg.bekleyen || {};
  const zincir = h.seviye === 'zincir';
  const planHtml = zincir
    ? (on.plan || []).map(_dgZincirKartHtml).join('')
    : (on.plan || []).map(p => `<div class="dg-plan">
        <span class="dg-rozet">${esc(String(p.sira))}</span>
        <b>${esc(tabloEtiketi(p.tablo))}</b> <span class="dg-pk">#${esc(pkKisa(p.pk))}</span>
        <div class="dg-not">${esc(p.yapilacak || islemEtiketi(p.islem))}${Array.isArray(p.alanlar) && p.alanlar.length ? ' — ' + esc(p.alanlar.map(a => alanEtiketi(p.tablo, a)).join(', ')) : ''}</div>
      </div>`).join('');
  const zincirCumle = zincir && (on.plan || []).length
    ? `<div class="dg-not" data-test="dg-zincir-cumle"><b>${esc(String((on.plan || []).length))} olay sıralıdır, komple geri alınacak. Onaylıyor musunuz?</b></div>`
    : '';
  const rehberHtml = (!on.geri_alinabilir && on.sirali_rehber && on.sirali_rehber.length)
    ? _dgRehberBloku(on.sirali_rehber) : '';
  const cakHtml = (!zincir && (on.cakismalar || []).length) ? _dgZincirOnerisiHtml(on) : '';
  const cakZincirDisi = (zincir && !on.geri_alinabilir && (on.cakismalar || []).length)
    ? `<div class="dg-blok dg-blok-r"><div class="dg-blok-bas">⚠️ Zincire girmeyen gerçek çakışmalar — önce bunları TEK TEK geri al</div>${on.cakismalar.map(c => `<div class="dg-not">${esc(_dgCakismaSatiri(c))}</div>`).join('')}</div>`
    : '';
  const blok = (baslik, dizi, sinif, fn) => dizi && dizi.length
    ? `<div class="dg-blok ${sinif}"><div class="dg-blok-bas">${baslik}</div>${dizi.map(fn).join('')}</div>` : '';
  const bagimliSayi = (on.bagimliliklar || []).filter(b => b.etki === 'ENGEL').length;
  const bagHtml = blok('🔗 Bağımlılıklar' + (bagimliSayi ? ` — ${bagimliSayi} alt kayıt ÖNCE geri alınmalı` : ''), on.bagimliliklar, 'dg-blok-a',
    b => `<div class="dg-not"><span class="dg-rozet ${b.etki === 'ENGEL' ? 'dg-rozet-r' : 'dg-rozet-a'}">${esc(b.etki)}</span> ${esc(tabloEtiketi(b.tablo))}${b.etki === 'ENGEL' ? ' — önce bunu geri al ya da sil' : ''}${b.iliski ? ' (' + esc(b.iliski) + ')' : ''}</div>`);
  return `
    ${rehberHtml}
    ${zincirCumle}
    <div class="dg-blok"><div class="dg-blok-bas">${zincir ? '🔗 Zincir planı (' + esc(String((on.plan || []).length)) + ' olay)' : 'Plan (' + esc(String((on.plan || []).length)) + ' adım)'}</div>${planHtml || '<div class="dg-not">Plan boş.</div>'}</div>
    ${cakHtml}
    ${cakZincirDisi}
    ${bagHtml}
    ${blok('📦 Stok uyarısı', on.stok_uyari, 'dg-blok-a', st => `<div class="dg-not">${esc(st.metin || '')}</div>`)}
    ${_dgTeknikDetayHtml(h.hedef, on)}`;
}

// Değişiklikler sayfası kendi düğmeleri (alan/satır/işlem) — token → tek giriş
async function degisimGeriAlBaslat(hi) {
  const h = _dg.hedefler[hi];
  if (!h) return;
  await dgGeriAlAkisi(h.hedef, h.seviye, { olayEtiketi: h.etiket, zaman: '', kim: '' });
}

async function degisimGeriAlOnayla() {
  if (!_dg.bekleyen) return;
  if (!_dgCevrimici()) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const b = _dgBiletOku();
  if (!b) { _dgBiletModalAc(); return; }
  await _dgUygula(b.bilet);
}

function _dgBiletModalAc(mesaj) {
  cl('dg-sifre');
  const m = document.getElementById('dg-bilet-mesaj');
  if (m) { m.textContent = mesaj || ''; m.hidden = !mesaj; }
  openM('m-dg-bilet');
}

async function degisimBiletAl(btn) {
  if (!_dgCevrimici()) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const inp = document.getElementById('dg-sifre');
  const sifre = inp ? inp.value : '';
  if (!sifre) { toast('⚠️ Şifre girin', true); return; }
  if (btn) btn.disabled = true;
  try {
    const r = await rpcGeriAlmaBiletiAl(sifre);
    _dgBiletYaz(r);
    if (inp) inp.value = '';
    closeM('m-dg-bilet');
    _dgBiletGostergesi();
    toast(`🔓 Geri alma bileti alındı (${Math.round((r.kalan_sn || 3600) / 60)} dk)`);
    if (_dg.bekleyen) await _dgUygula(r.bilet);
  } catch (e) {
    const m = document.getElementById('dg-bilet-mesaj');
    if (m) { m.textContent = _dgHataMetni(e); m.hidden = false; }
  } finally {
    if (btn) btn.disabled = false;
  }
}

// Sonuç bloğu — ⟲ Geri alınanı geri al (akış f): hedef = geri alma tx'i.
// tx değeri metne HİÇ yazılmaz; yalnız aksiyonun kullandığı state'te taşınır.
function _dgSonucHtml(sc) {
  if (!sc) return '';
  const bas = sc.zincir
    ? `✅ ${esc(String(sc.adim))} olay birlikte geri alındı`
    : `✅ ${esc(sc.etiket || 'İşlem')} geri alındı`;
  return `<div class="dg-sonuc" data-test="dg-sonuc">
    <div class="dg-sonuc-bas">${bas}</div>
    <div class="dg-not">${sc.zincir ? esc(String(sc.adim)) + ' olay tek işlemde geri alındı' : 'İşlem geri alındı'}</div>
    ${sc.txid ? '<button type="button" class="dg-geri" data-action="dg-geri-alinani-geri-al">⟲ Geri alınanı geri al</button>' : ''}
  </div>`;
}
function _dgSonucToast(sc) {
  return sc && sc.zincir
    ? `✅ ${sc.adim} olay birlikte geri alındı`
    : `✅ Geri alındı — ${(sc && sc.etiket) || 'işlem'}`;
}
// Geri alma sonrası yüzey tazeleme: Değişiklikler'de liste+tx detayı; diğer
// yüzeylerde (Geçmiş/vaka/görev/…) ilgili tablolar + mevcut sayfa render'ı.
async function _dgSonrasiTazele(r) {
  if (getState('currentPage') === 'degisiklikler') {
    await degisikliklerYukle(1);
    if (r && r.geri_alma_txid) await degisiklikTxAc(r.geri_alma_txid);
    return;
  }
  const tablolar = ['hayvanlar', 'tohumlama', 'dogum', 'gorev_log', 'cases', 'treatment_days',
    'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'islem_log',
    'uygulama_log', 'kizginlik_log', 'vaccination_log', 'protokol_instance'];
  try { await pullTables(tablolar); } catch (e) { /* çevrimdışı yol — toast verildi */ }
  if (typeof renderSafe === 'function') renderSafe();
}

async function _dgUygula(bilet) {
  const h = _dg.bekleyen;
  if (!h) return;
  const btn = document.getElementById('dg-onizle-onay');
  if (btn) btn.disabled = true;
  const gerekceEl = document.getElementById('dg-gerekce');
  const gerekce = gerekceEl && gerekceEl.value.trim() ? gerekceEl.value.trim() : null;
  try {
    const r = await rpcDegisimGeriAl(h.hedef, h.seviye, bilet, gerekce);
    const adim = Number((r && r.uygulanan_adim) || 1);
    _dg.sonuc = { adim, txid: r && r.geri_alma_txid ? String(r.geri_alma_txid) : '', etiket: h.etiket, zincir: h.seviye === 'zincir' };
    _dg.bekleyen = null;
    // Modal AÇIK kalır: sonuç bloğu + ⟲ kısayol (her yüzeyde aynı — akış f)
    const govde = document.getElementById('dg-onizle-govde');
    if (govde) govde.innerHTML = _dgSonucHtml(_dg.sonuc);
    const onayB = document.getElementById('dg-onizle-onay');
    if (onayB) onayB.hidden = true;
    const fg = document.querySelector('#m-dg-onizle .fg');
    if (fg) fg.hidden = true;
    _dgEngelGoster('');
    toast(_dgSonucToast(_dg.sonuc));
    await _dgSonrasiTazele(r);
  } catch (e) {
    const kod = e && e.data && e.data.hata;
    if (kod === 'BILET_GECERSIZ' || kod === 'BILET_SURESI_DOLMUS') {
      _dgBiletYaz(null);
      _dgBiletGostergesi();
      _dgBiletModalAc(_dgHataMetni(e));
      if (btn) btn.disabled = false;
      return;
    }
    _dgOnayDurumu(false);
    _dgEngelGoster(_dgEngelKutusu(_dgHataMetni(e), h.hedef));
  }
}

function _dgTarihSec(uc) {
  tekTarihTakvimAc({
    baslik: uc === 'baslangic' ? '📅 Başlangıç tarihi' : '📅 Bitiş tarihi',
    deger: _dg.filtre[uc] || bugun(),
    onSec: iso => {
      _dg.filtre[uc] = iso;
      if (_dg.filtre.baslangic && _dg.filtre.bitis && _dg.filtre.baslangic > _dg.filtre.bitis) {
        const t = _dg.filtre.baslangic; _dg.filtre.baslangic = _dg.filtre.bitis; _dg.filtre.bitis = t;
      }
      _dgSayfaCiz(); degisikliklerYukle(1);
    },
  });
}

function _dgHayvanUygula() {
  const inp = document.getElementById('dg-hayvan');
  const ref = inp ? inp.value.trim() : '';
  if (!ref) { delete _dg.filtre.hayvan_id; _dg.hayvanKupe = ''; _dgSayfaCiz(); degisikliklerYukle(1); return; }
  const h = typeof hayvanByKupeRef === 'function' ? hayvanByKupeRef(ref) : null;
  if (!h) { toast('⚠️ Hayvan bulunamadı: ' + ref, true); return; }
  _dg.filtre.hayvan_id = h.id;
  _dg.hayvanKupe = h.kupe_no || h.devlet_kupe || ref;
  _dgSayfaCiz(); degisikliklerYukle(1);
}

// Çevrimiçi/çevrimdışı geçişinde sayfayı yeniden çiz (açık ise)
function _dgAgDegisti() {
  if (getState('currentPage') !== 'degisiklikler') return;
  const acikDetay = _dg.detayTxid;
  _dgSayfaCiz();
  if (_dgCevrimici()) {
    if (acikDetay) degisiklikTxAc(acikDetay);       // detay açıksa aynı işleme dön
    else degisikliklerYukle(1);
  } else {
    const l = document.getElementById('dg-liste');
    if (l) l.innerHTML = '<div class="empty-s">📴 Çevrimdışıyken değişiklik listesi alınamaz.</div>';
    // Yalnız açık olanı kapat (üst üste closeM → history.back sızıntısı olmasın)
    ['m-dg-bilet', 'm-dg-onizle'].forEach(id => { const m = document.getElementById(id); if (m && m.classList.contains('on')) closeM(id); });
    _dg.bekleyen = null;
  }
}
window.addEventListener('online', _dgAgDegisti);
window.addEventListener('offline', _dgAgDegisti);

registerActions({
  'go-degisiklikler':         () => degisikliklerAc(),
  'dg-hayvan-degisiklikleri': (el) => degisikliklerHayvanIcin(el.dataset.hid, el.dataset.kupe),
  'dg-hayvan-uygula':         () => _dgHayvanUygula(),
  'dg-hayvan-enter':          (p) => { if (p.key === 'Enter') { p.event.preventDefault(); _dgHayvanUygula(); } },
  'dg-hayvan-temizle':        () => { delete _dg.filtre.hayvan_id; _dg.hayvanKupe = ''; _dgSayfaCiz(); degisikliklerYukle(1); },
  'dg-tarih':                 (el) => _dgTarihSec(el.dataset.uc),
  'dg-tarih-temizle':         () => { delete _dg.filtre.baslangic; delete _dg.filtre.bitis; _dgSayfaCiz(); degisikliklerYukle(1); },
  'dg-tablo':                 (el) => { if (el.value) _dg.filtre.tablo = el.value; else delete _dg.filtre.tablo; degisikliklerYukle(1); },
  'dg-islem':                 (el) => { if (el.dataset.islem) _dg.filtre.islem = el.dataset.islem; else delete _dg.filtre.islem; _dgSayfaCiz(); degisikliklerYukle(1); },
  'dg-daha':                  () => { if (!_dg.yukleniyor) degisikliklerYukle(_dg.sayfa + 1); },
  'dg-tx-ac':                 (el) => degisiklikTxAc(el.dataset.txid),
  'dg-liste-don':             () => { _dg.detayTxid = null; _dgListeCiz(); },
  'dg-tum-alanlar':           (el) => { _dg.tumAlanlar = !!el.checked; _dgDetayCiz(); },
  'dg-geri-al':               (el, e) => { if (e && e.stopPropagation) e.stopPropagation(); degisimGeriAlBaslat(parseInt(el.dataset.hi, 10)); },
  'dg-onizle-onay':           () => degisimGeriAlOnayla(),
  'dg-onizle-kapat':          () => {
    _dg.bekleyen = null; _dg.sonuc = null;
    const onayB = document.getElementById('dg-onizle-onay');
    if (onayB) { onayB.hidden = false; onayB.disabled = false; onayB.style.opacity = ''; onayB.textContent = '↩ Geri Almayı Uygula'; }
    const fg = document.querySelector('#m-dg-onizle .fg');
    if (fg) fg.hidden = false;
    _dgEngelGoster('');
    closeM('m-dg-onizle');
  },
  // ── L4-W2: zincir + rehber + gürültü + sonuç kısayolları ──
  'dg-zincir-oner':           () => { const h = _dg.bekleyen; if (h) dgGeriAlAkisi(h.hedef, 'zincir', h.baglam); },
  'dg-rehber-geri-al':        (el, e) => {
    if (e && e.stopPropagation) e.stopPropagation();
    const k = _dg.rehberHedefler[parseInt(el.dataset.hi, 10)];
    if (k) dgGeriAlAkisi(k.hedef, k.seviye, { olayEtiketi: k.etiket, zaman: '', kim: '' });
  },
  'dg-gurultu-cip':           () => { _dg.gurultu.uydis = !_dg.gurultu.uydis; _dgListeCiz(); },
  'dg-teknik-cip':            () => { _dg.detayTeknik = !_dg.detayTeknik; _dgDetayCiz(); },
  'dg-geri-alinani-geri-al':  () => {
    const tx = _dg.sonuc && _dg.sonuc.txid;
    if (!tx) return;
    dgGeriAlAkisi({ txid: tx }, 'islem', { olayEtiketi: 'Geri alma işlemi', zaman: '', kim: '' });
  },
  'dg-git-degisiklikler':     () => { closeM('m-dg-onizle'); _dg.bekleyen = null; degisikliklerAc(); },
  'dg-git-hayvan':            (el) => { if (el.dataset.hid && typeof openDet === 'function') openDet(el.dataset.hid); },
  'dg-bilet-al':              (el) => degisimBiletAl(el),
  'dg-bilet-enter':           (p) => { if (p.key === 'Enter') { p.event.preventDefault(); degisimBiletAl(document.getElementById('dg-bilet-al-btn')); } },
  'dg-bilet-kapat':           () => closeM('m-dg-bilet'),
  'dg-bilet-birak':           () => { _dgBiletYaz(null); _dgBiletGostergesi(); toast('🔒 Geri alma bileti bırakıldı'); },
});
