// js/tarih/tarih.js
// SAF TARİH KATMANI — G-20260913-TARIH-SECICI F1 (karar D-20260909'un
// "yerel API yok" ilkesinin çekirdeği). DOM YOK, yerel-ayar YOK:
// toLocale*/Intl/new Date(string) YASAK — yalnız string + tamsayı
// aritmetiği (bcIsoTrGoster/bcTrGosterIso yaklaşımı, forms.js).
//
// Bu dosya F3'te bcTakvim*/caseGunModalRender'ın da benimseyeceği ortak
// kaynaktır: imzaların buradan değişmesi manifest'li onay işidir.
//
// Sözleşme notları:
// - ISO her zaman 'YYYY-MM-DD' (10 karakter); geçerli ISO'ların sözlüksel
//   sırası kronolojik sıradır (min/max karşılaştırması bu yüzden string'tir).
// - tarihAyIzgara hücre listesi Pazartesi-önce tam haftalardır (uzunluk 7'nin
//   katı); ay-dışı konumlar null'dır. Hücre şekli {iso, gun, ayIci} — ayIci
//   v1'de hep true (ay-dışı = null); alan, F3'te komşu-ay hücre gösterimine
//   genişlerse çağıran tarafı kırılmadan genişler.
// - Gün-hafta matematiği Miladî gün-numarası ile (aşağıda _tarihGunNo):
//   1970-01-01 Perşembe → Pazartesi-önce indeks = ((gunNo + 3) % 7 + 7) % 7
//   (gunNo 1970 öncesinde negatif; JS % işaret korur — +7 sarması şart).

// Statik TR adları — takvim başlığı/günleri için TEK kaynak (toLocale yok).
const TARIH_AY_ADLARI  = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
const TARIH_GUN_ADLARI = ['Pt','Sa','Ca','Pe','Cu','Ct','Pz'];

// Artık yıl — Gregorjen kural, saf bölme.
function tarihArtikYilMi(yil){
  return (yil % 4 === 0 && yil % 100 !== 0) || yil % 400 === 0;
}

// Ayın gün sayısı — ay 1..12 dışıysa 0 (çağıran hata yolu belirler).
// Şubat ayrı dallanır (artık yıl); tablo dizini 1 bu yüzden hiç okunmaz.
function tarihAyGunSayisi(yil, ay){
  if(ay < 1 || ay > 12) return 0;
  if(ay === 2) return tarihArtikYilMi(yil) ? 29 : 28;
  return [31,28,31,30,31,30,31,31,30,31,30,31][ay - 1];
}

// Miladî gün numarası (1970-01-01 = 0) — Hinnant days_from_civil, saf tam
// sayı. DÂHİLİ: dışa açılmaz, testler hafta-konumu üzerinden doğrular.
function _tarihGunNo(yil, ay, gun){
  const y2 = ay <= 2 ? yil - 1 : yil;
  const cag = Math.floor(y2 / 400);
  const yic = y2 - cag * 400;
  const gunYil = Math.floor((153 * (ay + (ay > 2 ? -3 : 9)) + 2) / 5) + gun - 1;
  const gunCag = yic * 365 + Math.floor(yic / 4) - Math.floor(yic / 100) + gunYil;
  return cag * 146097 + gunCag - 719468;
}

// 'YYYY-MM-DD' takvim tarihi mi? (31.02 / 13. ay / kısa biçim RED — sessiz
// düzeltme yok; 2026-2-05 gibi esnek biçimler geçersizdir). Yıl 1..9999
// (ızgara etki alanıyla aynı — 0000 yılı ızgarada temsilsiz, reddedilir).
function tarihGecerliMi(iso){
  const s = String(iso == null ? '' : iso);
  if(!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const yil = Number(s.slice(0, 4)), ay = Number(s.slice(5, 7)), gun = Number(s.slice(8, 10));
  if(yil < 1 || yil > 9999) return false;
  return ay >= 1 && ay <= 12 && gun >= 1 && gun <= tarihAyGunSayisi(yil, ay);
}

// 'YYYY-MM-DD' → 'GG.AA.YYYY' (bcIsoTrGoster'in paylaşıma geçen hâli);
// geçersiz → '' (bugün fallback YOK).
function tarihIsoTr(iso){
  if(!tarihGecerliMi(iso)) return '';
  const s = String(iso);
  return s.slice(8, 10) + '.' + s.slice(5, 7) + '.' + s.slice(0, 4);
}

// EL GİRİŞİ ÇÖZÜMLEYİCİ — gg.aa.yyyy / gg/aa/yyyy / gg-aa-yyyy (aynı ayraç
// baştan sona) + 2 haneli yıl gg.aa.yy → 2000+yy. GÜN ÖNCE (05.02.2026 =
// 5 Şubat; mm/dd OKUNMASI YOK). Sessiz düzeltme yok: 31.02, 13. ay, çöp,
// karışık ayraç, yıl-önce biçim → { ok:false, error } (açık Türkçe mesaj).
function tarihParse(metin){
  const s = String(metin == null ? '' : metin).trim();
  // \2 geri-başvurusu: ayraç baştan sona TEK tür olur — 05/02.2026 karışık
  // ayraç biçim dışıdır (sessiz kabul yok).
  const m = s.match(/^(\d{1,2})([./-])(\d{1,2})\2(\d{4}|\d{2})$/);
  if(!m) return { ok:false, error:'Tarih okunamadı — gg.aa.yyyy yazın (örn: 05.02.2026)' };
  const gun = Number(m[1]), ay = Number(m[3]);
  const yil = m[4].length === 2 ? 2000 + Number(m[4]) : Number(m[4]);
  if(yil < 1 || yil > 9999) return { ok:false, error:'Yıl 1-9999 arasında olmalı (girilen: ' + m[4] + ')' };
  if(ay < 1 || ay > 12) return { ok:false, error:'Ay 1-12 arasında olmalı (girilen: ' + m[3] + ')' };
  const sonGun = tarihAyGunSayisi(yil, ay);
  if(gun < 1 || gun > sonGun){
    return { ok:false, error: TARIH_AY_ADLARI[ay - 1] + ' ' + yil + ' ' + sonGun + ' gün — ' + m[1] + '.' + m[3] + '.' + m[4] + ' yok' };
  }
  return { ok:true, iso: yil + '-' + String(ay).padStart(2, '0') + '-' + String(gun).padStart(2, '0') };
}

// MIN/MAX ARALIK KONTROLÜ — sınırlar dahil (kapalı aralık). Sınır geçerli
// ISO değilse o sınır yok sayılır (sınırlar kod tarafından verilir; kullanıcı
// girdisi değildir). ISO karşılaştırması sözlüksel = kronolojik.
function tarihAraliktaMi(iso, min, max){
  if(!tarihGecerliMi(iso)) return { ok:false, error:'Geçersiz tarih' };
  if(tarihGecerliMi(min) && iso < min) return { ok:false, error:'Tarih ' + tarihIsoTr(min) + ' tarihinden önce olamaz' };
  if(tarihGecerliMi(max) && iso > max) return { ok:false, error:'Tarih ' + tarihIsoTr(max) + ' tarihinden sonra olamaz' };
  return { ok:true, error:null };
}

// AY IZGARASI ÇEKİRDEĞİ — (yil, ay 1..12) → { yil, ay, hucreler };
// hucreler Pazartesi-önce tam haftalar (uzunluk % 7 = 0): ay içi hücre
// { iso:'YYYY-MM-DD', gun, ayIci:true }, ay-dışı konum null. Yol (leading)
// null sayısı = ayın 1. gününün hafta içi konumu; kuyruk (trailing) tam
// haftaya tamamlayan null'lar.
function tarihAyIzgara(yil, ay){
  if(!Number.isInteger(yil) || yil < 1 || yil > 9999) return null;
  if(!Number.isInteger(ay) || ay < 1 || ay > 12) return null;
  const sonGun = tarihAyGunSayisi(yil, ay);
  const onEk = yil + '-' + String(ay).padStart(2, '0') + '-';
  // 1970-01-01 Perşembe düzeltmesi; +7 ile JS negatif-modulo koruması —
  // 1970 ÖNCESİ aylarda gunNo negatiftir, çıplak % işareti korur.
  const bosluk = ((_tarihGunNo(yil, ay, 1) + 3) % 7 + 7) % 7;
  const hucreler = [];
  for(let i = 0; i < bosluk; i++) hucreler.push(null);
  for(let g = 1; g <= sonGun; g++){
    hucreler.push({ iso: onEk + String(g).padStart(2, '0'), gun: g, ayIci: true });
  }
  while(hucreler.length % 7 !== 0) hucreler.push(null);
  return { yil: yil, ay: ay, hucreler: hucreler };
}

// YIL SEÇİM MATEMATİĞİ — 1..9999'a kelepirli (ızgara etki alanı); delta
// tam sayıya yuvarlanır, sayı değilse 0.
function tarihYilKaydir(yil, delta){
  const adim = Math.trunc(Number(delta) || 0);
  return Math.min(9999, Math.max(1, (Number(yil) || 0) + adim));
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz —
// js/utils/helpers.js kalıbı).
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, {
    TARIH_AY_ADLARI, TARIH_GUN_ADLARI,
    tarihArtikYilMi, tarihAyGunSayisi, tarihGecerliMi, tarihIsoTr,
    tarihParse, tarihAraliktaMi, tarihAyIzgara, tarihYilKaydir
  });
}
