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
   g, v, cl, dAgo, dFwd, fmtTarih, toast, openM, closeM,
   db, rpc, pullTables, renderSafe, renderFromLocal,
   idbGetAll, getData, write,
   loadDrugsCache, loadStock, loadDash, loadTasks, loadUreme, loadGecmis,
   loadBildirimler, loadStokPanel, openDet, closeDet, openStokPanel,
   openAnimalEdit, closeAnimalEdit, getDisplayKupe, yasHesapla, loadIrkDropdown
*/

// ── YENİ HAYVAN ─────────────────────────────
async function submitAnimal(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }

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
  const anneId = v('b-anne');
  const tarih  = v('b-tarih');
  const kupe   = v('b-kupe');
  const cins   = v('b-cins');
  const tip    = v('b-tip');
  const kg     = Number.parseFloat(g('b-dogum-kg')?.value || '') || null;
  const baba   = v('b-baba') || v('b-baba-text') || null;
  if (!anneId) { toast('Anne seçilmedi — Gebelerden Seç veya Manuel Gir', true); return; }
  if (!tarih || !kupe) { toast('Doğum Tarihi ve Yavru Küpe zorunlu', true); return; }
  if (tarih > new Date().toISOString().split('T')[0]) { toast('Doğum tarihi ileri tarih olamaz', true); return; }

  const anne = getState('animals').find(a => a.id === anneId || a.kupe_no === anneId || a.devlet_kupe === anneId);
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

    toast(`✅ Doğum kaydedildi — ${kupe} sürüye eklendi, ${data?.gorev_sayisi ?? 0} görev oluşturuldu`);
    closeM('m-birth');

    // Formu sıfırla
    const anneEl = g('b-anne'); if (anneEl) anneEl.value = '';
    const anneCard = g('anne-secili-card'); if (anneCard) anneCard.style.display = 'none';
    const gebeBtn = g('btn-gebe-sec'); if (gebeBtn) gebeBtn.style.display = '';
    const anneManual = g('b-anne-manual'); if (anneManual) anneManual.style.display = 'none';
    ['b-kupe','b-dogum-kg','b-baba','b-baba-text'].forEach(id => { const el = g(id); if (el) el.value = ''; });
    const babaAuto = g('b-baba-auto'); if (babaAuto) babaAuto.style.display = 'none';
    const babaText = g('b-baba-text'); if (babaText) babaText.style.display = 'none';

    pullTables(['hayvanlar','dogum','gorev_log']).then(renderSafe).catch(console.warn);
  } catch (e) {
    toast('❌ Doğum kaydedilemedi: ' + getUserMessage(e), true);
  } finally { if (btn) { btn.disabled = false; btn.textContent = '🐄 Kaydet + Protokol Görevleri'; } }
}

// ── TOHUMLAMA ────────────────────────────────
async function submitInsem(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid    = v('i-hid');
  const tarih  = v('i-tarih');
  const sperma = v('i-sperma');
  if (!hid || !tarih || !sperma) { toast('Küpe, Tarih ve Sperma zorunlu', true); return; }
  if (tarih > new Date().toISOString().split('T')[0]) { toast('Tohumlama tarihi ileri tarih olamaz', true); return; }

  const hayvan = getState('animals').find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  // UI Telemetry: tohumlama submit
  uiLog('action', 'tohumlama_submit', { hayvan_id: hayvan.id, tarih });

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const result = await rpc('tohumlama_kaydet', {
      p_hayvan_id: hayvan.id,
      p_tarih:     tarih,
      p_sperma:    sperma,
      p_hekim_id:  v('i-hekim') || null,
    });

    toast('✅ Tohumlama kaydedildi + 2 kontrol görevi oluşturuldu');
    closeM('m-insem');
    cl('i-hid'); cl('i-sperma');
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
  if (tarih > new Date().toISOString().split('T')[0]) { toast('Tarih ileri olamaz', true); return; }

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
  document.getElementById('tr-tarih').value = new Date().toISOString().split('T')[0];
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

  const hayvan = getState('animals').find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const result = await rpc('kizginlik_kaydet', {
      p_hayvan_id: hayvan.id,
      p_tarih:     tarih,
      p_belirti:   v('k-belirti') || null,
      p_notlar:    v('k-notlar') || null,
    });

    // Hayvan 12 aydan küçükse backend red döner ama öneri verir
    if (result && result.oneri) {
      toast(`⚠️ ${result.mesaj} — ${result.oneri}`, true);
      return;
    }

    toast('✅ Kızgınlık kaydedildi');
    closeM('m-kizginlik');
    ['k-hid','k-notlar'].forEach(cl);
    pullTables(['kizginlik_log','gorev_log']).then(() => {
      renderSafe();
      if (typeof updateKizginlikAlert === 'function') updateKizginlikAlert();
    }).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
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
  Object.keys(grouped).sort().forEach(cat => {
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

function onDiseaseSelect() {
  const sel = g('d-disease-id');
  const catEl = g('d-disease-cat');
  const opt = sel?.selectedOptions[0];
  if (opt?.dataset.category) {
    catEl.textContent = '📂 ' + opt.dataset.category;
    catEl.style.display = 'block';
  } else {
    catEl.style.display = 'none';
  }
}

async function submitCase(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid       = v('d-hid');
  const diseaseId = v('d-disease-id');
  if (!hid)       { toast('Hayvan seçilmedi', true); return; }
  if (!diseaseId) { toast('Hastalık seçilmedi', true); return; }

  const hayvan = getState('animals').find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Açılıyor…'; }
  try {
    const res = await rpc('create_case', {
      p_animal_id:  hayvan.id,
      p_disease_id: diseaseId,
      p_notes:      v('d-case-notes') || null,
    });
    if (!res?.ok) {
      toast('❌ ' + (res?.mesaj || 'Vaka açılamadı'), true);
      return;
    }
    toast('✅ Vaka açıldı');
    closeM('m-disease');
    cl('d-hid'); cl('d-case-notes');
    g('d-disease-id').value = '';
    g('d-disease-cat').style.display = 'none';
    await pullTables(['cases','diseases','drugs','kizginlik_log']);
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

// ── ABORT ────────────────────────────────────
async function abortKaydet(hayvanId, tohId) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  if (!confirm('Bu hayvanda abort / erken doğum mu oldu? Gebelik kaydı kapatılacak.')) return;
  const notlar = prompt('Abort detayı (opsiyonel):') || '';
  try {
    // Yeni tohumlama_abort RPC kullan (islem_log kaydı oluşturur)
    const result = await rpc('tohumlama_abort', {
      p_tohumlama_id: tohId,
      p_notlar:       notlar || null,
    });
    if (result?.ok === false) { toast('❌ ' + (result.error || result.mesaj), true); return; }
    toast('✅ Abort kaydedildi, gebelik kapatıldı');
    await pullTables(['tohumlama','hayvanlar','islem_log']);
    renderSafe();
    openDet(hayvanId);
  } catch (e) { toast('❌ Abort kaydedilemedi: ' + getUserMessage(e), true); }
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
function openCikis(hayvanId, kupe, tip = 'olum') {
  g('cikis-hid').value = hayvanId;
  g('cikis-title').textContent = tip === 'satis' ? `💰 Satış Kaydı — ${kupe}` : `💀 Ölüm Kaydı — ${kupe}`;
  g('cikis-tip').value = tip;
  g('cikis-tarih').value = new Date().toISOString().split('T')[0];
  g('cikis-sebep').value = '';
  g('cikis-fiyat').value = '';
  g('cikis-notlar').value = '';
  cikisTipDegisti();
  openM('m-cikis');
}
function cikisTipDegisti() {
  const tip = g('cikis-tip').value;
  g('cikis-olum-alan').style.display = tip === 'olum' ? '' : 'none';
  g('cikis-satis-alan').style.display = tip === 'satis' ? '' : 'none';
}
async function submitCikis(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hayvanId = g('cikis-hid').value;
  const tip      = g('cikis-tip').value;
  const tarih    = g('cikis-tarih').value;
  const sebep    = g('cikis-sebep').value.trim();
  const fiyat    = Number.parseFloat(g('cikis-fiyat').value) || null;
  if (!tarih) { toast('Tarih zorunlu', true); return; }
  if (tip === 'olum' && !sebep) { toast('Ölüm sebebi girin', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const hayvan = getState('animals').find(a => a.id === hayvanId);
    if (!hayvan) { toast('Hayvan bulunamadı', true); return; }

    await rpc('cikis_yap', {
      p_hayvan_id:    hayvanId,
      p_cikis_tipi:   tip,
      p_cikis_tarihi: tarih,
      p_cikis_sebebi: tip === 'olum' ? sebep : (g('cikis-notlar').value.trim() || null),
      p_satis_fiyati: tip === 'satis' ? fiyat : null,
    });

    const tipTxt = tip === 'olum' ? 'Ölüm' : 'Satış';
    toast(`✅ ${getDisplayKupe(hayvan)} sürüden çıkarıldı (${tipTxt})`);
    closeM('m-cikis');
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '📤 Sürüden Çıkar'; } }
}

// ── SÜTTEN KESME ─────────────────────────────
function openSuttenKesModal() {
  const sutIcenler = getState('animals').filter(a => a.hesap_kategori === 'sut_icen');
  if (!sutIcenler.length) { toast('Süt içen buzağı yok'); return; }
  const liste = g('sk-liste');
  liste.innerHTML = sutIcenler.map(a => `
    <label style="display:flex;align-items:center;gap:10px;padding:9px 4px;border-bottom:1px solid var(--card2);cursor:pointer">
      <input type="checkbox" data-id="${a.id}" checked style="width:18px;height:18px;cursor:pointer">
      <div>
        <div style="font-weight:700;font-size:.85rem">${getDisplayKupe(a)}</div>
        <div style="font-size:.72rem;color:var(--ink3)">${a.irk || '—'} · ${yasHesapla(a.dogum_tarihi) || 'Yaş?'}</div>
      </div>
    </label>`).join('');
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
  if (!confirm(`${hayvanIdList.length} buzağı sütten kesilecek. Onaylıyor musunuz?`)) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  let basari = 0;
  try {
    for (const id of hayvanIdList) {
      const h = getState('animals').find(a => a.id === id);
      if (!h || h.hesap_kategori !== 'sut_icen') continue;
      await rpc('buzagi_sutten_kesme_onayla', { p_hayvan_id: id });
      basari++;
    }
    toast(`✅ ${basari} buzağı sütten kesildi`);
    closeM('m-sutten-kes');
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🍼 Sütten Kes'; } }
}
async function suttenKesTekil(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = getState('animals').find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (h.hesap_kategori !== 'sut_icen') { toast('Bu hayvan süt içen kategorisinde değil', true); return; }
  if (!confirm(`${getDisplayKupe(h)} sütten kesilecek. Onaylıyor musunuz?`)) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('buzagi_sutten_kesme_onayla', { p_hayvan_id: hayvanId });
    toast(`✅ ${getDisplayKupe(h)} sütten kesildi`);
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🍼 Sütten Kes'; } }
}

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

// ── AŞI DROPDOWN ─────────────────────────────
async function loadVaccinesDropdown() {
  const vaccines = await getData('vaccines');
  const sel = document.getElementById('v-vaccine-id');
  if (!sel) return;

  if (!vaccines || !vaccines.length) {
    sel.innerHTML = '<option value="" disabled>Aşı listesi yüklenemedi</option>';
    const btn = document.querySelector('#m-vaccine .btn-g');
    if (btn) btn.disabled = true;
    return;
  }

  const mandatory = vaccines.filter(v => v.is_mandatory);
  const optional = vaccines.filter(v => !v.is_mandatory);

  let html = '';
  if (mandatory.length) {
    html += '<optgroup label="Zorunlu Aşılar">';
    mandatory.forEach(v => { html += `<option value="${v.id}">${v.name} — ${v.disease_target || ''}</option>`; });
    html += '</optgroup>';
  }
  if (optional.length) {
    html += '<optgroup label="Diğer Aşılar">';
    optional.forEach(v => { html += `<option value="${v.id}">${v.name} — ${v.disease_target || ''}</option>`; });
    html += '</optgroup>';
  }
  sel.innerHTML = '<option value="">— Aşı seçin —</option>' + html;

  const today = new Date().toISOString().split('T')[0];
  const dateEl = document.getElementById('v-date');
  if (dateEl) dateEl.value = today;
}

let _onDoseInput; // dose override visual feedback handler
async function onVaccineSelect() {
  const sel = document.getElementById('v-vaccine-id');
  const info = document.getElementById('v-vaccine-info');
  const hint = document.getElementById('v-protocol-hint');
  const unit = document.getElementById('v-dose-unit');
  const doseOverride = document.getElementById('v-dose-override');
  if (!sel) return;

  const val = sel.value;
  if (!val) {
    if (info) info.style.display = 'none';
    if (hint) { hint.style.display = 'none'; hint.innerHTML = ''; }
    if (unit) unit.textContent = '';
    return;
  }

  const vaccines = await getData('vaccines') || [];
  const vax = vaccines.find(v => v.id === val);
  if (!vax) return;

  if (info) {
    info.style.display = 'block';
    let infoText = `Standart doz: ${vax.dose || '?'} ${vax.unit || 'ml'} · Uygulama: ${vax.route || '?'}`;
    if (vax.repeat_interval_days) infoText += ` · Her ${vax.repeat_interval_days} günde bir`;
    info.textContent = infoText;
  }

  if (unit) unit.textContent = vax.unit || 'ml';
  if (doseOverride) {
    doseOverride.placeholder = vax.dose || '';
    doseOverride.dataset.stdDose = vax.dose || '';
    // Kaldir eski listener'i (varsa)
    doseOverride.removeEventListener('input', _onDoseInput);
    _onDoseInput = function(){
      const std = doseOverride.dataset.stdDose;
      const val = doseOverride.value;
      if (info) {
        let base = `Standart doz: ${std || '?'} ${vax.unit || 'ml'} · Uygulama: ${vax.route || '?'}`;
        if (vax.repeat_interval_days) base += ` · Her ${vax.repeat_interval_days} günde bir`;
        if (val && val !== std) {
          base += `<br><span style="color:var(--orange);font-weight:600">→ Uygulanacak: ${val} ${vax.unit || 'ml'}</span>`;
        }
        info.innerHTML = base;
      }
    };
    doseOverride.addEventListener('input', _onDoseInput);
  }

  if (hint) {
    hint.style.display = 'block';
    if (vax.repeat_interval_days) {
      hint.innerHTML = `⏰ Bu aşı uygulandıktan <b>${vax.repeat_interval_days}</b> gün sonra otomatik hatırlatma görevi oluşturulur.`;
      hint.style.background = 'rgba(78,154,42,.12)';
      hint.style.borderColor = 'rgba(78,154,42,.25)';
    } else {
      hint.innerHTML = '💉 Tek doz aşı — hatırlatma görevi oluşmaz.';
      hint.style.background = 'rgba(42,107,181,.1)';
      hint.style.borderColor = 'rgba(42,107,181,.2)';
    }
  }
}

// ── AŞI UYGULA ──────────────────────────────
async function submitVaccination(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }

  const hid = v('v-hid');
  const vaccineId = v('v-vaccine-id');
  const date = v('v-date');
  const doseOverride = v('v-dose-override');
  const notes = v('v-notes');

  if (!hid) { toast('⚠️ Hayvan seçin', true); return; }
  if (!vaccineId) { toast('⚠️ Aşı seçin', true); return; }
  if (!date) { toast('⚠️ Tarih girin', true); return; }
  if (date > new Date().toISOString().split('T')[0]) { toast('İleri tarih girilemez', true); return; }

  const hayvan = getState('animals').find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const res = await rpc('add_vaccination', {
      p_animal_id: hayvan.id,
      p_vaccine_id: vaccineId,
      p_date: date,
      p_dose_override: doseOverride ? parseFloat(doseOverride) : null,
      p_notes: notes || null,
    });

    toast('💉 Aşı kaydedildi');
    closeM('m-vaccine');
    resetVaccineForm();
    if (res && res.next_due) toast(`⏰ Sonraki aşı: ${fmtTarih(res.next_due)}`, false);
    await pullTables(['vaccination_log', 'gorev_log', 'hayvanlar']);
    renderSafe();
  } catch (e) {
    toast('❌ Aşı kaydedilemedi: ' + getUserMessage(e), true);
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = '💉 Aşı Uygula'; }
  }
}

function resetVaccineForm() {
  const ids = ['v-hid','v-vaccine-id','v-date','v-dose-override','v-notes'];
  ids.forEach(id => { const el = document.getElementById(id); if (el) el.value = ''; });
  const info = document.getElementById('v-vaccine-info');
  const hint = document.getElementById('v-protocol-hint');
  if (info) info.style.display = 'none';
  if (hint) { hint.style.display = 'none'; hint.innerHTML = ''; }
  const unit = document.getElementById('v-dose-unit');
  if (unit) unit.textContent = '';
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
    await pullTables(['hayvanlar']).catch(()=>{});
    loadDash();
  } catch (e) {
    btn.disabled = false;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';
    toast(getUserMessage(e), true);
  }
}

// Görev detay modal
// openTaskDet, detayTamamla, detayIptal → ui.js'te tanımlı (daha tam versiyon)

// Manuel görev ekle
async function submitTaskAdd(btn) {
  const desc  = v('ta-desc');
  const tarih = v('ta-tarih');
  if (!desc || !tarih) { toast('Açıklama ve Tarih zorunlu', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Oluşturuluyor…'; }
  try {
    const hid    = v('ta-hid').trim();
    const hayvan = hid ? (getState('animals').find(a => a.kupe_no === hid || a.id === hid)) : null;
    await write('gorev_log', {
      id: crypto.randomUUID(), hayvan_id: hayvan?.id || hid || null,
      gorev_tipi: v('ta-tip'), aciklama: desc, hedef_tarih: tarih,
      tamamlandi: false, kaynak: 'MANUEL'
    });
    toast('✅ Görev oluşturuldu');
    closeM('m-task-add');
    ['ta-hid','ta-desc'].forEach(cl);
    await loadTasks(_curTaskFilter || 'today');
    loadDash();
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
  const degisen={};
  if(t.aciklama!==desc) degisen.aciklama=desc;
  if(t.hedef_tarih!==tarih) degisen.hedef_tarih=tarih;
  if(t.gorev_tipi!==tip) degisen.gorev_tipi=tip;
  if(Object.keys(degisen).length===0){
    toast('Hiçbir değişiklik yapılmadı'); return;
  }
  // Diff mesajı oluştur
  const tipEtiket={MANUEL:'📋 Genel',TEDAVI:'🚑 Tedavi',ILAC_UYGULAMA:'💊 İlaç',PADOK_DEGISIM:'🐄 Padok',MUAYENE:'🩺 Muayene',ILERI_GEBE_ASI:'💉 Aşı',ILERI_GEBE:'💊 Takviye',SUTTEN_KESME:'🍼 Sütten',DIGER:'📂 Diğer'};
  const diffSatirlari=[];
  if('aciklama' in degisen) diffSatirlari.push('📝 Açıklama: "'+(t.aciklama||'')+'" → "'+desc+'"');
  if('hedef_tarih' in degisen) diffSatirlari.push('📅 Tarih: '+(t.hedef_tarih||'')+' → '+tarih);
  if('gorev_tipi' in degisen) diffSatirlari.push('🏷 Tür: '+(tipEtiket[t.gorev_tipi]||t.gorev_tipi)+' → '+(tipEtiket[tip]||tip));
  openConfirm('✏️ Görevi Düzenle', diffSatirlari.join('\n'), async() => kaydetTaskEdit(btn, t, degisen, desc, tarih, tip));
}

async function kaydetTaskEdit(btn, t, degisen) {
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await write('gorev_log',degisen,'PATCH',`id=eq.${t.id}`);
    try {
      await db.from('islem_log').insert({
        ana_hayvan_id: t.hayvan_id||null,
        islem_tipi: 'gorev_duzenle',
        islem_detay: JSON.stringify({gorev_id:t.id,...degisen}),
        tarih: new Date().toISOString(),
        kullanici: null, kaynak: 'MANUEL'
      });
    } catch(_){}
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
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
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
    chip.innerHTML = `${val} <span style="font-size:.9rem;opacity:.7" onclick="semptomKaldir('${val}',this.parentElement)">✕</span>`;
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
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
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
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
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
    toast('❌ Sonuç kaydedilemedi: ' + getUserMessage(e), true);
  }
}

// ── GEBELİK İŞARETLE ────────────────────────
// ── GERİ ALMA ────────────────────────────────
function openGeriAl(islemLogId, ozet) {
  g('ga-hid').value = islemLogId;
  g('ga-ozet').textContent = ozet || 'Bu işlem geri alınacak.';
  openM('m-geri-al');
}
// ── İşlem Geri Al ──────────────────────────
async function islemGeriAl(btn, islemLogId) {
  if (!navigator.onLine) { toast('⚠️ Geri alma için internet gerekli', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Geri alınıyor…'; }

  try {
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
    }

    const res = await rpc(rpcName, rpcParams);
    if (!res?.ok) throw new Error(res?.hata || 'Geri alma başarısız');

    toast('✅ İşlem geri alındı');
    closeM('m-geri-al');
    closeM('m-toh-det');
    await pullTables(['tohumlama','gorev_log','hayvanlar','kizginlik_log','cases','treatment_days','stok_hareket','islem_log']);
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
  const ilacKatlar = ['Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç'];
  const isIlac = ilacKatlar.includes(kat);
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
      const r = await rpc('stok_ekleme', { p_stok_id: stokId, p_miktar: bslg, p_notlar: `Stok güncellendi: ${urun}` });
      toast(`✅ ${urun} stoku güncellendi (+${bslg} ${birim})`);
    } else {
      // Yeni kayıt (RPC — atomik)
      const r = await rpc('stok_ekle', { p_urun_adi: urun, p_kategori: kat, p_birim: birim, p_baslangic_miktar: bslg, p_esik: esik });
      stokId = r?.id;
      // İlaç ise drug_products'a da ekle (etken madde zorunlu)
      if (isIlac && navigator.onLine) {
        const etkenId = g('sa-etken')?.value || null;
        if (!etkenId) { toast('Etken madde seçilmedi', true); return; }
        const konst = g('sa-konst')?.value?.trim() || null;
        const route = g('sa-route')?.value || 'IM';
        // RPC ile drug_product ekle (stok bağlantısı atomik)
        const { data: dp, error: dpErr } = await db.rpc('drug_product_ekle', {
          p_drug_class_id:      etkenId,
          p_brand_name:         urun,
          p_concentration:      konst ? Number.parseFloat(konst) : null,
          p_concentration_unit: konst || null,
          p_default_route:      route,
          p_default_unit:       birim,
          p_stok_id:            stokId || null
        });
        if (dpErr) throw new Error(dpErr.message);
        if (!dp) throw new Error('İlaç kaydı oluşturulamadı');
        _drugsCache = [];
      }
      toast(`✅ ${urun} eklendi`);
    }
    closeM('m-stok-add');
    ['sa-ad','sa-ad-diger','sa-mik','sa-esik','sa-konst'].forEach(id=>{const e=g(id);if(e)e.value='';});
    await pullTables(['stok','drug_products']);
    _drugsCache = [];
    const _sp = document.getElementById('stok-panel');
    if(_sp?.style.transform !== 'translateX(100%)') await loadStokPanel();
  } catch (e) { toast(getUserMessage(e), true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '💾 Kaydet'; } }
}


// ── GEBELİK EKLE ─────────────────────────────
async function submitGebelikEkle(btn) {
  const modal = document.getElementById('m-gebelik');
  const hayvanId = modal?._hayvanId;
  if (!hayvanId) { toast('Hayvan seçilmedi', true); return; }
  const tarih = g('geb-tarih')?.value;
  if (!tarih) { toast('Tarih zorunlu', true); return; }
  const bugun = new Date().toISOString().split('T')[0];
  if (tarih > bugun) { toast('İleri tarih girilemez', true); return; }
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

async function bildirimKontrol() {
  try {
    const tasks = await getData('gorev_log', t => !t.tamamlandi);
    const today = new Date().toISOString().split('T')[0];
    const geciken = tasks.filter(t => t.hedef_tarih < today);
    if (!geciken.length) return;
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    const ozet = geciken.length === 1 ? geciken[0].aciklama : `${geciken.length} geciken görev var`;
    new Notification('🐄 EgeSüt — Görev Hatırlatması', { body: ozet });
  } catch (e) { console.warn('bildirimKontrol:', e.message); }
}

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
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
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
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
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
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
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
  const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort();
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
          ${a.kupe_no || a.devlet_kupe || a.id}
        </span>`
      ).join('');
    }
  }
  // Store selected animal IDs for submit
  window._bvAnimalIds = animals.map(a => a.id);
}

async function loadBulkVaccineVaccines() {
  const vaccines = await getData('vaccines');
  const sel = document.getElementById('bv-vaccine-sel');
  if (!sel) return;

  if (!vaccines || !vaccines.length) {
    sel.innerHTML = '<option value="" disabled>Aşı listesi yüklenemedi</option>';
    return;
  }

  const mandatory = vaccines.filter(v => v.is_mandatory);
  const optional = vaccines.filter(v => !v.is_mandatory);

  let html = '';
  if (mandatory.length) {
    html += '<optgroup label="Zorunlu Aşılar">';
    mandatory.forEach(v => { html += `<option value="${v.id}">${v.name} — ${v.disease_target || ''}</option>`; });
    html += '</optgroup>';
  }
  if (optional.length) {
    html += '<optgroup label="Diğer Aşılar">';
    optional.forEach(v => { html += `<option value="${v.id}">${v.name} — ${v.disease_target || ''}</option>`; });
    html += '</optgroup>';
  }
  sel.innerHTML = '<option value="">— Aşı seçin —</option>' + html;

  // Set default date
  const today = new Date().toISOString().split('T')[0];
  const dateEl = document.getElementById('bv-tarih');
  if (dateEl) dateEl.value = today;
}

async function submitBulkVaccination() {
  const animalIds = window._bvAnimalIds || [];
  if (!animalIds.length) { toast('Önce padok seçip hayvanları getirin'); return; }
  const vaccineId = document.getElementById('bv-vaccine-sel')?.value;
  if (!vaccineId) { toast('Aşı seçin'); return; }
  const tarih = document.getElementById('bv-tarih')?.value;
  if (!tarih) { toast('Tarih girin'); return; }
  const doz = parseFloat(document.getElementById('bv-doz')?.value) || null;
  const notes = document.getElementById('bv-notes')?.value || null;

  const submitBtn = document.querySelector('[onclick="submitBulkVaccination()"]');
  if (submitBtn) submitBtn.disabled = true;
  try {
    const result = await rpc('bulk_vaccination', {
      p_animal_ids: animalIds,
      p_vaccine_id: vaccineId,
      p_date: tarih,
      p_dose_ml: doz,
      p_notes: notes
    });

    const div = document.getElementById('bv-result');
    if (div) {
      const errors = result.errors || [];
      div.innerHTML = `<div style="margin-top:8px;font-size:.8rem">
        ✅ ${result.success}/${result.total} başarılı
        ${errors.length ? `<br>⚠️ ${errors.length} hata: ${errors.map(e=>e.error).join(', ')}` : ''}
      </div>`;
    }
    if (result.success > 0) {
      toast(`✅ ${result.success} hayvan aşılandı`);
      // Refresh data
      pullTables(['vaccination_log','gorev_log','stok_hareket']).catch(console.warn);
    }
  } catch(e) {
    toast('❌ ' + getUserMessage(e), true);
    const div = document.getElementById('bv-result');
    if (div) div.innerHTML = `<div style="margin-top:8px;font-size:.8rem;color:var(--red2)">❌ Hata: ${e.message}</div>`;
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
  const padoklar = [...new Set(animals.map(a => a.padok).filter(Boolean))].sort();
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
          ${a.kupe_no || a.devlet_kupe || a.id}
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
  if (!miktar) { toast('Miktar girin'); return; }
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
        ${result.ok === false
          ? `⚠️ ${result.mesaj}`
          : `✅ ${result.success}/${result.total} hayvana uygulandı
             ${errors.length ? '<br>⚠️ ' + errors.map(e=>e.error).join(', ') : ''}`
        }
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
    if (div) div.innerHTML = `<div style="margin-top:8px;font-size:.8rem;color:var(--red2)">❌ Hata: ${e.message}</div>`;
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
  const idKey = prefix === 'bv' ? '_bvAnimalIds' : '_biAnimalIds';
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
  const q = document.getElementById(prefix + '-s-ara')?.value?.toLowerCase() || '';
  const labels = document.querySelectorAll('#' + prefix + '-s-list label');
  labels.forEach(l => {
    l.style.display = l.textContent.toLowerCase().includes(q) ? '' : 'none';
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