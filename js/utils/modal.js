// js/utils/modal.js
// Modal yönetimi (app.js'den taşındı)

function openM(id) {
  const el = g(id); if (!el) return;
  el.classList.add('on');
  // Router stack: popstate en üstteki açık modalı kapatır (B2 — DOM sırasına
  // güvenilmez, yığılmış modallarda en son açılan kapanmalı)
  globalThis._modalStack = (globalThis._modalStack || []).filter(x => x !== id);
  globalThis._modalStack.push(id);
  // Android geri tuşu: modal açılışını history'e ekle (router)
  history.pushState({modal:id}, '', '');
  // Hayvan modalında doğum tarihi otomatik dolmasın — yaş hesabı bozuluyor
  if (id !== 'm-animal') {
    el.querySelectorAll('input[type=date]').forEach(i => { if (!i.value) i.value = new Date().toISOString().split('T')[0]; });
  }
  if (id === 'm-animal') {
    const today = new Date().toISOString().split('T')[0];
    const dtInput = g('a-dt');
    if (dtInput) dtInput.max = today;
    loadIrkDropdown();
    animalFormGuncelle();
  }
  if (id === 'm-insem') {
    clearTimeout(globalThis._insemKupeTid);
    cl('i-hid');
    const acIhid = g('ac-ihid'); if (acIhid) acIhid.style.display = 'none';
    db.from('tohumlanabilir_hayvanlar').select('*').then(({data}) => {
      globalThis._TH = data || [];
      const inp = g('i-hid');
      const ac  = g('ac-ihid');
      if (inp && (document.activeElement === inp || ac?.style.display !== 'none')) {
        acHayvan('i-hid', 'ac-ihid');
      }
    }).catch(console.warn);
    setTimeout(() => spermaModStok(), 100);
  }
  if (id === 'm-disease') {
    _semptomSecili = [];
    _diseasesCache = [];
    if(g('sempt-chips')) g('sempt-chips').innerHTML = '';
    if(g('d-sempt')) g('d-sempt').value = '';
    updateSemptomDropdown('');
    filterHastalikList();
    loadDiseasesDropdown('');
  }
  if (id === 'm-bulk-vaccine') {
    if(typeof loadBulkVaccinePadoklar==='function') loadBulkVaccinePadoklar();
    if(typeof loadBulkVaccineVaccines==='function') loadBulkVaccineVaccines();
  }
  if (id === 'm-bulk-ilac') {
    if(typeof loadBulkIlacPadoklar==='function') loadBulkIlacPadoklar();
    if(typeof loadBulkIlacDropdown==='function') loadBulkIlacDropdown();
  }
}

function closeM(id) {
  g(id)?.classList.remove('on');
  globalThis._modalStack = (globalThis._modalStack || []).filter(x => x !== id);
  // Android geri tuşu: bizim pushState ettiğimiz modalı back ile kapat.
  // _modalBackGuard: bu back'in ürettiği popstate, popstate handler'da
  // tüketilir — altındaki modalı/sayfayı yanlışlıkla kapatmasın diye.
  if (history.state?.modal === id) { globalThis._modalBackGuard = true; history.back(); }
  // Planlı tohumlama bayrağını HER kapanış yolunda bırak (overlay, X, ESC, geri tuşu).
  // Aksi halde bayrak takılı kalır ve bir sonraki NORMAL tohumlama, kapanmış bir
  // planlı göreve yazılmaya çalışılır.
  if (id === 'm-insem') globalThis._planliTohumlamaGorevId = null;
  // Hayvan formunu tam sıfırla — bir sonraki açılışta temiz başlasın
  if (id === 'm-animal') {
    ['a-devlet','a-kupe','a-irk-txt','a-dt','a-dkg','a-agirlik','a-boy','a-renk','a-ozellik'].forEach(cl);
    const cins = g('a-cinsiyet'); if (cins) cins.value = '';
    const irkSel = g('a-irk-sel'); if (irkSel) irkSel.value = '';
    const grup = g('a-grup'); if (grup) grup.innerHTML = '<option value="">Önce cinsiyet seçin</option>';
    const padok = g('a-padok'); if (padok) padok.innerHTML = '<option value="">Önce grup seçin</option>';
    const hint = g('a-grup-hint'); if (hint) hint.style.display = 'none';
  }
}

function mClose(e, el) {
  // Backdrop kapatma da closeM'den geçsin — cleanup + history tek noktadan (B3)
  if (e.target === el) closeM(el.id);
}
