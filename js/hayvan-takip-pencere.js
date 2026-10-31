// ═══════════════════════════════════════════════════════
// hayvan-takip-pencere.js — 📌 Hayvan Takip pencereleri (domain-rules §20, spec §5.2, §6)
// Takibe al, Muayene planla, Takibi kapat, Muayene sonucu. Yazma yalnız RPC ile.
// Kart tazelemesinin tek yolu pullTables → _detAciksaTazele; burada openDet çağrılmaz.
// Çağrı anında kullanılan globaller: helpers.js (g, cl, esc, escAttr, bugun, toast,
// getDisplayKupe), modal.js (openM, closeM), state.js (getState), api.js (rpc, pullTables,
// idbGetAll), ui.js (loadDash, loadTasks), app.js (_curTaskFilter), config.js,
// hayvan-takip.js (ht* yardımcıları).
// ═══════════════════════════════════════════════════════

const HT_TAZELEME_TABLOLARI = ['hayvan_takip', 'gorev_log', 'islem_log'];
// Ekrandaki veri bayat demektir: uyarı + pencere kapanır + liste tazelenir (spec §6).
const HT_BAYAT_VERI = /\bHT_(HAYVAN_AKTIF_DEGIL|TAKIP_KAPALI|TAKIP_YOK|GOREV_KAPALI|GOREV_YOK)\b/;
let _htKapatBaglam = null; // { baglam:'kart'|'vaka', caseId } — htKapatPencere yazar, htKapatGonder okur

/**
 * Çevrimdışıysa uyarır (spec §6: uyarı çıkar, RPC çağrılmaz).
 * @returns {boolean} Çevrimiçiyse true.
 */
function _htCevrimici() {
  if (navigator.onLine) return true;
  toast('⚠️ İnternet bağlantısı gerekli', true);
  return false;
}

/**
 * Hayvanın başlıkta gösterilecek küpesini verir.
 * @param {string} hayvanId Hayvan kimliği.
 * @returns {string} Küpe; hayvan durumda yoksa kimlik.
 */
function _htKupe(hayvanId) {
  return getDisplayKupe((getState('animals') || []).find(a => a.id === hayvanId), hayvanId);
}

/**
 * Hayvanın açık takiplerini yerel kopyadan, en eskisi önce verir.
 * @param {string} hayvanId Hayvan kimliği.
 * @returns {Promise<Array>} Açık takipler.
 * @tablo hayvan_takip (yerel)
 */
async function _htAciklar(hayvanId) {
  return htAcikTakipler(await idbGetAll('hayvan_takip'), hayvanId)
    .sort((a, b) => Date.parse(a.acilis_tarihi) - Date.parse(b.acilis_tarihi));
}

/**
 * Takibin seçim listelerindeki metni üretir: sebep ve süre. Kaçışlıdır.
 * @param {Object} t Takip satırı.
 * @returns {string} HTML güvenli metin.
 */
function _htSecimMetni(t) {
  return `📌 ${esc(htSebepEtiket(t))} · ${htGunSayisi(t.acilis_tarihi)} gün`;
}

/**
 * Pencereyi açar ve tarih alanını boşaltır: openM boş date alanını bugünle doldurur
 * (utils/modal.js), muayene tarihini kullanıcı bilerek seçmelidir.
 * @param {string} modalId Pencere kimliği.
 * @param {string} [tarihId] Boş kalacak tarih alanı.
 * @returns {void}
 */
function _htPencereAc(modalId, tarihId) {
  openM(modalId);
  if (tarihId) g(tarihId).value = '';
}

/**
 * Listeleri tazeler: tablolar, dashboard, açıksa görev sekmesi. Hata fırlatmaz, yalnız uyarır.
 * @param {string[]} [tablolar] Çekilecek tablolar.
 * @returns {Promise<void>}
 */
async function _htTazele(tablolar = HT_TAZELEME_TABLOLARI) {
  try {
    const sonuc = await pullTables(tablolar);
    // Ağ ve fetcher hatası reddetmez, failed ile çözülür (api.js _pullTablesNow).
    if (sonuc?.failed?.length) toast('⚠️ Liste tazelenemedi', true);
    await loadDash();
    if (getState('currentPage') === 'tasks') await loadTasks(_curTaskFilter || 'today');
  } catch (e) {
    console.warn('⚠️ Hayvan takip tazeleme hatası:', e);
    toast('⚠️ Liste tazelenemedi', true);
  }
}

/**
 * RPC'yi gönderir, başarı ve hata kollarını uygular. Bayat veri hatasında pencere kapanır
 * ve liste tazelenir; çıkmış hayvanda kart da doğru görünsün diye hayvanlar da çekilir.
 * Diğer hatalarda pencere açık kalır, kullanıcı düzeltip yeniden dener.
 * @param {HTMLElement} btn Gönderim düğmesi.
 * @param {string} modalId Pencere kimliği.
 * @param {string} ad RPC adı.
 * @param {Object} params RPC parametreleri.
 * @param {function(Object):string} basariMetni Sonuçtan başarı toast'u; boşsa toast yok.
 * @param {string} [hataOnek] Hata metninin önüne eklenen bağlam.
 * @returns {Promise<void>}
 * @rpc hayvan_takip_ac, hayvan_takip_kapat, hayvan_takip_muayene_planla, hayvan_takip_muayene_sonuc
 */
async function _htGonder(btn, modalId, ad, params, basariMetni, hataOnek = '') {
  // Bütün düğmeler kilitlenir: sonuç penceresinde SURSUN yoldayken KAPANSIN ikinci RPC olurdu.
  const dugmeler = [...g(modalId).querySelectorAll('button')];
  const kilit = acik => dugmeler.concat(btn || []).forEach(d => { d.disabled = !acik; });
  const eskiMetin = btn?.textContent;
  kilit(false);
  if (btn) btn.textContent = 'Kaydediliyor…';
  let sonuc, hata = null;
  try {
    sonuc = await rpc(ad, params);
  } catch (e) {
    hata = e;
  }
  kilit(true);
  if (btn) btn.textContent = eskiMetin;
  if (hata) {
    toast(`⚠️ ${hataOnek}${htHataMetni(hata)}`, true);
    const bayat = HT_BAYAT_VERI.exec(hata?.message || String(hata));
    if (!bayat) return;
    closeM(modalId);
    await _htTazele(bayat[1] === 'HAYVAN_AKTIF_DEGIL' ? ['hayvanlar', ...HT_TAZELEME_TABLOLARI] : HT_TAZELEME_TABLOLARI);
    return;
  }
  closeM(modalId);
  const metin = basariMetni(sonuc);
  if (metin) toast(metin);
  await _htTazele();
}

/**
 * Takibe al penceresini boş formla açar.
 * @param {string} hayvanId Hayvan kimliği.
 * @returns {void}
 */
function htAcPencere(hayvanId) {
  g('ht-ac-hid').value = hayvanId;
  g('ht-ac-title').textContent = `📌 Takibe al — ${_htKupe(hayvanId)}`;
  g('ht-ac-sebep').innerHTML = '<option value="">Sebep seçin…</option>'
    + HAYVAN_TAKIP_SEBEPLER.map(s => `<option value="${escAttr(s.kod)}">${esc(s.ad)}</option>`).join('');
  ['ht-ac-sebep', 'ht-ac-aciklama', 'ht-ac-saat'].forEach(cl);
  _htPencereAc('m-ht-ac', 'ht-ac-tarih');
}

/**
 * Takibi açar. Muayene tarihi doluysa RPC görevi de aynı işlemde açar.
 * @param {HTMLElement} btn Gönderim düğmesi.
 * @returns {Promise<void>}
 * @rpc hayvan_takip_ac
 */
async function htAcGonder(btn) {
  if (!_htCevrimici()) return;
  const sebep = g('ht-ac-sebep').value;
  const aciklama = g('ht-ac-aciklama').value.trim();
  if (!sebep) { toast(`⚠️ ${HT_HATA_METINLERI.SEBEP_BOS}`, true); return; }
  if (sebep === 'DIGER' && !aciklama) { toast(`⚠️ ${HT_HATA_METINLERI.ACIKLAMA_GEREKLI}`, true); return; }
  await _htGonder(btn, 'm-ht-ac', 'hayvan_takip_ac', {
    p_hayvan_id: g('ht-ac-hid').value,
    p_sebep_kodu: sebep,
    p_aciklama: aciklama || null,
    p_muayene_tarihi: g('ht-ac-tarih').value || null,
    p_muayene_saati: g('ht-ac-saat').value || null,
  }, () => '📌 Takibe alındı');
}

/**
 * Muayene planla penceresini açar. Tek takipte takip hazır seçilidir, seçici gizlenir.
 * @param {string} hayvanId Hayvan kimliği.
 * @returns {Promise<void>}
 */
async function htMuayenePencere(hayvanId) {
  const acik = await _htAciklar(hayvanId);
  if (!acik.length) { toast('⚠️ Açık takip yok', true); return; }
  const secici = g('ht-mu-takip');
  secici.innerHTML = '<option value="">Takip seçin…</option>'
    + acik.map(t => `<option value="${escAttr(t.id)}">${_htSecimMetni(t)}</option>`).join('');
  secici.value = acik.length === 1 ? acik[0].id : '';
  g('ht-mu-secici').style.display = acik.length > 1 ? '' : 'none';
  g('ht-mu-title').textContent = `🔍 Muayene planla — ${_htKupe(hayvanId)}`;
  cl('ht-mu-saat');
  _htPencereAc('m-ht-muayene', 'ht-mu-tarih');
}

/**
 * Seçilen takibin muayenesini planlar; açık görev varsa RPC tarihini günceller.
 * @param {HTMLElement} btn Gönderim düğmesi.
 * @returns {Promise<void>}
 * @rpc hayvan_takip_muayene_planla
 */
async function htMuayeneGonder(btn) {
  if (!_htCevrimici()) return;
  const takipId = g('ht-mu-takip').value;
  const tarih = g('ht-mu-tarih').value;
  if (!takipId) { toast('⚠️ Takip seçin', true); return; }
  if (!tarih) { toast(`⚠️ ${HT_HATA_METINLERI.TARIH_GEREKLI}`, true); return; }
  await _htGonder(btn, 'm-ht-muayene', 'hayvan_takip_muayene_planla', {
    p_takip_id: takipId,
    p_tarih: tarih,
    p_saat: g('ht-mu-saat').value || null,
  }, () => '🔍 Muayene planlandı');
}

/**
 * Takibi kapat penceresini açar. Kart: tek takip işaretli. Vaka: hiçbiri işaretli değil
 * ve "Açık kalsın" görünür (K6).
 * @param {string} hayvanId Hayvan kimliği.
 * @param {{baglam:'kart'|'vaka', caseId?:string}} [secenek] Açıldığı yer ve vaka kimliği.
 * @returns {Promise<void>}
 */
async function htKapatPencere(hayvanId, { baglam = 'kart', caseId = null } = {}) {
  const acik = await _htAciklar(hayvanId);
  if (!acik.length) { toast('⚠️ Açık takip yok', true); return; }
  const vaka = baglam === 'vaka';
  _htKapatBaglam = { baglam, caseId };
  const secili = htKapatOnSecim(acik, baglam);
  g('ht-ka-liste').innerHTML = acik.map(t => `<label style="display:flex;align-items:center;gap:8px;padding:6px 0;font-size:.82rem"><input type="checkbox" value="${escAttr(t.id)}"${secili.includes(t.id) ? ' checked' : ''}>${_htSecimMetni(t)}</label>`).join('');
  g('ht-ka-title').textContent = `✓ Takibi kapat — ${_htKupe(hayvanId)}`;
  g('ht-ka-acik-kalsin').style.display = vaka ? '' : 'none';
  g('ht-ka-iptal').style.display = vaka ? 'none' : '';
  cl('ht-ka-not');
  openM('m-ht-kapat');
}

/**
 * Listedeki bütün takipleri işaretler.
 * @returns {void}
 */
function htTumunuSec() {
  g('ht-ka-liste').querySelectorAll('input[type=checkbox]').forEach(k => { k.checked = true; });
}

/**
 * Vaka sonrası soruyu takip kapatmadan bitirir; vaka detayı altta açık kalır.
 * @returns {void}
 */
function htAcikKalsin() {
  closeM('m-ht-kapat');
}

/**
 * İşaretli takipleri kapatır. Başkasının kapattığı satırı RPC atlar (kapanan=0 hata değildir,
 * spec §6). Vaka bağlamında hata yalnız takibi ilgilendirir; vaka kayıtlı kalır.
 * @param {HTMLElement} btn Gönderim düğmesi.
 * @returns {Promise<void>}
 * @rpc hayvan_takip_kapat
 */
async function htKapatGonder(btn) {
  if (!_htCevrimici()) return;
  const ids = [...g('ht-ka-liste').querySelectorAll('input[type=checkbox]')].filter(k => k.checked).map(k => k.value);
  if (!ids.length) { toast(`⚠️ ${HT_HATA_METINLERI.BOS_LISTE}`, true); return; }
  const vaka = _htKapatBaglam?.baglam === 'vaka';
  await _htGonder(btn, 'm-ht-kapat', 'hayvan_takip_kapat', {
    p_takip_ids: ids,
    p_not: g('ht-ka-not').value.trim() || null,
    p_kapatan_vaka_id: vaka ? _htKapatBaglam.caseId : null,
  }, s => (s?.kapanan > 0 ? `✓ ${s.kapanan} takip kapatıldı` : ''), vaka ? 'Vaka kayıtlı, takip kapatılamadı: ' : '');
}

/**
 * Muayene sonucu penceresini açar; sonraki muayene +3 gün hazır gelir.
 * @param {string} gorevId Görev kimliği.
 * @returns {Promise<boolean>} Pencere açıldıysa true; çevrimdışı ya da görev kapalıysa false.
 * @tablo gorev_log (yerel), hayvan_takip (yerel)
 */
async function htSonucAc(gorevId) {
  if (!_htCevrimici()) return false;
  const gorev = (await idbGetAll('gorev_log')).find(x => x.id === gorevId);
  if (!gorev || gorev.tamamlandi || gorev.iptal) {
    toast(`⚠️ ${HT_HATA_METINLERI.GOREV_KAPALI}`, true);
    await _htTazele();
    return false;
  }
  const takip = (await idbGetAll('hayvan_takip')).find(t => t.id === gorev.ref_takip_id);
  g('ht-so-gid').value = gorevId;
  g('ht-so-title').textContent = `🔍 Muayene sonucu — ${_htKupe(gorev.hayvan_id)}`;
  g('ht-so-bilgi').textContent = takip ? `📌 ${htSebepEtiket(takip)}` : (gorev.aciklama || '');
  ['ht-so-saat', 'ht-so-not'].forEach(cl);
  _htPencereAc('m-ht-sonuc', 'ht-so-tarih');
  g('ht-so-tarih').value = htVarsayilanSonrakiTarih(bugun());
  return true;
}

/**
 * Sonucu kaydeder; düğmenin data-sonuc değeri SURSUN ya da KAPANSIN. Kapanışta sonraki
 * muayene alanları hiç gönderilmez. Takip sürerken boş tarih "görev açma" demektir.
 * @param {HTMLElement} btn Gönderim düğmesi.
 * @returns {Promise<void>}
 * @rpc hayvan_takip_muayene_sonuc
 */
async function htSonucGonder(btn) {
  if (!_htCevrimici()) return;
  const sursun = btn.dataset.sonuc === 'SURSUN';
  const params = {
    p_gorev_id: g('ht-so-gid').value,
    p_sonuc: btn.dataset.sonuc,
    p_not: g('ht-so-not').value.trim() || null,
  };
  if (sursun) {
    params.p_sonraki_tarih = g('ht-so-tarih').value || null;
    params.p_sonraki_saat = g('ht-so-saat').value || null;
  }
  await _htGonder(btn, 'm-ht-sonuc', 'hayvan_takip_muayene_sonuc', params,
    () => (sursun ? '🔍 Muayene kaydedildi, takip sürüyor' : '✓ Muayene kaydedildi, takip kapandı'));
}

/**
 * Elle açılan vakadan sonra hayvanın açık takibi varsa kapatma sorusunu açar (K6).
 * Tazeleme başarısızsa yalnız uyarır ve yerel listeyle sorar: kapalı satırı RPC atlar,
 * soruyu hiç sormamak ise kapanması gereken takibi açık bırakır.
 * @param {string} hayvanId Hayvan kimliği.
 * @param {string} caseId Yeni vakanın kimliği.
 * @returns {Promise<void>}
 */
async function htVakaSonrasi(hayvanId, caseId) {
  try {
    const sonuc = await pullTables(['hayvan_takip']);
    if (sonuc?.failed?.includes('hayvan_takip')) toast('⚠️ Takip listesi tazelenemedi', true);
  } catch (e) {
    console.warn('⚠️ Vaka sonrası takip tazeleme hatası:', e);
    toast('⚠️ Takip listesi tazelenemedi', true);
  }
  if (!(await _htAciklar(hayvanId)).length) return;
  await htKapatPencere(hayvanId, { baglam: 'vaka', caseId });
}
