// js/degisiklikler/degisiklikler-stub.js
// L4-W2 STUB katmanı — W1 motor genişletmesi (zincir/sirali_rehber/zaman hedefi/
// telafi kaydı) canlıya alınana kadar UI'ın deterministik veriyle koşması için.
//
// Kalıp: js/api.js:698 yorum deseni — 4 rpc* sarmalayıcısı AYNI imzayla EZİLİR
// (window ataması: api.js'teki global function bildirimlerinin yerine geçer).
// AKTİFLEŞME: yalnız DEMO + URL'de ?stub varken (window.DEGISIM_STUB=true);
// aksi halde dosya no-op'tur (gerçek RPC'ler çalışır). Entegrasyonda lead TEK
// noktadan söker: index.html'deki script satırı (goal §W2).
//
// Stub verisi zarf sözleşmesinin şekline uyar: zincir planı (txid+zaman+bağımlı
// adım), sirali_rehber (en yeni önce), çakışmalar TAM liste (zaman + değişen
// alanlar). Değerler deterministiktir (e2e S1/S3/S3b/S4); tx id'leri 7600001+
// uzayı stub tanımlıdır.

(function () {
  'use strict';
  const params = new URLSearchParams(location.search || '');
  // ?stub (değersiz) veya ?stub=1 → aktif; ?stub=0/false → kapalı (L4-W2 review-2)
  if (!window.IS_DEMO || !params.has('stub') || /^(0|false)$/i.test(params.get('stub') || '')) return;   // gerçek RPC'ler aynen
  window.DEGISIM_STUB = true;

  const ERR = (kod, mesaj, detay) => {
    const e = new Error(mesaj || kod);
    e.data = { ok: false, hata: kod, mesaj: mesaj || kod, detay: detay || {} };
    return e;
  };
  const TS = '2026-09-13T';

  // ── Stub tx evreni (Değişiklikler listesi) ─────────────────────────
  const STUB_KAYITLAR = [
    {
      txid: 7600001, ilk_zaman: TS + '17:25:00+03:00',
      ozet: { baslik: 'Görev Tamamlandı', islemler: { I: 2 } },
      kaynak: { app_name: 'egesut-web', rol: 'sahip' },
    },
    {
      txid: 7600002, ilk_zaman: TS + '16:10:00+03:00',
      ozet: { baslik: 'Hayvan Güncellendi', islemler: { U: 1 } },
      kaynak: { app_name: 'egesut-web', rol: 'sahip' },
    },
    {
      txid: 7600003, ilk_zaman: TS + '15:40:00+03:00',
      ozet: { baslik: 'Tohumlama', islemler: { I: 1 } },
      kaynak: { app_name: 'egesut-web', rol: 'sahip' },
    },
    {
      txid: 7600005, ilk_zaman: TS + '12:00:00+03:00',
      ozet: { baslik: 'Padok Güncellendi', islemler: { U: 1 } },
      kaynak: { app_name: 'egesut-web', rol: 'sahip' },
    },
    {
      txid: 7600004, ilk_zaman: TS + '14:00:00+03:00',
      ozet: { baslik: 'Toplu İlaç', islemler: { I: 3 } },
      kaynak: { app_name: 'harici-panel', rol: 'servis' },   // uygulama dışı → varsayılan gizli
    },
  ];

  // tx detayları: teknikal satır (7600001) ve boş-alan/değişen-alan karışımı (7600005) bilinçli
  const STUB_DETAYLAR = {
    7600001: [
      {
        tablo_adi: 'gorev_log', satir_pk: { id: 'gorev-stub-1' }, islem: 'I',
        zaman: TS + '17:25:00+03:00', kaynak: { app_name: 'egesut-web', rol: 'sahip' },
        eski: null,
        yeni: { id: 'gorev-stub-1', gorev_tipi: 'ASI', tamamlandi: true, tamamlanma_notu: 'Aşı uygulandı', notlar: '' },
      },
      {
        tablo_adi: 'stok_hareket', satir_pk: { id: 'hareket-stub-1' }, islem: 'I', teknikal_mi: true,
        zaman: TS + '17:25:00+03:00', kaynak: { app_name: 'egesut-web', rol: 'sahip' },
        eski: null,
        yeni: { id: 'hareket-stub-1', tur: 'Cikis', miktar: 2, birim: 'doz' },
      },
    ],
    7600005: [
      {
        tablo_adi: 'padoklar', satir_pk: { id: 'padok-stub-1' }, islem: 'U',
        zaman: TS + '12:00:00+03:00', kaynak: { app_name: 'egesut-web', rol: 'sahip' },
        eski: { id: 'padok-stub-1', ad: 'Padok A', kapasite: 50, aciklama: '' },
        yeni: { id: 'padok-stub-1', ad: 'Padok A', kapasite: 80, aciklama: 'genişletildi' },
      },
    ],
  };
  STUB_DETAYLAR[7600002] = [{
    tablo_adi: 'hayvanlar', satir_pk: { id: 'hayvan-stub-2' }, islem: 'U',
    zaman: TS + '16:10:00+03:00', kaynak: { app_name: 'egesut-web', rol: 'sahip' },
    eski: { id: 'hayvan-stub-2', canli_agirlik: 520 }, yeni: { id: 'hayvan-stub-2', canli_agirlik: 545 },
  }];
  STUB_DETAYLAR[7600003] = [{
    tablo_adi: 'tohumlama', satir_pk: { id: 'toh-stub-3' }, islem: 'I',
    zaman: TS + '15:40:00+03:00', kaynak: { app_name: 'egesut-web', rol: 'sahip' },
    eski: null, yeni: { id: 'toh-stub-3', sperma: 'HOL-77', sonuc: 'Bekliyor' },
  }];
  STUB_DETAYLAR[7600004] = [{
    tablo_adi: 'uygulama_log', satir_pk: { id: 'uyg-stub-4' }, islem: 'I',
    zaman: TS + '14:00:00+03:00', kaynak: { app_name: 'harici-panel', rol: 'servis' },
    eski: null, yeni: { id: 'uyg-stub-4', doz: 20, birim: 'ml', rota: 'IM' },
  }];

  // 7600005 satır geri-al → İKİ sonraki değişiklik (tam liste) → zincir önerisi;
  // zincir modu → 3 adımlı plan (ilk adım bağımlı: alt kayıt)
  const ZINCIR_CAKISMALAR = [
    { tablo: 'padoklar', pk: 'padok-stub-1', satir_pk: { id: 'padok-stub-1' }, txid: 7600002, neden: 'SONRAKI_DEGISIKLIK', zaman: TS + '16:10:00+03:00', islem: 'U', degisen_alanlar: ['kapasite'], log_id: 901 },
    { tablo: 'padoklar', pk: 'padok-stub-1', satir_pk: { id: 'padok-stub-1' }, txid: 7600004, neden: 'SONRAKI_DEGISIKLIK', zaman: TS + '14:00:00+03:00', islem: 'U', degisen_alanlar: ['kapasite', 'ad'], log_id: 902 },
  ];
  const ZINCIR_PLAN = [
    { sira: 1, tablo: 'stok_hareket', pk: 'hareket-stub-9', islem: 'D', yapilacak: 'İlaç stok hareketi silinecek', txid: 7600007, zaman: TS + '16:12:00+03:00', bagimli: true },
    { sira: 2, tablo: 'uygulama_log', pk: 'uyg-stub-4', islem: 'D', yapilacak: 'Uygulama kaydı silinecek', txid: 7600004, zaman: TS + '14:00:00+03:00' },
    { sira: 3, tablo: 'padoklar', pk: 'padok-stub-1', islem: 'U', yapilacak: 'Padok kaydı önceki sürümüne dönecek', alanlar: ['kapasite', 'aciklama'], txid: 7600005, zaman: TS + '12:00:00+03:00' },
  ];
  // 7600003 → otomatik zincir kurulamaz: SIRALI REHBER (en yeni önce; K1)
  const SIRALI_REHBER = [
    { sira: 1, hedef: { tablo: 'dogum', pk: 'dogum-stub-7', txid: '7600009' }, zaman: TS + '18:30:00+03:00', ozet: 'Doğum kaydı', neden_dahil_degil: 'bu geri almaya bağlı' },
    { sira: 2, hedef: { tablo: 'tohumlama', pk: 'toh-stub-3', txid: '7600008' }, zaman: TS + '15:45:00+03:00', ozet: 'Tohumlama sonucu (Gebe)', neden_dahil_degil: 'bu geri almaya bağlı' },
    { sira: 3, hedef: { tablo: 'tohumlama', pk: 'toh-stub-3', txid: '7600003' }, zaman: TS + '15:40:00+03:00', ozet: 'Tohumlama kaydı' },
  ];
  const TEMIZ_PLAN = [
    { sira: 1, tablo: 'gorev_log', pk: 'gorev-stub-1', islem: 'D', yapilacak: 'Görev kaydı silinecek (tamamlanma geri alınır)', txid: 7600001, zaman: TS + '17:25:00+03:00' },
    { sira: 2, tablo: 'stok_hareket', pk: 'hareket-stub-1', islem: 'D', yapilacak: 'İlaç stok hareketi geri yüklenir', txid: 7600001, zaman: TS + '17:25:00+03:00', bagimli: true },
  ];

  function stubOnizle(hedef, seviye) {
    const tx = hedef && hedef.txid != null ? String(hedef.txid) : '';
    if (seviye === 'zincir') {
      // zincir dışı gerçek çakışma yok → tam zincir uygulanabilir
      return { plan: ZINCIR_PLAN, cakismalar: [], engeller: [], bagimliliklar: [], stok_uyari: [], geri_alinabilir: true };
    }
    if (tx === '7600002') {
      throw ERR('HEDEF_BULUNAMADI', 'Hedef bulunamadı', { neden: 'ZAMAN_ESLESME_YOK' });
    }
    if (tx === '7600003') {
      return { plan: [], cakismalar: [], engeller: ['zincir kurulamadı: bağımlı adım aşılamaz'], bagimliliklar: [], stok_uyari: [], geri_alinabilir: false, sirali_rehber: SIRALI_REHBER };
    }
    if (tx === '7600005') {
      return { plan: [{ sira: 1, tablo: 'padoklar', pk: 'padok-stub-1', islem: 'U', yapilacak: 'Padok kaydı önceki sürümüne dönecek', alanlar: ['kapasite', 'aciklama'], txid: 7600005, zaman: TS + '12:00:00+03:00' }], cakismalar: ZINCIR_CAKISMALAR, engeller: [], bagimliliklar: [], stok_uyari: [], geri_alinabilir: false };
    }
    if (tx === '7600001') {
      return { plan: TEMIZ_PLAN, cakismalar: [], engeller: [], bagimliliklar: [], stok_uyari: [], geri_alinabilir: true };
    }
    if (tx) {
      // diğer txid'ler (rehber satır hedefleri dâhil) — hedef türevli tek-adım plan
      const tablo = hedef.tablo || 'kayit';
      return {
        plan: [{ sira: 1, tablo, pk: hedef.pk, islem: 'D', yapilacak: 'Kayıt önceki sürümüne dönecek', txid: Number(tx) || 0, zaman: hedef.zaman || '' }],
        cakismalar: [], engeller: [], bagimliliklar: [], stok_uyari: [], geri_alinabilir: true,
      };
    }
    // {tablo,pk,zaman} hedefi — temiz tek-adım plan
    return {
      plan: [{ sira: 1, tablo: hedef.tablo, pk: hedef.pk, islem: 'U', yapilacak: 'Kayıt önceki sürümüne dönecek', txid: 0, zaman: hedef.zaman || '' }],
      cakismalar: [], engeller: [], bagimliliklar: [], stok_uyari: [], geri_alinabilir: true,
    };
  }

  window.rpcDegisimListele = async function (filtre = {}) {
    if (filtre && filtre.txid != null) {
      const detay = STUB_DETAYLAR[String(filtre.txid)] || [];
      return { kayitlar: detay, toplam: detay.length };
    }
    const liste = STUB_KAYITLAR.slice().sort((a, b) => String(b.ilk_zaman).localeCompare(String(a.ilk_zaman)));
    return { kayitlar: liste, toplam: liste.length };
  };

  window.rpcDegisimOnizle = async function (hedef, seviye) {
    return stubOnizle(hedef, seviye);
  };

  window.rpcDegisimGeriAl = async function (hedef, seviye, bilet) {
    if (!bilet) throw ERR('BILET_GECERSIZ', 'Geri alma bileti geçersiz — şifreyle yeniden alın.');
    const zincir = seviye === 'zincir';
    const adim = zincir ? ZINCIR_PLAN.length : 1;
    return { ok: true, uygulanan_adim: adim, geri_alma_txid: '7600099', zincir_adim: zincir ? adim : undefined };
  };

  window.rpcGeriAlmaBiletiAl = async function (sifre) {
    if (!sifre) throw ERR('SIFRE_HATALI', 'Şifre hatalı.');
    return { ok: true, bilet: 'STUB-BILET-1', kalan_sn: 3600 };
  };
})();
