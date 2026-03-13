// ══════════════════════════════════════════
// EgeSüt — config.js
// Merkezi sabitler
// ══════════════════════════════════════════

// Hekimler (fallback, DB'den gelenlerle birleşecek)
const HEKIMLER = [
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

// Grup -> Padok eşlemesi
const GRUP_PADOK = {
  'Sağmal (Laktasyonda)':      ['Sağmal Padok'],
  'Sağmal (Kuru)':             ['Kuru/Gebe Padok'],
  'Gebe Düve':                 ['Kuru/Gebe Padok'],
  'Düve (Büyük)':              ['Düve Padok (Büyük)'],
  'Düve (Küçük)':              ['Düve Padok (Küçük)'],
  'Süt İçen Buzağı':           ['Buzağı Padok (Süt İçenler)'],
  'Sütten Kesilmiş Buzağı':    ['Buzağı Padok (Sütten Kesilmiş)'],
  'Besi':                      ['Düve Padok (Büyük)', 'Düve Padok (Küçük)', 'Sağmal Padok'],
};

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
