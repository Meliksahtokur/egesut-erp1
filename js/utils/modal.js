// js/utils/modal.js
// Modal yönetimi (app.js'den taşındı)

function openM(id) {
  const el = g(id); if (!el) return;
  el.classList.add('on');
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
  // Android geri tuşu: bizim pushState ettiğimiz modalı back ile kapat
  if (history.state?.modal === id) history.back();
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
  if (e.target === el) {
    el.classList.remove('on');
    // Android geri tuşu: backdrop tıklaması da history'ye yansısın
    if (history.state?.modal === el.id) history.back();
  }
}
