// ══════════════════════════════════════════
// EgeSüt — forms.js
// Tüm form submit fonksiyonları.
// Karmaşık işlemler → rpc() (stored procedure)
// Basit işlemler → write() (offline-first)
// yazIslemLog() KALDIRILDI → DB trigger yapıyor
// ══════════════════════════════════════════

/* global
   _curTaskDet, _curToh, _curHst, _curBildirimTab,
   _editMode, _semptomSecili, _hdeSmptSecili,
   _ilacCache, _drugsCache, _hdiIlacCache,
   _customHekimler, _customSperma, _disFreq,
   HEKIMLER, VARSAYILAN_HEKIM,
   HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SEMPTOM_KAT, SEMPTOM_GENEL,
   getState, setState,
   g, v, cl, dAgo, dFwd, fmtTarih, toast, openM, closeM, trLower,
   db, rpc, pullTables, renderSafe, renderFromLocal,
   idbGetAll, getData, write,
   loadDrugsCache, loadStock, loadDash, loadTasks, loadUreme, loadGecmis,
   loadBildirimler, loadStokPanel, openDet, closeDet, openStokPanel,
   openAnimalEdit, closeAnimalEdit, getDisplayKupe, yasHesapla, loadIrkDropdown,
   erkekKupeUygunMu, hayvanByKupeRef
*/

// ── KÜPE ÇAKIŞMA KONTROLÜ (blur) ────────────
// Küpe uyarıları üç durumlu (spec 2026-09-01 K1/K2):
//   1) aktif çakışma  → ⚠️ engel (submit durdurur, soft YOK)
//   2) geçmiş kullanım → ℹ️ bilgi (dataset.soft=1 — engel değil, recycle mümkün)
//   3) temiz          → uyarı temizlenir
// Uyarı elementinde kalan metin + soft bayrağı submit'lerde _kupeUyarisi ile okunur.
const _kupeUyarisi = el => el?.textContent && el.dataset.soft !== '1';

async function _kupeKontrolEt(alan) {
  const deger = v(alan).trim();
  const warnId = alan + '-warn';
  const warnEl = g(warnId);
  if (!warnEl) return;
  if (!deger) { warnEl.textContent = ''; delete warnEl.dataset.soft; return; }

  const modal  = g('m-animal');
  const editId = modal?.dataset.editId || null;
  // Devlet küpesi GLOBAL teklik (TURKVET, K2) → mesajı ayrı; işletme küpesi
  // (a-kupe/b-kupe) aktif-filtreli → mesajda "aktif hayvan" nitelendirmesi
  const cayismaMesaji = alan === 'a-devlet'
    ? '⚠️ Bu devlet küpesi zaten kayıtlı'
    : '⚠️ Bu küpe zaten kayıtlı (aktif hayvan)';
  try {
    const params = {
      // b-kupe (doğum formu yavru küpesi) da İŞLETME küpesidir
      p_kupe_no:     (alan === 'a-kupe' || alan === 'b-kupe') ? deger : null,
      p_devlet_kupe: alan === 'a-devlet'  ? deger : null,
    };
    if (editId) params.p_hayvan_id = editId;
    const res = await db.rpc('kupe_musait_mi', params);
    // Stale-response guard (openDet'in _detOpenId idiomu): await sırasında alan
    // değiştiyse bu sonucu YAZMA — yeni blur kontrolü zaten yolda
    if (v(alan).trim() !== deger) return;
    if (res.data && res.data.musait === false) {
      warnEl.textContent = cayismaMesaji;
      delete warnEl.dataset.soft;
    } else if (res.data && res.data.kupe_gecmis_id) {
      warnEl.textContent = `ℹ️ Bu numara geçmişte kullanılmış (${res.data.kupe_gecmis_durum || 'çıkmış'}) — yeniden kullanılabilir`;
      warnEl.dataset.soft = '1';
    } else {
      warnEl.textContent = '';
      delete warnEl.dataset.soft;
    }
  } catch (_) {
    // Fail-aware (test-rapor #1): kontrol hatası sessizce 'müsait' SAYILMAZ.
    // Önceki gerçek uyarı korunur; boşsa yumuşak not (soft) düşülür — submit'i
    // engellemez, kullanıcı durumu GÖRÜR; gerekirse alanı düzenleyip tekrar tetikler.
    if (v(alan).trim() === deger && !warnEl.textContent) {
      warnEl.textContent = '⏳ Küpe kontrolü yapılamadı — kayıtta teyit edilir';
      warnEl.dataset.soft = '1';
    }
  }
}

// ── YENİ HAYVAN ─────────────────────────────
async function submitAnimal(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }

  // Küpe çakışma uyarısı varsa durdur (soft not hariç — kontrol hatası/geçmiş kullanım engel değil)
  if (_kupeUyarisi(g('a-devlet-warn')) || _kupeUyarisi(g('a-kupe-warn'))) {
    toast('⚠️ Küpe çakışması var — formu kontrol edin', true); return;
  }

  const modal   = g('m-animal');
  const editId  = modal?.dataset.editId || null;
  const devlet  = v('a-devlet').trim();
  const kupe    = v('a-kupe').trim();
  const irk     = getIrkValue();

  if (!editId && !devlet && !kupe) { toast('Devlet küpesi veya işletme küpesi girin', true); return; }
  const _grup = v('a-grup');
  const _dt   = v('a-dt');
  if (_dt) {
    const _yasGun = Math.floor((Date.now() - new Date(_dt)) / 86400000);
    if (_yasGun < 0) { toast('⚠️ Doğum tarihi ileri tarih olamaz', true); return; }
    if (_grup === 'Süt İçen Buzağı' && _yasGun > 180) {
      toast('⚠️ 6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez', true); return;
    }
    if ((_grup === 'Süt İçen Buzağı' || _grup === 'Sütten Kesilmiş Buzağı') && _yasGun > 365) {
      toast('⚠️ 12 aylıktan büyük hayvan buzağı grubuna eklenemez', true); return;
    }
  }
  // K5 (manuel kayıt): erkek + sayısal + 500-599 dışı → UYARI (engel değil, doğum formundaki sert engel gibi DEĞİL)
  if (!erkekKupeUygunMu(kupe, v('a-cinsiyet'))) {
    toast('⚠️ Erkek hayvan küpesi için 500-599 aralığı önerilir');
  }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }

  try {
    if (editId) {
      // GÜNCELLEME MODU
      await rpc('hayvan_guncelle', {
        p_id:             editId,
        p_kupe_no:        kupe || null,
        p_devlet_kupe:    devlet || null,
        p_irk:            irk || null,
        p_cinsiyet:       v('a-cinsiyet') || null,
        p_dogum_tarihi:   v('a-dt') || null,
        p_grup:           v('a-grup') || null,
        p_padok_id:       v('a-padok') || null,
        p_dogum_kg:       Number.parseFloat(v('a-dkg')) || null,
        p_canli_agirlik:  Number.parseFloat(v('a-agirlik')) || null,
        p_boy:            Number.parseFloat(v('a-boy')) || null,
        p_renk:           v('a-renk') || null,
        p_ayirici_ozellik: v('a-ozellik') || null,
        p_kisir:          document.getElementById('a-kisir')?.checked === true || (document.getElementById('a-kisir')?.checked === false ? false : null),
      });
      // Genç anne statüsü — sadece belirsiz hayvanlarda gösterilir (wrap görünürse uygula)
      const gaEl=document.getElementById('a-genc-anne');
      const gaWrap=document.getElementById('a-genc-anne-wrap');
      if (gaWrap && gaWrap.style.display!=='none' && gaEl) {
        const gv = gaEl.value==='' ? null : (gaEl.value==='true');
        try { await rpc('hayvan_genc_anne_isaretle', { p_hayvan_id: editId, p_genc_anne: gv }); }
        catch(e){ console.warn('genc_anne:', e.message); }
      }
      toast(`✅ ${devlet || kupe} güncellendi`);
      closeAnimalEdit();
      await pullTables(['hayvanlar']);
      await renderFromLocal();
      openDet(editId);
    } else {
      // EKLEME MODU
      // UI Telemetry: hayvan ekle submit
      uiLog('action', 'hayvan_ekle_submit', { kupe_no: kupe || devlet, grup: v('a-grup') });

      const data = await rpc('hayvan_ekle', {
        p_kupe_no:        kupe || null,
        p_devlet_kupe:    devlet || null,
        p_irk:            irk || null,
        p_cinsiyet:       v('a-cinsiyet') || null,
        p_dogum_tarihi:   v('a-dt') || null,
        p_grup:           v('a-grup') || 'Genel',
        p_padok_id:       v('a-padok') || null,
        p_dogum_kg:       Number.parseFloat(v('a-dkg')) || null,
        p_canli_agirlik:  Number.parseFloat(v('a-agirlik')) || null,
        p_boy:            Number.parseFloat(v('a-boy')) || null,
        p_renk:           v('a-renk') || null,
        p_ayirici_ozellik: v('a-ozellik') || null,
      });
      toast(`✅ ${devlet || kupe} eklendi`);
      closeM('m-animal');
      ['a-devlet','a-kupe','a-irk-txt','a-dt','a-dkg','a-agirlik','a-boy','a-renk','a-ozellik'].forEach(cl);
      const cins = g('a-cinsiyet'); if (cins) cins.value = '';
      const sel  = g('a-irk-sel');  if (sel)  sel.value  = '';
      await pullTables(['hayvanlar']);
      await Promise.all([renderFromLocal(), loadIrkDropdown()]);
    }
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = editId ? '💾 Güncelle' : 'Kaydet'; } }
}

// ── DOĞUM ────────────────────────────────────
async function submitBirth(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }

  // Küpe çakışma uyarısı varsa durdur (soft not hariç — b-kupe blur ön kontrolü)
  if (_kupeUyarisi(g('b-kupe-warn'))) {
    toast('⚠️ Küpe çakışması var — formu kontrol edin', true); return;
  }
  const anneId = v('b-anne');
  const tarih  = v('b-tarih');
  const kupe   = v('b-kupe').trim();
  const cins   = v('b-cins');
  const tip    = v('b-tip');
  const kg     = Number.parseFloat(g('b-dogum-kg')?.value || '') || null;
  if (kg !== null && kg < 0) { toast('⚠️ Doğum ağırlığı negatif olamaz', true); return; }
  const baba   = v('b-baba') || v('b-baba-text') || null;
  if (!anneId) { toast('Anne seçilmedi — Gebelerden Seç veya Manuel Gir', true); return; }
  if (!tarih || !kupe) { toast('Doğum Tarihi ve Yavru Küpe zorunlu', true); return; }
  if (tarih > bugun()) { toast('Doğum tarihi ileri tarih olamaz', true); return; }
  // K5: erkek buzağı sayısal küpesi 500-599 aralığında olmalı (dogum_kaydet RPC de zorlar)
  if (!erkekKupeUygunMu(kupe, cins)) {
    toast('⚠️ Erkek buzağı küpesi 500-599 aralığında olmalı', true); return;
  }

  const anne = hayvanByKupeRef(anneId); // K7: küpe eşleşmesinde aktif önce
  if (!anne) { toast(`⚠️ Anne "${anneId}" sürüde bulunamadı`, true); return; }

  // UI Telemetry: doğum submit
  uiLog('action', 'dogum_submit', { anne_id: anne.id, tarih, kupe });

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const data = await rpc('dogum_kaydet', {
      p_anne_id:  anne.id,
      p_tarih:    tarih,
      p_kupe:     kupe,
      p_cins:     cins,
      p_tip:      tip,
      p_kg:       kg,
      p_baba:     baba,
      p_hekim_id: v('b-hekim') || null,
    });

    if (data?.coklu_dogum) {
      toast(`✅ İkiz kaydedildi — ${kupe} bu doğuma ${data.yavru_sirasi}. yavru olarak eklendi (${data.gorev_sayisi ?? 0} görev)`);
    } else {
      toast(`✅ Doğum kaydedildi — ${kupe} sürüye eklendi, ${data?.gorev_sayisi ?? 0} görev oluşturuldu`);
    }
    closeM('m-birth');

    // Formu sıfırla
    const anneEl = g('b-anne'); if (anneEl) anneEl.value = '';
    const anneCard = g('anne-secili-card'); if (anneCard) anneCard.style.display = 'none';
    const gebeBtn = g('btn-gebe-sec'); if (gebeBtn) gebeBtn.style.display = '';
    const anneManual = g('b-anne-manual'); if (anneManual) anneManual.style.display = 'none';
    ['b-kupe','b-dogum-kg','b-baba','b-baba-text'].forEach(id => { const el = g(id); if (el) el.value = ''; });
    const babaAuto = g('b-baba-auto'); if (babaAuto) babaAuto.style.display = 'none';
    const babaText = g('b-baba-text'); if (babaText) babaText.style.display = 'none';
    // Küpe kalıntısı: blur uyarısı + soft bayrak + öneri chip listesi (closeM de yapar — belt & braces)
    const kupeWarn = g('b-kupe-warn'); if (kupeWarn) { kupeWarn.textContent = ''; delete kupeWarn.dataset.soft; }
    const kupeOner = g('b-kupe-oner-list'); if (kupeOner) kupeOner.style.display = 'none';

    if (window.__ileriGebeListesi) {
      window.__ileriGebeListesi = window.__ileriGebeListesi.filter(h => h.hayvan_id !== anne.id);
    }
    pullTables(['hayvanlar','dogum','gorev_log','tohumlama']).then(renderSafe).catch(console.warn);
  } catch (e) {
    toast('❌ Doğum kaydedilemedi: ' + getUserMessage(e), true);
  } finally { if (btn) { btn.disabled = false; btn.textContent = '🐄 Kaydet + Protokol Görevleri'; } }
}

// ── EK UYGULAMA (tohumlama modalı) ──────────
let _ekUygulamalar = [];
let _ekSeciliTur = null;

function ekChipSec(btn) {
  _ekSeciliTur = btn.dataset.tur;
  document.querySelectorAll('.ek-chip').forEach(b => b.classList.remove('aktif'));
  btn.classList.add('aktif');
  document.getElementById('ek-stok-row').style.display = 'flex';
  _ekStokYukle(_ekSeciliTur);
}

async function _ekStokYukle(tur) {
  const tum = await idbGetAll('stok');
  const sel = document.getElementById('ek-stok-sel');
  const esTablo = {
    'GnRH':       ['Diğer İlaç', 'Diger Ilac', 'Hormon'],
    'PG':         ['Diğer İlaç', 'Diger Ilac', 'Hormon'],
    'E Vitamini': ['Vitamin'],
    'B12':        ['Vitamin'],
    'Selenium':   ['Vitamin', 'Diğer İlaç', 'Diger Ilac'],
    'Diğer':      null
  };
  const kategoriler = esTablo[tur] || null;
  const filtreli = kategoriler
    ? tum.filter(s => kategoriler.some(k => (s.kategori||'').toLowerCase().includes(k.toLowerCase())))
    : tum;
  sel.innerHTML = '<option value="">Stoktan seç…</option>' +
    filtreli.map(s => `<option value="${s.id}" data-ad="${esc(s.urun_adi)}" data-birim="${s.birim||'adet'}">${esc(s.urun_adi)} (${s.miktar||0} ${s.birim||'adet'})</option>`).join('');
}

function ekUygulamaEkle() {
  const sel = document.getElementById('ek-stok-sel');
  const doz = parseFloat(document.getElementById('ek-doz').value) || 0;
  const yol = document.getElementById('ek-yol').value;
  const stokId = sel.value;
  const stokAd = sel.options[sel.selectedIndex]?.dataset?.ad || '';
  const birim = sel.options[sel.selectedIndex]?.dataset?.birim || 'ml';

  if (!_ekSeciliTur) { toast('Uygulama türü seçin', true); return; }
  if (doz <= 0) { toast('Doz girin', true); return; }

  _ekUygulamalar.push({ tur: _ekSeciliTur, stok_id: stokId, stok_ad: stokAd, doz, birim, yol });
  _ekListeGoster();

  document.getElementById('ek-doz').value = '';
  document.querySelectorAll('.ek-chip').forEach(b => b.classList.remove('aktif'));
  document.getElementById('ek-stok-row').style.display = 'none';
  _ekSeciliTur = null;
}

function ekUygulama_sil(idx) {
  _ekUygulamalar.splice(idx, 1);
  _ekListeGoster();
}

function _ekListeGoster() {
  const el = document.getElementById('ek-liste');
  if (!_ekUygulamalar.length) { el.style.display = 'none'; return; }
  el.style.display = 'block';
  el.innerHTML = _ekUygulamalar.map((u, i) =>
    `<div style="display:flex;justify-content:space-between;align-items:center;padding:4px 0;border-bottom:1px solid var(--card3);font-size:.75rem">
      <span><b>${esc(u.tur)}</b> ${u.stok_ad ? '– ' + esc(u.stok_ad) : ''} · ${u.doz} ${u.birim} · ${u.yol}</span>
      <button type="button" onclick="ekUygulama_sil(${i})" style="background:none;border:none;color:var(--red2);cursor:pointer;font-size:.85rem">🗑</button>
    </div>`
  ).join('');
}

// ── TOHUMLAMA ────────────────────────────────
async function submitInsem(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid    = v('i-hid');
  const tarih  = v('i-tarih');
  const sperma = v('i-sperma');
  if (!hid || !tarih || !sperma) { toast('Küpe, Tarih ve Sperma zorunlu', true); return; }
  if (tarih > bugun()) { toast('Tohumlama tarihi ileri tarih olamaz', true); return; }

  const hayvan = hayvanByKupeRef(hid); // K7: küpe eşleşmesinde aktif önce
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  // UI Telemetry: tohumlama submit
  uiLog('action', 'tohumlama_submit', { hayvan_id: hayvan.id, tarih });

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const planliGorevId=globalThis._planliTohumlamaGorevId||null;
    const result = await rpc(planliGorevId?'planli_tohumlama_kaydet':'tohumlama_kaydet', {
      ...(planliGorevId?{p_gorev_id:planliGorevId}:{}),
      p_hayvan_id:      hayvan.id,
      p_tarih:          tarih,
      p_sperma:         sperma,
      p_hekim_id:       v('i-hekim') || null,
      p_ek_uygulamalar: _ekUygulamalar,
      p_vwp_override:   globalThis._vwpOverride || false,
    });
    globalThis._vwpOverride = false;
    globalThis._planliTohumlamaGorevId = null;

    toast('✅ Tohumlama kaydedildi + 2 kontrol görevi oluşturuldu');

    // Sorun toggle açıksa bottom sheet aç
    if (globalThis._insemSorunVar) {
      const tohId = result?.tohumlama_id || null;
      const kizId = globalThis._insemKizginlikId || null;
      closeM('m-insem');
      setTimeout(() => sorunBottomSheet(tohId, kizId), 200);
    } else {
      closeM('m-insem');
      globalThis._insemSorunVar = false;
      globalThis._insemKizginlikId = null;
    }
    cl('i-hid'); cl('i-sperma');
    _ekUygulamalar = [];
    _ekListeGoster();
    checkSpermaUyari();
    pullTables(['tohumlama','gorev_log','hayvanlar']).then(() => {
      renderSafe();
      if (typeof updateKizginlikAlert === 'function') updateKizginlikAlert();
      // Kızgınlık sekmesindeyse liste yenilensin
      if (typeof loadUreme === 'function' && window._curUremeTab === 'kizginlik') {
        loadUreme('kizginlik');
      }
    }).catch(console.warn);
  } catch (e) {
    // REVIEW #12: bayat override flag'i sonraki hayvanın submit'ini sessizce geçmesin
    globalThis._vwpOverride = false;
    const msg = e?.message || e?.toString() || '';
    // NOT: ABORT_VWP_VIOLATION alt dize olarak VWP_VIOLATION içerir; abort dalı
    // ÖNCE test edilmezse abort hatası doğum-bazlı dala düşer.
    const abortMatch = msg.match(/ABORT_VWP_VIOLATION:(-?\d+):(\d+)/);
    if (abortMatch) {
      const gun = abortMatch[1];
      const limit = abortMatch[2];
      if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; }
      const ok = confirm(`❗ Abort sonrası VWP dolmadı: ${gun}/${limit} gün.\n\nBu hayvan abort yaptı — yeterli süre geçmemiş.\nYine de kaydetmek istiyor musunuz?`);
      if (ok) {
        globalThis._vwpOverride = true;
        // btn'i aktar — argümansız çağrı tüm if(btn) guard'larını atlıyordu:
        // override RPC'si uçarken buton aktif kalıyor, çift tık = çift kayıt (B13)
        return submitInsem(btn);
      }
      return;
    }
    const vwpMatch = msg.match(/VWP_VIOLATION:(-?\d+):(\d+)/);
    if (vwpMatch) {
      const gun = vwpMatch[1];
      const limit = vwpMatch[2];
      if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; }
      const ok = confirm(`❗ VWP dolmadı: ${gun}/${limit} gün.\n\nDoğumdan sonra yeterli süre geçmemiş.\nYine de kaydetmek istiyor musunuz?`);
      if (ok) {
        globalThis._vwpOverride = true;
        return submitInsem(btn);
      }
      return;
    }
    toast('❌ Tohumlama kaydedilemedi: ' + getUserMessage(e), true);
  } finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet + Kontrol Görevleri'; } }
}

// ── TEKRAR AŞIM ───────────────────────────────
async function submitTekrarAsim(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid    = document.getElementById('tr-hid').value;
  const tarih  = document.getElementById('tr-tarih').value;
  const sperma = document.getElementById('tr-sperma').value;
  if (!hid || !tarih || !sperma) { toast('Tarih ve Sperma zorunlu', true); return; }
  if (tarih > bugun()) { toast('Tarih ileri olamaz', true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('tohumlama_tekrar_kaydet', {
      p_hayvan_id: hid,
      p_tarih:     tarih,
      p_sperma:    sperma,
      p_hekim_id:  document.getElementById('tr-hekim').value || null,
    });
    toast('✅ Tekrar aşım kaydedildi, görevler güncellendi');
    closeM('m-insem-tekrar');
    document.getElementById('tr-hid').value = '';
    document.getElementById('tr-sperma').value = '';
    pullTables(['tohumlama','gorev_log','hayvanlar']).then(() => {
      renderSafe();
      if (typeof loadUreme === 'function' && window._curUremeTab === 'tohumlama') {
        loadUreme('tohumlama');
      }
    }).catch(console.warn);
  } catch (e) {
    toast('❌ Tekrar aşım kaydedilemedi: ' + getUserMessage(e), true);
  } finally { if (btn) { btn.disabled = false; btn.textContent = '🔁 Tekrar Kaydet + Görevleri Güncelle'; } }
}

function openTekrarAsim(hayvanId, kupeNo) {
  document.getElementById('tr-hid').value = hayvanId;
  document.getElementById('tr-kupe-label').textContent = kupeNo;
  document.getElementById('tr-tarih').value = bugun();
  document.getElementById('tr-sperma').value = '';
  document.getElementById('tr-sperma-select').value = '';
  // Hekim: önce i-hekim'den kopyala, boşsa populateHekimSelects ile doldur
  const hekimSel = document.getElementById('tr-hekim');
  const insemHekimSel = document.getElementById('i-hekim');
  if (insemHekimSel && hekimSel && insemHekimSel.innerHTML.trim()) {
    hekimSel.innerHTML = insemHekimSel.innerHTML;
  } else if (typeof populateHekimSelects === 'function') {
    populateHekimSelects();
  }
  openM('m-insem-tekrar');
  // Sperma dropdown'ı otomatik yükle
  if (typeof trSpermaModStok === 'function') trSpermaModStok();
}

// ── KIZGINLIK ────────────────────────────────
async function submitKizginlik(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid   = v('k-hid');
  const tarih = v('k-tarih');
  if (!hid || !tarih) { toast('Küpe ve Tarih zorunlu', true); return; }
  if (tarih > bugun()) { toast('Kızgınlık tarihi ileri tarih olamaz', true); return; }

  const hayvan = hayvanByKupeRef(hid); // K7: küpe eşleşmesinde aktif önce
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const result = await rpc('kizginlik_kaydet', {
      p_hayvan_id: hayvan.id,
      p_tarih:     tarih,
      p_belirti:   v('k-belirti') || null,
      p_notlar:    v('k-notlar') || null,
    });

    // 12 aydan küçük red dönerse rpc() fırlatır; öneri gövdesi e.data'da taşınır
    toast('✅ Kızgınlık kaydedildi');
    closeM('m-kizginlik');
    ['k-hid','k-notlar'].forEach(cl);
    pullTables(['kizginlik_log','gorev_log']).then(() => {
      renderSafe();
      if (typeof updateKizginlikAlert === 'function') updateKizginlikAlert();
    }).catch(console.warn);
  } catch (e) {
    // Backend'in öneri içeren redleri (ör. 12 aydan küçük kızgınlık) öneriyle göster
    if (e?.data?.oneri) { toast(`⚠️ ${e.message} — ${e.data.oneri}`, true); return; }
    toast(getUserMessage(e), true);
  }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; } }
}

// ── VAKA AÇ (CLN-02) ────────────────────────
// diseases dropdown'u DB'den doldur
async function loadDiseasesDropdown() {
  const sel = g('d-disease-id');
  if (!sel) return;
  const list = await idbGetAll('diseases');
  
  // Kızgınlık tedavi akışından geliniyorsa sadece Üreme hastalıklarını göster
  const sadeceUreme = !!globalThis._kizginlikTedaviId;
  const filtrelenmis = sadeceUreme
    ? list.filter(d => (d.category || '').toLowerCase() === 'üreme')
    : list;

  // Kategoriye göre grupla
  const grouped = {};
  filtrelenmis.forEach(d => {
    const cat = d.category || 'Diğer';
    if (!grouped[cat]) grouped[cat] = [];
    grouped[cat].push(d);
  });
  sel.innerHTML = '<option value="">— Hastalık seçin —</option>';
  Object.keys(grouped).sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'})).forEach(cat => {
    const og = document.createElement('optgroup');
    og.label = cat;
    grouped[cat].forEach(d => {
      const o = document.createElement('option');
      o.value = d.id;
      o.textContent = d.name;
      o.dataset.category = d.category || '';
      og.appendChild(o);
    });
    sel.appendChild(og);
  });

  // Sadece Üreme ise info notu ekle
  if (sadeceUreme) {
    // Önceki notu temizle
    const prev = sel.parentNode.querySelector('.kizginlik-info');
    if (prev) prev.remove();
    const info = document.createElement('div');
    info.style.cssText = 'font-size:.68rem;color:var(--ink3);padding:4px 0;text-align:center';
    info.textContent = '🔴 Kızgınlık tedavisi için üreme hastalıkları listeleniyor';
    info.className = 'kizginlik-info';
    sel.parentNode.insertBefore(info, sel.nextSibling);
  }
}

async function onDiseaseSelect() {
  const sel = g('d-disease-id');
  const catEl = g('d-disease-cat');
  const opt = sel?.selectedOptions[0];
  if (opt?.dataset.category) {
    catEl.textContent = '📂 ' + opt.dataset.category;
    catEl.style.display = 'block';
  } else {
    catEl.style.display = 'none';
  }
  await _renderSablonSecim(sel?.value || '');
}

// #63 — seçili hastalığa bağlı şablonları radio liste olarak göster
// G-20260906-TOPLU-VAKA: container-parametrize edildi — varsayılan argümanlar
// m-disease çağrısını birebir korur (blok: <prefix>-sablon-blok, radio adı:
// <prefix>-sablon, seçim hedefi: d→_seciliSablonId / bc→_bcSeciliSablonId).
async function _renderSablonSecim(diseaseId, containerId='d-sablon-list', prefix='d'){
  const blok = g(prefix+'-sablon-blok'); const list = g(containerId);
  if(prefix==='bc') globalThis._bcSeciliSablonId = null;
  else globalThis._seciliSablonId = null;
  if(!blok || !list) return;
  if(!diseaseId){ blok.style.display='none'; list.innerHTML=''; return; }
  const eslem = (await idbGetAll('sablon_hastalik_eslem')).filter(e=>e.disease_id===diseaseId);
  if(!eslem.length){ blok.style.display='none'; list.innerHTML=''; return; }
  const sablonlar = await idbGetAll('tedavi_sablonu');
  const kalemler  = await idbGetAll('tedavi_sablonu_kalem');
  const list2 = eslem.map(e=>sablonlar.find(s=>s.id===e.sablon_id)).filter(Boolean);
  const radyoAd = prefix+'-sablon';
  let html = '';
  list2.forEach(s=>{
    const sk = kalemler.filter(k=>k.sablon_id===s.id);
    const gun = new Set(sk.map(k=>k.gun_no)).size;
    html += `<label style="display:flex;align-items:center;gap:6px;padding:3px 0;font-size:.82rem">
      <input type="radio" name="${radyoAd}" value="${s.id}"> ${esc(s.ad)}
      <span style="color:var(--ink2);font-size:.72rem">${gun} gün · ${sk.length} seans</span></label>`;
  });
  html += `<label style="display:flex;align-items:center;gap:6px;padding:3px 0;font-size:.82rem;color:var(--ink2)">
    <input type="radio" name="${radyoAd}" value="" checked> Şablonsuz (boş vaka aç)</label>`;
  list.innerHTML = html;
  blok.style.display='block';
  list.querySelectorAll(`input[name="${radyoAd}"]`).forEach(r=>{
    r.onchange = () => {
      if(prefix==='bc'){
        globalThis._bcSeciliSablonId = r.value || null;
        // V1.1 karşılıklı dışlama (şablon→ilaç): gerçek bir şablon seçildiyse
        // manuel ilaç seçimi tamamen temizlenir. d-prefix (m-disease) davranışı
        // DOKUNULMAZ — bu dal yalnız bc konteynerine dokunur.
        if(r.value) bcSablonIlacTemizle();
        bcButonEtiketi();
      }
      else globalThis._seciliSablonId = r.value || null;
    };
  });
}

async function submitCase(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid       = v('d-hid');
  const diseaseId = v('d-disease-id');
  if (!hid)       { toast('Hayvan seçilmedi', true); return; }
  if (!diseaseId) { toast('Hastalık seçilmedi', true); return; }

  const hayvan = hayvanByKupeRef(hid); // K7: küpe eşleşmesinde aktif önce
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Açılıyor…'; }
  try {
    const res = await rpc('create_case', {
      p_animal_id:  hayvan.id,
      p_disease_id: diseaseId,
      p_notes:      v('d-case-notes') || null,
    });
    // rpc() hata ve ok:false'te throw eder — create_case başarıda ok:true döner
    // #63 — şablon seçildiyse tek tıkla tüm planı uygula
    const sablonId = globalThis._seciliSablonId;
    if (sablonId && res?.case_id) {
      try {
        const r = await rpc('tedavi_sablon_uygula', { p_case_id: res.case_id, p_sablon_id: sablonId });
        const planli = await rpc('tedavi_sablon_tohumlama_gorev_ekle', { p_case_id: res.case_id, p_sablon_id: sablonId });
        if (r?.atlanan?.length) toast(`⚠️ ${r.atlanan.length} kalem atlandı (silinmiş ilaç)`, true);
        // Şablonda tohumlama var ama hayvan uygun değilse (erkek/12 aydan küçük/gebe)
        // görev sessizce atlanır — kullanıcı nedenini görsün.
        if (planli?.sebep) toast(`ℹ️ Planlı tohumlama görevi açılmadı: ${planli.sebep}`, true);
        toast(`✅ Vaka açıldı + şablon uygulandı (${r?.gun_sayisi||0} gün)${planli?.olustu?' + tohumlama':''}`);
      } catch(e) { toast('Vaka açıldı ama şablon uygulanamadı: '+e.message, true); }
    } else {
      toast('✅ Vaka açıldı');
    }
    globalThis._seciliSablonId = null;
    closeM('m-disease');
    cl('d-hid'); cl('d-case-notes');
    g('d-disease-id').value = '';
    g('d-disease-cat').style.display = 'none';
    { const sb = g('d-sablon-blok'); if (sb) sb.style.display = 'none'; }
    await pullTables(['cases','diseases','drugs','kizginlik_log','islem_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log']);
    _drugsCache = [];
    await loadDrugsCache();
    // Kızgınlık tedavi bağlantısı
    if (globalThis._kizginlikTedaviId && res?.case_id) {
      const kid = globalThis._kizginlikTedaviId;
      globalThis._kizginlikTedaviId = null;
      try {
        await rpc('kizginlik_tedavi_baglanti_kur', {
          p_kayit_id: kid,
          p_case_id:  res.case_id
        });
        toast('🔗 Kızgınlık tedaviye bağlandı');
      } catch (e) {
        toast('⚠️ Kızgınlık-case bağlantısı kurulamadı: ' + e.message, true);
      }
    }
    // Hayvan kartını güncelle + vakayı göster
    if (res?.case_id) {
      await openDet(hayvan.id);
      openCaseDet(res.case_id);
    }
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🏥 Vakayı Aç'; } }
}

// ── TOPLU VAKA (m-bulk-case) — G-20260906-TOPLU-VAKA ──
// Tek küpe yerine çoklu küpe: autocomplete chip + toplu yapıştır.
// Submit akışı W3'te (submitBulkCase); burada form kabuğu + seçim mekaniği.
//
// State sözleşmesi (W3 için):
//   globalThis._bcHayvanlar     → [{id, kupe}] — chip listesi (id dedupe'lu)
//   globalThis._bcSeciliSablonId→ string|null  — bc-sablon-list radio seçimi
//
// V2.1 çoklu gün plan editörü state'i (gün kartları + seans-grup dili):
//   globalThis._bcGunler → [{gun, seanslar}] — 'gun' KULLANICI SEÇİMİDİR
//     (boşluklu plan 1,5 geçerli; 1..31; silme diğer № KORUR). Dizi ASC
//     sıralı. seanslar: [{saat:'HH:MM', ilaclar:{<drugId>:{name, dose,
//     unit, route, legacy, stock_id}}}] — kalem [Seansı Ekle] onayıyla
//     yazılır (draft değil). Detay: plan bölümü başındaki sözleşme.
//   globalThis._bcAktifGunCard → number|null (açık gün kartı)
//   globalThis._bcSeansFormGun → number|null (açık '＋ seans ekle' formu)
function _bcKupeGoster(h){ return h.kupe_no || h.devlet_kupe || h.id; }

// m-bulk-case açılış yükleyicisi — openM hook'u ve 'open-bulk-case' aksiyonu çağırır.
// Hastalık dropdown'u loadDiseasesDropdown ile aynı kaynaktan gruplanır; kızgınlık
// üreme-filtresi (globalThis._kizginlikTedaviId) TOPLU akışa sızdırılmaz.
async function loadBulkCaseForm(){
  globalThis._bcHayvanlar = [];
  globalThis._bcSeciliSablonId = null;
  // V2.1 — gün kartları sıfırlama: TEK gün (№ 1, seanssız); gün 1'in
  // '＋ Bu güne seans ekle' formu AÇIK gelir. Gün № kullanıcı seçimidir;
  // başlık tarihleri bc-tarih'ten hesaplanır (bcPlanRender).
  globalThis._bcGunler = [{ gun: 1, seanslar: [] }];
  globalThis._bcAktifGunCard = 1;
  globalThis._bcSeansFormGun = 1;
  cl('bc-hid'); cl('bc-yapistir'); cl('bc-notes');
  const ac = g('ac-bchid'); if(ac) ac.style.display='none';
  const catEl = g('bc-disease-cat'); if(catEl){ catEl.textContent=''; catEl.style.display='none'; }
  const sb = g('bc-sablon-blok'); if(sb) sb.style.display='none';
  const sl = g('bc-sablon-list'); if(sl) sl.innerHTML='';
  const hn = g('bc-bulunamayan'); if(hn){ hn.textContent=''; hn.style.display='none'; }
  const sonuc = g('bc-sonuc'); if(sonuc){ sonuc.innerHTML=''; sonuc.style.display='none'; }
  const menu = g('bc-gun-ekle-menu'); if(menu) menu.style.display = 'none';
  // V1.2 — tarih + tohumlama sıfırlama: tarih bugün (min bugün — geçmiş seçilemez),
  // saat 08:00, gün 0, kutu kapalı; blok DURUMU (disabled/aktif) bcChipsRender'da kurulur.
  const tEl = g('bc-tarih');
  if(tEl){ tEl.value = bugun(); tEl.min = bugun(); }
  const tohumSaatEl = g('bc-tohum-saat'); if(tohumSaatEl) tohumSaatEl.value = '08:00';
  const tohumGunEl = g('bc-tohum-gun'); if(tohumGunEl) tohumGunEl.value = '0';
  const tohumChkEl = g('bc-tohum'); if(tohumChkEl) tohumChkEl.checked = false;
  bcTohumSaatChipsRender();
  bcTarihIpucuGuncelle();
  if(!(_drugsCache && _drugsCache.length)){ try { await loadDrugsCache(); } catch(_) {} }
  bcPlanRender(); // gün kartları + açık seans formu (ilaç listesi dahil)
  bcChipsRender();
  bcButonEtiketi();
  const sel = g('bc-disease-id');
  if(!sel) return;
  const list = await idbGetAll('diseases');
  const grouped = {};
  list.forEach(d => {
    const kategori = d.category || 'Diğer';
    if (!grouped[kategori]) grouped[kategori] = [];
    grouped[kategori].push(d);
  });
  sel.innerHTML = '<option value="">— Hastalık seçin —</option>';
  Object.keys(grouped).sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'})).forEach(kategori => {
    const og = document.createElement('optgroup');
    og.label = kategori;
    grouped[kategori].forEach(d => {
      const o = document.createElement('option');
      o.value = d.id;
      o.textContent = d.name;
      o.dataset.category = d.category || '';
      og.appendChild(o);
    });
    sel.appendChild(og);
  });
}

// m-bulk-case hastalık seçimi — onDiseaseSelect aynası (bc konteynerleri, bc şablon state'i)
async function bcDiseaseSelect() {
  const sel = g('bc-disease-id');
  const catEl = g('bc-disease-cat');
  const opt = sel?.selectedOptions[0];
  if (opt?.dataset.category) {
    catEl.textContent = '📂 ' + opt.dataset.category;
    catEl.style.display = 'block';
  } else {
    catEl.style.display = 'none';
  }
  await _renderSablonSecim(sel?.value || '', 'bc-sablon-list', 'bc');
}

// Chip mekaniği — _bcHayvanlar id bazlı dedupe'lu, sıra korunur
// V1.2: cinsiyet/dogum_tarihi/durum da taşınır — tohumlama uygunluk ön-kontrolü
// (bcTohumUygunOlmayanlar) ve blok görünürlüğü bu alanlardan okur.
function bcChipEkle(hayvan){
  if(!hayvan?.id) return false;
  globalThis._bcHayvanlar = globalThis._bcHayvanlar || [];
  if(globalThis._bcHayvanlar.some(x=>x.id===hayvan.id)) return false;
  globalThis._bcHayvanlar.push({
    id: hayvan.id,
    kupe: _bcKupeGoster(hayvan),
    cinsiyet: hayvan.cinsiyet ?? null,
    dogum_tarihi: hayvan.dogum_tarihi ?? null,
    durum: hayvan.durum ?? null,
  });
  bcChipsRender();
  return true;
}
function bcChipCikar(id){
  globalThis._bcHayvanlar = (globalThis._bcHayvanlar||[]).filter(x=>x.id!==id);
  bcChipsRender();
}
function bcChipsRender(){
  const kutu = g('bc-chips');
  const sayac = g('bc-sayac');
  const liste = globalThis._bcHayvanlar || [];
  if(kutu){
    kutu.innerHTML = liste.map(h =>
      `<span class="chip chip-g" style="gap:6px">${escAttr(h.kupe)}` +
      `<button type="button" data-action="bc-chip-sil" data-id="${escAttr(h.id)}" aria-label="Çıkar"` +
      ` style="background:none;border:none;color:inherit;font:inherit;font-weight:700;cursor:pointer;padding:0;line-height:1">✕</button></span>`
    ).join('');
  }
  if(sayac) sayac.textContent = liste.length + ' hayvan';
  // V2 — tohumlama bloğu keşfedilebilirliği: blok HER ZAMAN görünür; yalnız
  // duruma göre disabled olur (opacity .5 + pointer-events:none). İşaret
  // durumu KORUNUR — disabled iken kutu tıklanamaz, gizlenince sessizce
  // sıfırlanmaz (eski display:none + silent-uncheck davranışı kaldırıldı).
  const tohumBlok = g('bc-tohum-blok');
  if(tohumBlok){
    const d = bcTohumBlokDurumu(liste);
    tohumBlok.style.opacity = d.mod === 'aktif' ? '' : '.5';
    tohumBlok.style.pointerEvents = d.mod === 'aktif' ? '' : 'none';
    const ipucu = g('bc-tohum-ipucu');
    if(ipucu){
      ipucu.textContent = d.ipucu;
      ipucu.style.color = d.mod === 'disabled-erkek' ? 'var(--red)' : '';
    }
  }
  // V1.1 — chip değişimi buton etiketini de tazeler (manuel↔şablon modu)
  bcButonEtiketi();
}

// Yapıştırma kutusu → token listesi (satır/virgül/noktalı virgül, trim, boş at, dedupe)
function bcKupeParse(metin){
  return [...new Set(String(metin||'').split(/[\n,;]+/).map(t=>t.trim()).filter(Boolean))];
}
// Toplu çözümleme: her token hayvanByKupeRef ile çözülür (K7: aktif öncelikli),
// bulunan chip'e düşer, bulunamayan kırmızı listede. Tümü çözülürse kutu temizlenir.
function bcYapistirCoz(){
  const kutu = g('bc-yapistir');
  const hataKutu = g('bc-bulunamayan');
  const tokenler = bcKupeParse(kutu?.value);
  if(!tokenler.length){ toast('⚠️ Yapıştırma kutusu boş', true); return; }
  const once = (globalThis._bcHayvanlar||[]).length;
  const bulunamayan = [];
  tokenler.forEach(tok=>{
    const h = hayvanByKupeRef(tok);
    if(h) bcChipEkle(h);
    else bulunamayan.push(tok);
  });
  const eklenen = (globalThis._bcHayvanlar||[]).length - once;
  if(hataKutu){
    if(bulunamayan.length){
      hataKutu.textContent = 'Bulunamadı: ' + bulunamayan.join(', ');
      hataKutu.style.display = 'block';
    } else {
      hataKutu.textContent = '';
      hataKutu.style.display = 'none';
    }
  }
  if(bulunamayan.length){
    toast(`⚠️ ${eklenen} hayvan eklendi, ${bulunamayan.length} bulunamadı`, true);
  } else {
    if(kutu) kutu.value = '';
    toast(`✅ ${eklenen} hayvan eklendi`);
  }
}

// ── TOPLU VAKA TARİH + TOHUMLAMA (V1.2) ──────────────────────────────
// RPC v3 sözleşmesi (W7): vaka_toplu_ac(..., p_tarih, p_tohumlama,
// p_tohumlama_gun_offset, p_tohumlama_saat). p_tarih planlanan başlangıç —
// şablon/manuel günler ve tohumlama anchor'u ona oturur; NULL = bugün.
// p_tohumlama HER AÇILAN vaka için işlenir; sonucu acilan[i].tohumlama =
// {olustu:true, gorev_id} | {olustu:false, sebep}. Sunucu sebep cümleleri
// birebir: 'Erkek hayvana tohumlama görevi açılmaz',
// 'Hayvan hedef tarihte 12 aydan küçük', 'Hayvan gebe',
// 'Bu vakada zaten açık bir planlı tohumlama var'.

// YYYY-MM-DD → Date.UTC gün sayısı (TZ-safe; new Date(string) KULLANMA —
// yerel saat dilimi kaydırması 365 gün sınırını 1 güne kaydırabilir).
function _bcUtcGun(t){
  const p = String(t || '').split('-').map(Number);
  if(p.length !== 3 || p.some(x => !Number.isFinite(x))) return null;
  return Date.UTC(p[0], p[1] - 1, p[2]) / 86400000;
}

// Geçmiş plan tarihi mi? YYYY-MM-DD string karşılaştırması yeterli (sıralı biçim).
// Boş/null → false: doğrulama yok, NULL=bugün kararı sunucunun.
function bcGecmisPlanTarihiMi(tarihStr, bugunStr){
  if(!tarihStr) return false;
  return String(tarihStr) < String(bugunStr);
}

// Tohumlama uygunluk ön-kontrolü — sunucu kural aynası (bcTohumUygunOlmayanlar):
//   durum!=='Aktif'                 → 'Hayvan aktif değil'
//   cinsiyet==='Erkek'              → 'Erkek hayvana tohumlama görevi açılmaz'
//   hedefte yaş < 365 gün           → 'Hayvan hedef tarihte 12 aydan küçük'
// Gebe istisnası İSTEMCİDE YOK (sunucu teyitli — onay metninde belirtilir).
// dogum_tarihi null ise yaş kuralı atlanır (sunucu paritesi). Saf, DOM'suz.
function bcTohumUygunOlmayanlar(hayvanlar, hedefTarihStr){
  const hedefGun = _bcUtcGun(hedefTarihStr);
  return (hayvanlar || []).filter(h => {
    if(!h?.id) return false;
    if(h.durum !== 'Aktif') return true;
    if(h.cinsiyet === 'Erkek') return true;
    const dGun = _bcUtcGun(h.dogum_tarihi);
    if(dGun !== null && hedefGun !== null && (hedefGun - dGun) < 365) return true;
    return false;
  }).map(h => ({
    id: h.id,
    kupe: h.kupe,
    sebep: h.durum !== 'Aktif' ? 'Hayvan aktif değil'
      : h.cinsiyet === 'Erkek' ? 'Erkek hayvana tohumlama görevi açılmaz'
      : 'Hayvan hedef tarihte 12 aydan küçük',
  }));
}

// Tohumlama hedef tarihi: p_tarih (+ gün ofseti); p_tarih null → bugün.
// Yalnız submit/uyarı yolunda kullanılır (dFwd/bugun runtime global'leri).
function bcTohumHedefTarih(tarihStr, gun){
  return dFwd(tarihStr || bugun(), Math.max(0, Number(gun) || 0));
}

// V2 — tohumlama bloğu DURUMU (saf, DOM'suz): blok daima görünür; bu fonksiyon
// yalnız disabled/aktif modunu ve dinamik ipucu metnini üretir. Uygulayıcı
// bcChipsRender (opacity/pointer-events + bc-tohum-ipucu rengi):
//   disabled-bos   → seçim yok; 'Hayvan seçince aktifleşir'
//   disabled-erkek → tümü Erkek; kırmızı uyarı, hâlâ disabled
//   aktif          → orijinal uygunluk ipucu, tam opaklık
function bcTohumBlokDurumu(hayvanlar){
  const liste = hayvanlar || [];
  if(!liste.length) return { mod: 'disabled-bos', ipucu: 'Hayvan seçince aktifleşir' };
  if(liste.every(h => h.cinsiyet === 'Erkek')){
    return { mod: 'disabled-erkek', ipucu: 'Seçili hayvanların tümü erkek — tohumlama uygulanamaz' };
  }
  return {
    mod: 'aktif',
    ipucu: 'Erkek, 12 aydan küçük ve gebe hayvanlara tohumlama açılmaz — bunlar sebebiyle listede atlanır. Şablonun kendi tohumlama planı varsa o geçerli olur.',
  };
}

// bc-tarih ipucu: ileri tarih seçildiyse planlama cümlesi, aksi halde varsayılan.
function bcTarihIpucuGuncelle(){
  const ipucu = g('bc-tarih-ipucu');
  if(!ipucu) return;
  const t = (v('bc-tarih') || '').trim();
  ipucu.textContent = t
    ? `Vaka ve tüm tedavi günleri ${t} gününe planlanacak`
    : 'Tarih boş bırakılırsa vakalar bugün açılır.';
}

// HIZLI_SAATLER çipleri (config.js) — ek-chip deseni, bc-tohum-saat'i doldurur.
function bcTohumSaatChipsRender(){
  const kutu = g('bc-tohum-saat-chips');
  if(!kutu) return;
  const saatler = (typeof HIZLI_SAATLER !== 'undefined' && HIZLI_SAATLER) || ['08:00', '16:00', '20:00'];
  kutu.innerHTML = saatler.map(t =>
    `<button type="button" class="ek-chip" data-action="bc-tohum-saat-chip" data-t="${t}">${t}</button>`
  ).join('');
}

// ── TOPLU VAKA MANUEL TEDAVİ PLANI (V1.1 → V2.1 GÜN KARTLARI) ─────────
// V2.1 (sahibe beyin fırtınası, 2026-09-06): plan editörü m-sablon builder
// + seans planlayıcı diline taşındı — ÜST ÜSTE KATLANABİLİR GÜN KARTLARI
// (boşluklu "Başlangıçtan gün" № girişi + takvimden gün ekleme) ve SEANS
// GRUP DİLİ (bir günde çoklu seans; her seansın kendi saati; aynı ilaç
// farklı seanslarda geçerli). Eski gün sekmeleri + gün saati + düz ilaç
// listesi KALDIRILDI; ilaç seçimi artık her gün kartının içindeki
// "＋ Bu güne seans ekle" formunda (caseSeansEkleFormAc/sablonSeansAc
// dili: saat girişi + HIZLI_SAATLER çipleri + gruplu cdf-chk listesi +
// doz satırları + [Seansı Ekle]; form AÇIK kalır — seans A/B akışı).
// Gün kopyalama İKİSİ BİRDEN: [+ Gün ▾] → 'Önceki günden' menü öğesi ve
// kart altı '📋 Günü Kopyala → Gün № [Uygula]'.
//
// Plan state:
//   globalThis._bcGunler → [{gun: <int 1..31>, seanslar: [{saat:'HH:MM',
//     ilaclar: {<drugId>: {name, dose, unit, route, legacy, stock_id}}}]}]
//   — 'gun' ARTIK KULLANICI SEÇİMİDİR (boşluklu plan 1,5 geçerli —
//   m-sablon builder offset dilinin bc uyarlaması; silme DİĞER
//   numaraları KORUR, renumber yok). Dizi ASC sıralı tutulur; kalem
//   [Seansı Ekle] onayıyla state'e yazılır (draft değil).
//   globalThis._bcAktifGunCard → number|null (açık gün kartı)
//   globalThis._bcSeansFormGun → number|null (açık "＋ seans ekle" formu)
//
// RPC v4 sözleşmesi DEVAM (gün-keyed p_items) ama saat düzlemi değişti:
//   [{gun: 1..31, kalemler: [{drug_product_id, stok_id, dose>0, unit,
//   route?, saat}]}] — kalem.saat HER ZAMAN seans saatidir (aynı ilacın
//   A/B seansları sunucuda ayrı planned_time'lı uygulamalara düşer);
//   gün-düzlemi 'saat' alanı GÖNDERİLMEZ. p_items ile p_sablon_id
//   birbirini dışlar (karşılıklı dışlama UI'da birebir korunur).
// acilan[i].manuel = {gun_sayisi, seans_sayisi} — submit akışı değişmedi.

// ═══ V2.1 SAF BİRİMLER (DOM'suz — vaka-toplu-ac.test.js yeşil kilidi) ═══

// Gün № düzenleme doğrulaması: tam sayı 1..31 + mevcut başka günle
// çakışmama (gi = düzenlenen günün index'i — kendisiyle çakışma sayılmaz).
// Başarısızlık mesajları builder diliyle birebir: aralık + teklik.
function bcGunNoKontrol(gunler, gi, yeniGun){
  const n = Number(yeniGun);
  if(!Number.isInteger(n) || n < 1 || n > 31) return { ok: false, mesaj: 'Gün 1-31 aralığında bir tam sayı olmalı' };
  if((gunler || []).some((g, i) => i !== gi && g.gun === n)) return { ok: false, mesaj: 'Aynı gün zaten var; seansları o günün altında toplayın' };
  return { ok: true, mesaj: null };
}

// Gün kopyalama saf özü: kaynak günün seanslarını hedefe kopyalar. Hedef
// VARSa seanslarını DEĞİŞTİRİR (olusturuldu:false), YOKSA oluşturur
// (true). Sonuç ASC sıralı YENİ dizidir — girdi MUTASYONLANMAZ, seanslar
// deep-copy'dir. Geçersiz girdi (kaynak yok / hedef===kaynak / hedef
// 1..31 dışı) → null. Boş seanslı kaynak da kopyalanır (saf semantiği
// total; boş-kaynak UI politikası bcGunKopyalaUygula'da).
function bcGunKopyala(gunler, kaynakGun, hedefGun){
  const liste = gunler || [];
  const src = liste.find(g => g.gun === kaynakGun);
  const hedef = Number(hedefGun);
  if(!src || !Number.isInteger(hedef) || hedef < 1 || hedef > 31 || hedef === kaynakGun) return null;
  const seanslar = JSON.parse(JSON.stringify(src.seanslar || []));
  const olusturuldu = !liste.some(g => g.gun === hedef);
  const yeni = liste
    .filter(g => g.gun !== hedef)
    .concat([{ gun: hedef, seanslar }])
    .sort((a, b) => a.gun - b.gun);
  return { gunler: yeni, olusturuldu };
}

// Takvimden gün ekleme saf özü: ISO tarih listesini başlangıç tarihine
// göre gün numaralarına çevirir. Başlangıçtan ÖNCEKİ tarihler
// filtrelenir; dedupe + ASC; gün = UTC gün farkı + 1. Başlangıç
// geçersizse [] (TZ-safe aritmetik — _bcUtcGun ile, new Date(string) yok).
function bcTakvimdenGunler(dates, startDateStr){
  const bas = _bcUtcGun(startDateStr);
  if(bas === null) return [];
  return [...new Set(dates || [])]
    .map(d => ({ d, g: _bcUtcGun(d) }))
    .filter(x => x.g !== null && x.g >= bas)
    .sort((a, b) => a.g - b.g)
    .map(x => x.g - bas + 1);
}

// Gün kartı başlık tarihi: bc-tarih + (gun-1) → 'GG AyUzun'. bc-tarih
// boşsa bugün (NULL=bugün sunucu kararıyla paralel). UTC aritmetik.
function _bcGunTarihEtiketi(gun, tarihStr){
  const p = String(tarihStr || '').split('-').map(Number);
  const bas = (p.length === 3 && p.every(x => Number.isFinite(x))) ? p : bugun().split('-').map(Number);
  const d = new Date(Date.UTC(bas[0], bas[1] - 1, bas[2] + (Number(gun) || 1) - 1));
  return String(d.getUTCDate()).padStart(2, '0') + ' ' + d.toLocaleString('tr-TR', { month: 'long', timeZone: 'UTC' });
}

// ═══ V2.1 GÜN KARTLARI — RENDER (m-sablon builder _renderSablonBuilder
// dili: üst üste katlanabilir kartlar, son kart açık) ═══

// Planı bc-plan-gunler'e çizer. Başlık tarihleri bc-tarih'ten HESAPLANIR
// (Gün N = tarih + N−1) — tarih veya gün № her değiştiğinde yeniden çizilir.
function bcPlanRender(){
  const kutu = g('bc-plan-gunler');
  if(!kutu) return;
  const gunler = globalThis._bcGunler || [];
  const tarihStr = (v('bc-tarih') || '').trim() || bugun();
  kutu.innerHTML = gunler.map(gn => _bcGunKartiHtml(gn, tarihStr)).join('');
  bcButonEtiketi();
}

// Tek gün kartı html'i — başlık '▾/▸ Gün N · GG Ay' + seans sayacı + 🗑
// (silme diğer gün № KORUR); gövdede 'Başlangıçtan gün' № girişi
// (bc-gno-<gun>, 1..31), seans blokları (⏰ Seans · SS:DD + kalem satırları),
// katlı '＋ Bu güne seans ekle' formu ve '📋 Günü Kopyala → Gün №' şeridi.
function _bcGunKartiHtml(gn, tarihStr){
  const gun = gn.gun;
  const seanslar = gn.seanslar || [];
  const ilacSayi = seanslar.reduce((n, s) => n + Object.keys(s.ilaclar || {}).length, 0);
  const acik = globalThis._bcAktifGunCard === gun;
  return `
  <div style="margin:6px 0;padding:8px 10px;background:var(--card);border:1px solid var(--card3);border-radius:8px">
    <div style="display:flex;justify-content:space-between;align-items:center;cursor:pointer" data-action="bc-gun-toggle" data-gun="${gun}">
      <strong style="font-size:.82rem">${acik ? '▾' : '▸'} Gün ${gun} · ${escAttr(_bcGunTarihEtiketi(gun, tarihStr))}</strong>
      <span style="font-size:.72rem;color:var(--ink2);display:flex;align-items:center;gap:2px">
        <span id="bc-gsayac-${gun}">${seanslar.length} seans · ${ilacSayi} ilaç</span>
        <button type="button" data-action="bc-gun-sil" data-gun="${gun}" title="Günü sil (diğer gün numaraları korunur)" style="background:none;border:none;color:var(--red);cursor:pointer">🗑️</button>
      </span>
    </div>
    <div id="bc-ggovde-${gun}" style="display:${acik ? 'block' : 'none'};margin-top:6px">
      <label style="display:flex;align-items:center;gap:7px;font-size:.76rem;color:var(--ink2);margin:4px 0 7px">Başlangıçtan gün
        <input id="bc-gno-${gun}" class="fi" type="number" min="1" max="31" step="1" value="${gun}" data-change="bc-gun-no" data-gun="${gun}" style="width:75px;margin:0;padding:5px 7px"></label>
      <div id="bc-gseanslar-${gun}">${_bcSeansHtml(gn)}</div>
      <button type="button" class="btn-sm" data-action="bc-seans-form-ac" data-gun="${gun}" style="margin-top:4px;font-size:.78rem;font-weight:700;padding:7px 12px;background:rgba(42,107,181,.1);color:var(--blue);border:1px dashed rgba(42,107,181,.4);border-radius:7px;cursor:pointer;width:100%">＋ Bu güne seans ekle</button>
      <div id="bc-gseansform-${gun}">${globalThis._bcSeansFormGun === gun ? _bcSeansFormHtml(gun) : ''}</div>
      <div style="display:flex;align-items:center;gap:6px;margin-top:8px;padding-top:7px;border-top:1px solid var(--card3);font-size:.74rem;color:var(--ink2);flex-wrap:wrap">
        📋 Günü Kopyala → Gün №
        <input id="bc-gkopya-${gun}" class="fi" type="number" min="1" max="31" placeholder="örn. ${gun + 1}" style="width:74px;margin:0;padding:4px 7px">
        <button type="button" class="btn-sm" data-action="bc-gun-kopyala" data-gun="${gun}" style="font-weight:700;padding:6px 11px;background:rgba(78,154,42,.12);color:var(--green);border:1px solid rgba(78,154,42,.35);border-radius:7px;cursor:pointer">Uygula</button>
      </div>
    </div>
  </div>`;
}

// Bir günün seans blokları — '⏰ Seans · SS:DD' başlığı + 🗑 seans; kalem
// satırları '💊 <ad> <doz> <birim> · <yol> 🗑'. Aynı ilaç farklı seanslarda
// (farklı saat) GEÇERLİ — saat-grup dilinin özü.
function _bcSeansHtml(gn){
  const gun = gn.gun;
  return (gn.seanslar || []).map((s, si) => `
    <div style="border:1px solid var(--card3);border-radius:8px;padding:6px 8px;margin-bottom:5px;background:var(--card2)">
      <div style="display:flex;align-items:center;gap:8px">
        <strong style="font-size:.78rem;color:var(--ink2)">⏰ Seans · ${escAttr(s.saat)}</strong>
        <button type="button" data-action="bc-seans-sil" data-gun="${gun}" data-si="${si}" title="Seansı sil" style="margin-left:auto;background:none;border:none;color:var(--red);cursor:pointer">🗑️</button>
      </div>
      ${(s.ilaclar && Object.keys(s.ilaclar).length) ? Object.keys(s.ilaclar).map(id => {
        const k = s.ilaclar[id] || {};
        return `<div style="display:flex;align-items:center;gap:8px;padding:3px 0 3px 6px;font-size:.78rem">
          <span style="flex:1">💊 ${escAttr(k.name || id)} <span style="color:var(--ink3);font-size:.7rem">${escAttr(k.dose)} ${escAttr(k.unit)}${k.route ? ' · ' + escAttr(k.route) : ''}</span></span>
          <button type="button" data-action="bc-kalem-sil" data-gun="${gun}" data-si="${si}" data-id="${escAttr(id)}" title="Kalemi çıkar" style="background:none;border:none;color:var(--red);cursor:pointer">🗑️</button>
        </div>`;
      }).join('') : '<div style="font-size:.72rem;color:var(--ink3);padding:2px 0 2px 6px">Bu seansta ilaç yok</div>'}
    </div>`).join('');
}

// Cerrahi tazeleme: [Seansı Ekle] sonrası KARTI baştan kurmadan seans
// listesini + başlık sayacını günceller — açık seans formunun draft'ı
// (işaretli kutular + doz girişleri) KORUNUR, yalnız saat sıfırlanır
// (seans A → saat değiştir → seans B akışı).
function _bcSeanslariCiz(gun){
  const gunObj = (globalThis._bcGunler || []).find(g => g.gun === gun);
  const kutu = g('bc-gseanslar-' + gun);
  if(!gunObj || !kutu) return;
  kutu.innerHTML = _bcSeansHtml(gunObj);
  const seanslar = gunObj.seanslar || [];
  const ilacSayi = seanslar.reduce((n, s) => n + Object.keys(s.ilaclar || {}).length, 0);
  const sayac = g('bc-gsayac-' + gun);
  if(sayac) sayac.textContent = seanslar.length + ' seans · ' + ilacSayi + ' ilaç';
}

// Katlı '＋ seans ekle' formu — sablonSeansAc/caseSeansEkleFormAc dili:
// saat girişi (varsayılan 09:00) + HIZLI_SAATLER çipleri + gruplu ilaç
// checkbox listesi + doz satırları + [Seansı Ekle]/Vazgeç.
function _bcSeansFormHtml(gun){
  const saatler = (typeof HIZLI_SAATLER !== 'undefined' && HIZLI_SAATLER) || ['08:00', '16:00', '20:00'];
  const chips = saatler.map(t => `<button type="button" class="ek-chip" data-action="bc-saat-chip" data-t="${t}">${t}</button>`).join('');
  return `
  <div style="border:1px dashed var(--card3);border-radius:10px;padding:10px;margin-top:6px;background:var(--card2)">
    <div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">⏰ Yeni Seans — Saat</div>
    <div style="display:flex;gap:5px;align-items:center;flex-wrap:wrap;margin-bottom:8px">
      <input id="bc-gsaat" class="fi" type="time" value="09:00" style="margin:0;flex:1;min-width:100px">${chips}
    </div>
    <div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">İlaç Seç (çoklu — bu saatte uygulanacak)</div>
    <div style="max-height:200px;overflow-y:auto;background:var(--card);border-radius:8px;padding:8px;margin-bottom:8px;border:1px solid var(--card3)">${_bcSeansDrugGruplariHtml()}</div>
    <div id="bc-sdoz-alani" style="display:none">
      <div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Seçili İlaçlar — Doz Gir</div>
      <div id="bc-sdoz-satirlar"></div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px">
      <button type="button" class="btn-sm" data-action="bc-seans-ekle" data-gun="${gun}" style="background:var(--green);color:#fff;border:none;border-radius:7px;padding:9px;font-weight:700;cursor:pointer">＋ Seansı Ekle</button>
      <button type="button" class="btn-sm" data-action="bc-seans-vazgec" style="background:var(--card3);border:none;border-radius:7px;padding:9px;cursor:pointer">Vazgeç</button>
    </div>
  </div>`;
}

// Seans formunun gruplu ilaç listesi — bcIlacListesiRender dilinin
// (caseDrugFormAc aynası) seans formu uyarlaması: bc-schk checkbox'ları,
// stok renkli kalan, etken madde satırı.
function _bcSeansDrugGruplariHtml(){
  const cache = _drugsCache || [];
  const groups = {};
  [...cache].sort((a, b) => a.name.localeCompare(b.name, 'tr')).forEach(d => {
    const grp = d.group_name || 'Diger';
    (groups[grp] = groups[grp] || []).push(d);
  });
  return Object.keys(groups).sort((a, b) => a.localeCompare(b, 'tr', { sensitivity: 'base' })).map(grp => {
    const items = groups[grp].map(d => {
      const stokClrPos = d.guncel <= 0 ? 'var(--red)' : d.guncel <= 10 ? 'var(--amber)' : 'var(--green)';
      const stokClr = d.guncel === null ? 'var(--ink3)' : stokClrPos;
      const stokTxt = d.guncel !== null ? d.guncel.toFixed(1) + ' ' + d.birim : 'stok yok';
      const nm = d.name.replace(/"/g, '&quot;');
      const rt = (d.default_route || 'IM').split(' ')[0];
      return '<label class="bc-ilac-satir" style="display:flex;align-items:center;gap:8px;padding:5px 2px;cursor:pointer">' +
        '<input type="checkbox" class="bc-schk" data-id="' + d.id + '" data-name="' + nm + '" data-unit="' + (d.default_unit || d.birim || 'ml') + '" data-route="' + rt + '" data-legacy="' + (d._legacy || false) + '"' +
        ' onchange="bcSeansChkChange(this)" style="width:18px;height:18px;accent-color:var(--green);flex-shrink:0;cursor:pointer">' +
        '<div style="flex:1;min-width:0"><div style="font-size:.82rem;font-weight:600;color:var(--ink)">' + d.name + '</div>' +
        (d.active_ingredient ? '<div style="font-size:.65rem;color:var(--ink3)">' + d.active_ingredient + '</div>' : '') +
        '</div><span style="font-size:.72rem;font-weight:700;color:' + stokClr + ';flex-shrink:0">' + stokTxt + '</span></label>';
    }).join('');
    return '<div class="bc-ilac-grup" style="margin-bottom:8px"><div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px;padding:3px 0;border-bottom:1px solid var(--card3)">' + grp + '</div>' + items + '</div>';
  }).join('') || '<div style="color:var(--ink3);font-size:.78rem;padding:8px">Stokta ilaç yok</div>';
}

// ═══ V2.1 [+ Gün ▾] MENÜSÜ ═══

function bcGunEkleMenuToggle(){
  const menu = g('bc-gun-ekle-menu');
  if(menu) menu.style.display = menu.style.display === 'block' ? 'none' : 'block';
}
function bcGunEkleMenuKapat(){
  const menu = g('bc-gun-ekle-menu');
  if(menu) menu.style.display = 'none';
}

// ＋ Boş gün: sıradaki ardışık № (maks+1 — builder sablonGunEkle dili).
function bcGunEkleBos(){
  const gunler = globalThis._bcGunler || (globalThis._bcGunler = []);
  if(gunler.length >= 31){ toast('⚠️ En fazla 31 gün', true); return; }
  const yeni = gunler.reduce((m, g) => Math.max(m, g.gun), 0) + 1;
  gunler.push({ gun: yeni, seanslar: [] });
  gunler.sort((a, b) => a.gun - b.gun);
  globalThis._bcAktifGunCard = yeni;
  bcPlanRender();
}

// 📋 Önceki günden: açık kartın (yoksa en büyük №'lu günün) seanslarını
// taşıyan yeni gün — bcGunKopyala saf özü üzerinden.
function bcGunEkleOncekiGunden(){
  const gunler = globalThis._bcGunler || (globalThis._bcGunler = []);
  if(gunler.length >= 31){ toast('⚠️ En fazla 31 gün', true); return; }
  const maks = gunler.reduce((m, g) => Math.max(m, g.gun), 0);
  const kaynakGun = (globalThis._bcAktifGunCard && gunler.some(g => g.gun === globalThis._bcAktifGunCard))
    ? globalThis._bcAktifGunCard : maks;
  const hedef = maks + 1;
  const r = bcGunKopyala(gunler, kaynakGun, hedef);
  if(!r){ bcGunEkleBos(); return; }
  globalThis._bcGunler = r.gunler;
  globalThis._bcAktifGunCard = hedef;
  bcPlanRender();
  toast('📋 Gün ' + kaynakGun + ' → Gün ' + hedef + ' kopyalandı (oluşturuldu)');
}

// ═══ V2.1 GÜN KARTI İŞLEMLERİ ═══

// Kart başlığı: tek kart açılır (builder gibi); açık karta tekrar dokunuş kapatır.
function bcGunToggle(gun){
  globalThis._bcAktifGunCard = globalThis._bcAktifGunCard === gun ? null : gun;
  bcPlanRender();
}

// 🗑: gün kartını siler — DİĞER gün numaraları KORUNUR (boşluklu plan
// geçerlidir; renumber YOK). Son gün silinirse editör tek boş gün 1 ile
// devam eder. Silinen gün açıksa kart/form durumu temizlenir.
function bcGunSil(gun){
  const gunler = globalThis._bcGunler || [];
  const idx = gunler.findIndex(g => g.gun === gun);
  if(idx < 0) return;
  gunler.splice(idx, 1);
  if(!gunler.length) gunler.push({ gun: 1, seanslar: [] });
  if(globalThis._bcAktifGunCard === gun) globalThis._bcAktifGunCard = null;
  if(globalThis._bcSeansFormGun === gun) globalThis._bcSeansFormGun = null;
  bcPlanRender();
}

// 'Başlangıçtan gün' № değişimi (bc-gno-<gun>): doğrula (1..31 + teklik —
// değilse builder mesajı + revert), ASC yeniden sırala; başlık tarihleri
// yeni № ile yeniden hesaplanır (bcPlanRender).
function bcGunNoDegisti(el){
  const eskiGun = Number(el && el.dataset ? el.dataset.gun : NaN);
  const gunler = globalThis._bcGunler || [];
  const gi = gunler.findIndex(g => g.gun === eskiGun);
  if(gi < 0){ bcPlanRender(); return; }
  const kontrol = bcGunNoKontrol(gunler, gi, el.value);
  if(!kontrol.ok){ toast('⚠️ ' + kontrol.mesaj, true); bcPlanRender(); return; }
  const yeni = Number(el.value);
  gunler[gi].gun = yeni;
  gunler.sort((a, b) => a.gun - b.gun);
  if(globalThis._bcAktifGunCard === eskiGun) globalThis._bcAktifGunCard = yeni;
  if(globalThis._bcSeansFormGun === eskiGun) globalThis._bcSeansFormGun = yeni;
  bcPlanRender();
}

// Kart altı '📋 Günü Kopyala → Gün № [Uygula]': hedef yoksa OLUŞTURULUR,
// varsa seansları DEĞİŞTİRİLİR (bcGunKopyala). Boş kaynak gün
// kopyalanamaz (hedefi boşaltma veri kaybı).
function bcGunKopyalaUygula(kaynakGun){
  const gunler = globalThis._bcGunler || [];
  const src = gunler.find(g => g.gun === kaynakGun);
  if(!src || !(src.seanslar || []).length){ toast('⚠️ Kaynak günde kopyalanacak seans yok', true); return; }
  const hedef = Number.parseInt(g('bc-gkopya-' + kaynakGun)?.value, 10);
  if(!Number.isInteger(hedef) || hedef < 1 || hedef > 31){ toast('⚠️ Hedef gün numarası girin (1-31)', true); return; }
  if(hedef === kaynakGun){ toast('⚠️ Hedef gün kaynakla aynı olamaz', true); return; }
  const r = bcGunKopyala(gunler, kaynakGun, hedef);
  if(!r){ toast('⚠️ Gün kopyalanamadı', true); return; }
  globalThis._bcGunler = r.gunler;
  globalThis._bcAktifGunCard = hedef;
  bcPlanRender();
  toast('📋 Gün ' + kaynakGun + ' → Gün ' + hedef + ' kopyalandı (' + (r.olusturuldu ? 'oluşturuldu' : 'değiştirildi') + ')');
}

// ═══ V2.1 TAKVİMDEN GÜN EKLEME (bc-gun-takvim — gun-tarih-modal
// dilinin bc uyarlaması: ay takvimi, dokun-işaretle, seçili çipler,
// Onayla). Yalnız bc-tarih ve SONRASI seçilebilir; mevcut gün tarihleri
// mavi vurgulu (dokunuş no-op). ═══

let _bcTkAy = 0, _bcTkYil = 0;
let _bcTkSecili = new Set();

function _bcTkBaslangic(){
  return (v('bc-tarih') || '').trim() || bugun();
}

function bcTakvimAc(){
  const p = _bcTkBaslangic().split('-').map(Number);
  _bcTkAy = (p[1] || 1) - 1;
  _bcTkYil = p[0] || new Date().getFullYear();
  _bcTkSecili = new Set();
  bcTakvimRender();
}

function bcTakvimRender(){
  let box = document.getElementById('bc-gun-takvim');
  if(!box){
    box = document.createElement('div');
    box.id = 'bc-gun-takvim';
    box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex;align-items:flex-end';
    box.onclick = e => { if (e.target === box) box.remove(); };
    document.body.appendChild(box);
  }
  const ay = _bcTkAy, yil = _bcTkYil;
  const baslangic = _bcTkBaslangic();
  const basGun = _bcUtcGun(baslangic);
  // mevcut günlerin tarihleri mavi vurgulanır (Gün № = tarih + N−1)
  const tarihdenGun = {};
  (globalThis._bcGunler || []).forEach(gn => {
    const iso = dFwd(baslangic, (Number(gn.gun) || 1) - 1);
    if(iso) tarihdenGun[iso] = gn.gun;
  });
  const ilkGun = new Date(yil, ay, 1).getDay();
  const bosluk = (ilkGun + 6) % 7;
  const sonGun = new Date(yil, ay + 1, 0).getDate();
  const ayAdi = new Date(yil, ay, 1).toLocaleString('tr-TR', { month: 'long', year: 'numeric' });

  let kareler = '';
  for(let i = 0; i < bosluk; i++) kareler += '<div></div>';
  for(let g2 = 1; g2 <= sonGun; g2++){
    const iso = yil + '-' + String(ay + 1).padStart(2, '0') + '-' + String(g2).padStart(2, '0');
    const isoGun = _bcUtcGun(iso);
    const onceMi = basGun !== null && isoGun !== null && isoGun < basGun;
    const mevcutNo = tarihdenGun[iso] || null;
    const secili = _bcTkSecili.has(iso);
    let stil = 'color:var(--ink);';
    if(mevcutNo) stil = 'background:rgba(42,107,181,.15);color:var(--blue);border:1.5px solid var(--blue);';
    else if(secili) stil = 'background:var(--green);color:#fff;';
    const tik = (onceMi || mevcutNo) ? '' : ' onclick="bcTakvimToggle(&#39;' + iso + '&#39;)"';
    kareler += '<div' + tik + (mevcutNo ? ' title="Gün ' + mevcutNo + ' planlı"' : '') +
      ' style="aspect-ratio:1;display:flex;align-items:center;justify-content:center;border-radius:8px;font-size:.82rem;font-weight:700;cursor:' + (onceMi ? 'not-allowed;opacity:.35;' : 'pointer;') + stil + '">' + g2 + '</div>';
  }

  const seciliList = [..._bcTkSecili].sort();
  const seciliHtml = seciliList.length
    ? '<div style="display:flex;flex-wrap:wrap;gap:4px;margin-bottom:10px">' +
      seciliList.map(d => '<span style="background:rgba(78,154,42,.12);border:1px solid var(--green);border-radius:6px;padding:2px 8px;font-size:.72rem;font-weight:700;color:var(--green)">' + d.slice(5).replaceAll('-', '.') + '</span>').join('') +
      '</div>'
    : '<div style="font-size:.75rem;color:var(--ink3);margin-bottom:10px">Tarih seçin</div>';

  box.innerHTML =
    '<div style="background:var(--card);border-radius:18px 18px 0 0;width:100%;padding:16px;max-height:85vh;overflow-y:auto">' +
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:10px">📅 Tedavi Günleri — Takvimden Seç (başlangıç: ' + baslangic + ')</div>' +
    '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px">' +
    '<button onclick="_bcTkAy--;if(_bcTkAy<0){_bcTkAy=11;_bcTkYil--;}bcTakvimRender()" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:4px 12px;cursor:pointer;font-size:1rem">‹</button>' +
    '<span style="font-weight:800;font-size:.9rem">' + ayAdi + '</span>' +
    '<button onclick="_bcTkAy++;if(_bcTkAy>11){_bcTkAy=0;_bcTkYil++;}bcTakvimRender()" style="background:none;border:1px solid var(--card3);border-radius:8px;padding:4px 12px;cursor:pointer;font-size:1rem">›</button>' +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:4px">' +
    ['Pt', 'Sa', 'Ca', 'Pe', 'Cu', 'Ct', 'Pz'].map(g => '<div style="text-align:center;font-size:.6rem;font-weight:700;color:var(--ink3);padding:3px">' + g + '</div>').join('') +
    '</div>' +
    '<div style="display:grid;grid-template-columns:repeat(7,1fr);gap:3px;margin-bottom:12px">' + kareler + '</div>' +
    '<div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;margin-bottom:6px">Seçili Günler (' + seciliList.length + ')</div>' +
    seciliHtml +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">' +
    '<button onclick="bcTakvimOnayla()" style="padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-weight:700;cursor:pointer">Ekle</button>' +
    '<button onclick="bcTakvimKapat()" style="padding:12px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">İptal</button>' +
    '</div></div>';
  box.style.display = 'flex';
}

function bcTakvimToggle(iso){
  const basGun = _bcUtcGun(_bcTkBaslangic());
  const isoGun = _bcUtcGun(iso);
  if(basGun !== null && isoGun !== null && isoGun < basGun){ toast('⚠️ Başlangıç tarihinden önceki gün seçilemez', true); return; }
  if(_bcTkSecili.has(iso)) _bcTkSecili.delete(iso);
  else _bcTkSecili.add(iso);
  bcTakvimRender();
}

// Onayla: yeni tarihler boş gün olarak eklenir (bir günün seansı olmak
// zorunda — ilk yeni günün '＋ seans ekle' formu AÇIK gelir); mevcut
// günler birleştirilir (dokunulmaz). Üst sınır 31.
function bcTakvimOnayla(){
  const gunNolar = bcTakvimdenGunler([..._bcTkSecili], _bcTkBaslangic());
  const gunler = globalThis._bcGunler || (globalThis._bcGunler = []);
  const mevcut = new Set(gunler.map(g => g.gun));
  const yeniler = gunNolar.filter(n => !mevcut.has(n));
  if(!yeniler.length){ bcTakvimKapat(); toast('⚠️ Yeni eklenecek tarih seçilmedi (mevcut günler mavi)', true); return; }
  let ilk = null, eklendi = 0;
  for(const n of yeniler){
    if(gunler.length >= 31){ toast('⚠️ En fazla 31 gün', true); break; }
    gunler.push({ gun: n, seanslar: [] });
    if(ilk === null) ilk = n;
    eklendi++;
  }
  gunler.sort((a, b) => a.gun - b.gun);
  bcTakvimKapat();
  toast('📅 ' + eklendi + ' gün eklendi — seans ekleyin');
  bcSeansFormAc(ilk); // boş gün tek başına kalamaz: seans formu açık gelir
}

function bcTakvimKapat(){
  const box = document.getElementById('bc-gun-takvim');
  if(box) box.remove();
}

// ═══ V2.1 SEANS FORMU ('＋ Bu güne seans ekle') ═══

async function bcSeansFormAc(gun){
  if(!(_drugsCache && _drugsCache.length)){ try { await loadDrugsCache(); } catch(_) {} }
  globalThis._bcSeansFormGun = gun;
  globalThis._bcAktifGunCard = gun;
  bcPlanRender();
}
function bcSeansVazgec(){
  globalThis._bcSeansFormGun = null;
  bcPlanRender();
}

// İlaç checkbox'ı → doz satırı (#bc-srow-<id>: doz/birim/yol ön-dolular,
// doz BOŞ). Değerler [Seansı Ekle] onayında okunur — anlık state sync yok
// (bc-irow deseninin seans formu uyarlaması).
function bcSeansChkChange(chk){
  const satirlar = g('bc-sdoz-satirlar');
  if(!satirlar) return;
  const alan = g('bc-sdoz-alani');
  if(chk.checked){
    if(alan) alan.style.display = 'block';
    satirlar.appendChild(_bcSeansDozSatiri(chk.dataset));
  } else {
    const row = g('bc-srow-' + chk.dataset.id);
    if(row) row.remove();
    if(alan && !satirlar.children.length) alan.style.display = 'none';
  }
}

function _bcSeansDozSatiri(ds){
  const id = ds.id;
  const name = String(ds.name || id).replace(/"/g, '&quot;');
  const route = ds.route || 'IM';
  const row = document.createElement('div');
  row.id = 'bc-srow-' + id;
  row.style.cssText = 'background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:8px;padding:8px;margin-bottom:6px';
  row.innerHTML =
    '<div style="font-size:.78rem;font-weight:700;color:var(--green);margin-bottom:5px">' + name + '</div>' +
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">' +
    '<input type="number" id="bc-sdoz-' + id + '" min="0.01" step="0.01" placeholder="Doz" class="fi" style="margin:0">' +
    '<input type="text" id="bc-sunit-' + id + '" placeholder="Birim" value="' + escAttr(ds.unit || 'ml') + '" class="fi" style="margin:0">' +
    '</div>' +
    '<select id="bc-srot-' + id + '" class="fsel" style="margin-top:5px">' +
    '<option value="">Uygulama yolu</option>' +
    '<option ' + (route === 'IM' ? 'selected' : '') + ' value="IM">IM — Kas ici</option>' +
    '<option ' + (route === 'IV' ? 'selected' : '') + ' value="IV">IV — Damar ici</option>' +
    '<option ' + (route === 'SC' ? 'selected' : '') + ' value="SC">SC — Deri alti</option>' +
    '<option ' + (route === 'PO' ? 'selected' : '') + ' value="PO">PO — Agizdan</option>' +
    '<option value="Topikal">Topikal</option>' +
    '<option value="Intrauterin">Intrauterin</option>' +
    '</select>';
  return row;
}

function bcSeansSaatChip(t, btn){
  const i = g('bc-gsaat');
  if(i) i.value = t;
  if(btn && btn.parentElement) btn.parentElement.querySelectorAll('.ek-chip').forEach(c => c.classList.remove('aktif'));
  if(btn) btn.classList.add('aktif');
}

// [Seansı Ekle]: saat + işaretli ilaçların doz/birim'ini doğrular
// (sablonSeansEkle aynası), kalem state'e YAZAR, seansı saate göre ASC
// ekler, seans listesini cerrahi çizer; form AÇIK kalır, yalnız saat
// sıfırlanır (seans A → 20:00 → seans B akışı). Kalem state'e girmeden
// şablon Şablonsuz'a döner (karşılıklı dışlama).
function bcSeansEkle(gun){
  const gunObj = (globalThis._bcGunler || []).find(g => g.gun === gun);
  if(!gunObj) return;
  const saat = (g('bc-gsaat')?.value || '').trim();
  if(!saat){ toast('⚠️ Seans saati girin', true); return; }
  if(!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(saat)){ toast('⚠️ Geçerli saat girin (SS:DD)', true); return; }
  const secililer = [];
  let hata = false;
  document.querySelectorAll('.bc-schk:checked').forEach(chk => {
    if(hata) return;
    const id = chk.dataset.id;
    const dose = Number.parseFloat(g('bc-sdoz-' + id)?.value);
    const unit = (g('bc-sunit-' + id)?.value || '').trim();
    const route = g('bc-srot-' + id)?.value || null;
    if(!dose || dose <= 0){ toast(chk.dataset.name + ': geçerli doz girin', true); hata = true; return; }
    if(!unit){ toast(chk.dataset.name + ': birim girin', true); hata = true; return; }
    const d = (_drugsCache || []).find(x => x.id === id);
    secililer.push({
      id,
      name: d?.name || chk.dataset.name || id,
      dose, unit, route,
      legacy: d ? !!d._legacy : chk.dataset.legacy === 'true',
      stock_id: d ? (d.stock_id || null) : null,
    });
  });
  if(hata) return;
  if(!secililer.length){ toast('⚠️ En az bir ilaç seçin', true); return; }
  bcSablonaDonustur();
  const ilaclar = {};
  secililer.forEach(k => {
    ilaclar[k.id] = { name: k.name, dose: k.dose, unit: k.unit, route: k.route, legacy: k.legacy, stock_id: k.stock_id };
  });
  gunObj.seanslar = gunObj.seanslar || [];
  gunObj.seanslar.push({ saat, ilaclar });
  gunObj.seanslar.sort((a, b) => (a.saat || '').localeCompare(b.saat || ''));
  _bcSeanslariCiz(gun);
  const saatInp = g('bc-gsaat');
  if(saatInp){
    saatInp.value = '09:00';
    if(saatInp.parentElement) saatInp.parentElement.querySelectorAll('.ek-chip').forEach(c => c.classList.remove('aktif'));
  }
  bcButonEtiketi();
}

function bcSeansSil(gun, si){
  const gunObj = (globalThis._bcGunler || []).find(g => g.gun === gun);
  if(!gunObj || !gunObj.seanslar || gunObj.seanslar[si] === undefined) return;
  gunObj.seanslar.splice(si, 1);
  bcPlanRender();
}

function bcKalemSil(gun, si, drugId){
  const gunObj = (globalThis._bcGunler || []).find(g => g.gun === gun);
  const seans = gunObj && gunObj.seanslar ? gunObj.seanslar[si] : null;
  if(!seans || !seans.ilaclar) return;
  delete seans.ilaclar[drugId];
  if(!Object.keys(seans.ilaclar).length){
    // son kalemi çıkarılan seans boş kalır — seanssız gün hatasına düşmesin
    gunObj.seanslar.splice(si, 1);
  }
  bcPlanRender();
}

// Karşılıklı dışlama (ilaç→şablon): radyoyu "Şablonsuz"a çeker, state'i
// temizler. Zaten Şablonsuz ise (state null + default işaretli/rendesiz)
// no-op — false döner; değişiklik olduysa true.
function bcSablonaDonustur(){
  const dflt = document.querySelector('input[name="bc-sablon"][value=""]');
  if(globalThis._bcSeciliSablonId == null && (!dflt || dflt.checked)) return false;
  globalThis._bcSeciliSablonId = null;
  document.querySelectorAll('input[name="bc-sablon"]').forEach(r => { r.checked = (r.value === ''); });
  return true;
}

// Karşılıklı dışlama (şablon→kalem): gerçek bir şablon seçildiyse TÜM
// günlerin seansları temizlenir + açık seans formu kapanır (V2.1'de kalem
// state'i seansların içindedir — eski 'secili state' düzlemi kalktı).
function bcSablonIlacTemizle(){
  document.querySelectorAll('.bc-schk:checked').forEach(chk => { chk.checked = false; });
  (globalThis._bcGunler || []).forEach(gn => { gn.seanslar = []; });
  globalThis._bcSeansFormGun = null;
  bcPlanRender();
  bcButonEtiketi();
}

// Dinamik buton etiketi (V2.1): HERHANGİ bir günün herhangi bir seansında
// ilaç varsa "💊 Tedaviyi Uygula", yoksa "🩺 Vakaları Aç". Yalnız seans
// state'i sorgulanır — kalem [Seansı Ekle] onayıyla state'e yazıldığından
// DOM sorgusuna gerek kalmadı (V2'deki aktif-gün DOM kontrolü kalktı).
function bcButonMetni(){
  const varMi = (globalThis._bcGunler || []).some(gn => (gn.seanslar || []).some(s => Object.keys(s.ilaclar || {}).length > 0));
  return varMi ? '💊 Tedaviyi Uygula' : '🩺 Vakaları Aç';
}
function bcButonEtiketi(){
  const btn = g('bc-submit');
  if(btn) btn.textContent = bcButonMetni();
}

// Gün planını RPC v4 p_items sözleşmesine toplar (V2.1: seans-saat
// eşlemeli) — {hatalar:[strings], items:[{gun, kalemler:[...]}]}.
//   - STATE-TABANLI: kalem [Seansı Ekle] anında state'te — DOM harvest yok.
//   - TÜM günler boşsa {hatalar:[], items:[]} — eski akış (vaka ilaçsız veya
//     şablon yolu) korunur.
//   - Herhangi bir günde kalem varsa: seanssız gün hata alır ('Gün N: en az
//     bir seans ekleyin ya da günü silin'); seans saati SS:DD regex'ten
//     geçer; satır hataları gün+saat önekli: 'Gün N (<saat>): <ad>: doz
//     girin' / '... birim girin'; hatalı satırın öğesi TOPLANMAZ.
//   - kalem.saat HER ZAMAN seans saatini taşır; gün-düzlemi 'saat' alanı
//     GÖNDERİLMEZ (replace-old-day-saat semantiği — aynı ilacın A/B
//     seansları sunucuda ayrı planned_time'lı uygulamalara düşer).
//   - drug_product_id/stok_id: kalem state'inde check anında çözülür;
//     eksikse _drugsCache fallback (legacy stok kaleminde drug_product_id null).
function bcGunlardenItems(){
  const gunler = globalThis._bcGunler || [];
  const herhangiKalem = gunler.some(gn => (gn.seanslar || []).some(s => Object.keys(s.ilaclar || {}).length > 0));
  if(!herhangiKalem) return { hatalar: [], items: [] };
  const hatalar = [];
  const items = [];
  gunler.slice().sort((a, b) => a.gun - b.gun).forEach(gn => {
    const gunNo = gn.gun;
    const seanslar = gn.seanslar || [];
    if(!seanslar.length){ hatalar.push('Gün ' + gunNo + ': en az bir seans ekleyin ya da günü silin'); return; }
    const kalemler = [];
    seanslar.forEach(seans => {
      const saat = (seans.saat || '').trim();
      if(!saat){ hatalar.push('Gün ' + gunNo + ': seans saati girin'); return; }
      if(!/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(saat)){ hatalar.push('Gün ' + gunNo + ': geçersiz seans saati (' + saat + ')'); return; }
      const ids = Object.keys(seans.ilaclar || {});
      if(!ids.length) return; // boş seans — sessiz atlanır (yarıda kalan draft)
      ids.forEach(id => {
        const k = seans.ilaclar[id] || {};
        const d = (_drugsCache||[]).find(x => x.id === id);
        const legacy = k.legacy !== undefined ? !!k.legacy : !!(d && d._legacy);
        const stockId = k.stock_id !== undefined ? (k.stock_id || null) : (d?.stock_id || null);
        const dose = Number.parseFloat(k.dose);
        const unit = (k.unit || '').trim();
        let satirHatali = false;
        if(!Number.isFinite(dose) || dose <= 0){ hatalar.push('Gün ' + gunNo + ' (' + saat + '): ' + (k.name || id) + ': doz girin'); satirHatali = true; }
        if(!unit){ hatalar.push('Gün ' + gunNo + ' (' + saat + '): ' + (k.name || id) + ': birim girin'); satirHatali = true; }
        if(satirHatali) return;
        kalemler.push({
          drug_product_id: legacy ? null : id,
          stok_id: stockId,
          dose: dose,
          unit: unit,
          route: (k.route || '').trim() || null,
          saat: saat,
        });
      });
    });
    if(!kalemler.length) return; // tüm seansları hatalı gün — hatalar zaten toplandı
    items.push({ gun: gunNo, kalemler });
  });
  return { hatalar, items };
}

// ── TOPLU GÖNDERİM (FORM-SUBMIT-01 zinciri) ──
// Sunucu guard aynası: aynı hayvan + aynı hastalık + status='active' vaka varsa
// hayvan atlanacak demektir (cases.animal_id/disease_id/status alanlarıyla
// birebir). Saf, DOM'suz — IndexedDB ucuz ön-kontrol; sunucu guard'a
// dokunulmaz (çifte emniyet).
function bcMukerrerBul(hayvanlar, cases, diseaseId){
  if(!diseaseId) return [];
  return (hayvanlar || []).filter(h =>
    h?.id && (cases || []).some(c =>
      c.animal_id === h.id && c.disease_id === diseaseId && c.status === 'active'
    )
  ).map(h => ({ id: h.id, kupe: h.kupe }));
}

// vaka_toplu_ac jsonb sonucunu render satırlarına çevirir:
// acilan→{tip:'ok',kupe}, atlanan→{tip:'atlanan',kupe,mesaj},
// hatalar→{tip:'hata',kupe,mesaj}. Sabit sıra: acilan → atlanan → hatalar.
// V1.1: manuel yol acilan[i].manuel.seans_sayisi → ok satırına ilacSayisi
// olarak taşınır (yoksa anahtar hiç eklenmez — eski sözleşme korunur).
// V1.2: acilan[i].tohumlama → ok satırına tohumlamaOlustu:true YA DA
// tohumlamaSebep:<sebep> olarak taşınır (additive — tohumlama yoksa anahtar yok).
// Saf, DOM'suz.
function bcSonucSatirlari(result){
  const r = result || {};
  const satirlar = [];
  (r.acilan  || []).forEach(a => {
    const satir = { tip: 'ok', kupe: a.kupe };
    // V1.1: manuel.seans_sayisi → ilacSayisi; V2: manuel.gun_sayisi → gunSayisi
    // (additive — alan yoksa anahtar hiç eklenmez, eski sözleşme korunur)
    const m = a.manuel;
    if(m && typeof m.seans_sayisi === 'number') satir.ilacSayisi = m.seans_sayisi;
    if(m && typeof m.gun_sayisi === 'number') satir.gunSayisi = m.gun_sayisi;
    const th = a.tohumlama;
    if(th && th.olustu === true) satir.tohumlamaOlustu = true;
    else if(th && th.olustu === false && th.sebep) satir.tohumlamaSebep = th.sebep;
    satirlar.push(satir);
  });
  (r.atlanan || []).forEach(a => satirlar.push({ tip: 'atlanan', kupe: a.kupe, mesaj: a.mesaj }));
  (r.hatalar || []).forEach(h => satirlar.push({ tip: 'hata',    kupe: h.kupe, mesaj: h.mesaj }));
  return satirlar;
}

// V2 — manuel ok-satırı metin eki: manuel {gun_sayisi, seans_sayisi} →
// ' + N gün · M ilaç'; yalnız seans varsa eski ' + M ilaç' fallback; ikisi de
// yoksa '' (ek yok). Saf, DOM'suz.
function bcManuelSatirEki(manuel){
  const m = manuel || {};
  const gun = typeof m.gun_sayisi === 'number' ? m.gun_sayisi : null;
  const ilac = typeof m.seans_sayisi === 'number' ? m.seans_sayisi : null;
  if(gun !== null && ilac !== null) return ` + ${gun} gün · ${ilac} ilaç`;
  if(ilac !== null) return ` + ${ilac} ilaç`;
  return '';
}

// Toplu vaka gönderimi — submitCase:590 zincirinin N-hayvan aynası:
// online-only guard → seçim/hastalık doğrulaması → IndexedDB mükerrer
// ön-kontrol (openConfirm) → tek rpc('vaka_toplu_ac') → bc-sonuc satır
// render → pullTables(submitCase seti). Modal KAPANMAZ — kullanıcı sonuç
// listesini gözden geçirir; form sıfırlanmaz (chips kalır).
async function submitBulkCase(btn){
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const liste = globalThis._bcHayvanlar || [];
  if (!liste.length) { toast('⚠️ En az bir hayvan seçin', true); return; }
  if (liste.length > 200) { toast('⚠️ En fazla 200 hayvan', true); return; }
  const diseaseId = v('bc-disease-id');
  if (!diseaseId) { toast('⚠️ Hastalık seçin', true); return; }

  // V1.1/V2 manuel çoklu gün yolu — toplayıcı hatalıysa ilk hata toast'lanır
  // ve akış durur; kalem varsa p_items yolu açılır (p_sablon_id null —
  // karşılıklı dışlama; kalem state'e girerken UI zaten Şablonsuz'a çeker).
  // p_items Gün-KEYED (RPC v4, V2.1): [{gun, kalemler:[{..., saat}]}] —
  // kalem.saat HER ZAMAN seans saatini taşır (gün-düzlemi saat gönderilmez).
  const sec = bcGunlardenItems();
  if (sec.hatalar.length) { toast('⚠️ ' + sec.hatalar[0], true); return; }
  const manuelVar = sec.items.length > 0;

  // V1.2 — planlanan tedavi tarihi (boş → null = bugün); geçmiş tarih erken red
  // (sunucu da reddeder: 'Geçmiş tarih planlanamaz' — istemci aynası).
  const tarih = (v('bc-tarih') || '').trim() || null;
  if (tarih && bcGecmisPlanTarihiMi(tarih, bugun())) {
    toast('⚠️ Geçmiş tarih planlanamaz', true);
    return;
  }

  // V1.2/V2 — tohumlama isteği: blok DAIMA görünür; kutu yalnız AKTİF modda
  // (en az bir dişi seçili) okunur. Disabled moddan değer OKUNMAZ (erkek/boş
  // listede istek yok sayılır); işaret durumu korunur ama gönderilmez.
  const tohumMod = bcTohumBlokDurumu(liste).mod;
  const tohumChkEl = g('bc-tohum');
  const tohumIste = !!(tohumMod === 'aktif' && tohumChkEl && tohumChkEl.checked);
  const tohumGun = tohumIste
    ? Math.max(0, Math.min(365, Number.parseInt(v('bc-tohum-gun'), 10) || 0))
    : 0;
  const tohumSaat = tohumIste ? ((v('bc-tohum-saat') || '').trim() || '08:00') : '08:00';

  // Mükerrer ön-kontrol: seçili hayvanlar × disease × status='active' (IndexedDB)
  let cases = [];
  try { cases = await idbGetAll('cases'); } catch { cases = []; }
  const dups = bcMukerrerBul(liste, cases, diseaseId);

  // V1.2 — tohumlama uygunluk ön-kontrolü (hedef = p_tarih + gün ofseti;
  // gebe kontrolü istemcide YOK — sunucu teyitli, onay metninde belirtilir).
  const uygunsuz = tohumIste
    ? bcTohumUygunOlmayanlar(liste, bcTohumHedefTarih(tarih, tohumGun))
    : [];

  const gonder = async () => {
    if (btn) { btn.disabled = true; btn.textContent = '⏳ Gönderiliyor…'; }
    try {
      // rpc() hata ve ok:false'ta throw eder (e.data gövdeyi taşır) —
      // buraya gelen res her zaman ok:true gövdesidir; if (!res.ok) ÖLÜ KOD.
      // V1.2 — named args: p_tarih + tohumlama üçlüsü her yolda gönderilir.
      const res = await rpc('vaka_toplu_ac', {
        p_animal_ids: liste.map(h => h.id),
        p_disease_id: diseaseId,
        p_notes:      v('bc-notes') || null,
        ...(manuelVar
          ? { p_items: sec.items, p_sablon_id: null }
          : { p_sablon_id: globalThis._bcSeciliSablonId || null }),
        p_tarih:                tarih,
        p_tohumlama:            tohumIste,
        p_tohumlama_gun_offset: tohumGun,
        p_tohumlama_saat:       tohumSaat,
      });

      // Sonuç listesi (bcSonucSatirlari sırası: acilan → atlanan → hatalar)
      const satirlar = bcSonucSatirlari(res);
      const acilanlar = res.acilan || [];
      const renk = { ok: 'var(--green)', atlanan: 'var(--amber)', hata: 'var(--red)' };
      let ai = 0;
      const html = satirlar.map(s => {
        if (s.tip === 'ok') {
          const a = acilanlar[ai++];
          const gun = a?.sablon?.gun_sayisi;
          // V2 manuel satır: "✅ <kupe> — vaka açıldı + N gün · M ilaç"
          // (gün alanı yoksa eski "+ M ilaç" fallback; hiçbiri yoksa ek yok)
          const manuelEk = bcManuelSatirEki(a?.manuel);
          const sablonEk = manuelEk ? '' : (gun ? ` + ${gun} gün şablon` : '');
          // V1.2 tohumlama eki: olustu → saat; olustu=false + istek var → sebep
          const tohumEk = (s.tohumlamaOlustu === true)
            ? ` · 🐄 tohumlama ${tohumSaat}`
            : (s.tohumlamaSebep && tohumIste ? ` · ⏭ tohumlama: ${s.tohumlamaSebep}` : '');
          return `<div style="font-size:.78rem;padding:2px 0;color:${renk.ok}">✅ ${escAttr(s.kupe)} — vaka açıldı${manuelEk}${sablonEk}${tohumEk}</div>`;
        }
        if (s.tip === 'atlanan') {
          return `<div style="font-size:.78rem;padding:2px 0;color:${renk.atlanan}">⏭ ${escAttr(s.kupe)} — ${esc(s.mesaj || 'atlandı')}</div>`;
        }
        return `<div style="font-size:.78rem;padding:2px 0;color:${renk.hata}">❌ ${esc(s.mesaj || 'hata')}</div>`;
      }).join('');
      const ozet = `Toplam ${res.toplam ?? liste.length} · Açılan ${res.basari ?? 0} · Atlanan ${(res.atlanan || []).length} · Hata ${(res.hatalar || []).length}`;
      const sonuc = g('bc-sonuc');
      if (sonuc) {
        sonuc.innerHTML =
          `<div style="font-size:.78rem;font-weight:700;padding:4px 0">${esc(ozet)}</div>` + html;
        sonuc.style.display = 'block';
      }

      const basari = res.basari || 0;
      if (basari > 0) toast(`✅ ${basari} vaka açıldı`);
      else toast('⚠️ Hiç vaka açılamadı — listeye bakın', true);

      // submitCase:629 pull setinin aynısı (RPC-WRITE-01); pull/cache hatası
      // başarıyı maskelemesin — uyarı sadece console'a
      await pullTables(['cases','diseases','drugs','kizginlik_log','islem_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log']).catch(console.warn);
      _drugsCache = [];
      await loadDrugsCache().catch(console.warn);
      renderSafe();
    } catch (e) {
      toast(getUserMessage(e), true);
    } finally {
      // V1.1 — sabit etiket değil AKTİF dinamik etikete dön (manuel/şablon modu)
      if (btn) { btn.disabled = false; btn.textContent = bcButonMetni(); }
    }
  };

  // V1.2 — BİRLEŞİK uyarı onayı: mükerrer aktif vaka + tohumlama uygunsuzleri
  // TEK openConfirm'de; her iki uyarı da "atlanacak" — onay akışı sürer.
  const uyariSatirlari = [
    ...dups.map(d => `• ${d.kupe} — zaten aktif vaka — atlanacak`),
    ...uygunsuz.map(u => `• ${u.kupe} — ${u.sebep} — tohumlaması atlanacak`),
  ];
  if (uyariSatirlari.length) {
    // Planlı aşı tekrar uyarısı (forms.js:1400) openConfirm deseni —
    // desc textContent ile basılır, HTML kaçış gerektirmez
    openConfirm('⚠️ Uyarılar',
      uyariSatirlari.join('\n') + '\n\nDevam edilsin mi?',
      gonder);
    return;
  }
  await gonder();
}

// ── ABORT ────────────────────────────────────
async function abortKaydet(hayvanId, tohId) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  if (!confirm('Bu hayvanda abort / erken doğum mu oldu? Gebelik kaydı kapatılacak.')) return;
  // B14: Cancel (null) ile boş-OK ayrıtılır — Cancel akışı tamamen iptal eder.
  // Eskiden Cancel yine de bugün tarihiyle abort kaydediyordu.
  const bugunTr = bugun();
  const rawTarih = prompt('Abort tarihi (YYYY-AA-GG, boş=bugün):', bugunTr);
  if (rawTarih === null) return;
  const tarihGirdi = rawTarih.trim();
  let abortTarihi = bugunTr;
  if (tarihGirdi && !/^\d{4}-\d{2}-\d{2}$/.test(tarihGirdi)) {
    toast('⚠️ Abort tarihi formatı hatalı (YYYY-AA-GG)', true);
    return;
  }
  if (tarihGirdi) abortTarihi = tarihGirdi;
  // B14: ileri tarih ve tohumlamadan önce tarih reddi — bozuk VWP/sessiz ankrajı
  // önler (2027 yazımı "-354 gün" gibi anlamsız uyarılar üretiyordu)
  if (abortTarihi > bugunTr) { toast('⚠️ Abort tarihi ileri tarih olamaz', true); return; }
  const tohKayit = (await getData('tohumlama', t => t.id === tohId))[0];
  if (tohKayit?.tarih && abortTarihi < tohKayit.tarih) {
    toast(`⚠️ Abort tarihi tohumlama tarihinden önce olamaz (${fmtTarih(tohKayit.tarih)})`, true);
    return;
  }
  const notlar = prompt('Abort detayı (opsiyonel):') || '';
  try {
    // Yeni tohumlama_abort RPC kullan (islem_log kaydı oluşturur)
    const result = await rpc('tohumlama_abort', {
      p_tohumlama_id:  tohId,
      p_notlar:        notlar || null,
      p_abort_tarihi:  abortTarihi,
    });
    toast('✅ Abort kaydedildi, gebelik kapatıldı');
    await pullTables(['tohumlama','hayvanlar','islem_log']);
    renderSafe();
    openDet(hayvanId);
  } catch (e) { toast('❌ Abort kaydedilemedi: ' + (e?.message || getUserMessage(e)), true); }
}

// ── HAYVAN NOTU EKLE ─────────────────────────
async function hayvanNotEkle(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const notText = (g('not-input')?.value || '').trim();
  if (!notText) { toast('Not yazın', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('hayvan_not_ekle', { p_hayvan_id: hayvanId, p_not: notText });
    toast('✅ Not kaydedildi');
    closeM('m-not');
    cl('not-input');
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
    openDet(hayvanId);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Not Ekle'; } }
}

function openNotModal(hayvanId, kupe) {
  g('not-hid').value = hayvanId;
  g('not-title').textContent = `📝 Not Ekle — ${kupe}`;
  cl('not-input');
  openM('m-not');
}

// ── SÜRÜDEN ÇIKIŞ ────────────────────────────
async function submitCikis(btn) {
  const expected = parseInt(g('cx-math-ok').value);
  const given    = parseInt(g('cx-math-ans').value);
  if (isNaN(given) || given !== expected) { toast('⚠️ Hatalı onay cevabı', true); return; }
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hayvanId  = g('cx-hid').value;
  const cxTip     = g('cx-tip').value;           // 'Satıldı' | 'Kesildi' | 'Öldü' | 'Kayıp'
  const tarih     = g('cx-tarih').value;
  const sebep     = g('cx-sebep').value.trim();
  const fiyat     = Number.parseFloat(g('cx-fiyat').value) || null;
  if (fiyat !== null && fiyat < 0) { toast('⚠️ Satış fiyatı negatif olamaz', true); return; }
  // M-11 fix: cikis_yap RPC artık 4 ayrı tip kabul ediyor (eskiden Kesildi/Öldü/Kayıp
  // hepsi 'olum'a sıkıştırılıyordu, rapor/audit'te ayrım kayboluyordu).
  const RPC_TIP_MAP = { 'Satıldı': 'satis', 'Kesildi': 'kesim', 'Öldü': 'olum', 'Kayıp': 'kayip' };
  const rpcTip    = RPC_TIP_MAP[cxTip] || 'olum';
  if (!tarih) { toast('Tarih zorunlu', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const hayvan = getState('animals').find(a => a.id === hayvanId);
    if (!hayvan) { toast('Hayvan bulunamadı', true); return; }

    // Küpeyi localStorage'a kaydet — çıkan hayvan view'dan düşünce UUID görünmesin
    try {
      const cache = JSON.parse(localStorage.getItem('ege_exited_kupe') || '{}');
      cache[hayvanId] = getDisplayKupe(hayvan);
      localStorage.setItem('ege_exited_kupe', JSON.stringify(cache));
    } catch(_) {}

    await rpc('cikis_yap', {
      p_hayvan_id:    hayvanId,
      p_cikis_tipi:   rpcTip,
      p_cikis_tarihi: tarih,
      p_cikis_sebebi: sebep || cxTip || null,
      p_satis_fiyati: rpcTip === 'satis' ? fiyat : null,
    });

    toast(`✅ ${getDisplayKupe(hayvan)} sürüden çıkarıldı (${cxTip})`);
    closeM('m-cikis');
    closeDet();
    pullTables(['hayvanlar','gorev_log','protokol_instance']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🚪 Çıkışı Onayla'; } }
}

// ── SÜTTEN KESME ─────────────────────────────
// Süt içen buzağı seti: aktif + kesilmemiş + (grup 'Buzağı' içerir VEYA yaş ≤ 180g)
// Saf katman helpers.js'te (sutIcenBuzagiSec) — dashboard kartı sayacıyla tek kaynak.
function _sutIcenBuzagilar() {
  return sutIcenBuzagiSec(getState('animals'));
}
// Kesim eşiği: protokol_ayar 'sutten_kesme_gun' (varsayılan 60)
function suttenKesmeEsigi() {
  return +(getState('protokol_ayar')?.find(x => x.anahtar === 'sutten_kesme_gun')?.deger ?? 60);
}
function renderBuzagiPicker(filter) {
  const liste = document.getElementById('sk-liste');
  if (!liste) return;
  const q = (filter || '').toLowerCase();
  const esik = suttenKesmeEsigi();
  const tum = _sutIcenBuzagilar();
  const hazir = suttenKesimeHazirSec(tum, esik);
  const ozet = document.getElementById('sk-ozet');
  if (ozet) ozet.innerHTML = hazir.length
    ? `<span style="color:var(--green3);font-weight:700">${hazir.length} buzağı kesim vakti</span> <span style="color:var(--ink3)">(≥ ${esik} gün) · toplam ${tum.length} süt içen</span>`
    : `<span style="color:var(--ink3)">Kesim vakti gelen yok (eşik ≥ ${esik} gün) · toplam ${tum.length} süt içen</span>`;
  const havuz = q ? tum.filter(a => (getDisplayKupe(a) || '').toLowerCase().includes(q)) : tum;
  const rows = suttenKesListeSirala(havuz, esik);
  if (!rows.length) { liste.innerHTML = '<div style="color:var(--ink3);padding:8px">Süt içen buzağı yok</div>'; return; }
  const hazirId = new Set(hazir.map(a => a.id));
  liste.innerHTML = rows.map(a => {
    const yas = yasHesapla(a.dogum_tarihi) || 'Yaş?';
    const vakti = hazirId.has(a.id);
    const rozet = vakti ? ' <span style="font-size:.66rem;font-weight:700;color:var(--green3);background:rgba(78,154,42,.14);border:1px solid rgba(78,154,42,.35);border-radius:999px;padding:1px 7px;margin-left:4px;white-space:nowrap">🍼 Kesim vakti</span>' : '';
    return `<label style="display:flex;align-items:center;gap:10px;padding:9px 4px;border-bottom:1px solid var(--card2);cursor:pointer;${vakti ? 'background:rgba(78,154,42,.07);' : ''}">
      <input type="checkbox" data-id="${a.id}" checked style="width:18px;height:18px">
      <div><div style="font-weight:700;font-size:.85rem">${esc(getDisplayKupe(a))}${rozet}</div>
      <div style="font-size:.72rem;color:var(--ink3)">${esc(a.irk || '—')} · ${yas}</div></div></label>`;
  }).join('');
}
function openSuttenKesModal() {
  if (!_sutIcenBuzagilar().length) { toast('Süt içen buzağı yok'); return; }
  const t = document.getElementById('sk-tarih'); if (t) t.value = bugun();
  const h = document.getElementById('sk-hatalar'); if (h) h.innerHTML = '';
  renderBuzagiPicker('');
  const ara = document.getElementById('sk-ara');
  if (ara) { ara.value = ''; ara.oninput = () => renderBuzagiPicker(ara.value); }
  openM('m-sutten-kes');
}
function skHepsiniSec(durum) {
  document.querySelectorAll('#sk-liste input[type=checkbox]').forEach(cb => cb.checked = durum);
}
async function skOnayla(btn) {
  const secili = [...document.querySelectorAll('#sk-liste input[type=checkbox]:checked')].map(cb => cb.dataset.id);
  await submitSuttenKes(secili, btn);
}
async function submitSuttenKes(hayvanIdList, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  if (!hayvanIdList || !hayvanIdList.length) { toast('Hayvan seçilmedi', true); return; }
  const tarih = (document.getElementById('sk-tarih')?.value) || bugun();
  if (!confirm(`${hayvanIdList.length} buzağı ${tarih} tarihinde sütten kesilecek. Onaylıyor musunuz?`)) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const res = await rpc('buzagi_sutten_kesme_toplu', { p_hayvan_idler: hayvanIdList, p_tarih: tarih });
    if (res.ok && res.hata_sayisi === 0) {
      toast(`✅ ${res.basari} buzağı sütten kesildi`);
      closeM('m-sutten-kes');
    } else if (res.ok && res.hata_sayisi > 0) {
      toast(`⚠️ ${res.basari} başarılı, ${res.hata_sayisi} hatalı`, true);
      const hd = document.getElementById('sk-hatalar');
      if (hd) hd.innerHTML = res.hatalar.map(h => `<div style="color:var(--err);font-size:.72rem">• ${esc(h.hata)}</div>`).join('');
    } else {
      // RPC hata durumunda 'hata' değil 'hatalar' dizisi döner (B33)
      const hMsj = (res.hatalar && res.hatalar.length)
        ? res.hatalar.map(h => h.hata || h).join('; ')
        : (res.mesaj || res.hata || 'Bilinmeyen hata');
      toast(hMsj, true);
    }
    pullTables(['hayvanlar','gorev_log','protokol_instance']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🍼 Sütten Kes'; } }
}
async function suttenKesTekil(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = (getState('animals') || []).find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (h.suttten_kesme_tarihi) { toast('Zaten sütten kesilmiş', true); return; }
  const yas = h.dogum_tarihi ? Math.floor((Date.now() - new Date(h.dogum_tarihi)) / 86400000) : null;
  const min = +(getState('protokol_ayar')?.find(x => x.anahtar === 'sutten_kesme_erken_uyari')?.deger ?? 40);
  if (yas !== null && yas < min && !confirm(`Buzağı ${yas} günlük (min ${min}). Çok erken — yine de kesilsin mi?`)) return;
  if (!confirm(`${getDisplayKupe(h)} sütten kesilecek. Onaylıyor musunuz?`)) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('buzagi_sutten_kesme_onayla', { p_hayvan_id: hayvanId });
    toast(`✅ ${getDisplayKupe(h)} sütten kesildi`);
    if (typeof closeDet === 'function') closeDet();
    pullTables(['hayvanlar','gorev_log','protokol_instance']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🍼 Sütten Kes'; } }
}
async function suttenKesGeriAl(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = (getState('animals') || []).find(a => a.id === hayvanId);
  if (!confirm(`${h ? getDisplayKupe(h) : 'Bu hayvan'} için sütten kesme geri alınacak. Onaylıyor musunuz?`)) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Geri alınıyor…'; }
  try {
    await rpc('buzagi_sutten_kesme_geri_al', { p_hayvan_id: hayvanId });
    toast('↩️ Sütten kesme geri alındı');
    if (typeof closeDet === 'function') closeDet();
    await pullTables(['hayvanlar','gorev_log','protokol_instance','islem_log']).catch(()=>{});
    renderSafe();
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '↩️ Sütten Kesmeyi Geri Al'; } }
}
window.openSuttenKesModal = openSuttenKesModal;
window.renderBuzagiPicker = renderBuzagiPicker;
window.suttenKesmeEsigi = suttenKesmeEsigi;
window.skHepsiniSec = skHepsiniSec;
window.skOnayla = skOnayla;
window.suttenKesTekil = suttenKesTekil;
window.suttenKesGeriAl = suttenKesGeriAl;

// ── PROTOKOL AYARLARI (Ayarlar paneli) ───────
function protokolAyarYukle() {
  const rows = getState('protokol_ayar') || [];
  const val = k => rows.find(r => r.anahtar === k)?.deger;
  document.querySelectorAll('#m-ayarlar [data-ayar]').forEach(inp => {
    const v = val(inp.dataset.ayar); if (v != null) inp.value = v;
    inp.onchange = () => protokolAyarKaydet(inp.dataset.ayar, inp.value);
  });
  const wrap = document.getElementById('pa-chips-sutten_kesme_gun');
  if (wrap) {
    const cur = val('sutten_kesme_gun');
    wrap.innerHTML = [45,60,75,90,105,120].map(g =>
      `<button class="btn ${+cur===g?'':'btn-g'}" data-action="pa-chip" data-anahtar="sutten_kesme_gun" data-deger="${g}" style="font-size:.72rem;padding:3px 8px">${g}</button>`).join('');
  }
}
async function protokolAyarKaydet(anahtar, deger) {
  try {
    await rpc('protokol_ayar_guncelle', { p_anahtar: anahtar, p_deger: +deger });
    toast(`✅ ${anahtar} = ${deger}`);
    await pullTables(['protokol_ayar']);
    if (typeof setState === 'function') { try { setState('protokol_ayar', await getData('protokol_ayar')); } catch(e){} }
    protokolAyarYukle();
  } catch (e) { toast(getUserMessage(e), true); }
}
window.protokolAyarYukle = protokolAyarYukle;
window.protokolAyarKaydet = protokolAyarKaydet;

// ── TOHUMLANABILIR ONAY ──────────────────────
async function submitTohumOnayla(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = getState('animals').find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('hayvan_tohumlanabilir_onayla', { p_hayvan_id: hayvanId });
    toast(`✅ ${getDisplayKupe(h)} tohumlanabilir olarak onaylandı`);
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '✅ Tohumlanabilir Onayla'; } }
}
async function submitTohumErtele(hayvanId, ay, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = getState('animals').find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const res = await rpc('hayvan_tohumlama_ertele', { p_hayvan_id: hayvanId, p_ay: ay });
    toast(`✅ ${getDisplayKupe(h)} tohumlama ${ay} ay ertelendi${res?.hedef_tarih ? ' (hedef: ' + res.hedef_tarih + ')' : ''}`);
    closeM('m-tohum-ertele');
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '⏰ Ertele'; } }
}
function openTohumErtele(hayvanId, kupe) {
  g('te-hid').value = hayvanId;
  g('te-title').textContent = `⏰ Tohumlama Ertele — ${kupe}`;
  g('te-ay').value = '1';
  openM('m-tohum-ertele');
}

// ── ORTAK AŞI PICKER (checkbox + arama) ────────────
// m-vaccine (prefix 'v') ve m-bulk-vaccine (prefix 'bv') paylaşır
async function renderVaccinePicker(containerId, prefix){
  const vaccines = (await getData('vaccines')) || [];
  const c = document.getElementById(containerId);
  if(!c) return;
  const groups = { 'Zorunlu Aşılar':[], 'Diğer Aşılar':[] };
  vaccines.forEach(vx => (vx.is_mandatory?groups['Zorunlu Aşılar']:groups['Diğer Aşılar']).push(vx));
  const groupHtml = Object.keys(groups).filter(g=>groups[g].length).map(g=>{
    const items = groups[g].map(vx=>{
      const esc=(vx.name||'').replace(/"/g,'&quot;');
      const dt=(vx.disease_target||'').replace(/"/g,'&quot;');
      return '<label class="vp-item" data-name="'+esc.toLowerCase()+' '+dt.toLowerCase()+'" '+
        'style="display:flex;align-items:center;gap:8px;padding:5px 2px;cursor:pointer">'+
        '<input type="checkbox" class="'+prefix+'-chk" data-id="'+vx.id+'" data-name="'+esc+'" '+
        'data-dose="'+(vx.dose||'')+'" data-unit="'+(vx.unit||'ml')+'" data-rid="'+(vx.repeat_interval_days||'')+'" '+
        'onchange="'+prefix+'ChkChange(this)" style="width:18px;height:18px;accent-color:var(--green);flex-shrink:0;cursor:pointer">'+
        '<div style="flex:1;min-width:0"><div style="font-size:.82rem;font-weight:600;color:var(--ink)">'+vx.name+'</div>'+
        (dt?'<div style="font-size:.65rem;color:var(--ink3)">'+vx.disease_target+'</div>':'')+'</div></label>';
    }).join('');
    return '<div style="margin-bottom:8px"><div style="font-size:.65rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin-bottom:4px;padding:3px 0;border-bottom:1px solid var(--card3)">'+g+'</div>'+items+'</div>';
  }).join('');
  c.innerHTML =
    '<input class="fi" placeholder="Aşı ara…" oninput="vaccinePickerSearch(\''+prefix+'\',this.value)" style="margin-bottom:6px">'+
    '<div id="'+prefix+'-list" style="max-height:200px;overflow-y:auto;background:var(--card);border-radius:8px;padding:8px;border:1px solid var(--card3)">'+
    (groupHtml||'<div style="color:var(--ink3);font-size:.78rem;padding:8px">Aşı yok</div>')+'</div>'+
    '<div id="'+prefix+'-rows" style="margin-top:8px"></div>';
}

function vaccinePickerSearch(prefix, term){
  const t=(term||'').toLowerCase().trim();
  document.querySelectorAll('#'+prefix+'-list .vp-item').forEach(el=>{
    el.style.display = (!t || (el.dataset.name||'').includes(t)) ? 'flex' : 'none';
  });
}

// Seçili aşı satırlarını topla: [{id,name,dose,stdDose,offset,defOffset}]
function selectedVaccineRows(prefix){
  const out=[];
  document.querySelectorAll('.'+prefix+'-chk:checked').forEach(chk=>{
    const id=chk.dataset.id;
    const doseInp=document.querySelector('#'+prefix+'-row-'+id+' .vp-dose');
    const offInp =document.querySelector('#'+prefix+'-row-'+id+' .vp-off');
    out.push({
      id, name:chk.dataset.name,
      dose: doseInp && doseInp.value!=='' ? parseFloat(doseInp.value) : null,
      stdDose: chk.dataset.dose!=='' ? parseFloat(chk.dataset.dose) : null,
      offset: offInp && offInp.value!=='' ? parseInt(offInp.value,10) : null,
      defOffset: offInp && offInp.dataset.def!=='' ? parseInt(offInp.dataset.def,10) : null
    });
  });
  return out;
}

// ── AŞI MODAL (çoklu picker) ─────────────────
async function loadVaccinesDropdown() {
  // Ö4: naive hesabı için cache garanti (vaccination_log + vaccine_diseases + protocol_steps)
  await pullTables(['vaccination_log','vaccine_diseases','vaccine_protocol_steps']).catch(()=>{});
  await renderVaccinePicker('v-vaccine-picker','v');
  const _d=document.getElementById('v-date');
  if(_d && !_d.value) _d.value=bugun();
  // Ö5: hayvan değişince seçili satır hint'lerini yenile
  const _vh=document.getElementById('v-hid');
  if(_vh && !_vh._refreshBound){ _vh.addEventListener('change', _vRefreshRows); _vh._refreshBound=true; }
}

// muadil naive: hayvanın bu aşıyı kapsayan hastalık geçmişi var mı?
function _vaccineNaive(animalId, vaccineId){
  const logs=(getState('vaccination_log')||[]).filter(l=>l.animal_id===animalId);
  if(!logs.length) return true;
  const vd=getState('vaccine_diseases')||[];
  const myDis=new Set(vd.filter(x=>x.vaccine_id===vaccineId).map(x=>x.disease_id));
  for(const l of logs){
    if(l.vaccine_id===vaccineId) return false;
    const od=vd.filter(x=>x.vaccine_id===l.vaccine_id).map(x=>x.disease_id);
    if(od.some(d=>myDis.has(d))) return false;
  }
  return true;
}
function _vStep2(vaccineId){
  const s=(getState('vaccine_protocol_steps')||[]).find(x=>x.vaccine_id===vaccineId && x.adim_no===2);
  return s? s.offset_gun : null;
}
function vChkChange(chk){
  const id=chk.dataset.id, rows=document.getElementById('v-rows');
  if(!rows) return;
  if(chk.checked){
    const hid=v('v-hid');
    const hayvan=hayvanByKupeRef(hid); // K7: küpe eşleşmesinde aktif önce
    const naive=hayvan? _vaccineNaive(hayvan.id,id):true;
    const step2=_vStep2(id);
    const rid=chk.dataset.rid!==''?parseInt(chk.dataset.rid,10):null;
    let defOff=null, hint='';
    if(naive && step2!=null){ defOff=step2; hint='2. doz: +'+step2+'g'; }
    else if(rid!=null){ defOff=rid; hint='yıllık: +'+rid+'g'; }
    else hint='tekrar yok';
    const row=document.createElement('div');
    row.id='v-row-'+id;
    row.style.cssText='background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:8px;padding:8px;margin-bottom:6px';
    row.innerHTML='<div style="font-size:.78rem;font-weight:700;color:var(--green);margin-bottom:5px">'+chk.dataset.name+'</div>'+
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">'+
      '<input type="number" step="0.1" class="fi vp-dose" placeholder="Doz" value="'+(chk.dataset.dose||'')+'" style="margin:0">'+
      '<input type="number" class="fi vp-off" placeholder="Offset (g)" '+(defOff!=null?'value="'+defOff+'"':'')+' data-def="'+(defOff!=null?defOff:'')+'" style="margin:0">'+
      '</div>'+
      '<div style="font-size:.65rem;color:var(--ink3);margin-top:4px">⏰ '+hint+'</div>';
    rows.appendChild(row);
  } else { document.getElementById('v-row-'+id)?.remove(); }
}
// Hayvan değişince seçili satırların naive hint'lerini yeniden hesapla
function _vRefreshRows(){
  document.querySelectorAll('.v-chk:checked').forEach(chk=>{ document.getElementById('v-row-'+chk.dataset.id)?.remove(); vChkChange(chk); });
}

// ── AŞI UYGULA (tek hayvan, çoklu aşı) ───────
async function submitVaccination(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid = v('v-hid');
  const date = v('v-date');
  const notes = v('v-notes');
  const secili = selectedVaccineRows('v');
  if (!hid) { toast('⚠️ Hayvan seçin', true); return; }
  if (!secili.length) { toast('⚠️ En az bir aşı seçin', true); return; }
  if (!date) { toast('⚠️ Tarih girin', true); return; }
  if (date > bugun()) { toast('İleri tarih girilemez', true); return; }
  const hayvan = hayvanByKupeRef(hid); // K7: küpe eşleşmesinde aktif önce
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  let ok=0, fail=0, lastDue=null;
  try {
    for (const s of secili) {
      try {
        const res = await rpc('add_vaccination', {
          p_animal_id: hayvan.id, p_vaccine_id: s.id, p_date: date,
          p_dose_override: (s.dose!=null && s.dose!==s.stdDose) ? s.dose : null,
          p_notes: notes || null,
          p_next_offset_days: (s.offset!=null && s.offset!==s.defOffset) ? s.offset : null,
        });
        ok++; if (res && res.next_due) lastDue=res.next_due;
      } catch(e){ fail++; }
    }
    toast(`💉 ${ok} aşı kaydedildi${fail?` · ${fail} hata`:''}${(ok===1&&lastDue)?` · Sonraki: ${fmtTarih(lastDue)}`:''}`, fail>0);
    closeM('m-vaccine');
    resetVaccineForm();
    await pullTables(['vaccination_log', 'gorev_log', 'hayvanlar', 'stok_hareket']);
    renderSafe();
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = '💉 Aşı Uygula'; }
  }
}

function resetVaccineForm() {
  ['v-hid','v-date','v-notes'].forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
  if (typeof renderVaccinePicker === 'function') renderVaccinePicker('v-vaccine-picker','v');
}

// ── GÖREV TAMAMLA ────────────────────────────
async function doneTask(id, hid, stokId, miktar, padok, btn) {
  btn.disabled = true;
  btn.innerHTML = '<div class="spin" style="width:14px;height:14px;border-width:2px"></div>';
  try {
    await rpc('gorev_tamamla', { p_gorev_id: id, p_padok_hedef: padok || null });
    const el = document.getElementById('tc-' + id);
    if (el) { el.classList.add('done'); setTimeout(() => el.remove(), 320); }
    toast('✅ Tamamlandı');
    await pullTables(['gorev_log','hayvanlar']).catch(()=>{});
    if (typeof _islemSonrasiRefresh === 'function') _islemSonrasiRefresh();
    loadDash();
    // Sürü/padok listesini de tazele (grup/padok değiştiren görevler için — sütten kesme, padok değişim)
    if (typeof loadAnimals === 'function') loadAnimals().catch(()=>{});
  } catch (e) {
    btn.disabled = false;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';
    toast(getUserMessage(e), true);
  }
}

// Görev detay modal
// openTaskDet, detayTamamla, detayIptal → ui.js'te tanımlı (daha tam versiyon)

// Manuel görev ekle
// ── Planlı aşı görevi: tür seçimi + checkbox'lı aşı planlayıcı ──
// Tedavi plan modalindeki gruplu checkbox dilinin aşıya uyarlanması: birden çok aşı
// seçilebilir; her seçim için doz satırı açılır (standart doz dolu gelir).
let _taVaxCache = [];
async function taskAddTipDegisti(val){
  const alani=document.getElementById('ta-asi-alani');
  if(!alani) return;
  if(val!=='ASI_PLANLI'){ alani.style.display='none'; return; }
  alani.style.display='block';
  const dozSatirlari=document.getElementById('ta-doz-satirlari'); if(dozSatirlari) dozSatirlari.innerHTML='';
  try{
    let vaccines=(await getData('vaccines'))||[];
    if(!vaccines.length){ await pullTables(['vaccines']).catch(()=>{}); vaccines=(await getData('vaccines'))||[]; }
    const [stockRows,hmvs]=await Promise.all([getData('stok'),getData('stok_hareket')]);
    const kalalar=_asiStokKalanlar(vaccines,stockRows,hmvs);
    _taVaxCache=vaccines;
    const liste=document.getElementById('ta-vax-liste');
    if(!liste) return;
    const zorunlu=vaccines.filter(v=>v.is_mandatory), diger=vaccines.filter(v=>!v.is_mandatory);
    const gruplar={}; if(zorunlu.length) gruplar['Zorunlu Aşılar']=zorunlu; if(diger.length) gruplar['Diğer Aşılar']=diger;
    let html='';
    for(const [g,liste2] of Object.entries(gruplar)){
      html+=`<div style="font-size:.62rem;font-weight:800;color:var(--ink3);text-transform:uppercase;letter-spacing:.06em;margin:4px 0 2px">${g}</div>`;
      for(const vx of liste2){
        const kalan=kalalar[vx.id];
        const kalanClr=kalan==null?'var(--ink3)':(kalan<=0?'var(--red2)':(kalan<=10?'var(--amber)':'var(--green)'));
        const kalanTxt=kalan==null?'stok yok':`kalan ${kalan} ${vx.unit||'ml'}`;
        html+=`<label style="display:flex;align-items:center;gap:8px;padding:5px 2px;cursor:pointer;border-bottom:1px solid var(--card2)">
          <input type="checkbox" class="ta-vaxchk" data-id="${escAttr(vx.id)}" onchange="taskAddVaxChkChange(this)" style="width:17px;height:17px;accent-color:var(--green);cursor:pointer;flex-shrink:0">
          <span style="flex:1;min-width:0"><span style="font-size:.8rem;font-weight:600;color:var(--ink)">${esc(vx.name||vx.id)}</span>
          ${vx.dose?`<span style="font-size:.65rem;color:var(--ink3);margin-left:4px">standart ${vx.dose} ${vx.unit||'ml'}</span>`:''}</span>
          <span style="font-size:.66rem;font-weight:700;color:${kalanClr};flex-shrink:0">${kalanTxt}</span></label>`;
      }
    }
    liste.innerHTML=html||'<div style="color:var(--ink3);font-size:.78rem;padding:8px">Aşı yok</div>';
  }catch(e){ toast('Aşı listesi yüklenemedi', true); }
}
// Checkbox işaretlenince doz satırı aç/kapat (standart doz dolu gelir)
function taskAddVaxChkChange(chk){
  const satirlari=document.getElementById('ta-doz-satirlari'); if(!satirlari) return;
  const vax=_taVaxCache.find(v=>v.id===chk.dataset.id);
  const stdDoz=vax?.dose??'';
  const unit=vax?.unit||'ml';
  if(chk.checked){
    const row=document.createElement('div');
    row.id='ta-dozrow-'+chk.dataset.id;
    row.style.cssText='display:flex;align-items:center;gap:6px;background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:8px;padding:6px 8px;margin-bottom:5px';
    row.innerHTML=`<span style="font-size:.72rem;font-weight:700;color:var(--green);min-width:70px">${esc(chk.dataset.name||'')}</span>
      <input type="number" step="0.5" min="0.5" class="fi ta-doz-giris" data-vax="${escAttr(chk.dataset.id)}" value="${escAttr(stdDoz)}" placeholder="doz" style="width:80px;margin:0;padding:5px 8px">
      <span style="font-size:.68rem;color:var(--ink3)">${unit}</span>`;
    satirlari.appendChild(row);
  } else {
    document.getElementById('ta-dozrow-'+chk.dataset.id)?.remove();
  }
}
// İşaretli aşıları topla → [{vaccine_id,doz,name,unit}] (doz girilmemişse standart)
function taskAddSeciliAsilar(){
  const out=[];
  document.querySelectorAll('.ta-vaxchk:checked').forEach(chk=>{
    const row=document.getElementById('ta-dozrow-'+chk.dataset.id);
    const inp=row?.querySelector('.ta-doz-giris');
    const vax=_taVaxCache.find(v=>v.id===chk.dataset.id);
    const doz=inp&&inp.value!==''?parseFloat(inp.value):(vax?.dose??null);
    out.push({ vaccine_id:chk.dataset.id, doz, name:vax?.name||chk.dataset.name, unit:vax?.unit||'ml' });
  });
  return out;
}
// Manuel görev formunu her açılışta sıfırla (bayat tip/doz/aşı taşınmaz)
function taskAddFormSifirla(){
  const tt=document.getElementById('ta-tip'); if(tt) tt.value='MANUEL';
  ['ta-hid','ta-desc'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  document.querySelectorAll('.ta-vaxchk:checked').forEach(c=>{ c.checked=false; });
  const ds=document.getElementById('ta-doz-satirlari'); if(ds) ds.innerHTML='';
  taskAddTipDegisti('');
}
// Hayvanın 1 yıl içinde aynı hastalığı kapsayan aşısı var mı? (marka bağımsız; _vaccineNaive'in 1 yıllık hali)
function _asiTekrarUyariBilgisi(hayvanId, vaccineId){
  const sinir=new Date(); sinir.setDate(sinir.getDate()-365);
  const isoSinir=sinir.toISOString().slice(0,10);
  const logs=(getState('vaccination_log')||[]).filter(l=>l.animal_id===hayvanId&&l.vaccination_date&&l.vaccination_date>=isoSinir);
  if(!logs.length) return null;
  const vd=getState('vaccine_diseases')||[];
  const myDis=new Set(vd.filter(x=>x.vaccine_id===vaccineId).map(x=>x.disease_id));
  const vaxlar=getState('vaccines')||[];
  for(const l of logs.sort((a,b)=>(b.vaccination_date||'').localeCompare(a.vaccination_date||''))){
    const ad=(vaxlar.find(v=>v.id===l.vaccine_id)||{}).name||'aşı';
    if(l.vaccine_id===vaccineId) return { tarih:l.vaccination_date, ad };
    const od=vd.filter(x=>x.vaccine_id===l.vaccine_id).map(x=>x.disease_id);
    if(od.some(d=>myDis.has(d))) return { tarih:l.vaccination_date, ad };
  }
  return null;
}

async function submitTaskAdd(btn) {
  const desc  = v('ta-desc');
  const tarih = v('ta-tarih');
  const tip   = v('ta-tip');
  const planli = tip==='ASI_PLANLI';
  if (planli ? !tarih : (!desc || !tarih)) { toast(planli?'Tarih zorunlu':'Açıklama ve Tarih zorunlu', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Oluşturuluyor…'; }
  try {
    const hid    = v('ta-hid').trim();
    // B15: devlet_kupe de denenir; serbest metin hayvana bağlanamıyorsa görev
    // yaratılmaz — eskiden yazılan string gorev_log.hayvan_id'ye giriyor, gece
    // cron'u (gorev_orphan_temizle) görevi sessizce siliyordu
    const hayvan = hid ? hayvanByKupeRef(hid) : null; // K7: küpe eşleşmesinde aktif önce
    if (hid && !hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil — hayvan alanını boş bırakırsanız genel görev oluşur`, true); return; }
    if (planli) {
      // Planlı aşı: checkbox'lı çoklu seçim → tek kart (+ alt görevler), stok plan anında rezerve.
      if (!navigator.onLine) { toast('⚠️ Planlı aşı için internet gerekli (stok rezervasyonu)', true); return; }
      const items = taskAddSeciliAsilar();
      if (!items.length) { toast('En az bir aşı seçin', true); return; }
      if (items.some(it => !it.doz || it.doz <= 0)) { toast('Seçili tüm aşılar için geçerli doz girin (ml)', true); return; }
      if (!hayvan) { toast('Planlı aşı görevi için küpe zorunlu', true); return; }
      // Mükerrer plan: aynı hayvan + aynı aşı + aynı gün için açık görev varsa engel
      const acikPlanlilar = (await getData('gorev_log', g => g.gorev_tipi==='ASI_PLANLI' && !g.tamamlandi && !g.iptal && g.hedef_tarih===tarih)) || [];
      const cakisan = [];
      for (const it of items) {
        const v = _taVaxCache.find(vv => vv.id === it.vaccine_id);
        if (v?.stock_item_id && acikPlanlilar.some(g => g.stok_id === v.stock_item_id && g.hayvan_id === hayvan.id)) cakisan.push(v.name);
      }
      if (cakisan.length) { toast('⚠️ Bu tarih için zaten planlı: ' + cakisan.join(', '), true); return; }
      // Tekrar uyarısı: 1 yıl içinde aynı hastalığı kapsayan aşı (marka bağımsız) — engel değil
      await pullTables(['vaccination_log','vaccine_diseases']).catch(()=>{});
      const uyariSatirlari = items.map(it => {
        const u = _asiTekrarUyariBilgisi(hayvan.id, it.vaccine_id);
        return u ? `• ${it.name}: bu hayvan ${fmtTarih(u.tarih)} tarihinde "${u.ad}" olmuş` : null;
      }).filter(Boolean);
      const olustur = async () => {
        let res;
        if (items.length === 1) {
          res = await rpc('asi_gorev_planla', { p_hayvan_id: hayvan.id, p_vaccine_id: items[0].vaccine_id, p_doz: items[0].doz, p_tarih: tarih, p_aciklama: desc || null });
        } else {
          res = await rpc('asi_toplu_planla', { p_hayvan_id: hayvan.id, p_tarih: tarih, p_items: items.map(it => ({ vaccine_id: it.vaccine_id, doz: it.doz })), p_aciklama: desc || null }); // jsonb param → dizi (string scalar OLMAZ)
        }
        if (!res || res.ok === false) { toast(getUserMessage(res?.mesaj || 'Hata'), true); return; }
        await pullTables(['stok','stok_hareket']).catch(()=>{});
        toast(items.length > 1 ? `✅ Toplu aşı görevi (${items.length} aşı) — stok rezerve edildi` : '✅ Planlı aşı görevi oluşturuldu — stok rezerve edildi');
        closeM('m-task-add');
        taskAddFormSifirla();
        await loadTasks(_curTaskFilter || 'today');
        loadDash();
      };
      if (uyariSatirlari.length) {
        openConfirm('⚠️ Tekrar aşı uyarısı', uyariSatirlari.join('\n') + '\n\nYine de kaydetmek istiyor musunuz?', olustur);
        return;
      }
      await olustur();
      return;
    } else {
      await write('gorev_log', {
        id: crypto.randomUUID(), hayvan_id: hayvan?.id || null,
        gorev_tipi: tip, aciklama: desc, hedef_tarih: tarih,
        tamamlandi: false, kaynak: 'MANUEL'
      });
      toast('✅ Görev oluşturuldu');
      closeM('m-task-add');
      taskAddFormSifirla();
      await loadTasks(_curTaskFilter || 'today');
      loadDash();
    }
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Görev Oluştur'; } }
}

async function submitTaskEdit(btn) {
  if(!_curTaskDet) return;
  const desc  = v('te-desc');
  const tarih = v('te-tarih');
  if (!desc || !tarih) { toast('Açıklama ve Tarih zorunlu', true); return; }
  const t=_curTaskDet;
  const tip=v('te-tip');
  // Planlı aşı görevinin türü değiştirilemez — aktif stok rezervasyonu boşa düşer.
  if(t.gorev_tipi==='ASI_PLANLI' && tip!=='ASI_PLANLI'){
    toast('⚠️ Planlı aşı görevinin türü değiştirilemez — iptal edip yeniden oluşturun (stok iade edilir)', true); return;
  }
  const degisen={};
  if(t.aciklama!==desc) degisen.aciklama=desc;
  if(t.hedef_tarih!==tarih) degisen.hedef_tarih=tarih;
  if(t.gorev_tipi!==tip) degisen.gorev_tipi=tip;
  if(Object.keys(degisen).length===0){
    toast('Hiçbir değişiklik yapılmadı'); return;
  }
  // Diff mesajı oluştur
  const tipEtiket={MANUEL:'📋 Genel',TEDAVI:'🚑 Tedavi',ILAC_UYGULAMA:'💊 İlaç',PADOK_DEGISIM:'🐄 Padok',MUAYENE:'🩺 Muayene',ASI_PLANLI:'💉 Aşı (Planlı)',ILERI_GEBE_ASI:'💉 Aşı (İleri Gebe)',ILERI_GEBE:'💊 Takviye',SUTTEN_KESME:'🍼 Sütten',DIGER:'📂 Diğer'};
  const diffSatirlari=[];
  if('aciklama' in degisen) diffSatirlari.push('📝 Açıklama: "'+(t.aciklama||'')+'" → "'+desc+'"');
  if('hedef_tarih' in degisen) diffSatirlari.push('📅 Tarih: '+(t.hedef_tarih||'')+' → '+tarih);
  if('gorev_tipi' in degisen) diffSatirlari.push('🏷 Tür: '+(tipEtiket[t.gorev_tipi]||t.gorev_tipi)+' → '+(tipEtiket[tip]||tip));
  openConfirm('✏️ Görevi Düzenle', diffSatirlari.join('\n'), async() => kaydetTaskEdit(btn, t, degisen));
}

async function kaydetTaskEdit(btn, t, degisen) {
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('gorev_guncelle', {
      p_id: t.id,
      p_aciklama: degisen.aciklama ?? null,
      p_hedef_tarih: degisen.hedef_tarih ?? null,
      p_gorev_tipi: degisen.gorev_tipi ?? null
    });
    toast('✅ Görev güncellendi');
    closeM('m-task-edit');
    await loadTasks(_curTaskFilter||'today');
    loadDash();
    _curTaskDet={...t,...degisen};
    openTaskDet(t.id);
  } catch(e){ toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '💾 Kaydet'; } }
}

// ── HASTALIK KAPAT ───────────────────────────
async function hstKapat() {
  if (!_curHst) return;
  try {
    const res = await rpc('hastalik_kapat', { p_id: _curHst.id });
    toast('✅ Hastalık kaydı kapatıldı');
    closeM('m-hst-det');
    await pullTables(['cases']); renderSafe();
  } catch(e) { toast('❌ ' + getUserMessage(e), true); }
}

// _editMode: true iken submitDisease → hastalik_guncelle çağırır
let _editMode = false;

function closeDisease() {
  _editMode = false;
  globalThis._kizginlikTedaviId = null;
  const t = document.getElementById('m-disease-title');
  if (t) t.textContent = '🏥 Hastalık / Tedavi';
  ['d-hid','d-tani','d-sempt','d-lokasyon'].forEach(id => { const e = document.getElementById(id); if(e) e.value=''; });
  const kat = document.getElementById('d-kat'); if(kat) kat.value='';
  const sid = document.getElementById('d-sid'); if(sid) sid.value='';
  const gun = document.getElementById('d-tedavi-gun'); if(gun) gun.value='0';
  const dHid = document.getElementById('d-hid'); if(dHid){ dHid.readOnly=false; dHid.style.opacity=''; }
  if(g('ilac-rows')) g('ilac-rows').innerHTML='';
  if(g('tani-secenekler')) g('tani-secenekler').innerHTML='';
  if(g('sempt-chips')) g('sempt-chips').innerHTML='';
  if(g('d-lokasyon-wrap')) g('d-lokasyon-wrap').style.display='none';
  const gunWrap = document.getElementById('d-tedavi-gun')?.closest('.fg');
  if(gunWrap) gunWrap.style.display='';
  globalThis._semptomSecili = [];
  _ilacCache = [];
  closeM('m-disease');
}

function hstDuzenleAc() {
  if (!_curHst) return;
  _editMode = true;
  const t = document.getElementById('m-disease-title');
  if (t) t.textContent = '✏️ Hastalık Düzenle';
  const dHid = document.getElementById('d-hid');
  if (dHid) {
    const hayvan = getState('animals').find(a => a.id === _curHst.hayvan_id);
    dHid.value = hayvan ? (hayvan.kupe_no || hayvan.devlet_kupe || '') : '';
    dHid.readOnly = true;
    dHid.style.opacity = '0.6';
  }
  const dKat = document.getElementById('d-kat');
  if (dKat) { dKat.value = _curHst.kategori || ''; filterHastalikList(); }
  const dSid = document.getElementById('d-sid');
  if (dSid) dSid.value = _curHst.siddet || '';
  const dTani = document.getElementById('d-tani');
  if (dTani) dTani.value = _curHst.tani || '';
  globalThis._semptomSecili = [];
  const semptChips = g('sempt-chips');
  if (semptChips) semptChips.innerHTML = '';
  if (g('d-sempt')) g('d-sempt').value = '';
  const mevSemptomlar = (_curHst.semptomlar || '').split(',').map(s => s.trim()).filter(Boolean);
  mevSemptomlar.forEach(val => {
    if (_semptomSecili.includes(val)) return;
    _semptomSecili.push(val);
    const chips = g('sempt-chips'); if (!chips) return;
    const chip = document.createElement('span');
    chip.style.cssText = 'display:inline-flex;align-items:center;gap:4px;padding:4px 10px;background:rgba(42,107,181,.12);border:1px solid rgba(42,107,181,.25);border-radius:20px;font-size:.72rem;font-weight:700;color:var(--blue);cursor:pointer';
    chip.innerHTML = `${esc(val)} <span style="font-size:.9rem;opacity:.7" data-val="${escAttr(val)}" onclick="semptomKaldir(this.dataset.val,this.parentElement)">✕</span>`;
    chips.appendChild(chip);
    if (g('d-sempt')) g('d-sempt').value = _semptomSecili.join(', ');
  });
  updateSemptomDropdown(_curHst.kategori || '');
  if (g('d-lokasyon')) g('d-lokasyon').value = _curHst.lokasyon || '';
  const dHekim = document.getElementById('d-hekim');
  if (dHekim && _curHst.hekim_id) dHekim.value = _curHst.hekim_id;
  const gunWrap = document.getElementById('d-tedavi-gun')?.closest('.fg');
  if (gunWrap) gunWrap.style.display = 'none';
  if(g('ilac-rows')) g('ilac-rows').innerHTML='';
  closeM('m-hst-det');
  openM('m-disease');
}


async function hstGuncelle(btn) {
  if (!_curHst) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const res = await rpc('hastalik_guncelle', {
      p_id:         _curHst.id,
      p_tani:       v('d-tani')     || null,
      p_kategori:   v('d-kat')      || null,
      p_siddet:     v('d-sid')      || null,
      p_semptomlar: v('d-sempt')    || null,
      p_lokasyon:   v('d-lokasyon') || null,
      p_hekim_id:   v('d-hekim')    || null,
    });
    toast('✅ Güncellendi');
    closeDisease();
    await pullTables(['cases']);
    await renderFromLocal();
  } catch(e) { toast('❌ ' + getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🏥 Kaydet + Görevler'; } }
}

async function hstSilOnay() {
  if (!_curHst) return;
  const onay = confirm(`"${_curHst.tani || 'Bu kayıt'}" silinecek. Emin misin?`);
  if (!onay) return;
  try {
    const res = await rpc('hastalik_sil', { p_id: _curHst.id });
    toast('🗑 Kayıt silindi');
    closeM('m-hst-det');
    await pullTables(['cases']); renderSafe();
  } catch(e) { toast('❌ ' + getUserMessage(e), true); }
}

// ── TOHUMLAMA SONUÇ ──────────────────────────
// openTohDet → ui.js'de tanımlı
async function tohSonucKaydet() {
  const sel = document.querySelector('input[name="toh-sonuc"]:checked');
  if (!sel) { toast('Sonuç seçin'); return; }
  await tohSonuc(sel.value);
}
async function tohSonuc(sonuc, btn) {
  if (!_curToh) return;
  if (_curToh.sonuc === 'Gebe' || _curToh.sonuc === 'Doğum Yaptı') {
    toast('⛔ Bu kayıt değiştirilemez — hayvan kartını kullanın', true); return;
  }
  if (sonuc === 'Boş' && !confirm('Bu tohumlama kaydı "Boş" olarak işaretlenecek. Emin misiniz?')) return;

  try {
    let rpcName, successMsg;
    if (sonuc === 'Gebe') {
      rpcName = 'tohumlama_sonuc_gebe';
      successMsg = '✅ Gebe olarak işaretlendi';
    } else if (sonuc === 'Boş') {
      const res = await rpc('tohumlama_sonuc_bos', { p_tohumlama_id: _curToh.id });
      if (!res.ok) { toast(res.mesaj || 'Hata'); return; }
      successMsg = 'Boş olarak işaretlendi';
    } else {
      const res = await rpc('tohumlama_sonuc_bekliyor', { p_tohumlama_id: _curToh.id });
      if (!res.ok) { toast(res.mesaj || 'Hata'); return; }
      successMsg = 'Bekliyor\'a alındı';
    }

    if (rpcName) {
      const res = await rpc(rpcName, { p_tohumlama_id: _curToh.id });
      if (!res.ok) { toast(res.mesaj || 'Hata'); return; }
    }
    toast(successMsg);
    await pullTables(['tohumlama', 'hayvanlar', 'islem_log']);
    closeM('m-toh-det');
    const detEl = document.getElementById('det');
    if (detEl && detEl.classList.contains('on') && _curToh.hayvan_id) {
      await openDet(_curToh.hayvan_id, true);
    }
    await renderFromLocal();
  } catch (e) {
    // rpc() iş kuralı mesajlarını (data.mesaj / RAISE) zaten Türkçe fırlatır —
    // generic "tekrar deneyin"e çevirme, spesifik mesajı göster.
    toast('❌ Sonuç kaydedilemedi: ' + (e?.message || getUserMessage(e)), true);
  }
}

// ── GEBELİK İŞARETLE ────────────────────────
// ── GERİ ALMA ────────────────────────────────
function openGeriAl(islemLogId, ozet) {
  const a = Math.floor(Math.random()*9)+1;
  const b = Math.floor(Math.random()*9)+1;
  g('ga-hid').value = islemLogId;
  g('ga-ozet').textContent = ozet || 'Bu işlem geri alınacak.';
  g('ga-math-label').textContent = `${a} + ${b}`;
  g('ga-math-ans').value = '';
  g('ga-math-ok').value = String(a + b);
  openM('m-geri-al');
}
// ── İşlem Geri Al ──────────────────────────
async function islemGeriAl(btn, islemLogId) {
  const expected = parseInt(g('ga-math-ok').value);
  const given    = parseInt(g('ga-math-ans').value);
  if (isNaN(given) || given !== expected) { toast('⚠️ Hatalı onay cevabı', true); return; }
  if (!navigator.onLine) { toast('⚠️ Geri alma için internet gerekli', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Geri alınıyor…'; }

  try {
    // Doğrudan tohumlama silme (islem_log olmayan kayıtlar — agent/manuel)
    if (String(islemLogId).startsWith('toh:')) {
      const tohId = islemLogId.slice(4);
      const res = await rpc('tohumlama_geri_al', { p_tohumlama_id: tohId });
      toast('✅ Kayıt silindi');
      closeM('m-geri-al'); closeM('m-toh-det');
      await pullTables(['tohumlama','gorev_log','hayvanlar','kizginlik_log','islem_log']);
      renderSafe();
      return;
    }

    const islemList = await idbGetAll('islem_log');
    const islem = islemList.find(i => i.id === islemLogId);
    if (!islem) { toast('⚠️ İşlem bulunamadı', true); return; }

    let rpcName = 'geri_al';
    let rpcParams = { p_islem_id: islemLogId };

    // Domain-specific geri alma
    if ((islem.tip === 'TOHUMLAMA' || islem.tip === 'TOHUMLAMA_GUNCELLENDI') && islem.ref_id) {
      rpcName = 'tohumlama_geri_al';
      rpcParams = { p_tohumlama_id: islem.ref_id };
    } else if (islem.tip === 'HASTALIK_KAYDI') {
      // islem_log'daki HASTALIK_KAYDI eski hastalik_log tablosundan gelir
      // cases tablosu icin trigger henuz eklenmedi, generic geri_al RPC kullan
      rpcName = 'geri_al';
      rpcParams = { p_islem_id: islemLogId };
    } else if (islem.tip === 'VAKA_ACILDI' || islem.tip === 'TEDAVI_GUN_EKLENDI') {
      rpcName = 'geri_al';
      rpcParams = { p_islem_id: islemLogId };
    }

    const res = await rpc(rpcName, rpcParams);
    toast('✅ İşlem geri alındı');
    closeM('m-geri-al');
    closeM('m-toh-det');
    closeM('m-case-det');
    await pullTables(['tohumlama','gorev_log','hayvanlar','kizginlik_log','cases','treatment_days','stok_hareket','islem_log','drug_administrations']);
    renderSafe();
  } catch (e) {
    const sebep = e?.message || String(e);
    toast('❌ Geri alma başarısız: ' + sebep, true);
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'İşlemi Geri Al'; }
  }
}

// ── STOK ─────────────────────────────────────
async function submitStk(btn) {
  const mik = Number.parseFloat(g('se-mik').value);
  if (!mik || mik <= 0) { toast('Geçerli miktar girin', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Ekleniyor…'; }
  try {
    const curStk=getState('curStok');
    await rpc('stok_ekleme', { p_stok_id: curStk.id, p_miktar: mik, p_notlar: 'Manuel ekleme' });
    toast(`✅ ${curStk.urun_adi}: +${mik} ${curStk.birim || ''}`);
    closeM('m-stk');
    await pullTables(['stok','stok_hareket']);
    await loadStock();
    loadDash();
    const _sp = document.getElementById('stok-panel');
    if(_sp?.style.transform !== 'translateX(100%)') loadStokPanel();
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Stok Ekle'; } }
}

async function submitStokAdd(btn) {
  const kat  = g('sa-kat')?.value || 'Antibiyotik';
  if(navigator.onLine) await pullTables(['stok_kategorileri']);
  const allKats = (await idbGetAll('stok_kategorileri')) || [];
  const isIlac = allKats.some(k => k.tip === 'ilac' && k.ad === kat);
  const isSperma = kat === 'Sperma';
  // İsim alanı tipe göre değişiyor
  const urun = isIlac
    ? (g('sa-ad')?.value||'').trim()
    : (g('sa-ad-diger')?.value||'').trim();
  if (!urun) { toast('İsim zorunlu', true); return; }
  const bslg = Number.parseFloat(g('sa-mik')?.value||'0');
  const birim = g('sa-birim')?.value || 'adet';
  const esik  = Number.parseFloat(g('sa-esik')?.value||'0') || 0;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    // Aynı isimde stok var mı? Varsa miktarı ekle
    const mevcutlar = await idbGetAll('stok');
    const mevcut = mevcutlar.find(s => s.urun_adi?.toLowerCase() === urun.toLowerCase() && s.kategori === kat);
    let stokId;
    if (mevcut) {
      // Miktarı güncelle (RPC — stok_hareket ile immutable)
      stokId = mevcut.id;
      await rpc('stok_ekleme', { p_stok_id: stokId, p_miktar: bslg, p_notlar: `Stok güncellendi: ${urun}` });
      toast(`✅ ${urun} stoku güncellendi (+${bslg} ${birim})`);
    } else if (isIlac) {
      // YENİ İLAÇ — katalog (etken madde) ZORUNLU. Stok oluşturmadan ÖNCE doğrula.
      // İlaç kataloglanmadan eklenemez (tasarım kuralı); stok+drug_product atomik yazılır.
      if (!navigator.onLine) { toast('İlaç eklemek için internet gerekli (katalog kaydı)', true); return; }
      const etkenId = g('sa-etken')?.value || null;
      if (!etkenId) { toast('Etken madde zorunlu — ilaç kataloglanmadan eklenemez', true); return; }
      // "100mg/ml" gibi tek alandan değer+birim ayrıştırılır — eskiden değerin
      // kendisi p_concentration_unit'a gidiyordu (B29: birim alanına çöp veri)
      const route = g('sa-route')?.value || 'IM';
      const konstRaw = g('sa-konst')?.value?.trim() || null;
      let konstVal = null, konstUnit = null;
      if (konstRaw) {
        const km = konstRaw.match(/^(\d+(?:[.,]\d+)?)\s*([a-zA-Zµμ][a-zA-Zµμ\/]*)?$/);
        if (km) { konstVal = parseFloat(km[1].replace(',', '.')); konstUnit = km[2] || null; }
      }
      const r = await rpc('ilac_ekle', {
        p_urun_adi:           urun,
        p_kategori:           kat,
        p_birim:              birim,
        p_baslangic_miktar:   bslg,
        p_esik:               esik,
        p_drug_class_id:      etkenId,
        p_concentration:      konstVal,
        p_concentration_unit: konstUnit,
        p_default_route:      route
      });
      stokId = r?.stok_id;
      _drugsCache = [];
      toast(`✅ ${urun} eklendi (kataloglu)`);
    } else {
      // Yeni kayıt — ilaç olmayan stok kalemi
      const r = await rpc('stok_ekle', { p_urun_adi: urun, p_kategori: kat, p_birim: birim, p_baslangic_miktar: bslg, p_esik: esik });
      stokId = r?.id;
      toast(`✅ ${urun} eklendi`);
    }
    closeM('m-stok-add');
    ['sa-ad','sa-ad-diger','sa-mik','sa-esik','sa-konst'].forEach(id=>{const e=g(id);if(e)e.value='';});
    await pullTables(['stok','drug_products']);
    _drugsCache = [];
    const _sp = document.getElementById('stok-panel');
    if(_sp?.style.transform !== 'translateX(100%)') await loadStokPanel();
  } catch (e) { console.error('[StokAdd]', e); toast('❌ Stok eklenemedi: ' + (e?.message || getUserMessage(e)), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '💾 Kaydet'; } }
}


// ── GEBELİK EKLE ─────────────────────────────
async function submitGebelikEkle(btn) {
  const modal = document.getElementById('m-gebelik');
  const hayvanId = modal?._hayvanId;
  if (!hayvanId) { toast('Hayvan seçilmedi', true); return; }
  const tarih = g('geb-tarih')?.value;
  if (!tarih) { toast('Tarih zorunlu', true); return; }
  const bugunTr = bugun();
  if (tarih > bugunTr) { toast('İleri tarih girilemez', true); return; }
  const sperma = (g('geb-sperma')?.value||'').trim();
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('gebelik_kaydet_manual', { p_hayvan_id: hayvanId, p_tarih: tarih, p_sperma: sperma || null });
    toast('✅ Gebelik kaydedildi');
    closeM('m-gebelik');
    await pullTables(['tohumlama','hayvanlar']);
    renderSafe();
  } catch(e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; } }
}

// ── BİLDİRİM ─────────────────────────────────
async function bildirimGoruldu(bildirimId) {
  try {
    await write('bildirim_log', { durum: 'goruldu' }, 'PATCH', `id=eq.${bildirimId}`);
    loadBildirimler(_curBildirimTab || 'bekliyor');
    updateBildirimBadge();
  } catch (e) { toast(getUserMessage(e), true); }
}

// bildirimKontrol: ui.js'teki M-26 düzeltmeli (dedup + tag + 3-saat-öncesi
// hatırlatma) sürüm kullanılır — buradaki eskisi (B11) yükleme sırası
// gereği kazanıp saatlik tekrarlayan bildirim spam'i üretiyordu. Silindi.

async function bildirimIzniAl() {
  if (!('Notification' in window)) { toast('Tarayıcınız bildirimleri desteklemiyor', true); return false; }
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
  if (isIOS && !window.navigator.standalone) { toast('iOS: Önce Ana Ekrana Ekle yapın, sonra bildirimleri açın', true); return false; }
  if (Notification.permission === 'granted') return true;
  if (Notification.permission === 'denied') { toast('Bildirim izni reddedilmiş — tarayıcı ayarlarından açın', true); return false; }
  const result = await Notification.requestPermission();
  return result === 'granted';
}

async function bildirimAc() {
  const izin = await bildirimIzniAl();
  if (izin) { toast('✅ Bildirimler açık!'); localStorage.setItem('bildirim_aktif', '1'); bildirimKontrol(); }
  else { toast('⚠️ Bildirim izni verilmedi', true); }
}

// ──────────────────────────────────────────
// T-07 — İLAÇ YÖNETİMİ (hastalık detay)
// ──────────────────────────────────────────

function hstIlacFormToggle() {
  const f = document.getElementById('hd-ilac-form');
  if (!f) return;
  const visible = f.style.display !== 'none';
  f.style.display = visible ? 'none' : 'block';
  if (!visible) {
    document.getElementById('hdi-stok-ac').value = '';
    document.getElementById('hdi-stok-id').value = '';
    document.getElementById('hdi-birim').value = '';
    document.getElementById('hdi-miktar').value = '';
    document.getElementById('hdi-yol').value = '';
    document.getElementById('hdi-bekleme').value = '';
    document.getElementById('ac-hdi').style.display = 'none';
    globalThis._hdiIlacCache = [];
  }
}

async function hstIlacEkle(btn) {
  const stokId  = document.getElementById('hdi-stok-id').value.trim();
  const miktar  = Number.parseFloat(document.getElementById('hdi-miktar').value);
  const yol     = document.getElementById('hdi-yol').value;
  const bekleme = parseInt(document.getElementById('hdi-bekleme').value) || null;
  if (!stokId)       { toast('❌ İlaç seçin', true); return; }
  if (!miktar || miktar <= 0) { toast('❌ Miktar girin', true); return; }
  if (!_curHst?.id)  { toast('❌ Hastalık kaydı bulunamadı', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const res = await rpc('tedavi_ekle', {
      p_vaka_id:       _curHst.id,
      p_hayvan_id:     _curHst.hayvan_id,
      p_ilac_stok_id:  stokId,
      p_miktar:        miktar,
      p_uygulama_yolu: yol || null,
      p_bekleme_gun:   bekleme,
      p_hekim_id:      null,
    });
    toast('✅ İlaç kaydedildi');
    hstIlacFormToggle();
    await renderHstIlaclar(_curHst.id);
    pullTables(['tedavi','stok','stok_hareket']).then(renderSafe).catch(console.warn);
  } catch(e) { toast('❌ ' + getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '💾 İlaç Kaydet'; } }
}


async function hstIlacSil(tedaviId) {
  if (!confirm('Bu ilaç kaydı silinsin mi?')) return;
  try {
    const res = await rpc('tedavi_sil', { p_tedavi_id: tedaviId });
    toast('✅ İlaç silindi');
    await renderHstIlaclar(_curHst.id);
    pullTables(['tedavi','stok','stok_hareket']).then(renderSafe).catch(console.warn);
  } catch(e) { toast('❌ ' + getUserMessage(e), true); }
}

// ── İLAÇ–STOK BAĞLAMA ────────────────────────────────────────
async function submitDrugStokLink(drugId, stockItemId) {
  // Boş string → NULL (bağlantı kaldır)
  const stockId = stockItemId || null;
  try {
    const res = await rpc('link_drug_to_stock', {
      p_drug_id:       drugId,
      p_stock_item_id: stockId,
    });
    toast(stockId ? '✅ Stok bağlantısı kaydedildi' : '✅ Bağlantı kaldırıldı');
    // drugs cache'ini güncelle (IDB + _drugsCache)
    _drugsCache = [];
    await pullTables(['drugs']);
  } catch(e) { toast('❌ ' + getUserMessage(e), true); }
}

// ── TOPLU AŞILAMA ─────────────────────────────────────────────
async function loadBulkVaccinePadoklar() {
  const animals = getState('animals');
  if (!animals || !animals.length) return;
  const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'}));
  const sel = document.getElementById('bv-padok');
  if (!sel) return;
  sel.innerHTML = '<option value="">— Padok Seç —</option>' +
    padoklar.map(p => `<option value="${p}">${p}</option>`).join('');
}

async function loadBulkVaccineHayvanlar() {
  const padok = document.getElementById('bv-padok')?.value;
  if (!padok) { toast('Padok seçin'); return; }
  const animals = getState('animals').filter(a => a.padok === padok);
  const list = document.getElementById('bv-hayvan-list');
  const count = document.getElementById('bv-count');
  if (count) count.textContent = animals.length > 0 ? animals.length : '';
  if (list) {
    if (!animals.length) {
      list.style.display = 'none';
      list.innerHTML = '';
    } else {
      list.style.display = 'block';
      list.innerHTML = animals.map(a =>
        `<span style="font-size:.72rem;background:var(--card2);padding:2px 6px;border-radius:4px;margin:2px;display:inline-block">
          ${esc(a.kupe_no || a.devlet_kupe || a.id)}
        </span>`
      ).join('');
    }
  }
  // Store selected animal IDs for submit
  window._bvAnimalIds = animals.map(a => a.id);
}

async function loadBulkVaccineVaccines() {
  // Ö4: muadil/protokol cache (bulk'ta naive hint yok ama tutarlilik icin)
  await pullTables(['vaccine_diseases','vaccine_protocol_steps']).catch(()=>{});
  await renderVaccinePicker('bv-vaccine-picker','bv');
  const dateEl = document.getElementById('bv-tarih');
  if (dateEl && !dateEl.value) dateEl.value = bugun();
  const r=document.getElementById('bv-result'); if(r) r.innerHTML=''; // Ö8: eski sonucu temizle
}

// Bulk'ta naive hint YOK (çok hayvan) — sadece doz satırı, .vp-off yok
function bvChkChange(chk){
  const id=chk.dataset.id, rows=document.getElementById('bv-rows');
  if(!rows) return;
  if(chk.checked){
    const row=document.createElement('div');
    row.id='bv-row-'+id;
    row.style.cssText='background:rgba(78,154,42,.06);border:1px solid rgba(78,154,42,.2);border-radius:8px;padding:8px;margin-bottom:6px';
    row.innerHTML='<div style="font-size:.78rem;font-weight:700;color:var(--green);margin-bottom:5px">'+chk.dataset.name+'</div>'+
      '<input type="number" step="0.1" class="fi vp-dose" placeholder="Doz (boş=standart '+(chk.dataset.dose||'?')+')" value="'+(chk.dataset.dose||'')+'" style="margin:0">';
    rows.appendChild(row);
  } else { document.getElementById('bv-row-'+id)?.remove(); }
}

async function submitBulkVaccination() {
  const animalIds = window._bvAnimalIds || [];
  if (!animalIds.length) { toast('Önce hayvanları getirin'); return; }
  const secili = selectedVaccineRows('bv');
  if (!secili.length) { toast('En az bir aşı seçin'); return; }
  const tarih = document.getElementById('bv-tarih')?.value;
  if (!tarih) { toast('Tarih girin'); return; }
  const notes = document.getElementById('bv-notes')?.value || null;

  const submitBtn = document.querySelector('[data-action="submit-bv"]');
  if (submitBtn) submitBtn.disabled = true;
  let totOk=0, totErr=0;
  try {
    for (const s of secili) {
      try {
        const r = await rpc('bulk_vaccination', {
          p_animal_ids: animalIds, p_vaccine_id: s.id, p_date: tarih,
          p_dose_ml: (s.dose!=null && s.dose!==s.stdDose) ? s.dose : null, p_notes: notes });
        totOk += (r.success||0); totErr += ((r.errors||[]).length);
      } catch(e){ totErr += animalIds.length; }
    }
    const div = document.getElementById('bv-result');
    if (div) div.innerHTML = `<div style="margin-top:8px;font-size:.8rem">✅ ${totOk} uygulama${totErr?` · ⚠️ ${totErr} hata`:''}</div>`;
    if (totOk>0) {
      toast(`✅ ${animalIds.length} hayvan × ${secili.length} aşı`);
      pullTables(['vaccination_log','gorev_log','stok_hareket','islem_log']).catch(()=>{});
    } else {
      toast(`⚠️ Hiçbir aşı uygulanamadı${totErr?` · ${totErr} hata`:''}`, true);
    }
  } catch(e) {
    toast('❌ ' + getUserMessage(e), true);
    const div = document.getElementById('bv-result');
    if (div) div.innerHTML = `<div style="margin-top:8px;font-size:.8rem;color:var(--red2)">❌ Hata: ${esc(e.message)}</div>`;
  } finally {
    if (submitBtn) submitBtn.disabled = false;
  }
}

// ============================================================
// TOPLU İLAÇ — m-bulk-ilac modal
// ============================================================

async function loadBulkIlacPadoklar() {
  const animals = getState('animals');
  if (!animals || !animals.length) return;
  const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort((a,b) => a.localeCompare(b, 'tr', {sensitivity:'base'}));
  const sel = document.getElementById('bi-padok');
  if (!sel) return;
  sel.innerHTML = '<option value="">— Padok Seç —</option>' +
    padoklar.map(p => `<option value="${p}">${p}</option>`).join('');
}

async function loadBulkIlacHayvanlar() {
  const padok = document.getElementById('bi-padok')?.value;
  if (!padok) { toast('Padok seçin'); return; }
  const animals = getState('animals').filter(a => a.padok === padok);
  const list = document.getElementById('bi-hayvan-list');
  const count = document.getElementById('bi-count');
  if (count) count.textContent = animals.length > 0 ? animals.length : '';
  if (list) {
    if (!animals.length) {
      list.style.display = 'none';
      list.innerHTML = '';
    } else {
      list.style.display = 'block';
      list.innerHTML = animals.map(a =>
        `<span style="font-size:.72rem;background:var(--card2);padding:2px 6px;border-radius:4px;margin:2px;display:inline-block">
          ${esc(a.kupe_no || a.devlet_kupe || a.id)}
        </span>`
      ).join('');
    }
  }
  // Store selected animal IDs for submit
  window._biAnimalIds = animals.map(a => a.id);
}

async function loadBulkIlacDropdown() {
  const DRUG_KATEGORI = ['İlaç','Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç'];
  const stoklar = (getState('stock') || []).filter(s => DRUG_KATEGORI.includes(s.kategori));
  const sel = document.getElementById('bi-ilac-sel');
  if (!sel) return;
  sel.innerHTML = '<option value="">— İlaç seçin —</option>' +
    stoklar.map(s => `<option value="${s.id}">${esc(s.urun_adi)} (${s.guncel ?? 0} ${s.birim || 'adet'})</option>`).join('');
}

async function submitBulkIlac() {
  const animalIds = window._biAnimalIds || [];
  if (!animalIds.length) { toast('Önce padok seçip hayvanları getirin'); return; }
  const ilacId = document.getElementById('bi-ilac-sel')?.value;
  if (!ilacId) { toast('İlaç seçin'); return; }
  const miktar = parseFloat(document.getElementById('bi-miktar')?.value);
  if (!miktar || isNaN(miktar)) { toast('Miktar girin'); return; }
  if (miktar <= 0) { toast('Miktar sıfırdan büyük olmalı'); return; }
  const notes = document.getElementById('bi-notes')?.value || null;

  try {
    const result = await rpc('bulk_ilac', {
      p_animal_ids: animalIds,
      p_ilac_stok_id: ilacId,
      p_miktar: miktar,
      p_notlar: notes
    });

    const div = document.getElementById('bi-result');
    if (div) {
      const errors = result.errors || [];
      div.innerHTML = `<div style="margin-top:8px;font-size:.8rem">
        ✅ ${result.success}/${result.total} hayvana uygulandı
        ${errors.length ? '<br>⚠️ ' + errors.map(e=>esc(e.error)).join(', ') : ''}
      </div>`;
    }
    if (result.success > 0) {
      toast(`✅ ${result.success} hayvana ilaç uygulandı`);
      // Refresh data
      pullTables(['stok','stok_hareket','islem_log']).catch(console.warn);
    }
  } catch(e) {
    toast('❌ ' + getUserMessage(e), true);
    const div = document.getElementById('bi-result');
    if (div) div.innerHTML = `<div style="margin-top:8px;font-size:.8rem;color:var(--red2)">❌ Hata: ${esc(e.message)}</div>`;
  }
}

// ============================================================
// SHARED BULK SELECTION FUNCTIONS (prefix: bv or bi)
// ============================================================

// Tab switcher — works for both modals via prefix
function bulkTabSwitch(prefix, tab) {
  try {
    ['padok','filtre','serbest'].forEach(t => {
      const sec = document.getElementById(prefix + '-section-' + t);
      const btn = document.getElementById(prefix + '-tab-' + t);
      if (sec) sec.style.display = t === tab ? '' : 'none';
      if (btn) {
        btn.style.opacity = t === tab ? '1' : '0.5';
        btn.className = t === tab ? 'btn btn-g' : 'btn btn-o';
      }
    });
    // Load serbest list on first click
    if (tab === 'serbest') loadBulkSerbest(prefix);
  } catch(e) {
    console.error('bulkTabSwitch error:', e);
  }
}

// Filter-based selection
function applyBulkFiltre(prefix) {
  // Start from current filtered list (padok selection), not all animals
  let idKey = prefix === 'bv' ? '_bvAnimalIds' : '_biAnimalIds';
  const currentIds = window[idKey] || [];
  const allAnimals = getState('animals');
  const animals = currentIds.length > 0
    ? allAnimals.filter(a => currentIds.includes(a.id))
    : allAnimals;
  const durum = document.getElementById(prefix + '-f-durum')?.value;
  const yasMin = parseInt(document.getElementById(prefix + '-f-yas-min')?.value) || 0;
  const yasMax = parseInt(document.getElementById(prefix + '-f-yas-max')?.value) || 9999;

  let filtered = animals;
  if (durum) {
    filtered = filtered.filter(a => 
      a.tohumlama_durumu === durum
    );
  }
  if (yasMin || yasMax < 9999) {
    const now = new Date();
    filtered = filtered.filter(a => {
      if (!a.dogum_tarihi) return false;
      const ayFark = (now - new Date(a.dogum_tarihi)) / (1000 * 60 * 60 * 24 * 30);
      return ayFark >= yasMin && ayFark <= yasMax;
    });
  }

  // Update animal IDs and show preview
  idKey = prefix === 'bv' ? '_bvAnimalIds' : '_biAnimalIds';
  window[idKey] = filtered.map(a => a.id);
  const count = document.getElementById(prefix + '-count');
  const list = document.getElementById(prefix + '-hayvan-list');
  if (count) count.textContent = filtered.length > 0 ? filtered.length : '';
  if (list) {
    if (!filtered.length) {
      list.style.display = 'none';
      list.innerHTML = '';
    } else {
      list.style.display = 'block';
      list.innerHTML = filtered.slice(0, 20).map(a =>
        '<span style="font-size:.72rem;background:var(--card2);padding:2px 6px;border-radius:4px;margin:2px;display:inline-block">' +
        (a.kupe_no || a.devlet_kupe || a.id) + '</span>'
      ).join('') + (filtered.length > 20 ? '<span style="font-size:.68rem;color:var(--ink3)">+' + (filtered.length - 20) + ' daha</span>' : '');
    }
  }
  toast(filtered.length + ' hayvan seçildi');
}

// Populate serbest seçim checkbox list
function loadBulkSerbest(prefix) {
  const animals = getState('animals');
  const div = document.getElementById(prefix + '-s-list');
  if (!div) return;
  div.innerHTML = animals.map(a => {
    const kupe = a.kupe_no || a.devlet_kupe || a.id;
    return '<label style="display:flex;align-items:center;gap:6px;padding:4px;font-size:.78rem;cursor:pointer">' +
      '<input type="checkbox" value="' + a.id + '" onchange="updateBulkSerbest(\'' + prefix + '\')">' +
      '<span>' + kupe + '</span>' +
      '<span style="color:var(--ink3);font-size:.68rem">' + (a.padok || '') + ' · ' + (a.irk || '') + '</span>' +
      '</label>';
  }).join('');
}

// Filter checkbox list by search
function filterBulkSerbest(prefix) {
  const q = trLower(document.getElementById(prefix + '-s-ara')?.value || '') || '';
  const labels = document.querySelectorAll('#' + prefix + '-s-list label');
  labels.forEach(l => {
    l.style.display = trLower(l.textContent).includes(q) ? '' : 'none';
  });
}

// Update selected IDs from checkboxes
function updateBulkSerbest(prefix) {
  const boxes = document.querySelectorAll('#' + prefix + '-s-list input[type=checkbox]:checked');
  const idKey = prefix === 'bv' ? '_bvAnimalIds' : '_biAnimalIds';
  window[idKey] = [...boxes].map(b => b.value);
  const countEl = document.getElementById(prefix + '-s-count');
  if (countEl) countEl.textContent = window[idKey].length;
}

// ── SORUN TESPİT TOGGLE (tohumlama modalı) ──
function sorunToggle(cb) {
  const thumb = document.getElementById('i-sorun-thumb');
  thumb.style.background = cb.checked ? 'var(--red2)' : 'var(--card3)';
  globalThis._insemSorunVar = cb.checked;
}

// ══════════════════════════════════════════
// BUG-059 — Seans tamamla/iptal handler'ı
// (seans planı düzenleme ve erken kapat ui.js'de: caseSeansFormAc, caseErkenKapat*)
// ══════════════════════════════════════════

async function seansTamamla(seansId, uygulanmadi, btn) {
  if (!seansId) { toast('❌ Seans ID eksik', true); return; }
  const row = btn?.closest('.seans-row, .seans-gorev-card');
  if (row) row.querySelectorAll('button').forEach(b => { b.disabled = true; });
  if (btn) btn.textContent = '…';
  try {
    const res = await rpcSeansTamamla(seansId, uygulanmadi, null);
    toast(uygulanmadi ? '↩ Yapılamadı işaretlendi, stok iade edildi' : '✓ Seans tamamlandı');
    await pullTables(['treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'treatment_days', 'gorev_log', 'cases']);
    // Açık görünümleri tazele
    if (_curCase) {
      await renderCaseTimeline(_curCase.id);
      _updateKapatBtn(_curCase.id);
    }
    if (_curTaskDet?.gorev_tipi === 'TEDAVI_GUN') {
      try {
        const meta = JSON.parse(_curTaskDet.aciklama || '{}');
        if (meta.day_id) await renderTedaviGunSeanslar(meta.day_id);
      } catch (e) { /* sessiz */ }
    }
    // Görev listesi görünürse tazele (seans kartları oradan tamamlanabilir)
    try {
      const _tb=document.getElementById('tasks-body');
      if(_tb && _tb.offsetParent!==null) await loadTasks(_curTaskFilter||'today',null,{skipPull:true});
      if(typeof updateTaskBadge==='function') updateTaskBadge();
    } catch(e){ /* sessiz */ }
  } catch (e) {
    toast('❌ ' + (e.message || 'Hata'), true);
    if (row) row.querySelectorAll('button').forEach(b => { b.disabled = false; });
    if (btn) btn.textContent = uygulanmadi ? '✕' : '✓ Uygulandı';
  }
}

// ── Aşı ekle/düzenle submit (içerik-odaklı) ──
async function submitAsiEkle(btn){
  if(typeof _syncAsiForm==='function') _syncAsiForm();
  const s = _asiEdit;
  if(!s.name || !s.name.trim()){ toast('Preparat adı zorunlu',true); return; }
  if(!navigator.onLine){ toast('Aşı eklemek için internet gerekli',true); return; }
  const adimlar = [{adim_no:1, offset_gun:0, label:'1. doz'}];
  if(s.protokol_tipi==='primer_seri'){
    adimlar.push({adim_no:2, offset_gun:parseInt(s.ikinci_doz_gun)||28, label:'2. doz (primer)'});
  }
  const params = {
    p_name:s.name.trim(), p_marka:s.marka?.trim()||null, p_etken_madde:s.etken_madde?.trim()||null,
    p_dose:s.dose?parseFloat(s.dose):null, p_unit:s.unit||'ml', p_route:s.route||'SC',
    p_is_mandatory:!!s.is_mandatory, p_disease_ids:s.disease_ids||[],
    p_protokol_tipi:s.protokol_tipi||'tek_doz', p_protokol_adimlar:adimlar,
    p_repeat_interval_days:s.repeat?parseInt(s.repeat):null
  };
  if(btn){ btn.disabled=true; btn.textContent='Kaydediliyor…'; }
  try{
    // baslangic_stok/esik hem ekleme hem (stoksuz aşıya sonradan stok bağlama — Ö1) düzenlemede geçer
    params.p_baslangic_stok = s.baslangic_stok ? parseFloat(s.baslangic_stok) : null;
    params.p_esik = s.esik ? parseFloat(s.esik) : 0;
    if(s.id){
      await rpc('asi_guncelle', { p_vaccine_id:s.id, ...params });
    } else {
      await rpc('asi_ekle', params);
    }
    toast(`✅ ${s.name} kaydedildi`);
    closeM('m-asi-ekle');
    await pullTables(['vaccines','vaccine_diseases','vaccine_protocol_steps','stok','stok_hareket']).catch(()=>{});
    if(typeof loadStokPanel==='function') loadStokPanel();
  }catch(e){ toast('❌ '+getUserMessage(e),true); }
  finally{ if(btn){ btn.disabled=false; btn.textContent='💾 Kaydet'; } }
}
