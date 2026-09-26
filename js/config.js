// ══════════════════════════════════════════
// EgeSüt — config.js
// Merkezi sabitler
// ══════════════════════════════════════════

// Hekimler (fallback, DB'den gelenlerle birleşecek)
let HEKIMLER = [
  { id: 'H1', ad: 'Melik Tokur' },
  { id: 'H2', ad: 'Hüseyin Aygün' },
  { id: 'H3', ad: 'Süleyman Kocabaş' },
];
const VARSAYILAN_HEKIM = 'H1';

// Hastalık listesi ve kategorileri
const HASTALIK_LISTESI = [
  'Mastit','Subklinik Mastit','Klinik Mastit',
  'Metrit','Endometrit','Pyometra','Retensiyo Sekundinarum','Kistik Over','Anoestrus',
  'Hipokalsemi (Süt Humması)','Ketozis','Ruminal Asidoz','Timpani','Şirden Deplasmanı',
  'Topallık (Dermatit)','Topallık (Laminit)','Beyaz Çizgi Hastalığı','Tırnak Yarası',
  'Pnömoni','Buzağı İshali','Buzağı Göbek İltihabı','Neonatal Zayıflık',
];

const HASTALIK_KAT = {
  'Meme':    ['Mastit','Subklinik Mastit','Klinik Mastit'],
  'Üreme':   ['Metrit','Endometrit','Pyometra','Retensiyo Sekundinarum','Kistik Over','Anoestrus'],
  'Metabolik':['Hipokalsemi (Süt Humması)','Ketozis','Ruminal Asidoz','Timpani','Şirden Deplasmanı'],
  'Ayak':    ['Topallık (Dermatit)','Topallık (Laminit)','Beyaz Çizgi Hastalığı','Tırnak Yarası'],
  'Solunum': ['Pnömoni'],
  'Sindirim':['Ruminal Asidoz','Timpani','Şirden Deplasmanı'],
  'Buzağı':  ['Buzağı İshali','Buzağı Göbek İltihabı','Neonatal Zayıflık'],
  'Diğer':   [],
};

const LOKASYON_KAT = {
  'Meme': ['Sol Ön','Sol Arka','Sağ Ön','Sağ Arka'],
  'Ayak': ['Sol Ön','Sol Arka','Sağ Ön','Sağ Arka'],
  'Göz':  ['Sol Göz','Sağ Göz'],
};

const SPERMA_LISTESI = [
  'ABK-Zenith-ET','ABK-Parfect-ET','ABK-Iconic-ET',
  'CRI-Crushabull','CRI-Extreme-ET','Alta-Kalahari','Alta-Achiever',
  'Semex-O-Man','Semex-Planet',
];

// Grup -> Padok eşlemesi (DB'den yüklenir, fallback hardcoded)
let GRUP_PADOK = {
  'Sağmal (Laktasyonda)':      ['Sağmal Padok'],
  'Sağmal (Kuru)':             ['Kuru/Gebe Padok'],
  'Gebe Düve':                 ['Kuru/Gebe Padok'],
  'Gebe İnek':                 ['Kuru/Gebe Padok'],
  'Düve (Büyük)':              ['Düve Padok (Büyük)'],
  'Düve (Küçük)':              ['Düve Padok (Küçük)'],
  'Süt İçen Buzağı':           ['Buzağı Padok (Süt İçenler)'],
  'Sütten Kesilmiş Buzağı':    ['Buzağı Padok (Sütten Kesilmiş)'],
  'Besi':                      ['Besi Padok (Erkek)', 'Besi Padok (Dişi)'],
};

// Padoklar listesi (DB'den yüklenir)
let PADOKLAR = [];

async function loadPadokConfig() {
  try {
    const [padoklar, eslem] = await Promise.all([
      getData('padoklar'),
      getData('grup_padok_eslem'),
    ]);
    if (!padoklar.length) return;
    PADOKLAR = padoklar;
    // grup -> [padok adları] haritasını yeniden oluştur
    const padokMap = Object.fromEntries(padoklar.map(p => [p.id, p.ad]));
    const newGP = {};
    eslem.forEach(e => {
      const padAd = padokMap[e.padok_id];
      if (!padAd) return;
      if (!newGP[e.grup]) newGP[e.grup] = [];
      if (!newGP[e.grup].includes(padAd)) newGP[e.grup].push(padAd);
    });
    if (Object.keys(newGP).length) GRUP_PADOK = newGP;
  } catch(e) { console.warn('loadPadokConfig failed:', e.message); }
}

async function loadHekimlerFromDB() {
  try {
    const rows = await getData('hekimler');
    if (rows.length) HEKIMLER = rows.map(h => ({ id: h.id, ad: h.ad }));
  } catch(e) { console.warn('loadHekimlerFromDB failed:', e.message); }
}

// Semptom kategorileri
const SEMPTOM_KAT = {
  'Solunum': ['Öksürük','Burun Akıntısı','Nefes Darlığı','Ateş','Hırıltı','İştahsızlık','Halsizlik'],
  'Sindirim': ['İshal','Kabızlık','Şişkinlik','İştahsızlık','Ateş','Halsizlik','Ağız Kokusu'],
  'Üreme':   ['Akıntı','Ateş','İştahsızlık','Halsizlik','Yememe','Ödem'],
  'Ayak':    ['Topallık','Şişlik','Isı Artışı','Yara','Ağrı'],
  'Meme':    ['Süt Değişimi','Meme Şişliği','Ateş','Ağrı','İştahsızlık','Halsizlik'],
  'Metabolik':['Sallantı','Düşkünlük','Ateş','Halsizlik','Titreme','Yememe','Ödem'],
  'Buzağı':  ['İshal','Halsizlik','Ateş','Göbek Şişliği','İştahsızlık','Solunum Güçlüğü'],
};
const SEMPTOM_GENEL = ['Ateş','Halsizlik','İştahsızlık','Ağrı','Ödem','Titreme','Yememe','Düşkünlük'];

// ══════════════════════════════════════════
// BUG-059 — Saat Bazlı Tedavi Seans Sistemi
// ══════════════════════════════════════════

// Uygulama yolları (BUG-059 tedavi seanslarında)
const UYGULAMA_YOLU = ['IM','IV','SC','PO','Topikal','Intrauterin','Meme içi'];

// Seans durumları (computeSeansState tarafından döner)
const SEANS_STATE = {
  scheduled:  { renk: 'gri',     ikon: '○', etiket: 'Bekliyor',    cssClass: 's-scheduled' },
  'due-soon': { renk: 'amber',   ikon: '◐', etiket: 'Yaklaşıyor',  cssClass: 's-due-soon' },
  now:        { renk: 'mavi',    ikon: '●', etiket: 'Vakti geldi', cssClass: 's-now' },
  overdue:    { renk: 'kırmızı', ikon: '●', etiket: 'Gecikti',     cssClass: 's-overdue' },
  done:       { renk: 'yeşil',   ikon: '✓', etiket: 'Uygulandı',   cssClass: 's-done' },
  cancelled:  { renk: 'üstü çizili', ikon: '✕', etiket: 'Yapılamadı', cssClass: 's-cancelled' },
};

// Done seans için geri al (undo) penceresi — dakika cinsinden (backend RPC bekliyor)
const SEANS_UNDO_WINDOW_MIN = 5;

// Aynı saatteki pip'ler için offset (px) — max 5 aynı saat
const PIP_STACK_OFFSETS = [0, 6, -6, 12, -12];

// Hızlı saat şablonları (seans formunda chip olarak) — input[type=time] 24:00 kabul etmez
const HIZLI_SAATLER = ['08:00', '16:00', '20:00'];

// Tedavi seansı ekleme üst sınırı
const MAX_SEANS_PER_DAY = 10;

// ══════════════════════════════════════════
// Küpe Numara Planı (spec 2026-09-01, K5/K10/K11)
// Erkek yeni kayıt: sayısal küpe 500-599 zorunlu.
// Dişi: 1-999 içinde 5xx hariç her numara serbest.
// Havuz: yalnız AKTİFlerin numaraları dolu (çıkmışınki geri döner — K1).
// Doluluk SAYISAL uzayda hesaplanır ("02" ve "002" aynı 2'yi işgal eder — K9).
// Öneri listesi her iki cinsiyette küçükten büyüğe (K10).
// ══════════════════════════════════════════
const KUPE_ERKEK_MIN = 500, KUPE_ERKEK_MAX = 599;

function erkekKupeUygunMu(kupe, cinsiyet) {
  if (cinsiyet !== 'Erkek' || !/^\d+$/.test(String(kupe || ''))) return true;
  const n = parseInt(kupe, 10);
  return n >= KUPE_ERKEK_MIN && n <= KUPE_ERKEK_MAX;
}

function bosKupeOner(hayvanlar, cinsiyet, adet = 10) {
  const dolu = new Set((hayvanlar || [])
    .filter(a => a && a.durum === 'Aktif' && a.kupe_no && /^\d+$/.test(String(a.kupe_no)))
    .map(a => parseInt(a.kupe_no, 10)));
  const erkek = cinsiyet === 'Erkek';
  const out = [];
  for (let n = erkek ? KUPE_ERKEK_MIN : 1; n <= (erkek ? KUPE_ERKEK_MAX : 999) && out.length < adet; n++) {
    if (!erkek && n >= KUPE_ERKEK_MIN && n <= KUPE_ERKEK_MAX) continue;
    if (!dolu.has(n)) out.push(String(n));
  }
  return out;
}


// ══════════════════════════════════════════
// Görev listesi — hayvan grubu katmanı (spec: .claude/plans/2026-09-09-tedavi-doz-gorev-design.md §4.1)
// Saat → grup → küpe katmanlamasının 2. katmanı. Değerler hayvanlar.grup
// sütununun canlı sözlüğüyle birebir; sıra işletmenin çalışma düzenine göre
// (buzağıdan ineğe). Burada olmayan bir grup değeri "Diğer" bloğuna düşer.
const GOREV_GRUP_SIRA = [
  'Süt İçen Buzağı',
  'Sütten Kesilmiş Buzağı',
  'Düve (Küçük)',
  'Düve (Büyük)',
  'Besi',
  'Sağmal (Laktasyonda)',
  'Sağmal (Kuru)',
];

// ══════════════════════════════════════════
// Ovsync/PG — hata sözleşmesi ve tohumlama saat pencereleri
// (PLAN 2026-09-24 P1/P6; SPEC S-4/S-5/S-6, MK1/MK6)
// getUserMessage bu sözlüğü tek kaynak olarak okur (errorHandler'da kopya yok).

// Sunucudan RAISE ile gelen 'KOD:json' / 'KOD' önekli hata kodları.
// Değerler {msg} şablonundaki alanlarla doldurulur: {kupe}, {gun}, {tarih}, {deneme}.
const PG_HATA_SOZLUGU = {
  'PG_KAPI:BLOCK_PREGNANT': 'Gebe inekte PG uygulanamaz ({kupe}). Gebelik sonlandırma ayrı yetkili klinik işlemdir.',
  'PG_KAPI:REQUIRE_ACK_PENDING': 'Son tohumlama sonucu Bekliyor ({kupe}, {tarih}, deneme {deneme}) — onay ver ya da Boş ata.',
  'PG_KAPI:BLOCK_CATALOG_UNRESOLVED': 'Ürünün PG kataloğu bağı belirsiz — katalog kaydı düzeltilmeden uygulama yapılamaz.',
  'PG_ZAMAN_GECERSIZ': 'Uygulama zamanı geçersiz (en çok 5 dk ileri / 7 gün geri girilebilir).',
  'SISTEM_ETKEN_MADDE': 'Sistem etken maddesi değiştirilemez/silinemez.',
  'KATALOG_SINIF_KODU_KILITLI': 'Bu katalog satırının sınıf kodu kilitli — değiştirilemez.',
  // cila2 C1 — DB 000018 trigger/şablon guard RAISE kodu
  'KISIR_HAYVAN_OVSYNC_YASAK': 'Kısır işaretli hayvana Ovsync protokolü açılamaz.',
  // K4 (p5b-fix) — ovsync_baslat erken çağrı kapısı RAISE kodu (000002)
  'OVSYNC_ERKEN': 'Protokol henüz başlatılamaz — pencere hedef tarihten 2 gün önce açılır.',
  // E1-UI (erteleme-genel D18): gorev_ertele RAISE ailesi. Mesaj gövdesi
  // 'KOD:{"sebep":"ALT_TIP",…}' biçiminde gelir; getUserMessage adım-2 includes
  // eşleşmesi sebep kodlarını JSON içinden yakalar — alt tipler aile-jenerik
  // metne DÜŞMEZ (step-2, USER_FRIENDLY'nin 'GOREV_ERTELENEMEZ' genelinden önce).
  'TIP_ERTELENEMEZ': 'Bu görev tipi ertelenemez (kural: tedavi gün/seans görevleri protokol tarafından yönetilir).',
  'GOREV_ACIK_DEGIL': 'Yalnız açık görevler ertelenebilir — görev tamamlanmış ya da iptal edilmiş.',
  'GOREV_BULUNAMADI': 'Görev bulunamadı — başka bir cihazda silinmiş olabilir.',
  'MAX_ASIM': 'Erteleme sınırı aşıldı (bu görev tipi için izin verilen en çok erteleme günü).',
  'GECMIS_TARIH': 'Geçmiş tarihe erteleme yapılamaz.',
  // E4-UI: protokol_iptal RAISE ailesi (sebep: VAKA_ACIK_DEGIL / PROTOKOL_VAKASI_DEGIL)
  'PROTOKOL_IPTAL_EDILEMEZ': 'Protokol vakası iptal edilemedi — vaka kapalı ya da protokol vakası değil.',
};

// Tohumlama saat pencereleri (MK1, kapalı aralık, Europe/Istanbul).
// JS aynası: ui.js erteleme modalı canlı önizlemede DB _tohumlama_pencere ile
// aynı sonucu vermeli. Asla erkene yuvarlanmaz.
const TOHUMLAMA_PENCERELERI = [
  { bas: '09:00', son: '12:00' },
  { bas: '18:00', son: '21:00' },
];

// Pencereye ileri yuvarlama (MK1): verilen 'YYYY-MM-DD HH:MM' yerel an
// pencere içindeyse olduğu gibi; değilse bir sonraki pencere başlangıcı.
// DB'deki _tohumlama_pencere IMMUTABLE gövdesinin aynası (birim testte karşılaştırılır).
function pencereYuvarla(ts) {
  const [gun, saat] = ts.split(' ');
  const [h, m] = saat.split(':').map(Number);
  const dk = h * 60 + m;
  for (const p of TOHUMLAMA_PENCERELERI) {
    const [ph, pm] = p.bas.split(':').map(Number);
    const [sh, sm] = p.son.split(':').map(Number);
    if (dk >= ph * 60 + pm && dk <= sh * 60 + sm) return `${gun} ${saat}`;  // pencere içinde: olduğu gibi
  }
  // 12:00–18:00 arası → 18:00 (aynı gün); 21:00–09:00 arası → ertesi gün 09:00
  const [e1] = TOHUMLAMA_PENCERELERI[0].bas.split(':').map(Number);
  const [s2] = TOHUMLAMA_PENCERELERI[1].son.split(':').map(Number);
  const [b2] = TOHUMLAMA_PENCERELERI[1].bas.split(':').map(Number);
  if (dk < e1 * 60) return `${gun} ${TOHUMLAMA_PENCERELERI[0].bas}`;
  if (dk < b2 * 60) return `${gun} ${TOHUMLAMA_PENCERELERI[1].bas}`;
  const [y, mo, d] = gun.split('-').map(Number);
  const ertesi = new Date(Date.UTC(y, mo - 1, d + 1));
  const iso = ertesi.toISOString().slice(0, 10);
  return `${iso} ${TOHUMLAMA_PENCERELERI[0].bas}`;
}
