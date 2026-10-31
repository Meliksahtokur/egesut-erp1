// ═══════════════════════════════════════════════════════
// hayvan-takip.js — 📌 Hayvan Takip saf yardımcıları (domain-rules §20)
// DOM yazmaz, yalnız string ve veri üretir. Çağrı anında kullandığı globaller:
// config.js (HAYVAN_TAKIP_*), helpers.js (_istanbulGunNo, esc, escAttr, fmtTarih,
// getDisplayKupe, kuceDogalKarsilastir), ui.js (band), errorHandler.js (getUserMessage).
// ═══════════════════════════════════════════════════════

const HT_HATA_METINLERI = {
  HAYVAN_AKTIF_DEGIL: 'Hayvan aktif değil.',
  SEBEP_BOS: 'Sebep seçilmedi.',
  SEBEP_ZATEN_ACIK: 'Bu sebeple zaten takipte',
  ACIKLAMA_GEREKLI: 'Diğer için açıklama gerekli.',
  TARIH_GEREKLI: 'Muayene tarihi gerekli.',
  GECMIS_TARIH: 'Muayene tarihi geçmişte olamaz.',
  BOS_LISTE: 'Kapatılacak takip seçilmedi.',
  FARKLI_HAYVAN: 'Takipler aynı hayvana ait olmalı.',
  VAKA_UYUMSUZ: 'Vaka bu hayvana ait değil.',
  TAKIP_YOK: 'Takip bulunamadı.',
  TAKIP_KAPALI: 'Bu takip kapanmış.',
  GOREV_YOK: 'Muayene görevi bulunamadı.',
  GOREV_TIP_UYUMSUZ: 'Bu görev takip muayenesi değil.',
  GOREV_KAPALI: 'Bu muayene görevi kapanmış.',
  SONUC_GECERSIZ: 'Geçersiz muayene sonucu.',
};

/**
 * Takibin ekranda görünen sebebini verir. Kaçışsızdır; HTML'e basan esc uygular.
 * DIGER açıklamayı, bilinmeyen kod kendisini gösterir (satır gizlenmez).
 * @param {{sebep_kodu:string, aciklama?:string}} takip Takip satırı.
 * @returns {string} Sebep metni.
 */
function htSebepEtiket(takip) {
  const kod = takip?.sebep_kodu;
  const ad = HAYVAN_TAKIP_SEBEPLER.find(s => s.kod === kod)?.ad;
  if (kod === 'DIGER') return String(takip.aciklama || '').trim() || ad;
  return ad || String(kod ?? '');
}

/**
 * Açılıştan bugüne geçen İstanbul takvim günü sayısı (UTC gününe kaymaz).
 * @param {string} acilisIso Açılış zamanı.
 * @param {string} [bugunIso] Başvuru günü; verilmezse şimdi.
 * @returns {number} Gün sayısı; gelecek ya da bozuk girdide 0.
 */
function htGunSayisi(acilisIso, bugunIso) {
  const acilis = _istanbulGunNo(acilisIso);
  const bugun = _istanbulGunNo(bugunIso || new Date().toISOString());
  if (acilis == null || bugun == null) return 0;
  return Math.max(0, bugun - acilis);
}

/**
 * Açık takipleri süzer (kapanis_tarihi boş).
 * @param {Array} takipler hayvan_takip satırları.
 * @param {string} [hayvanId] Verilirse yalnız bu hayvan.
 * @returns {Array} Açık takipler.
 */
function htAcikTakipler(takipler, hayvanId) {
  return (takipler || []).filter(t => !t.kapanis_tarihi && (hayvanId == null || t.hayvan_id === hayvanId));
}

/**
 * Takipleri açılış zamanına göre karşılaştırır (eski önce). Metin değil zaman
 * karşılaştırılır: timestamptz farklı biçimlerde gelebilir.
 * @param {{acilis_tarihi:string}} a Takip.
 * @param {{acilis_tarihi:string}} b Takip.
 * @returns {number} Sıralama değeri.
 */
function _htAcilisKarsilastir(a, b) {
  return Date.parse(a.acilis_tarihi) - Date.parse(b.acilis_tarihi);
}

/**
 * Dashboard satırlarını üretir: yalnız aktif hayvanlar, hayvan başına tek satır;
 * en eski açık takibi olan hayvan üstte, satır içi eski önce, eşitlikte küpe.
 * @param {Array} takipler hayvan_takip satırları.
 * @param {Array} animals hayvanlar satırları.
 * @returns {Array<{hayvan_id:string,kupe:string,sebepler:Array<{takip_id:string,etiket:string,gun:number}>}>} Satırlar.
 */
function htDashSatirlari(takipler, animals) {
  const aktif = new Map((animals || []).filter(a => a.durum === 'Aktif').map(a => [a.id, a]));
  const gruplar = new Map();
  htAcikTakipler(takipler).forEach(t => {
    if (!aktif.has(t.hayvan_id)) return;
    if (!gruplar.has(t.hayvan_id)) gruplar.set(t.hayvan_id, []);
    gruplar.get(t.hayvan_id).push(t);
  });
  return [...gruplar.entries()]
    .map(([hayvanId, liste]) => ({
      hayvanId,
      kupe: getDisplayKupe(aktif.get(hayvanId), hayvanId),
      liste: [...liste].sort(_htAcilisKarsilastir),
    }))
    .sort((x, y) => _htAcilisKarsilastir(x.liste[0], y.liste[0]) || kuceDogalKarsilastir(x.kupe, y.kupe))
    .map(g => ({
      hayvan_id: g.hayvanId,
      kupe: g.kupe,
      sebepler: g.liste.map(t => ({ takip_id: t.id, etiket: htSebepEtiket(t), gun: htGunSayisi(t.acilis_tarihi) })),
    }));
}

/**
 * Dashboard bandını üretir. Kimlik onclick içine değil data özniteliğine yazılır.
 * @param {Array} satirlar htDashSatirlari çıktısı.
 * @returns {string} Band HTML'i; satır yoksa boş metin.
 */
function htBandHtml(satirlar) {
  if (!satirlar || !satirlar.length) return '';
  const ok = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg>';
  const govde = satirlar.map(s => {
    const sebepler = s.sebepler.map(x => `${esc(x.etiket)} · ${x.gun} gün`).join(' | ');
    return `<div class="arow" data-hid="${escAttr(s.hayvan_id)}" onclick="openDet(this.dataset.hid)"><div class="arow-left"><div class="arow-id">${esc(s.kupe)}</div><div class="arow-sub">${sebepler}</div></div>${ok}</div>`;
  }).join('');
  return band('takip', `📌 Takipteki hayvanlar (${satirlar.length})`, govde);
}

/**
 * Takibin açık muayene görevini bulur.
 * @param {Array} gorevler gorev_log satırları.
 * @param {string} takipId Takip kimliği.
 * @returns {Object|undefined} Açık görev.
 */
function _htAcikGorev(gorevler, takipId) {
  return (gorevler || []).find(g => g.gorev_tipi === HAYVAN_TAKIP_GOREV_TIPI && g.ref_takip_id === takipId && !g.tamamlandi && !g.iptal);
}

/**
 * Hayvan kartı gövdesindeki takip listesini üretir: süre ve varsa planlı muayene.
 * @param {Array} acikTakipler Hayvanın açık takipleri.
 * @param {Array} gorevler gorev_log satırları.
 * @returns {string} Blok HTML'i; açık takip yoksa boş metin.
 */
function htKartBlokHtml(acikTakipler, gorevler) {
  if (!acikTakipler || !acikTakipler.length) return '';
  const satirlar = [...acikTakipler].sort(_htAcilisKarsilastir).map(t => {
    const gorev = _htAcikGorev(gorevler, t.id);
    const saat = gorev?.hedef_saat ? ' ' + esc(String(gorev.hedef_saat).slice(0, 5)) : '';
    const muayene = gorev ? ` · 🔍 Muayene: ${esc(fmtTarih(gorev.hedef_tarih))}${saat}` : '';
    return `<div class="ht-kart-satir" style="font-size:.75rem;padding:2px 0">📌 ${esc(htSebepEtiket(t))} · ${htGunSayisi(t.acilis_tarihi)} gün${muayene}</div>`;
  }).join('');
  return `<div class="ht-kart-blok">${satirlar}</div>`;
}

/**
 * Takibi kapat penceresinde hazır işaretli gelecek takipleri verir.
 * @param {Array} acikTakipler Açık takipler.
 * @param {'kart'|'vaka'} baglam Pencerenin açıldığı yer.
 * @returns {string[]} Kimlikler: karttan tek takipte o takip, aksi halde boş.
 */
function htKapatOnSecim(acikTakipler, baglam) {
  return baglam === 'kart' && acikTakipler?.length === 1 ? [acikTakipler[0].id] : [];
}

/**
 * Muayene sonucu penceresinin hazır sonraki tarihi (+3 gün).
 * @param {string} bugunIso 'YYYY-MM-DD' bugün.
 * @returns {string} 'YYYY-MM-DD'.
 */
function htVarsayilanSonrakiTarih(bugunIso) {
  const [y, a, g] = String(bugunIso).slice(0, 10).split('-').map(Number);
  return new Date(Date.UTC(y, a - 1, g + 3)).toISOString().slice(0, 10);
}

/**
 * RPC hatasını kullanıcı metnine çevirir. HT_ kodları getUserMessage'dan ÖNCE
 * çözülür: HT_GECMIS_TARIH orada GECMIS_TARIH erteleme metnine düşerdi.
 * @param {Error|string} err Hata.
 * @returns {string} Kullanıcı metni.
 */
function htHataMetni(err) {
  const kod = /\bHT_[A-Z_]+\b/.exec(err?.message || String(err))?.[0];
  if (!kod) return getUserMessage(err);
  return HT_HATA_METINLERI[kod.slice(3)] || `İşlem reddedildi: ${kod}`;
}
