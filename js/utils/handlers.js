// js/utils/handlers.js
// Event handler registrations (app.js'den ayrıştırıldı)

registerActions({

  // ═══ NAVİGASYON ═══
  'refresh': (el) => { el.classList.add('spinning'); refreshAll().finally(() => el.classList.remove('spinning')); },
  'open-ayarlar': () => ayarlarAc(),
  'show-error-panel': () => { g('error-panel').style.display = 'block'; renderErrorLog(); },
  'go-dash':    () => goTo('dash'),
  'go-suru':    () => goTo('suru'),
  'go-tasks':   () => goTo('tasks'),
  'go-ureme':   () => goTo('ureme'),
  'go-gecmis':  () => goTo('gecmis'),
  'go-log':     () => goTo('log'),
  'go-back': () => {
    if (window._prevTaskId) {
      const tid = window._prevTaskId;
      window._prevTaskId = null;
      closeDet();
      openTaskDet(tid);
    } else {
      history.back();
    }
  },
  'hayvan-git': () => {
    if (!_curTaskDet) return;
    fromTaskOpenDet(_curTaskDet.hayvan_id, _curTaskDet.id);
  },

  // ═══ ARAMA ═══
  'search-input': () => { filterA(); srchDropdown(); },
  'search-focus': () => srchDropdown(),
  'search-keydown': (opts) => acNav(opts.event, 'ac-srch'),
  'search-change': () => filterA(),

  // ═══ FİLTRE CHİPLERİ ═══
  'fchip-cinsiyet-hepsi':  (el) => fchipSec('cinsiyet', 'hepsi', el),
  'fchip-cinsiyet-disi':   (el) => fchipSec('cinsiyet', 'disi', el),
  'fchip-cinsiyet-erkek':  (el) => fchipSec('cinsiyet', 'erkek', el),
  'fchip-gebelik-gebe':    (el) => fchipSec('gebelik', 'gebe', el),
  'fchip-gebelik-bos':     (el) => fchipSec('gebelik', 'bos', el),
  'fchip-saglik-hasta':    (el) => fchipSec('saglik', 'hasta', el),
  'fchip-kisir':           (el) => fchipSec('kisir', 'kisir', el),
  'fchip-tekrar':          (el) => fchipSec('tekrar', 'tekrar', el),

  // ═══ ÜREME SEKMELERİ ═══
  'ureme-kizginlik': (el) => uremeTab('kizginlik', el),
  'ureme-tohumlama': (el) => uremeTab('tohumlama', el),
  'ureme-gebelik':   (el) => uremeTab('gebelik', el),
  'ureme-dogum':     (el) => uremeTab('dogum', el),
  'ureme-abort':     (el) => uremeTab('abort', el),

  // ═══ GÖREV FİLTRELERİ ═══
  'tasks-today': (el) => loadTasks('today', el),
  'tasks-late':  (el) => loadTasks('late', el),
  'tasks-all':   (el) => loadTasks('all', el),
  'tasks-done':  (el) => loadTasks('done', el),
  'task-kat-all':     (el) => setTaskKat('all', el),
  'task-kat-asi':     (el) => setTaskKat('asi', el),
  'task-kat-vitamin': (el) => setTaskKat('vitamin', el),
  'task-kat-muayene': (el) => setTaskKat('muayene', el),
  'task-kat-tedavi':  (el) => setTaskKat('tedavi', el),
  'task-kat-bakim':   (el) => setTaskKat('bakim', el),
  'task-kat-diger':   (el) => setTaskKat('diger', el),

  // ═══ GEÇMİŞ FİLTRELERİ ═══
  'gecmis-hepsi':     (el) => loadGecmis('hepsi', el),
  'gecmis-dogum':     (el) => loadGecmis('dogum', el),
  'gecmis-tohumlama': (el) => loadGecmis('tohumlama', el),
  'gecmis-hastalik':  (el) => loadGecmis('hastalik', el),
  'gecmis-gorev':     (el) => loadGecmis('gorev', el),
  'gecmis-hayvan':    (el) => loadGecmis('hayvan', el),

  // ═══ MODAL AÇ/KAPAT ═══
  'open-modal': (el) => openM(el.dataset.modal),
  'mclose-overlay': (el, e) => { if (e.target === el) el.classList.remove('on'); },
  'open-birth-modal':    () => openM('m-birth'),
  'open-insem-modal':    () => openM('m-insem'),
  'open-disease-modal':  () => openM('m-disease'),
  'open-bulk-vaccine':   () => openM('m-bulk-vaccine'),
  'open-bulk-ilac':      () => openM('m-bulk-ilac'),
  'open-animal-modal':   () => openM('m-animal'),
  'open-task-add-modal': () => openM('m-task-add'),
  'open-stok-panel':     () => openStokPanel(),
  'close-birth':     () => closeM('m-birth'),
  'close-insem':     () => closeM('m-insem'),
  'close-disease':   () => closeM('m-disease'),
  'close-vaccine':   () => closeM('m-vaccine'),
  'close-bulk-vaccine': () => closeM('m-bulk-vaccine'),
  'close-bulk-ilac': () => closeM('m-bulk-ilac'),
  'close-kizginlik': () => closeM('m-kizginlik'),
  'close-task-add':  () => closeM('m-task-add'),
  'close-task-edit': () => closeM('m-task-edit'),
  'close-task-det':  () => closeM('m-task-det'),
  'close-done-det':  () => closeM('m-done-det'),
  'close-case-det':  () => closeM('m-case-det'),
  'close-toh-det':   () => closeM('m-toh-det'),
  'close-geri-al':   () => closeM('m-geri-al'),
  'close-not':       () => closeM('m-not'),
  'close-cikis':     () => closeM('m-cikis'),
  'close-gebelik':   () => closeM('m-gebelik'),
  'close-confirm':   () => closeM('m-confirm'),
  'close-padok-det': () => closeM('m-padok-det'),
  'close-padok-transfer': () => closeM('m-padok-transfer'),
  'close-stok-det':  () => closeM('m-stok-det'),
  'close-stok-hareketler': () => closeM('m-stok-hareketler'),
  'close-hekim-det': () => closeM('m-hekim-det'),
  'close-stk':       () => closeM('m-stk'),
  'close-ayarlar':   () => closeM('m-ayarlar'),
  'close-stok-panel': () => closeStokPanel(),
  'close-stok-add':   () => closeM('m-stok-add'),

  // ═══ HAYVAN DETAY SEKMELERİ ═══
  'tab-ozet':   (el) => showTab('ozet', el),
  'tab-saglik': (el) => showTab('saglik', el),
  'tab-ureme':  (el) => showTab('ureme', el),
  'tab-gorev':  (el) => showTab('gorev', el),
  'tab-gecmis': (el) => showTab('gecmis', el),

  // ═══ KIZGINLIK ═══
  'kizginlik-ac': (el) => { acHayvan('k-hid', 'ac-khid'); el.focus(); },
  'kizginlik-focus': (el) => acHayvan('k-hid', 'ac-khid'),
  'kizginlik-keydown': (opts) => acNav(opts.event, 'ac-khid'),
  'submit-kizginlik':  (el) => submitKizginlik(el),
  'kizginlik-search':  () => kizginlikSearch(),
  'kizginlik-filtre-tumu':        (el) => kizginlikFiltre('tumu', el),
  'kizginlik-filtre-bekleyen':    (el) => kizginlikFiltre('bekleyen', el),
  'kizginlik-filtre-sonuclanan':  (el) => kizginlikFiltre('sonuclanan', el),

  // ═══ TOHUMLAMA ═══
  'insem-ac':     (el) => { acHayvan('i-hid', 'ac-ihid'); el.focus(); },
  'insem-focus':  (el) => acHayvan('i-hid', 'ac-ihid'),
  'insem-keydown':(opts) => acNav(opts.event, 'ac-ihid'),
  'sperma-stok':  () => spermaModStok(),
  'sperma-elle':  () => spermaModElle(),
  'sperma-select':(el) => onSpermaSelect(el),
  'sperma-input': (el) => { g('i-sperma').value = el.value; },
  'submit-insem': (el) => submitInsem(el),

  // ═══ HASTALIK ═══
  'disease-focus':  (el) => acHayvan('d-hid', 'ac-dhid'),
  'disease-keydown':(opts) => acNav(opts.event, 'ac-dhid'),
  'disease-select': () => onDiseaseSelect(),
  'submit-case':    (el) => submitCase(el),

  // ═══ AŞI ═══
  'vaccine-focus':  (el) => acHayvan('v-hid', 'ac-vhid'),
  'vaccine-keydown':(opts) => acNav(opts.event, 'ac-vhid'),
  'vaccine-select': () => onVaccineSelect(),
  'submit-vaccine': (el) => submitVaccination(el),

  // ═══ DOĞUM ═══
  'birth-focus':  (el) => acHayvan('b-anne', 'ac-banne'),
  'birth-keydown':(opts) => acNav(opts.event, 'ac-banne'),
  'birth-gebeden-sec': () => gebedenSec(),
  'birth-manual': (el) => { el.style.display = 'none'; g('b-anne-manual').style.display = 'block'; },
  'birth-anne-sifirla': () => anneSecimSifirla(),
  'submit-birth': (el) => submitBirth(el),

  // ═══ HAYVAN FORMU ═══
  'animal-guncelle':     () => animalFormGuncelle(),
  'irk-secim-degisti':   () => irkSecimDegisti(),
  'grup-degisti':        () => animalGrupDegisti(),
  'submit-animal':       (el) => submitAnimal(el),
  'close-animal-edit':   () => closeAnimalEdit(),

  // ═══ TOPLU AŞI (BULK VACCINE) ═══
  'bv-tab-padok':   () => bulkTabSwitch('bv', 'padok'),
  'bv-tab-filtre':  () => bulkTabSwitch('bv', 'filtre'),
  'bv-tab-serbest': () => bulkTabSwitch('bv', 'serbest'),
  'bv-load':        () => loadBulkVaccineHayvanlar(),
  'bv-apply-filtre':() => applyBulkFiltre('bv'),
  'bv-filter-input':() => filterBulkSerbest('bv'),
  'submit-bv':      () => submitBulkVaccination(),

  // ═══ TOPLU İLAÇ ═══
  'bi-tab-padok':   () => bulkTabSwitch('bi', 'padok'),
  'bi-tab-filtre':  () => bulkTabSwitch('bi', 'filtre'),
  'bi-tab-serbest': () => bulkTabSwitch('bi', 'serbest'),
  'bi-load':        () => loadBulkIlacHayvanlar(),
  'bi-apply-filtre':() => applyBulkFiltre('bi'),
  'bi-filter-input':() => filterBulkSerbest('bi'),
  'submit-bi':      () => submitBulkIlac(),

  // ═══ STOK ═══
  'stok-tab-tumu':    (el) => setStokTab('tumu', el),
  'stok-tab-ilac':    (el) => setStokTab('ilac', el),
  'stok-tab-asi':     (el) => setStokTab('asi', el),
  'stok-tab-sperma':  (el) => setStokTab('sperma', el),
  'stok-tab-diger':   (el) => setStokTab('diger', el),
  'stok-add-open':    () => openStokAdd(),
  'stok-hareketler':  () => tumStokHareketleriniGoster(),
  'stok-add-tip-ilac':   () => saTipSec('ilac'),
  'stok-add-tip-sperma': () => saTipSec('sperma'),
  'stok-add-tip-ekipman':() => saTipSec('ekipman'),
  'submit-stok-add':  (el) => submitStokAdd(el),
  'submit-stk':       (el) => submitStk(el),

  // ═══ GÖREV DETAY ═══
  'asi-uygula-tamamla': () => asiUygulaVeTamamla(),
  'asi-form-gizle':     () => { g('td-asi-form').style.display = 'none'; g('td-asi-ac-btn').style.display = 'block'; const ri=g('td-rapel-info'); if(ri) ri.style.display='none'; },
  'rapel-tarihi-kaydet':() => rapelTarihiKaydet(),
  'detay-tamamla':      () => detayTamamla(),
  'tedavi-gun-tamamla': () => gorevTedaviGunDone(),
  'asi-form-ac':        () => asiFormAc(),
  'detay-duzenle':      () => openTaskEdit(),
  'detay-iptal':        () => detayIptal(),
  'gorev-geri-al':      () => gorevGeriAl(),
  'case-gun-ekle':      () => caseGunEkle(),
  'case-kapat':         () => caseKapat(),
  'toh-sonuc-kaydet':   () => tohSonucKaydet(),
  'toh-sonuc-bekliyor': () => tohSonuc('Bekliyor'),
  'geri-al':            (el) => islemGeriAl(el, g('ga-hid').value),
  'submit-cikis':       (el) => submitCikis(el),
  'submit-gebelik':     (el) => submitGebelikEkle(el),
  'submit-task-add':    (el) => submitTaskAdd(el),
  'submit-task-edit':   (el) => submitTaskEdit(el),

  // ═══ HAYVAN İŞLEMLERİ ═══
  'hayvan-not-ekle':  (el) => hayvanNotEkle(g('not-hid').value, el),

  // ═══ PADOK ═══
  'padok-duzenle-kaydet': () => padokDuzenleKaydet(),
  'padok-sil-onay':       () => padokSilOnay(),
  'padok-input':          () => { if (_pdKaynakPadokId) renderPadokHayvanlar(_pdKaynakPadokId); },
  'padok-toplu-tasi':     () => padokTopluTasi(),
  'padok-transfer-onay':  () => padokTransferOnayla(),

  // ═══ STOK DETAY ═══
  'stok-duzelt-kaydet': () => stokDuzeltKaydet(),
  'stok-det-kaydet':    () => stokDetKaydet(),
  'stok-det-arsivle':   () => stokDetArsivle(),

  // ═══ HEKİM ═══
  'hekim-period-all': (el, e) => hekimPeriod('all', e),
  'hekim-period-30':  (el, e) => hekimPeriod(30, e),
  'hekim-period-90':  (el, e) => hekimPeriod(90, e),
  'hekim-period-180': (el, e) => hekimPeriod(180, e),
  'hekim-period-365': (el, e) => hekimPeriod(365, e),
  'hekim-det-kaydet': () => hekimDetKaydet(),
  'hekim-det-sil':    () => hekimDetSil(),

  // ═══ AYARLAR ═══
  'ayar-hekim-ekle':     () => ayarlarHekimEkle(),
  'ayar-hekim-kaydet':   () => ayarlarHekimKaydet(),
  'ayar-hekim-form-gizle':() => { g('ay-hekim-form').style.display = 'none'; },
  'ayar-padok-ekle':     () => ayarlarPadokEkle(),
  'ayar-padok-kaydet':   () => ayarlarPadokKaydet(),
  'ayar-padok-form-gizle':() => { g('ay-padok-form').style.display = 'none'; },

  // ═══ DATA TRAFFIC ═══
  'data-traffic-yenile': () => dataTrafficYenile(),
  'data-traffic-gonder': () => dataTrafficGonder(),
  'kuyrugu-temizle':     () => kuyrukuTemizle(),
  'stok-hareketi-temizle':() => stokHareketiTemizle(),
  'bildirim-ac':   () => bildirimAc(),
  'pwa-install':   () => pwaInstall(),
  'theme-light':   () => setTheme('light'),
  'theme-dark':    () => setTheme('dark'),
  'copy-errors':   () => copyErrors(),
  'clear-errors':  () => clearErrors(),
  'hide-error-panel': () => { g('error-panel').style.display = 'none'; },

  // ═══ TEKRAR AŞIM ═══
  'submit-tekrar-asim': (el) => submitTekrarAsim(el),
  'close-tekrar-asim':  () => closeM('m-insem-tekrar'),
  'close-insem-intercept': () => closeM('m-insem-intercept'),
  'intercept-tekrar-asim': () => {
    closeM('m-insem-intercept');
    const h=globalThis._insemInterceptHayvan;
    if(h) openTekrarAsim(h.id, h.kupeNo);
  },
  'tr-sperma-stok':     () => trSpermaModStok(),
  'tr-sperma-elle':     () => trSpermaModElle(),
  'tr-sperma-select':   (el) => onTrSpermaSelect(el),
  'tr-sperma-text':     (el) => { g('tr-sperma').value = el.value; },
});