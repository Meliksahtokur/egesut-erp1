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

// ═══ EL GİRİŞİ MASKE + NORMALİZASYON + YIL ARALIĞI (R1, G-20260913-
// TARIH-SECICI-R1 bulgu 3/4 — sahip testi: '13,09,2026' "okunamadı") ═══
// tarihParse sözleşmesi SABİT kalır (mevcut red-pinler '5 2 2026'/'5,2,2026'
// girişini RED olarak kilitler); tolerans AYRI saf adımlarda yaşar: bileşen
// Uygula'yı tarihGirisCoz'dan, canlı yazımı tarihMaskeUygula'dan geçirir.

// GİRİŞ ÇÖZÜMLEYİCİ (Uygula yolu) — ayraç toleransı: ',' '/' '-' ve boşluk
// '.'a normalize edilir, sonra tarihParse konuşur (mm/dd yorumu YOK, hayali
// tarih sessizce düzeltilmez). DOM yok.
function tarihGirisCoz(metin){
  return tarihParse(String(metin == null ? '' : metin).replace(/[,.\/\-\s]+/g, '.'));
}

// CANLI MASKE (input olayı yolu) — rakamları GG.AA.YYYY segmentlerine dizer;
// yazılan ayraçlar (, / - boşluk) '.'a döner; segment dolunca nokta kendiliğinden
// gelir. Silme doğal kalsın diye değer ayraçla bitiyorsa kuyruk noktası
// KORUNUR (tam tarih uzunluğuna ulaşıldıysa eklenmez — '13.09.2026.' gibi
// bozuk kuyruk oluşamaz). Döner { metin, hata }:
// - hata: taşan segmentin adını taşıyan anlık uyarı ('Gün 1-31 olmalı',
//   'Ay 1-12 olmalı', 'Yıl 4 hane olmalı') — POLITIKA: hane YUTULMAZ.
//   Yutma, yapıştırılan geçersiz tarihi sessizce başka bir tarihe çevirirdi
//   ('90.09.2026' → '9.09.2026' kabulü = sessiz düzeltme); sahip kuralı
//   "yazılamasın ya da anında işaretlensin" — işaretleme seçildi. Gerçek
//   ay-gün sayısı denetimi Uygula'da (tarihParse) yapılır.
function tarihMaskeUygula(ham){
  const s = String(ham == null ? '' : ham);
  const rakamlar = s.replace(/\D/g, '');
  // Segment planı: gün 2 hane / ay 2 hane / yıl 4 hane (değer tavanları ayrı).
  const uzunluklar = [2, 2, 4];
  const tavanlar  = [31, 12, null];
  let metin = '', hata = null, kalan = rakamlar;
  for(let i = 0; i < 3 && kalan.length; i++){
    const parca = kalan.slice(0, uzunluklar[i]);
    kalan = kalan.slice(parca.length);
    if(i < 2){
      if(Number(parca) > tavanlar[i]) hata = (i === 0 ? 'Gün 1-31 olmalı' : 'Ay 1-12 olmalı');
    } else if(parca.length === uzunluklar[i] && kalan.length){
      hata = 'Yıl 4 hane olmalı'; // 5. yıl hanesi yutulur ama sessiz kalmaz
    }
    metin += parca;
    if(kalan.length && i < 2) metin += '.';
  }
  // Kuyruk ayraç koruması: değer ayraçla bittiyse ('11.12.' geri-silme hâli,
  // ya da kullanıcı ayracı kendisi yazdıysa) nokta yerinde kalır; tam tarih
  // kurulduysa (10 karakter) kuyruk eklenmez.
  if(metin && metin.length < 10 && /[,.\/\-\s]$/.test(s)) metin += '.';
  return { metin: metin, hata: hata };
}

// MASKE İMLECİ — eski imlecin önündeki rakam sayısını yeni maskeli metinde
// aynı rakamın ardına taşır; ara ayraçların ÜSTÜNDEN ATLANIR (imleç noktanın
// soluna düşerse sonraki hane segmente karışır); rakam azalırsa (silme)
// metin sonuna kıskanır. Bileşen input olayında setSelectionRange ile
// uygular; saf, test edilebilir.
function tarihMaskeImlec(yeniMetin, rakamSayisi){
  const s = String(yeniMetin == null ? '' : yeniMetin);
  if(!(rakamSayisi > 0)) return 0;
  let sayilan = 0;
  for(let i = 0; i < s.length; i++){
    if(s[i] >= '0' && s[i] <= '9'){
      sayilan++;
      if(sayilan === rakamSayisi){
        while(i + 1 < s.length && !(s[i + 1] >= '0' && s[i + 1] <= '9')) i++;
        return i + 1;
      }
    }
  }
  return s.length;
}

// YIL AÇILIR LİSTE ARALIĞI — alanın min/max'ından türetilir (sahip kuralı:
// doğum geçmiş yıllara hâkim, görev birkaç gelecek yıl). Tek sınır varsa
// öbür taraf ±120 yıl; ikisi de yoksa bugunYil-120 .. bugunYil+10 (raporda
// beyanlı varsayılan). Sonuç 1..9999'a kelepirli; geçersiz ISO sınır yok
// sayılır (tarihAraliktaMi aynı tavır). DOM yok.
function tarihYilAraligi(min, max, bugunYil){
  const simdi = Math.trunc(Number(bugunYil) || 0);
  const yilOf = v => (tarihGecerliMi(v) ? Number(String(v).slice(0, 4)) : null);
  const minYil = yilOf(min), maxYil = yilOf(max);
  let a, b;
  if(minYil !== null && maxYil !== null){ a = minYil; b = maxYil; }
  else if(minYil !== null){ a = minYil; b = minYil + 120; }
  else if(maxYil !== null){ a = maxYil - 120; b = maxYil; }
  else { a = simdi - 120; b = simdi + 10; }
  return [Math.max(1, a), Math.min(9999, b)];
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz —
// js/utils/helpers.js kalıbı).
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, {
    TARIH_AY_ADLARI, TARIH_GUN_ADLARI,
    tarihArtikYilMi, tarihAyGunSayisi, tarihGecerliMi, tarihIsoTr,
    tarihParse, tarihAraliktaMi, tarihAyIzgara, tarihYilKaydir,
    tarihGirisCoz, tarihMaskeUygula, tarihMaskeImlec, tarihYilAraligi
  });
}
