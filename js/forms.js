// ══════════════════════════════════════════
// EgeSüt — forms.js
// Tüm form submit fonksiyonları.
// Karmaşık işlemler → rpc() (stored procedure)
// Basit işlemler → write() (offline-first)
// yazIslemLog() KALDIRILDI → DB trigger yapıyor
// ══════════════════════════════════════════

// ── YENİ HAYVAN ─────────────────────────────
async function submitAnimal(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }

  const modal   = g('m-animal');
  const editId  = modal?.dataset.editId || null;
  const devlet  = v('a-devlet').trim();
  const kupe    = v('a-kupe').trim();
  const irk     = getIrkValue();

  if (!editId && !devlet && !kupe) { toast('Devlet küpesi veya işletme küpesi girin', true); return; }
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
        p_padok:          v('a-padok') || null,
        p_dogum_kg:       parseFloat(v('a-dkg')) || null,
        p_canli_agirlik:  parseFloat(v('a-agirlik')) || null,
        p_boy:            parseFloat(v('a-boy')) || null,
        p_renk:           v('a-renk') || null,
        p_ayirici_ozellik: v('a-ozellik') || null,
      });
      toast(`✅ ${devlet || kupe} güncellendi`);
      closeAnimalEdit();
      await pullTables(['hayvanlar']);
      await renderFromLocal();
      openDet(editId);
    } else {
      // EKLEME MODU
      const data = await rpc('hayvan_ekle', {
        p_kupe_no:        kupe || null,
        p_devlet_kupe:    devlet || null,
        p_irk:            irk || null,
        p_cinsiyet:       v('a-cinsiyet') || null,
        p_dogum_tarihi:   v('a-dt') || null,
        p_grup:           v('a-grup') || 'Genel',
        p_padok:          v('a-padok') || 'P1',
        p_dogum_kg:       parseFloat(v('a-dkg')) || null,
        p_canli_agirlik:  parseFloat(v('a-agirlik')) || null,
        p_boy:            parseFloat(v('a-boy')) || null,
        p_renk:           v('a-renk') || null,
        p_ayirici_ozellik: v('a-ozellik') || null,
      });
      toast(`✅ ${devlet || kupe} eklendi (ID: ${data.hayvan_id})`);
      closeM('m-animal');
      ['a-devlet','a-kupe','a-irk-txt','a-dt','a-dkg','a-agirlik','a-boy','a-renk','a-ozellik'].forEach(cl);
      const cins = g('a-cinsiyet'); if (cins) cins.value = '';
      const sel  = g('a-irk-sel');  if (sel)  sel.value  = '';
      pullTables(['hayvanlar']).then(() => Promise.all([renderSafe(), loadIrkDropdown()])).catch(console.warn);
    }
  } catch (e) { toast(e.message, true); }
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
  const kg     = parseFloat(g('b-dogum-kg')?.value || '') || null;
  const baba   = v('b-baba');

  if (!anneId) { toast('Anne seçilmedi — Gebelerden Seç veya Manuel Gir', true); return; }
  if (!tarih || !kupe) { toast('Doğum Tarihi ve Yavru Küpe zorunlu', true); return; }
  if (tarih > new Date().toISOString().split('T')[0]) { toast('Doğum tarihi ileri tarih olamaz', true); return; }

  const anne = _A.find(a => a.id === anneId || a.kupe_no === anneId || a.devlet_kupe === anneId);
  if (!anne) { toast(`⚠️ Anne "${anneId}" sürüde bulunamadı`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const data = await rpc('dogum_kaydet', {
      p_anne_id:  anne.id,
      p_tarih:    tarih,
      p_kupe:     kupe,
      p_cins:     cins,
      p_tip:      tip,
      p_kg:       kg,
      p_baba:     baba || null,
      p_hekim_id: v('b-hekim') || null,
    });

    toast(`✅ Doğum kaydedildi — ${kupe} sürüye eklendi, ${data.gorev_sayisi} görev oluşturuldu`);
    closeM('m-birth');

    // Formu sıfırla
    const anneEl = g('b-anne'); if (anneEl) anneEl.value = '';
    g('anne-secili-card').style.display = 'none';
    g('btn-gebe-sec').style.display = '';
    g('b-anne-manual').style.display = 'none';
    ['b-kupe','b-dogum-kg','b-baba','b-baba-text'].forEach(id => { const el = g(id); if (el) el.value = ''; });

    pullTables(['hayvanlar','dogum','gorev_log']).then(renderSafe).catch(console.warn);
  } catch (e) { toast('❌ Doğum kaydedilemedi: ' + e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🐄 Kaydet + Protokol Görevleri'; } }
}

// ── TOHUMLAMA ────────────────────────────────
async function submitInsem(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid    = v('i-hid');
  const tarih  = v('i-tarih');
  const sperma = v('i-sperma');
  if (!hid || !tarih || !sperma) { toast('Küpe, Tarih ve Sperma zorunlu', true); return; }
  if (tarih > new Date().toISOString().split('T')[0]) { toast('Tohumlama tarihi ileri tarih olamaz', true); return; }

  const hayvan = _A.find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await rpc('tohumlama_kaydet', {
      p_hayvan_id: hayvan.id,
      p_tarih:     tarih,
      p_sperma:    sperma,
      p_hekim_id:  v('i-hekim') || null,
    });

    toast('✅ Tohumlama kaydedildi + 2 kontrol görevi oluşturuldu');
    closeM('m-insem');
    cl('i-hid'); cl('i-sperma');
    checkSpermaUyari();
    pullTables(['tohumlama','gorev_log']).then(renderSafe).catch(console.warn);
  } catch (e) { toast('❌ Tohumlama kaydedilemedi: ' + e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet + Kontrol Görevleri'; } }
}

// ── KIZGINLIK ────────────────────────────────
async function submitKizginlik(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const hid   = v('k-hid');
  const tarih = v('k-tarih');
  if (!hid || !tarih) { toast('Küpe ve Tarih zorunlu', true); return; }

  const hayvan = _A.find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
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
    pullTables(['kizginlik_log','gorev_log']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; } }
}

// ── HASTALIK ─────────────────────────────────
async function submitDisease(btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  // Düzenleme modu
  if (_editMode) { await hstGuncelle(btn); return; }
  const hid  = v('d-hid');
  const tani = v('d-tani');
  if (!hid || !tani) { toast('Küpe ve Tanı zorunlu', true); return; }

  const hayvan = _A.find(a => a.kupe_no === hid || a.id === hid || a.devlet_kupe === hid);
  if (!hayvan) { toast(`⚠️ "${hid}" sürüde kayıtlı değil`, true); return; }

  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    // İlaç satırlarını topla
    const ilacRows = document.querySelectorAll('.ilac-satir');
    const ilaclar  = [];
    ilacRows.forEach(row => {
      const stokId = row.querySelector('.ilac-stok-id')?.value || '';
      const stokAd = row.querySelector('.ilac-stok-ac')?.value || '';
      const mik    = parseFloat(row.querySelector('.ilac-mik')?.value) || 0;
      const birim  = row.querySelector('.ilac-birim')?.value || '';
      if ((stokId || stokAd) && mik > 0) ilaclar.push({ stokId, stokAd, mik, birim });
    });

    const tedaviGun = parseInt(g('d-tedavi-gun')?.value || '1') || 1;

    await rpc('hastalik_kaydet', {
      p_hayvan_id:  hayvan.id,
      p_tani:       tani,
      p_kategori:   v('d-kat') || null,
      p_siddet:     v('d-sid') || null,
      p_semptomlar: v('d-sempt') || null,
      p_lokasyon:   v('d-lokasyon') || null,
      p_hekim_id:   v('d-hekim') || null,
      p_ilaclar:    ilaclar,
      p_tedavi_gun: tedaviGun,
    });

    const ilacAciklama = ilaclar.map(i => `${i.stokAd || i.stokId} ${i.mik} ${i.birim}`).join(', ');
    toast(tedaviGun > 1
      ? `✅ Hastalık + ${tedaviGun - 1} günlük takip görevi kaydedildi`
      : `✅ Hastalık kaydedildi${ilacAciklama ? ' · ' + ilacAciklama : ''}`);

    closeDisease();

    pullTables(['hastalik_log','gorev_log','stok','stok_hareket']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🏥 Kaydet + Görevler'; } }
}

// ── ABORT ────────────────────────────────────
async function abortKaydet(hayvanId, tohId) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  if (!confirm('Bu hayvanda abort / erken doğum mu oldu? Gebelik kaydı kapatılacak.')) return;
  const notlar = prompt('Abort detayı (opsiyonel):') || '';
  try {
    await rpc('abort_kaydet', {
      p_tohumlama_id: tohId,
      p_notlar:       notlar || null,
    });
    toast('✅ Abort kaydedildi, gebelik kapatıldı');
    pullTables(['tohumlama','gorev_log','hayvanlar']).then(renderSafe).catch(console.warn);
    openDet(hayvanId);
  } catch (e) { toast('❌ Abort kaydedilemedi: ' + e.message, true); }
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
  } catch (e) { toast(e.message, true); }
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
  const fiyat    = parseFloat(g('cikis-fiyat').value) || null;
  if (!tarih) { toast('Tarih zorunlu', true); return; }
  if (tip === 'olum' && !sebep) { toast('Ölüm sebebi girin', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    const hayvan = _A.find(a => a.id === hayvanId);
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
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '📤 Sürüden Çıkar'; } }
}

// ── SÜTTEN KESME ─────────────────────────────
function openSuttenKesModal() {
  const sutIcenler = _A.filter(a => a.hesap_kategori === 'sut_icen');
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
  const bugun = new Date().toISOString().split('T')[0];
  let basari = 0;
  try {
    for (const id of hayvanIdList) {
      const h = _A.find(a => a.id === id);
      if (!h || h.hesap_kategori !== 'sut_icen') continue;
      await write('hayvanlar', { suttten_kesme_tarihi: bugun }, 'PATCH', `id=eq.${id}`);
      basari++;
    }
    toast(`✅ ${basari} buzağı sütten kesildi`);
    closeM('m-sutten-kes');
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🍼 Sütten Kes'; } }
}
async function suttenKesTekil(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = _A.find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (h.hesap_kategori !== 'sut_icen') { toast('Bu hayvan süt içen kategorisinde değil', true); return; }
  if (!confirm(`${getDisplayKupe(h)} sütten kesilecek. Onaylıyor musunuz?`)) return;
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  const bugun = new Date().toISOString().split('T')[0];
  try {
    await write('hayvanlar', { suttten_kesme_tarihi: bugun }, 'PATCH', `id=eq.${hayvanId}`);
    toast(`✅ ${getDisplayKupe(h)} sütten kesildi`);
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🍼 Sütten Kes'; } }
}

// ── TOHUMLANABILIR ONAY ──────────────────────
async function submitTohumOnayla(hayvanId, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = _A.find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  try {
    await write('hayvanlar', { tohumlama_durumu: 'tohumlanabilir', tohumlama_onay_tarihi: new Date().toISOString().split('T')[0] }, 'PATCH', `id=eq.${hayvanId}`);
    toast(`✅ ${getDisplayKupe(h)} tohumlanabilir olarak onaylandı`);
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '✅ Tohumlanabilir Onayla'; } }
}
async function submitTohumErtele(hayvanId, ay, btn) {
  if (!navigator.onLine) { toast('⚠️ İnternet bağlantısı gerekli', true); return; }
  const h = _A.find(a => a.id === hayvanId);
  if (!h) { toast('Hayvan bulunamadı', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Kaydediliyor…'; }
  const erteleme = dFwd(new Date().toISOString().split('T')[0], ay * 30);
  try {
    await write('hayvanlar', { tohumlama_durumu: 'ertelendi', tohumlama_onay_tarihi: erteleme }, 'PATCH', `id=eq.${hayvanId}`);
    toast(`✅ ${getDisplayKupe(h)} tohumlama ${ay} ay ertelendi`);
    closeM('m-tohum-ertele');
    closeDet();
    pullTables(['hayvanlar']).then(renderSafe).catch(console.warn);
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '⏰ Ertele'; } }
}
function openTohumErtele(hayvanId, kupe) {
  g('te-hid').value = hayvanId;
  g('te-title').textContent = `⏰ Tohumlama Ertele — ${kupe}`;
  g('te-ay').value = '1';
  openM('m-tohum-ertele');
}

// ── GÖREV TAMAMLA ────────────────────────────
async function doneTask(id, hid, stokId, miktar, padok, btn) {
  btn.disabled = true;
  btn.innerHTML = '<div class="spin" style="width:14px;height:14px;border-width:2px"></div>';
  try {
    await write('gorev_log', { id, tamamlandi: true, tamamlanma_tarihi: new Date().toISOString() }, 'PATCH', `id=eq.${id}`);
    const _stokKontrol = stokId ? _S.find(s => s.id === stokId) : null;
    if (stokId && miktar > 0 && _stokKontrol)
      await write('stok_hareket', { id: crypto.randomUUID(), stok_id: stokId, tur: 'Görev', miktar, notlar: 'GorevID:' + id, iptal: false });
    if (padok && hid)
      await write('hayvanlar', { id: hid, padok }, 'PATCH', `id=eq.${hid}`);
    const el = document.getElementById('tc-' + id);
    if (el) { el.classList.add('done'); setTimeout(() => el.remove(), 320); }
    toast('✅ Tamamlandı');
    loadDash();
  } catch (e) {
    btn.disabled = false;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>';
    toast(e.message, true);
  }
}

// Görev detay modal
async function openTaskDet(id) {
  const task = (await getData('gorev_log', t => t.id === id))[0];
  if (!task) return;
  _curTaskDet = task;
  const h = _A.find(a => a.id === task.hayvan_id);
  g('td-title').textContent  = task.aciklama || '';
  g('td-hayvan').textContent = h ? getDisplayKupe(h) : (task.hayvan_id || '—');
  g('td-tarih').textContent  = fmtTarih(task.hedef_tarih);
  g('td-tip').textContent    = task.gorev_tipi || '';

  // Sub-görevler
  const subs = await getData('gorev_log', t => t.parent_id === id);
  const subEl = g('td-subs');
  if (subEl) subEl.innerHTML = subs.length
    ? subs.map(s => `<div style="display:flex;align-items:center;gap:8px;padding:6px 0;border-bottom:1px solid var(--card2)">
        <input type="checkbox" ${s.tamamlandi ? 'checked' : ''} onchange="toggleSub('${s.id}','${id}',this)" style="width:16px;height:16px">
        <span style="font-size:.8rem;${s.tamamlandi ? 'text-decoration:line-through;color:var(--ink3)' : ''}">${s.aciklama}</span>
      </div>`).join('')
    : '';
  openM('m-task-det');
}

async function toggleSub(subId, parentId, el) {
  const tamamlandi = el.checked;
  await write('gorev_log', { tamamlandi, tamamlanma_tarihi: tamamlandi ? new Date().toISOString() : null }, 'PATCH', `id=eq.${subId}`);
}

async function detayTamamla() {
  if (!_curTaskDet) return;
  await write('gorev_log', { ..._curTaskDet, tamamlandi: true, tamamlanma_tarihi: new Date().toISOString() }, 'PATCH', `id=eq.${_curTaskDet.id}`);
  toast('✅ Görev tamamlandı');
  closeM('m-task-det');
  await loadTasks(_curTaskFilter || 'today');
  loadDash();
}
async function detayIptal() {
  if (!_curTaskDet) return;
  if (!confirm('Bu görevi iptal etmek istediğinize emin misiniz?')) return;
  await write('gorev_log', { ..._curTaskDet, tamamlandi: true, tamamlanma_tarihi: new Date().toISOString() }, 'PATCH', `id=eq.${_curTaskDet.id}`);
  toast('Görev iptal edildi');
  closeM('m-task-det');
  await loadTasks(_curTaskFilter || 'today');
  loadDash();
}

// Manuel görev ekle
async function submitTaskAdd(btn) {
  const desc  = v('ta-desc');
  const tarih = v('ta-tarih');
  if (!desc || !tarih) { toast('Açıklama ve Tarih zorunlu', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Oluşturuluyor…'; }
  try {
    const hid    = v('ta-hid').trim();
    const hayvan = hid ? (_A.find(a => a.kupe_no === hid || a.id === hid)) : null;
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
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Görev Oluştur'; } }
}

// ── HASTALIK KAPAT ───────────────────────────
async function hstKapat() {
  if (!_curHst) return;
  try {
    const res = await rpc('hastalik_kapat', { p_id: _curHst.id });
    if (res?.ok === false) { toast('❌ ' + res.mesaj, true); return; }
    toast('✅ Hastalık kaydı kapatıldı');
    closeM('m-hst-det');
    await pullTables(['hastalik_log']); renderSafe();
  } catch(e) { toast('❌ ' + e.message, true); }
}

// _editMode: true iken submitDisease → hastalik_guncelle çağırır
let _editMode = false;

function closeDisease() {
  _editMode = false;
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
  window._semptomSecili = [];
  _ilacCache = [];
  closeM('m-disease');
}

// _editMode: true iken submitDisease → hastalik_guncelle çağırır
let _editMode = false;

function closeDisease() {
  _editMode = false;
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
  window._semptomSecili = [];
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
    const hayvan = _A.find(a => a.id === _curHst.hayvan_id);
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
  window._semptomSecili = [];
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
    const id = _curHst.id;
    closeDisease();
    await pullTables(['hastalik_log']);
    await openHstDet(id);
  } catch(e) { toast('❌ ' + e.message, true); }
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
    await pullTables(['hastalik_log']); renderSafe();
  } catch(e) { toast('❌ ' + e.message, true); }
}

// ── TOHUMLAMA SONUÇ ──────────────────────────
async function openTohDet(id) {
  const all = await idbGetAll('tohumlama');
  const t   = all.find(x => x.id === id); if (!t) return;
  _curToh = t;
  const hk = HEKIMLER.find(x => x.id === t.hekim_id) || _customHekimler.find(x => x.id === t.hekim_id);
  g('td2-hayvan').textContent = t.hayvan_id || '?';
  g('td2-sperma').textContent = `💉 ${t.sperma || '?'}`;
  const sc    = t.sonuc === 'Gebe' ? 'var(--green)' : t.sonuc === 'Boş' ? 'var(--red)' : 'var(--amber)';
  const chips = [
    `<span style="background:rgba(0,0,0,.06);padding:3px 9px;border-radius:10px;font-size:.7rem;font-weight:700;color:${sc}">${t.sonuc || 'Bekliyor'}</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">${t.deneme_no || 1}. deneme</span>`,
    `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">📅 ${fmtTarih(t.tarih)}</span>`,
    hk ? `<span style="background:var(--card2);padding:3px 9px;border-radius:10px;font-size:.7rem">👨‍⚕️ ${hk.ad}</span>` : '',
  ];
  g('td2-meta').innerHTML = chips.filter(Boolean).join('');
  openM('m-toh-det');
}
async function tohSonuc(sonuc) {
  if (!_curToh) return;
  await write('tohumlama', { ..._curToh, sonuc }, 'PATCH', `id=eq.${_curToh.id}`);
  toast(sonuc === 'Gebe' ? '✅ Gebe olarak işaretlendi' : sonuc === 'Boş' ? 'Boş olarak işaretlendi' : 'Güncellendi');
  closeM('m-toh-det');
  renderSafe();
}

// ── GEBELİK İŞARETLE ────────────────────────
async function gebeIsaretle() {
  const tohs         = await idbGetAll('tohumlama');
  const hayvanTohMap = {};
  tohs.forEach(t => { if (!hayvanTohMap[t.hayvan_id] || t.tarih > hayvanTohMap[t.hayvan_id].tarih) hayvanTohMap[t.hayvan_id] = t; });
  const adaylar = Object.values(hayvanTohMap).filter(t => t.sonuc === 'Bekliyor');
  if (!adaylar.length) { toast('Bekleyen tohumlama kaydı yok'); return; }

  let box = g('gebe-isaret-modal');
  if (!box) { box = document.createElement('div'); box.id = 'gebe-isaret-modal'; box.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:300;display:flex;align-items:flex-end'; box.onclick = e => { if (e.target === box) box.remove(); }; document.body.appendChild(box); }

  const rows = adaylar.map(t => {
    const h    = _A.find(a => a.id === t.hayvan_id);
    const kupe = getDisplayKupe(h, t.hayvan_id);
    const gun  = Math.floor((Date.now() - new Date(t.tarih)) / 86400000);
    return `<label style="display:flex;align-items:center;gap:12px;padding:12px 16px;border-bottom:1px solid #eee;cursor:pointer">
      <input type="checkbox" class="gebe-chk" data-toh-id="${t.id}" data-hayvan-id="${t.hayvan_id}" style="width:20px;height:20px;accent-color:var(--green);cursor:pointer">
      <div>
        <div style="font-weight:700;color:var(--ink)">${kupe}</div>
        <div style="font-size:.7rem;color:var(--ink3)">${t.sperma || '?'} · ${t.tarih} · ${gun}. gün</div>
      </div>
    </label>`;
  }).join('');

  box.innerHTML = `<div style="background:#fff;border-radius:18px 18px 0 0;width:100%;max-height:80vh;display:flex;flex-direction:column">
    <div style="padding:14px 16px 0;display:flex;justify-content:space-between;align-items:center">
      <div style="font-weight:800;font-size:1rem">🤰 Gebe İşaretle</div>
      <button onclick="g('gebe-isaret-modal').remove()" style="background:none;border:none;font-size:1.3rem;cursor:pointer;color:#999">✕</button>
    </div>
    <div style="font-size:.7rem;color:#999;padding:4px 16px 10px">Gebe olduğunu onayladığınız hayvanları seçin</div>
    <div style="overflow-y:auto;flex:1">${rows}</div>
    <div style="padding:12px 16px;display:flex;gap:8px;border-top:1px solid #eee">
      <button onclick="gebeIsaretKaydet()" style="flex:1;padding:12px;background:var(--green);color:#fff;border:none;border-radius:10px;font-weight:700;font-size:.9rem;cursor:pointer">✅ Gebe Olarak Kaydet</button>
      <button onclick="g('gebe-isaret-modal').remove()" style="padding:12px 16px;background:#f0f0f0;border:none;border-radius:10px;font-weight:700;cursor:pointer">İptal</button>
    </div>
  </div>`;
}

async function gebeIsaretKaydet() {
  const secili = [...document.querySelectorAll('.gebe-chk:checked')];
  if (!secili.length) { toast('En az bir hayvan seçin', true); return; }
  let n = 0;
  for (const chk of secili) {
    await write('tohumlama', { sonuc: 'Gebe' }, 'PATCH', `id=eq.${chk.dataset.tohId}`);
    n++;
  }
  g('gebe-isaret-modal')?.remove();
  toast(`✅ ${n} hayvan gebe olarak işaretlendi`);
  renderSafe();
  loadUreme('gebelik');
}

// ── GERİ ALMA ────────────────────────────────
function openGeriAl(islemLogId, ozet) {
  g('ga-hid').value = islemLogId;
  g('ga-ozet').textContent = ozet || 'Bu işlem geri alınacak.';
  openM('m-geri-al');
}
async function geriAl(islemLogId, btn) {
  if (!navigator.onLine) { toast('⚠️ Geri alma için internet gerekli', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Geri alınıyor…'; }
  try {
    await rpc('geri_al', { p_islem_id: islemLogId });
    toast('✅ İşlem geri alındı');
    closeM('m-geri-al');
    pullTables(['hayvanlar','tohumlama','hastalik_log','dogum','gorev_log','islem_log']).then(renderSafe).catch(console.warn);
  } catch (e) { toast('❌ ' + e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = '🔄 Evet, Geri Al'; } }
}

// ── STOK ─────────────────────────────────────
async function submitStk(btn) {
  const mik = parseFloat(g('se-mik').value);
  if (!mik || mik <= 0) { toast('Geçerli miktar girin', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Ekleniyor…'; }
  try {
    const updated = { ..._curStk, baslangic_miktar: (+_curStk.baslangic_miktar || 0) + mik };
    await write('stok', updated, 'PATCH', `id=eq.${_curStk.id}`);
    toast(`✅ ${_curStk.urun_adi}: +${mik} ${_curStk.birim || ''}`);
    closeM('m-stk');
    await loadStock();
    loadDash();
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Stok Ekle'; } }
}

async function submitStokAdd(btn) {
  const urun = (g('sa-ad')?.value||'').trim();
  const bslg = parseFloat(g('sa-mik')?.value||'0');
  if (!urun) { toast('Ürün adı zorunlu', true); return; }
  if (btn) { btn.disabled = true; btn.textContent = 'Ekleniyor…'; }
  const kat = g('sa-kat')?.value || 'İlaç';
  try {
    await write('stok', {
      id: crypto.randomUUID(), urun_adi: urun,
      birim: g('sa-birim')?.value || 'adet',
      baslangic_miktar: bslg || 0,
      esik: parseFloat(g('sa-esik')?.value||'0') || 0,
      kategori: kat,
      tur: kat,
    });
    toast(`✅ ${urun} stoka eklendi`);
    closeM('m-stok-add');
    ['sa-ad','sa-mik','sa-esik'].forEach(id=>{const e=g(id);if(e)e.value=''});
    await loadStock();
    await loadStokList();
  } catch (e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Ekle'; } }
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
    await write('tohumlama', {
      id: crypto.randomUUID(), hayvan_id: hayvanId,
      tarih, sperma: sperma || null, sonuc: 'Gebe', deneme_no: 1
    });
    toast('✅ Gebelik kaydedildi');
    closeM('m-gebelik');
    pullTables(['tohumlama','hayvanlar']).then(renderSafe);
  } catch(e) { toast(e.message, true); }
  finally { if (btn) { btn.disabled = false; btn.textContent = 'Kaydet'; } }
}

// ── BİLDİRİM ─────────────────────────────────
async function bildirimGoruldu(bildirimId) {
  try {
    await write('bildirim_log', { durum: 'goruldu' }, 'PATCH', `id=eq.${bildirimId}`);
    loadBildirimler(_curBildirimTab || 'bekliyor');
    updateBildirimBadge();
  } catch (e) { toast(e.message, true); }
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
    window._hdiIlacCache = [];
  }
}

async function hstIlacEkle(btn) {
  const stokId  = document.getElementById('hdi-stok-id').value.trim();
  const miktar  = parseFloat(document.getElementById('hdi-miktar').value);
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
  } catch(e) { toast('❌ ' + e.message, true); }
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
  } catch(e) { toast('❌ ' + e.message, true); }
}
