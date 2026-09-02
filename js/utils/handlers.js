// js/utils/handlers.js
// Event handler registrations (app.js'den ayrıştırıldı)

registerActions({

  // ═══ NAVİGASYON ═══
  'refresh': (el) => { el.classList.add('spinning'); refreshAll().finally(() => el.classList.remove('spinning')); },
  'open-ayarlar': () => { ayarlarAc(); if (window.authFillAccount) window.authFillAccount(); },
  'hesap-sifre-degistir': () => { if (window.authChangePassword) window.authChangePassword(); },
  'hesap-cikis':          () => { if (window.authLogout) window.authLogout(); },
  'show-error-panel': () => { g('error-panel').style.display = 'block'; renderErrorLog(); },
  'go-dash':    () => goTo('dash'),
  'go-suru':    () => goTo('suru'),
  'go-tasks':   () => goTo('tasks'),
  'go-ureme':   () => goTo('ureme'),
  'go-gecmis':  () => goTo('gecmis'),
  'go-log':     () => goTo('log'),

  // ═══ AI ASİSTAN ═══
  'open-asistan':         () => { if (typeof goTo === 'function') goTo('asistan'); },
  'asistan-gonder':       () => window.asistanGonder(),
  'asistan-yeni':         () => window.asistanYeniSohbet(),
  'asistan-gecmis':       () => window.asistanGecmisAc(),
  'asistan-drawer-kapat': () => window.asistanDrawerKapat(),
  'asistan-tumunu-sil':   () => window.asistanTumunuSil(),
  'asistan-thread-ac':    (el) => window.asistanThreadAc(el.dataset.tid),
  'asistan-thread-sil':   (el) => window.asistanThreadSil(el.dataset.tid),
  'asistan-ornek':        (el) => window.asistanGonder(el.dataset.soru),
  'asistan-mesaj-duzenle': (el) => window.asistanMesajDuzenle(el),
  'asistan-mesaj-kopyala': (el) => window.asistanMesajKopyala(el),
  'asistan-plan-onayla':  (el) => window.asistanPlanOnayla(el.dataset.pid, el),
  'asistan-plan-vazgec':  (el) => window.asistanPlanVazgec(el.dataset.pid, el),
  'asistan-plan-geri-al': (el) => window.asistanPlanGeriAl(el.dataset.pid, el),
  'asistan-enter':        (p) => { if (p.key === 'Enter' && !p.event.shiftKey) { p.event.preventDefault(); window.asistanGonder(); } },
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
  'search-input': (() => { let _t; return () => { filterA(); clearTimeout(_t); _t = setTimeout(srchDropdown, 200); }; })(),
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
  'fchip-dogum':           (el) => fchipSec('dogum', 'dogurdu', el),
  'fchip-grup':            (el) => fchipSec('grup', el.dataset.grup, el),

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
  'pend-win-hepsi': () => { _pendWin = null; loadTasks('all'); },
  'pend-win-yarin': () => { _pendWin = _pendWin === 'yarin' ? null : 'yarin'; loadTasks('all'); },
  'pend-win-7':     () => { _pendWin = _pendWin === '7' ? null : '7'; loadTasks('all'); },
  'pend-win-30':    () => { _pendWin = _pendWin === '30' ? null : '30'; loadTasks('all'); },
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
  'gecmis-search':    (() => { let _t; return (el) => { clearTimeout(_t); _t = setTimeout(() => _gecmisRender(el.value), 200); }; })(),
  'gecmis-tumu-toggle': () => {
    _gecmisTumu = !_gecmisTumu;
    const tog = document.getElementById('gecmis-toggle');
    if (tog) {
      tog.style.background = _gecmisTumu ? 'var(--green)' : 'var(--card3)';
      tog.firstElementChild.style.left = _gecmisTumu ? '16px' : '2px';
    }
    loadGecmis(_curGecmisFilter);
  },

  // ═══ MODAL AÇ/KAPAT ═══
  'open-modal': (el) => openM(el.dataset.modal),
  // Backdrop kapatma closeM'den geçmeli — direkt classList.remove cleanup'ı
  // atlıyordu (_planliTohumlamaGorevId sızıntısı → B3) ve history.back yapmıyordu
  'mclose-overlay': (el, e) => { if (e.target === el) closeM(el.id); },
  'open-birth-modal':    () => openM('m-birth'),
  'ikinci-yavru-ekle':   (el) => ikinciYavruAc(el.dataset.hid, el.dataset.kupe, el.dataset.dt, el.dataset.sperma),
  'open-insem-modal':    () => openM('m-insem'),
  'open-disease-modal':  () => openM('m-disease'),
  'open-bulk-vaccine':   () => openM('m-bulk-vaccine'),
  'open-bulk-ilac':      () => openM('m-bulk-ilac'),
  'open-sutten-kes':     () => openSuttenKesModal(),
  'close-sutten-kes':    () => closeM('m-sutten-kes'),
  'sk-hepsi':            () => skHepsiniSec(true),
  'sk-hicbiri':          () => skHepsiniSec(false),
  'sk-onayla':           (el) => skOnayla(el),
  'sutten-kes-tekil':    (el) => suttenKesTekil(el.dataset.hid, el),
  'sutten-kes-geri-al':  (el) => suttenKesGeriAl(el.dataset.hid, el),
  'pa-toggle':           (el) => { const s = document.getElementById(el.dataset.sec); if (s) s.style.display = s.style.display === 'none' ? 'block' : 'none'; },
  'pa-chip':             (el) => protokolAyarKaydet(el.dataset.anahtar, el.dataset.deger),
  'open-animal-modal':   () => openM('m-animal'),
  'open-task-add-modal': () => openM('m-task-add'),
  // m-task-add küpe autocomplete (m-vaccine'deki acHayvan deseninin aynısı)
  'taskadd-focus':   (el) => acHayvan('ta-hid', 'ac-tahid'),
  'taskadd-keydown': (opts) => acNav(opts.event, 'ac-tahid'),
  'commit-pending':      () => loadTasks(),   // argümansız → _curTaskFilter; loadTasks başı flushPendingDone yapar
  'cancel-pending':      () => cancelPendingDone(),
  'open-stok-panel':     () => openStokPanel(),
  'open-tanimlar-panel':  () => openTanimlarPanel(),
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
  'close-tanimlar-panel': () => closeTanimlarPanel(),
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
  'tohumlama-search': () => tohumlamaSearch(),
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
  'planli-insem-iptal': () => { globalThis._planliTohumlamaGorevId=null; closeM('m-insem'); },

  // ═══ HASTALIK ═══
  'disease-focus':  (el) => acHayvan('d-hid', 'ac-dhid'),
  'disease-keydown':(opts) => acNav(opts.event, 'ac-dhid'),
  'disease-select': () => onDiseaseSelect(),
  'submit-case':    (el) => submitCase(el),

  // ═══ AŞI ═══
  'vaccine-focus':  (el) => acHayvan('v-hid', 'ac-vhid'),
  'vaccine-keydown':(opts) => acNav(opts.event, 'ac-vhid'),
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
  'tanimlar-tab-hastaliklar': (el) => setTanimlarTab('hastaliklar', {target:el}),
  'tanimlar-tab-ilaclar':     (el) => setTanimlarTab('ilaclar', {target:el}),
  'tanimlar-tab-kategoriler':  (el) => setTanimlarTab('kategoriler', {target:el}),
  'tanimlar-tab-sablonlar':   (el) => setTanimlarTab('sablonlar', {target:el}),
  // #63 şablon tedavi planlama
  'sablon-yeni':         () => openSablonBuilder(null),
  'sablon-duzenle':      (el) => openSablonBuilder(el.dataset.id),
  'sablon-sil':          (el) => silSablon(el.dataset.id),
  'sablon-gun-ekle':     () => sablonGunEkle(),
  'sablon-gun-sil':      (el) => sablonGunSil(el.dataset.gi),
  'sablon-gun-ofset':    (el) => sablonGunOfsetGuncelle(el.dataset.gi, el.value),
  'sablon-gun-toggle':   (el) => sablonGunToggle(el.dataset.gi),
  'sablon-seans-ac':     (el) => sablonSeansAc(el.dataset.gi),
  'sablon-seans-sil':    (el) => sablonSeansSil(el.dataset.gi, el.dataset.ki),
  'sablon-seans-ekle':   (el) => sablonSeansEkle(el.dataset.gi),
  'sablon-seans-vazgec': () => sablonSeansVazgec(),
  'sablon-saat-chip':    (el) => sablonSaatChip(el.dataset.t),
  'sablon-tohumlama-gun-ekle': (el) => sablonTohumlamaGunEkle(el.dataset.gi),
  'sablon-tohumlama-sil':      () => sablonTohumlamaSil(),
  'sablon-tohumlama-saat':   (el) => sablonTohumlamaSaat(el.value),
  'sablon-kaydet':       () => sablonKaydet(),
  'sablon-iptal':        () => closeM('m-sablon'),
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
  'case-tohumlama-ekle':() => caseTohumlamaEkleAc(),
  'case-kapat':         () => caseKapat(),
  'erken-kapat-toggle': () => caseErkenKapatToggle(),
  'erken-kapat-onayla': (el) => caseErkenKapatOnayla(el),
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

  // ── Toplu Transfer ──
  'bt-toggle-mode':  () => btToggleSecimModu(),
  'bt-transfer':     () => { if (_btSecilenIds.length) openBulkTransfer(); },
  'bt-cancel':       () => exitBtSecimModu(),
  'close-bulk-transfer': () => closeM('m-bulk-transfer'),
  'bt-tab-padok':    () => bulkTabSwitch('bt', 'padok'),
  'bt-tab-filtre':   () => bulkTabSwitch('bt', 'filtre'),
  'bt-tab-serbest':  () => bulkTabSwitch('bt', 'serbest'),

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
