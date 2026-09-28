#!/usr/bin/env node
// EgeSut iç-sel Atlas etiketi tazelik denetleyicisi — ÖZ-BAĞLI (tools-bank/ss-research bağımlılığı YOK).
//
// Ne yapar: js/ altındaki her fonksiyonun JSDoc'undaki @rpc/@tablo/@olay satırlarını
// fonksiyon gövdesiyle karşılaştırır. Gövde ölçümü espree AST'ile yapılır (repo devDependency,
// 2026-09-28'de eklendi); etiket satırları kaynaktan çıkarılır — atlas haritası/indeks GEREKMEZ.
//
// Tanınan gövde çağrıları (EgeSut/supabase-js konvansiyonu):
//   .from('<literal>')            -> tablo (işlemsiz)
//   rpc('<literal>')              -> rpc
//   addEventListener('<literal>') -> olay
//   <islem>() zincirinde .from()  -> tablo + işlem (ISLEMLER: select/insert/update/upsert/delete)
//
// Hükümler: DOĞRU (iki yönlü küme eşitliği) | HATALI (FAZLA/EKSİK) | DOGRULANAMADI
//   (tanınmayan etiket girdisi ya da fn düğümü bulunamadı — sessiz DOĞRU yok; ayrı sayılır,
//   basılır ama çıkış kodunu bozmaz).
//
// Çıkış kodları: 0 temiz | 1 HATALI satır var | 2 ayrıştırma hatası (bozuk js dosyası)
// Kullanım:
//   node scripts/etiket-tazelik.mjs                       # tüm js/ (_archive + *.bak.js hariç)
//   node scripts/etiket-tazelik.mjs --dosya js/api.js ... # yalnız verilen dosyalar (staged modu)
//   node scripts/etiket-tazelik.mjs --kirmizi             # 4 bozma kolu öz-testi (diske yazmaz)
//   node scripts/etiket-tazelik.mjs --jsonl <yol>         # satır-bazlı rapor dosyası
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(REPO, 'package.json'));
const espree = require('espree');

const ISLEMLER = new Set(['select', 'insert', 'update', 'upsert', 'delete']);
// v2.3 (EGESUT-V23-ETIKET kalem 2): dolaylı tablo yardımcıları — türetim atlas v2.3
// motoruyla (tools-bank/atlas/atlas.mjs TABLO_YARDIMCILARI) birebir; Map: prototip
// zehirlenmesine kapalı (toLocaleString dersi). Çıplak çağrı biçimi.
const TABLO_YARDIMCILARI = new Map([['getData', 'okuma'], ['pullTables', 'tazeleme'], ['_pullTablesNow', 'tazeleme']]);
const ETIKET_DESEN = /^@(rpc|tablo|olay)\b\s*(.*)$/;

// --- argümanlar -------------------------------------------------------------
const args = process.argv.slice(2);
function argDeger(adi) {
  const i = args.indexOf(adi);
  return i >= 0 ? args[i + 1] : null;
}
const DOSYALAR = args.includes('--dosya') ? args.slice(args.indexOf('--dosya') + 1).filter(a => !a.startsWith('--')) : null;
const JSONL_YOL = argDeger('--jsonl');
const KIRMIZI = args.includes('--kirmizi');

// --- yardımcılar ------------------------------------------------------------
function jsDosyalari(kok) {
  const sonuc = [];
  function yuru(d) {
    for (const girdi of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const yol = path.join(d, girdi.name);
      if (girdi.isDirectory()) {
        if (girdi.name === '_archive') continue; // arşiv denetim dışı
        yuru(yol);
      } else if (girdi.name.endsWith('.js') && !girdi.name.endsWith('.bak.js')) {
        sonuc.push(yol);
      }
    }
  }
  yuru(kok);
  return sonuc;
}

function ayristir(kod, dosya) {
  for (const sourceType of ['module', 'script']) {
    try {
      return espree.parse(kod, { ecmaVersion: 'latest', loc: true, range: true, comment: true, sourceType });
    } catch (e) {
      if (sourceType === 'script') throw new Error(`ayrıştırma başarısız: ${dosya}: ${e.message}`);
    }
  }
}

function fnDugumleri(ast) {
  const fns = [];
  function yuru(dugum) {
    if (!dugum || typeof dugum.type !== 'string') return;
    if (dugum.type === 'FunctionDeclaration' || dugum.type === 'FunctionExpression' || dugum.type === 'ArrowFunctionExpression') fns.push(dugum);
    for (const anahtar of Object.keys(dugum)) {
      if (anahtar === 'loc' || anahtar === 'range' || anahtar === 'leadingComments') continue;
      const deger = dugum[anahtar];
      if (Array.isArray(deger)) deger.forEach(yuru);
      else if (deger && typeof deger === 'object' && typeof deger.type === 'string') yuru(deger);
    }
  }
  yuru(ast);
  fns.sort((a, b) => a.start - b.start);
  return fns;
}

// JSDoc blok yorum ham metnini satırlara bölüp *@ işaretlerini soyar
function yorumSatirlari(comment) {
  return comment.value.split('\n').map(satir => satir.replace(/^\s*\*\s?/, '').trimEnd());
}

// Etiket satırlarını çöz: [{tip, ham, adlar|girisler, dogrulanamadiSorun}]
function etiketCoz(comment) {
  const satirlar = [];
  for (const ham of yorumSatirlari(comment)) {
    const m = ham.match(ETIKET_DESEN);
    if (!m) continue;
    const [, tip, govde] = m;
    const satir = { tip, ham: ham.trim(), dogrulanamadiSorun: null };
    if (tip === 'rpc') {
      satir.adlar = govde.split(',').map(s => s.trim()).filter(Boolean);
      // v2.3: koşullu çift işareti — yalnız SON adın sonundaki '(koşullu)' eki soyulur
      // (etiket çıkarıcısı atlas-etiket'in yazdığı tek biçim; satır.kosullu bilgi amaçlı)
      const son = satir.adlar[satir.adlar.length - 1];
      if (son && son.endsWith('(koşullu)')) {
        satir.adlar[satir.adlar.length - 1] = son.slice(0, -'(koşullu)'.length).trim();
        satir.kosullu = true;
      }
      satir.adlar = satir.adlar.filter(Boolean);
      if (satir.adlar.length === 0) satir.dogrulanamadiSorun = `tanınmayan @rpc satırı (ad yok): ${ham.trim()}`;
    } else if (tip === 'tablo') {
      satir.girisler = [];
      for (const g of govde.split(', ')) {
        if (!g.trim()) continue;
        const mm = g.trim().match(/^(\S+?)(?: \((.+)\))?$/);
        if (!mm) {
          satir.dogrulanamadiSorun = `tanınmayan @tablo girdisi: ${g.trim()}`;
          break;
        }
        satir.girisler.push({ tablo: mm[1], islem: mm[2] || null });
      }
      if (!satir.dogrulanamadiSorun && satir.girisler.length === 0) satir.dogrulanamadiSorun = `tanınmayan @tablo satırı (girdi yok): ${ham.trim()}`;
    } else if (tip === 'olay') {
      satir.adlar = govde.split(',').map(s => s.trim()).filter(Boolean);
      if (satir.adlar.length === 0) satir.dogrulanamadiSorun = `tanınmayan @olay satırı (ad yok): ${ham.trim()}`;
    }
    satirlar.push(satir);
  }
  return satirlar;
}

// Gövde ölçümü: fn düğümünün alt ağacındaki tanınan çağrılar
// (referans dogrula.mjs olc() ile birebir: callee adı Identifier ya da member property —
//  alıcı fark etmez, yani window.db.rpc('x') de db.from('t') de tanınır)
function propAdi(p) {
  if (!p) return null;
  if (p.type === 'Identifier') return p.name;
  if (p.type === 'Literal') return String(p.value);
  return null;
}

function govdeOlc(fnDugumu) {
  const rpcler = new Set();
  const olaylar = new Set();
  const tablolar = new Map(); // tablo -> Set(islem|null)
  function yuru(dugum) {
    if (!dugum || typeof dugum.type !== 'string') return;
    if (dugum.type === 'CallExpression') {
      const ad = dugum.callee.type === 'Identifier' ? dugum.callee.name
        : dugum.callee.type === 'MemberExpression' ? propAdi(dugum.callee.property) : null;
      const ilkArg = dugum.arguments[0];
      const deger = ilkArg && ilkArg.type === 'Literal' && typeof ilkArg.value === 'string' ? ilkArg.value : null;
      if (ad === 'from' && deger !== null) {
        if (!tablolar.has(deger)) tablolar.set(deger, new Set());
        tablolar.get(deger).add(null);
      } else if (ad === 'rpc' && deger !== null) {
        rpcler.add(deger);
      } else if (ad === 'rpc') {
        // v2.3-KA1: ternary literal çifti — iki dal da kaydedilir (atlas.mjs ile birebir)
        const kosul = ilkArg && ilkArg.type === 'ConditionalExpression'
          ? [ilkArg.consequent, ilkArg.alternate].map(x => x && x.type === 'Literal' && typeof x.value === 'string' ? x.value : null)
          : null;
        if (kosul && kosul[0] !== null && kosul[1] !== null) {
          rpcler.add(kosul[0]); rpcler.add(kosul[1]);
        }
      } else if (ad === 'addEventListener' && deger !== null) {
        olaylar.add(deger);
      } else if (TABLO_YARDIMCILARI.has(ad) && dugum.callee.type === 'Identifier') {
        // v2.3-KA2: dolaylı tablo erişimi — getData('t') → okuma;
        // pullTables/_pullTablesNow(['a','b']) dizi literal → tazeleme (atlas.mjs ile birebir)
        const islem = TABLO_YARDIMCILARI.get(ad);
        const a0 = dugum.arguments[0];
        const adaylar = a0 && a0.type === 'ArrayExpression' ? a0.elements
          : a0 && a0.type === 'Literal' && typeof a0.value === 'string' ? [a0] : [];
        for (const el of adaylar) {
          if (el && el.type === 'Literal' && typeof el.value === 'string') {
            if (!tablolar.has(el.value)) tablolar.set(el.value, new Set());
            tablolar.get(el.value).add(islem);
          }
        }
      } else if (ISLEMLER.has(ad)) {
        // işlem çağrısı: callee.object zincirinde geriye yürüyüp .from('<lit>') ara
        let o = dugum.callee.object;
        while (o && o.type === 'CallExpression') {
          const po = o.callee.type === 'MemberExpression' ? propAdi(o.callee.property) : null;
          if (po === 'from') {
            const tv = o.arguments[0] && o.arguments[0].type === 'Literal' && typeof o.arguments[0].value === 'string' ? o.arguments[0].value : null;
            if (tv !== null) {
              if (!tablolar.has(tv)) tablolar.set(tv, new Set());
              tablolar.get(tv).add(ad);
            }
            break;
          }
          o = o.callee && o.callee.object;
        }
      }
    }
    for (const anahtar of Object.keys(dugum)) {
      if (anahtar === 'loc' || anahtar === 'range') continue;
      const deger = dugum[anahtar];
      if (Array.isArray(deger)) deger.forEach(yuru);
      else if (deger && typeof deger === 'object' && typeof deger.type === 'string') yuru(deger);
    }
  }
  yuru(fnDugumu);
  return { rpcler, olaylar, tablolar };
}

// Bir etiket satırını gövde ölçümüyle karşılaştır -> sorun listesi
function karsilastir(satir, govde) {
  const sorunlar = [];
  if (satir.tip === 'rpc') {
    for (const a of satir.adlar) if (!govde.rpcler.has(a)) sorunlar.push(`FAZLA: gövdede rpc('${a}') yok`);
    for (const a of govde.rpcler) if (!satir.adlar.includes(a)) sorunlar.push(`EKSİK: rpc('${a}') etikette yok`);
  } else if (satir.tip === 'tablo') {
    for (const g of satir.girisler) {
      if (!govde.tablolar.has(g.tablo)) sorunlar.push(`FAZLA: gövdede .from('${g.tablo}') yok`);
      else if (g.islem && !govde.tablolar.get(g.tablo).has(g.islem)) {
        sorunlar.push(`FAZLA: ${g.tablo} zincirinde '${g.islem}' yok (gövde işlemleri: ${[...govde.tablolar.get(g.tablo)].map(x => x ?? '—').join(',')})`);
      }
    }
    for (const t of govde.tablolar.keys()) {
      if (!satir.girisler.some(g => g.tablo === t)) sorunlar.push(`EKSİK: gövdede .from('${t}') var, etikette yok`);
    }
  } else if (satir.tip === 'olay') {
    for (const a of satir.adlar) if (!govde.olaylar.has(a)) sorunlar.push(`FAZLA: gövdede addEventListener('${a}') yok`);
    for (const a of govde.olaylar) if (!satir.adlar.includes(a)) sorunlar.push(`EKSİK: addEventListener('${a}') etikette yok`);
  }
  return sorunlar;
}

function hukumVer(sorunlar, dogrulanamadiSorun) {
  if (dogrulanamadiSorun) return 'DOGRULANAMADI';
  if (sorunlar.length === 0) return 'DOĞRU';
  if (sorunlar.some(s => s.startsWith('FAZLA') || s.startsWith('EKSİK'))) return 'HATALI';
  return 'DOGRULANAMADI';
}

// Etiketli yorumu sahibi fn düğümüne iliştir:
// kural — yorum ile fn arasındaki metin ne ';' ne '}' içerir (yani arada başka deyim yok);
// `const ad = ` gibi bağlaçlar serbest. Arada fn varsa yorum ona ait demektir, sonrakine geçmez.
function etiketliKayitlar(dosya, kod, ast, goreli) {
  const kayitlar = [];
  const fns = fnDugumleri(ast);
  const yorumlar = (ast.comments || []).filter(c => c.type === 'Block' && /@(rpc|tablo|olay)\b/.test(c.value));
  for (const yorum of yorumlar) {
    const satirlar = etiketCoz(yorum);
    if (satirlar.length === 0) continue;
    const hedef = fns.find(f => f.start > yorum.end);
    let fnAdi = hedef ? (hedef.id && hedef.id.name) || null : null;
    if (!fnAdi && hedef) {
      // anonim (const x = () => / key: function()): boslugun son belirteci sahibin adidir
      const bosluk = kod.slice(yorum.end, hedef.start).trim();
      const adEs = bosluk.match(/([A-Za-z_$][\w$]*)\s*$/);
      fnAdi = adEs ? adEs[1] : '(anonim)';
    }
    const fnSatir = hedef ? hedef.loc.start.line : yorum.loc.start.line;
    const id = `${goreli}:${fnAdi}@${fnSatir}`;
    if (!hedef || /[;}]/.test(kod.slice(yorum.end, hedef.start))) {
      for (const s of satirlar) {
        kayitlar.push({ id, etiket: s.ham, hukum: 'DOGRULANAMADI', sorun: [s.dogrulanamadiSorun || 'fn düğümü bulunamadı (yorum fn ile bitişik değil)'] });
      }
      continue;
    }
    const govde = govdeOlc(hedef);
    for (const s of satirlar) {
      const sorunlar = s.dogrulanamadiSorun ? [s.dogrulanamadiSorun] : karsilastir(s, govde);
      kayitlar.push({ id, etiket: s.ham, hukum: hukumVer(sorunlar, s.dogrulanamadiSorun), sorun: sorunlar, _satir: s, _govde: govde });
    }
  }
  return kayitlar;
}

// --- kırmızı kontrol: 4 bozma kolu ( bellekte, diske yazmaz ) ----------------
function kirmiziKontrol(kayitlar) {
  const kollar = [];
  function kos(ad, boz) {
    // boz(kopya) -> beklenen sorun deseni (ya da null = bozma etkisiz kaldı)
    const kopya = kayitlar.filter(k => k._satir).map(k => ({ ...k, _satir: { ...k._satir, adlar: k._satir.adlar ? [...k._satir.adlar] : undefined, girisler: k._satir.girisler ? k._satir.girisler.map(g => ({ ...g })) : undefined } }));
    const desen = boz(kopya);
    if (!desen) {
      kollar.push({ ad, sonuc: 'ATLANDI (uygun örnek yok)' });
      return true;
    }
    const vuran = kopya.filter(k => {
      const sorunlar = karsilastir(k._satir, k._govde);
      return sorunlar.some(s => s.includes(desen));
    });
    kollar.push({ ad, sonuc: vuran.length > 0 ? `YAKALANDI (${vuran.length} satır HATALI)` : `KAÇTI — HATA! (aranan: ${desen})` });
    return vuran.length > 0;
  }
  const var_mi = tip => kayitlar.some(k => k._satir && k._satir.tip === tip);
  const islemli = kayitlar.find(k => k._satir && k._satir.tip === 'tablo' && (k._satir.girisler || []).some(g => g.islem));
  let tam = true;
  tam = kos('K1 rpc-ad', ks => {
    if (!var_mi('rpc')) return null;
    ks.find(x => x._satir.tip === 'rpc')._satir.adlar = ['olmayan_rpc_ad'];
    return "rpc('olmayan_rpc_ad')";
  }) && tam;
  tam = kos('K2 tablo-ad', ks => {
    if (!var_mi('tablo')) return null;
    ks.find(x => x._satir.tip === 'tablo')._satir.girisler = [{ tablo: 'olmayan_tablo', islem: 'select' }];
    return ".from('olmayan_tablo')";
  }) && tam;
  tam = kos('K3 olay-ad', ks => {
    if (!var_mi('olay')) return null;
    ks.find(x => x._satir.tip === 'olay')._satir.adlar = ['olmayan-olay'];
    return "addEventListener('olmayan-olay')";
  }) && tam;
  tam = kos('K4 tablo-islem', ks => {
    const k = ks.find(x => x._satir.tip === 'tablo' && x._satir.girisler.some(g => g.islem));
    if (!k) return null;
    for (const g of k._satir.girisler) {
      if (!g.islem) continue;
      // gövde kümesinde OLMAYAN bir işlem seç — bozma her koşumda deterministik yakalanır
      const eksik = [...ISLEMLER].find(i => !k._govde.tablolar.get(g.tablo)?.has(i)) || 'olmayan_islem';
      g.islem = eksik;
      return `'${eksik}' yok`;
    }
    return null;
  }) && tam;
  // v2.3 kolları (EGESUT-V23-ETIKET kalem 2): yeni sözlük de bozulmaya yakalanmalı
  tam = kos('K5 koşullu-rpc-ad', ks => {
    const k = ks.find(x => x._satir.tip === 'rpc' && x._satir.kosullu && x._satir.adlar.length);
    if (!k) return null;
    k._satir.adlar = ['olmayan_kosullu_ad'];
    return "rpc('olmayan_kosullu_ad') yok";
  }) && tam;
  tam = kos('K6 yardimci-tablo-ad', ks => {
    const k = ks.find(x => x._satir.tip === 'tablo' && (x._satir.girisler || []).some(g => g.islem === 'okuma' || g.islem === 'tazeleme'));
    if (!k) return null;
    const g = k._satir.girisler.find(x => x.islem === 'okuma' || x.islem === 'tazeleme');
    g.tablo = 'olmayan_yardimci_tablo';
    return ".from('olmayan_yardimci_tablo') yok";
  }) && tam;
  for (const k of kollar) console.log(`  [kirmizi] ${k.ad}: ${k.sonuc}`);
  return { tam, kollar };
}

// --- ana akış ----------------------------------------------------------------
const kok = path.join(REPO, 'js');
const dosyalar = DOSYALAR ? DOSYALAR.map(d => path.isAbsolute(d) ? d : path.join(REPO, d)) : jsDosyalari(kok);
const kayitlar = [];
for (const dosya of dosyalar) {
  const kod = fs.readFileSync(dosya, 'utf8');
  try {
    const ast = ayristir(kod, dosya);
    kayitlar.push(...etiketliKayitlar(dosya, kod, ast, path.relative(REPO, dosya)));
  } catch (e) {
    console.error(`HATA: ${e.message}`);
    process.exit(2);
  }
}

if (KIRMIZI) {
  console.log(`kırmızı kontrol — etiketli satır paydası: ${kayitlar.length}`);
  const kirmizi = kirmiziKontrol(kayitlar);
  const canli = kirmizi.kollar.filter(k => k.sonuc !== 'ATLANDI (uygun örnek yok)').length;
  console.log(kirmizi.tam
    ? `kırmızı kontrol: YAKALANDI (${canli} canlı kol / ${kirmizi.kollar.length} kol)`
    : 'kırmızı kontrol: EKSİK — bazı kollar kaçtı');
  process.exitCode = kirmizi.tam ? 0 : 1;
} else {
  const dogru = kayitlar.filter(k => k.hukum === 'DOĞRU').length;
  const hatali = kayitlar.filter(k => k.hukum === 'HATALI').length;
  const dogrulanamadi = kayitlar.filter(k => k.hukum === 'DOGRULANAMADI').length;
  for (const k of kayitlar) {
    if (k.hukum !== 'DOĞRU') {
      console.log(`  [${k.hukum}] ${k.id} → ${k.etiket}`);
      for (const s of k.sorun) console.log(`      ${s}`);
    }
  }
  console.log(`payda ${kayitlar.length} satır: DOĞRU ${dogru} | HATALI ${hatali} | DOGRULANAMADI ${dogrulanamadi}`);
  if (JSONL_YOL) {
    const temiz = kayitlar.map(({ _satir, _govde, ...kalan }) => kalan);
    fs.writeFileSync(JSONL_YOL, temiz.map(k => JSON.stringify(k)).join('\n') + '\n');
  }
  process.exitCode = hatali > 0 ? 1 : 0;
}
