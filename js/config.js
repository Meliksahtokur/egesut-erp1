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
