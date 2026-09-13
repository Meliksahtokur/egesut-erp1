// js/degisiklikler/etiketler.js
// SAF katman (G-20260913-SURUM-GECMISI F3): tablo/alan adı → Türkçe etiket.
// DOM'a dokunmaz; node --test ile test edilir (tests/unit/degisiklikler-etiketler.test.js).
// Envanter: yerel şema aynası (egesut_lsp, public BASE TABLE kolonları, 2026-09-13).
// Bilinmeyen tablo/alan çökmez: snake_case → "Snake case" insanlaştırmasına düşer.

const DG_TABLO_ETIKETLERI = {
  hayvanlar: 'Hayvan',
  dogum: 'Doğum',
  tohumlama: 'Tohumlama',
  kizginlik_log: 'Kızgınlık',
  cases: 'Vaka',
  treatment_days: 'Tedavi günü',
  treatment_day_uygulamalar: 'Tedavi uygulaması',
  drug_administrations: 'İlaç uygulaması',
  uygulama_log: 'Uygulama kaydı',
  tedavi: 'Tedavi',
  hastalik_log: 'Hastalık kaydı',
  gorev_log: 'Görev',
  vaccination_log: 'Aşı uygulaması',
  vaccination_schedule: 'Aşı takvimi',
  vaccines: 'Aşı tanımı',
  vaccine_protocol_steps: 'Aşı protokol adımı',
  vaccine_diseases: 'Aşı–hastalık eşlemesi',
  stok: 'Stok ürünü',
  stok_hareket: 'Stok hareketi',
  stok_kategorileri: 'Stok kategorisi',
  diseases: 'Hastalık tanımı',
  drugs: 'İlaç',
  drug_classes: 'İlaç sınıfı',
  drug_products: 'İlaç ürünü',
  padoklar: 'Padok',
  grup_padok_eslem: 'Grup–padok eşlemesi',
  hekimler: 'Hekim',
  irk_esik: 'Irk eşiği',
  protokol_instance: 'Protokol',
  protokol_dismiss: 'Protokol kapatma',
  protokol_ayar: 'Protokol ayarı',
  tedavi_sablonu: 'Tedavi şablonu',
  tedavi_sablonu_kalem: 'Şablon kalemi',
  sablon_hastalik_eslem: 'Şablon–hastalık eşlemesi',
  bildirim_log: 'Bildirim',
  hayvan_override: 'Hayvan istisnası',
  islem_log: 'İşlem kaydı',
  cop_kutusu: 'Çöp kutusu',
  pedigree_meta: 'Pedigree üst-verisi',
  pedigree_nodes: 'Pedigree düğümü',
  pedigree_parentage: 'Pedigree ebeveynliği',
  semen_catalog: 'Sperma kataloğu',
};

// Tablodan bağımsız ortak alanlar
const DG_ORTAK_ALANLAR = {
  id: 'Kayıt no',
  created_at: 'Oluşturulma',
  updated_at: 'Güncellenme',
  olusturma: 'Oluşturulma',
  guncelleme: 'Güncellenme',
  hayvan_id: 'Hayvan',
  animal_id: 'Hayvan',
  anne_id: 'Anne',
  display_name: 'Görünen ad',
  source_ref: 'Kaynak referansı',
  code: 'Kod',
  target_type: 'Hedef tipi',
  label: 'Etiket',
  // LUNA-2 tam süpürme (393 kolon / 39 tablo): İngilizce-adlı kolonlar
  active_ingredient: 'Etkin madde',
  class_name: 'Sınıf adı',
  group_name: 'Grup adı',
  brand_name: 'Marka',
  concentration: 'Konsantrasyon',
  concentration_unit: 'Konsantrasyon birimi',
  default_route: 'Varsayılan rota',
  default_unit: 'Varsayılan birim',
  drug_class_id: 'İlaç sınıfı',
  std_dose: 'Standart doz',
  std_dose_max: 'Maks. standart doz',
  std_dose_min: 'Min. standart doz',
  std_dose_unit: 'Standart doz birimi',
  description: 'Açıklama',
  stock_item_id: 'Stok ürünü',
  kategori_id: 'Kategori',
  birth_date: 'Doğum tarihi',
  breed: 'Irk',
  country_code: 'Ülke kodu',
  farm_animal_id: 'Çiftlik hayvanı',
  founder_status: 'Kurucu durumu',
  metadata: 'Üst veri',
  node_kind: 'Düğüm tipi',
  registry_code: 'Kayıt kodu',
  registry_system: 'Kayıt sistemi',
  sex: 'Cinsiyet',
  child_node_id: 'Yavru düğüm',
  parent_node_id: 'Ebeveyn düğüm',
  parent_role: 'Ebeveyn rolü',
  confidence: 'Güven',
  evidence: 'Kanıt',
  source_type: 'Kaynak tipi',
  bull_node_id: 'Boğa düğümü',
  semen_type: 'Sperma tipi',
  supplier: 'Tedarikçi',
  sequence_order: 'Sıra',
  timing_days: 'Zamanlama günü',
  timing_type: 'Zamanlama tipi',
  disease_target: 'Hedef hastalık',
  is_mandatory: 'Zorunlu',
  repeat_interval_days: 'Tekrar aralığı (gün)',
  // Türkçe-adlı ama i/ı diyakritiği insanlaştırmada bozulanlar
  buzagi_id: 'Buzağı kaydı',
  suttten_kesme_gun: 'Sütten kesme günü',
  tohumlama_gun: 'Tohumlama günü',
  kullanim_sayisi: 'Kullanım sayısı',
  guncelleme_tarihi: 'Güncelleme tarihi',
  kupe_no: 'Küpe no',
  deger: 'Değer',
  min_deger: 'Min. değer',
  max_deger: 'Maks. değer',
  guncellendi: 'Güncellendi',
  // LUNA-2 (A3) tam kapsama: kalan tüm kapsam-kolonları (canlı envanter
  // tests/unit/support/degisiklikler-kapsam-kolonlari.json ile kilitli)
  abort_tarihi: 'Abort tarihi',
  active: 'Aktif',
  adim_no: 'Adım no',
  anahtar: 'Anahtar',
  belirti: 'Belirti',
  boy: 'Boy',
  category: 'Kategori',
  cins: 'Cins',
  cinsiyet: 'Cinsiyet',
  deneme_no: 'Deneme no',
  denemeler: 'Denemeler',
  ek_uygulamalar: 'Ek uygulamalar',
  erteleme_notu: 'Erteleme notu',
  ertelendi: 'Ertelendi',
  etiketler: 'Etiketler',
  etken_madde: 'Etken madde',
  farm_id: 'Çiftlik',
  grup: 'Grup',
  gun_no: 'Gün no',
  hedef_saat: 'Hedef saat',
  hedef_tarih: 'Hedef tarih',
  iptal_nedeni: 'İptal nedeni',
  irk: 'Irk',
  kapasite: 'Kapasite',
  key: 'Anahtar',
  kontrol_tarihi: 'Kontrol tarihi',
  lokasyon: 'Lokasyon',
  maliyet: 'Maliyet',
  marka: 'Marka',
  neden: 'Neden',
  offset_gun: 'Ofset gün',
  padok: 'Padok',
  pasif_mi: 'Pasif mı',
  plan_notu: 'Plan notu',
  protokol: 'Protokol',
  protokol_tipi: 'Protokol tipi',
  referans_tipi: 'Referans tipi',
  renk: 'Renk',
  sablon_id: 'Şablon',
  semptomlar: 'Semptomlar',
  sira: 'Sıra',
  sperma: 'Sperma',
  stock_id: 'Stok ürünü',
  tamamlanma_notu: 'Tamamlanma notu',
  telefon: 'Telefon',
  tohumlama_durumu: 'Tohumlama durumu',
  tohumlama_onay_tarihi: 'Tohumlama onay tarihi',
  tohumlama_plani: 'Tohumlama planı',
  tohumlayan: 'Tohumlayan',
  uygulama_notu: 'Uygulama notu',
  uygulama_yolu: 'Uygulama yolu',
  uygulayan: 'Uygulayan',
  value: 'Değer',
  veteriner_notu: 'Veteriner notu',
  tarih: 'Tarih',
  notlar: 'Notlar',
  notes: 'Not',
  aciklama: 'Açıklama',
  durum: 'Durum',
  status: 'Durum',
  hekim_id: 'Hekim',
  stok_id: 'Stok ürünü',
  case_id: 'Vaka',
  disease_id: 'Hastalık',
  drug_product_id: 'İlaç ürünü',
  treatment_day_id: 'Tedavi günü',
  vaccine_id: 'Aşı',
  padok_id: 'Padok',
  miktar: 'Miktar',
  birim: 'Birim',
  unit: 'Birim',
  dose: 'Doz',
  doz: 'Doz',
  route: 'Uygulama yolu',
  rota: 'Uygulama yolu',
  etken_kod: 'Etken kodu',
  kategori: 'Kategori',
  tip: 'Tip',
  tur: 'Tür',
  ad: 'Ad',
  name: 'Ad',
  aktif: 'Aktif',
  iptal: 'İptal',
  planned_time: 'Planlanan saat',
  kaynak: 'Kaynak',
};

// Tabloya özgü alanlar (ortak etiketi ezer)
const DG_ALAN_ETIKETLERI = {
  hayvanlar: {
    kupe_no: 'Küpe no', devlet_kupe: 'Devlet küpesi', cins: 'Cins', irk: 'Irk',
    dogum_tarihi: 'Doğum tarihi', dogum_kg: 'Doğum ağırlığı (kg)', kesim_kg: 'Kesim ağırlığı (kg)',
    grup: 'Grup', padok: 'Padok', durum: 'Durum', cikis_tarihi: 'Çıkış tarihi',
    cikis_sebebi: 'Çıkış sebebi', cikis_tipi: 'Çıkış tipi', satis_fiyati: 'Satış fiyatı',
    cinsiyet: 'Cinsiyet', baba_bilgi: 'Baba bilgisi', canli_agirlik: 'Canlı ağırlık',
    boy: 'Boy', renk: 'Renk', ayirici_ozellik: 'Ayırıcı özellik',
    suttten_kesme_tarihi: 'Sütten kesme tarihi', tohumlama_onay_tarihi: 'Tohumlama onay tarihi',
    tohumlama_durumu: 'Tohumlama durumu', abort_sayisi: 'Abort sayısı', kisir: 'Kısır',
    etiketler: 'Etiketler', genc_anne: 'Genç anne',
  },
  dogum: {
    tarih: 'Doğum tarihi', yavru_cins: 'Yavru cinsiyeti', yavru_kupe: 'Yavru küpesi',
    yavru_irk: 'Yavru ırkı', dogum_tipi: 'Doğum tipi', dogum_kg: 'Doğum ağırlığı (kg)',
    baba_bilgi: 'Baba bilgisi', olay_id: 'Doğum olayı',
  },
  tohumlama: {
    tarih: 'Tohumlama tarihi', sperma: 'Sperma', irk_bilgisi: 'Irk bilgisi',
    tohumlayan: 'Tohumlayan', kontrol_tarihi: 'Kontrol tarihi', sonuc: 'Sonuç',
    deneme_no: 'Deneme no', dogum_tarihi: 'Beklenen doğum', buzagi_kupe: 'Buzağı küpesi',
    abort_notlar: 'Abort notu', abort_tarihi: 'Abort tarihi', deneme_sayisi: 'Deneme sayısı',
    denemeler: 'Denemeler', ek_uygulamalar: 'Ek uygulamalar', vwp_override: 'VWP istisnası',
    gerceklesme_at: 'Gerçekleşme',
  },
  kizginlik_log: {
    belirti: 'Belirti', sonuc: 'Sonuç', tedavi_case_id: 'Tedavi vakası', cozuldu: 'Çözüldü',
  },
  cases: {
    start_date: 'Başlangıç', closed_at: 'Kapanış', plan_notu: 'Plan notu',
  },
  treatment_days: {
    day_no: 'Gün no', treatment_date: 'Tedavi tarihi', treatment_time: 'Tedavi saati',
    tamamlandi: 'Tamamlandı', tamamlanma_tarihi: 'Tamamlanma', tamamlanma_notu: 'Tamamlanma notu',
    seans_sayisi: 'Seans sayısı',
  },
  treatment_day_uygulamalar: {
    planned_date: 'Planlanan tarih', uygulama_tamamlandi_at: 'Uygulandı',
    uygulayan: 'Uygulayan', uygulama_notu: 'Uygulama notu', gerceklesme_saati: 'Gerçekleşme saati',
    uygulanmadi: 'Uygulanmadı', iptal_nedeni: 'İptal nedeni',
  },
  drug_administrations: { uygulanmadi: 'Uygulanmadı', seans_admin_id: 'Seans' },
  gorev_log: {
    gorev_tipi: 'Görev tipi', hedef_tarih: 'Hedef tarih', hedef_saat: 'Hedef saat',
    tamamlandi: 'Tamamlandı', tamamlanma_tarihi: 'Tamamlanma', padok_hedef: 'Hedef padok',
    stok_dusuldu: 'Stok düşüldü', parent_id: 'Üst görev', ref_tohumlama_id: 'İlgili tohumlama',
    kapatan_ref: 'Kapatan kayıt', protokol_instance_id: 'Protokol', seans_admin_id: 'Seans',
  },
  vaccination_log: {
    vaccination_date: 'Aşı tarihi', dose_given: 'Verilen doz', next_due_date: 'Sonraki doz',
    created_by: 'Kaydeden', ertelendi: 'Ertelendi', erteleme_notu: 'Erteleme notu',
  },
  stok: {
    urun_adi: 'Ürün adı', birim_turu: 'Birim türü', baslangic_miktar: 'Başlangıç miktarı',
    esik: 'Uyarı eşiği', maliyet: 'Maliyet',
  },
  stok_hareket: {
    tur: 'Hareket türü', referans_tipi: 'Referans tipi', referans_id: 'Referans',
  },
  hastalik_log: {
    tani: 'Tanı', siddet: 'Şiddet', semptomlar: 'Semptomlar', kapanis_tarihi: 'Kapanış',
    kapanma_tarihi: 'Kapanma', veteriner_notu: 'Veteriner notu', lokasyon: 'Lokasyon',
  },
  tedavi: {
    tani: 'Tanı', ilac_stok_id: 'İlaç', sut_yasagi_bitis: 'Süt yasağı bitişi',
    vaka_id: 'Vaka', uygulama_yolu: 'Uygulama yolu', bekleme_suresi_gun: 'Bekleme süresi (gün)',
  },
  protokol_instance: {
    alttip: 'Alt tip', kaynak_ref: 'Kaynak kayıt', baslangic: 'Başlangıç',
    kapandi_at: 'Kapanış', kapandi_sebep: 'Kapanış sebebi',
  },
  padoklar: { kapasite: 'Kapasite', sira: 'Sıra' },
};

const DG_ISLEM_ETIKETLERI = { I: 'Ekleme', U: 'Güncelleme', D: 'Silme' };

function _dgInsanlastir(ad) {
  const s = String(ad == null ? '' : ad).replace(/_+/g, ' ').trim();
  if (!s) return '—';
  const ilk = s.charAt(0);
  const buyuk = ilk === 'i' ? 'İ' : ilk === 'ı' ? 'I' : ilk.toUpperCase();
  return buyuk + s.slice(1);
}

function tabloEtiketi(tablo) {
  return Object.prototype.hasOwnProperty.call(DG_TABLO_ETIKETLERI, tablo)
    ? DG_TABLO_ETIKETLERI[tablo]
    : _dgInsanlastir(tablo);
}

function alanEtiketi(tablo, alan) {
  const ozel = Object.prototype.hasOwnProperty.call(DG_ALAN_ETIKETLERI, tablo) ? DG_ALAN_ETIKETLERI[tablo] : null;
  if (ozel && Object.prototype.hasOwnProperty.call(ozel, alan)) return ozel[alan];
  if (Object.prototype.hasOwnProperty.call(DG_ORTAK_ALANLAR, alan)) return DG_ORTAK_ALANLAR[alan];
  return _dgInsanlastir(alan);
}

function islemEtiketi(kod) {
  return Object.prototype.hasOwnProperty.call(DG_ISLEM_ETIKETLERI, kod) ? DG_ISLEM_ETIKETLERI[kod] : String(kod ?? '—');
}

// Filtre açılır listesi için sabit sıra: [{kod, etiket}]
function tabloSecenekleri() {
  return Object.keys(DG_TABLO_ETIKETLERI)
    .map(kod => ({ kod, etiket: DG_TABLO_ETIKETLERI[kod] }))
    .sort((a, b) => a.etiket.localeCompare(b.etiket, 'tr'));
}

// LUNA-2/A3 kapsam kilidi: haritaları teste açan görünüüm (const'lar sandbox'a
// kapanmadığından fonksiyon üzerinden verilir). Test:
// tests/unit/degisiklikler-etiketler.test.js + support/degisiklikler-kapsam-kolonlari.json
function kapsamHaritalari() {
  return {
    tabloEtiketleri: DG_TABLO_ETIKETLERI,
    ortakAlanlar: DG_ORTAK_ALANLAR,
    tabloOzelAlanlar: DG_ALAN_ETIKETLERI,
  };
}
