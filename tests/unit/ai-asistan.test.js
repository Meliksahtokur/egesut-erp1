// tests/unit/ai-asistan.test.js
// js/ai-asistan.js — saf string/DOM-yardımcıları birim testleri.
// Ağ/LLM çağrısı yapan akışlar (asistanGonder vb.) kapsam DIŞI; yalnızca
// saf ön/işleme sonrası yardımcıları (_asistanEsc/_asistanStripThink/...)
// ve DOM-stub ile çalışabilen kurucular test edilir.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

const ai = loadBrowserModule('js/ai-asistan.js');

// ── _asistanEsc ────────────────────────────────────────────────
test('_asistanEsc: null/undefined/boş → boş string', () => {
  assert.strictEqual(ai.sandbox._asistanEsc(null), '');
  assert.strictEqual(ai.sandbox._asistanEsc(undefined), '');
  assert.strictEqual(ai.sandbox._asistanEsc(''), '');
});

test('_asistanEsc: & < > kaçar, sırayla & önce', () => {
  assert.strictEqual(ai.sandbox._asistanEsc('a & b < c > d'), 'a &amp; b &lt; c &gt; d');
  assert.strictEqual(ai.sandbox._asistanEsc('&'), '&amp;');
  assert.strictEqual(ai.sandbox._asistanEsc('<'), '&lt;');
  assert.strictEqual(ai.sandbox._asistanEsc('>'), '&gt;');
});

test('_asistanEsc: zaten kaçışlı metin çift kaçılır (&amp; → &amp;amp;)', () => {
  // Kaçış farkındalığı YOK — escaper sözleşmesi gereği doğru davranış
  assert.strictEqual(ai.sandbox._asistanEsc('&amp;'), '&amp;amp;');
  assert.strictEqual(ai.sandbox._asistanEsc('&lt;script&gt;'), '&amp;lt;script&amp;gt;');
});

test('_asistanEsc: çift/tek tırnak KAÇMAZ (mevcut davranış)', () => {
  // _asistanEsc yalnızca metin-bağlamı (innerHTML text) için tasarlanmış;
  // attribute bağlamında kullanılırsa risk olurdu. Bu modülde attribute'lar
  // escAttr kullanıyor — burada sadece mevcut davranış belgelenir.
  assert.strictEqual(ai.sandbox._asistanEsc('"tırnak"'), '"tırnak"');
  assert.strictEqual(ai.sandbox._asistanEsc("tek'tırnak"), "tek'tırnak");
  assert.strictEqual(ai.sandbox._asistanEsc('`bt`'), '`bt`');
});

test('_asistanEsc: falsy girdi sayısı — 0/false → boş string (ŞÜPHELİ DAVRANIŞ)', () => {
  // ŞÜPHELİ DAVRANIŞ: (s || '') kalıbı yalnızca FALSY girdileri '' yapar;
  // truthy ama string-olmayan girdi (ör. sayı 5) String'e dönüştürülMEDİĞİ
  // için TypeError fırlatır. Mevcut davranış aynen sabitlenir.
  assert.strictEqual(ai.sandbox._asistanEsc(0), '');
  assert.strictEqual(ai.sandbox._asistanEsc(false), '');
  // Not: hata vm bağlamından geldiği için prototype host TypeError'ı değil —
  // isim ile eşlenir (realm farkı).
  assert.throws(() => ai.sandbox._asistanEsc(5), { name: 'TypeError' }); // 5.replace yok
});

// ── _asistanStripThink ─────────────────────────────────────────
test('_asistanStripThink: null/undefined/boş → boş string', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink(null), '');
  assert.strictEqual(ai.sandbox._asistanStripThink(undefined), '');
  assert.strictEqual(ai.sandbox._asistanStripThink(''), '');
});

test('_asistanStripThink: think içermeyen metin aynen döner (trim uygulanır)', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink('merhaba dünya'), 'merhaba dünya');
  assert.strictEqual(ai.sandbox._asistanStripThink('  baştaki/sondaki boşluk  '), 'baştaki/sondaki boşluk');
  assert.strictEqual(ai.sandbox._asistanStripThink('satir1\nsatir2'), 'satir1\nsatir2'); // iç boşluk korunur
});

test('_asistanStripThink: tek eşli blok silinir, çevre metin kalır', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink('<think>düşünme</think>cevap'), 'cevap');
  assert.strictEqual(ai.sandbox._asistanStripThink('önce<think>x</think>sonra'), 'öncesonra');
  assert.strictEqual(ai.sandbox._asistanStripThink('<think>çok\nsatırlı</think>ok'), 'ok'); // [\s\S] yeni satırı da kapsar
  assert.strictEqual(ai.sandbox._asistanStripThink('<think></think>boş blok'), 'boş blok');
});

test('_asistanStripThink: birden çok eşli blok tamamı silinir', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink('<think>a</think>x<think>b</think>y'), 'xy');
});

test('_asistanStripThink: lazy (açgözlü olmayan) eşleşme — bloklar arası görünür metin korunur', () => {
  // Greedy olsaydı ilk <think>'ten son </think>'e kadar hepsi yutulurdu; regex *? lazy
  assert.strictEqual(ai.sandbox._asistanStripThink('<think>1</think>ORTO<think>2</think>'), 'ORTO');
});

test('_asistanStripThink: kapanmamış <think> — sonrasındaki HER ŞEY yutulur (ŞÜPHELİ DAVRANIŞ)', () => {
  // ŞÜPHELİ DAVRANIŞ: canlı akış için kasıtlı tasarım, ama asistanThreadAc
  // geçmiş mesajları da aynı fonksiyondan geçirir — cevap gövdesinde literal
  // "<think>" geçen (kapanmamış) bir mesajın kuyruğu tarihsel görünümdde de kaybolur.
  assert.strictEqual(ai.sandbox._asistanStripThink('merhaba<think>abc'), 'merhaba');
  assert.strictEqual(ai.sandbox._asistanStripThink('a<think>b c d hepsi gitti'), 'a');
  assert.strictEqual(ai.sandbox._asistanStripThink('<think>'), '');
});

test('_asistanStripThink: öksüz </think> etiketi silinir, metin birleşir', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink('a</think>b'), 'ab');
});

test('_asistanStripThink: iç içe görünümli — ilk açılıştan ilk kapanışa kadar (lazy)', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink('<think>a<think>b</think>c'), 'c');
});

test('_asistanStripThink: BÜYÜK/karma harf etiket eşleşmez (case-sensitive, mevcut davranış)', () => {
  // <THINK>/<Think> tanınmaz — LLM çıktısı her zaman küçük harf ürettiği varsayılıyor.
  // Belgeleme amaçlı; değişiklik gerektirmez.
  assert.strictEqual(ai.sandbox._asistanStripThink('<THINK>x</THINK>kalan'), '<THINK>x</THINK>kalan');
});

test('_asistanStripThink: trim en sonda uygulanır', () => {
  assert.strictEqual(ai.sandbox._asistanStripThink('  <think>x</think>  selam  '), 'selam');
});

// ── _asistanToken (window.db.auth.getSession stub'lı) ──────────
// Not: modülde "token sayma" yardımcısı YOK — _asistanToken oturum
// access_token'ını çeker; ağ yok, stub'lanabilir.
test('_asistanToken: session varsa access_token döner', async () => {
  let payload = { session: { access_token: 'tok-abc-123' } };
  const m = loadBrowserModule('js/ai-asistan.js', {
    extra: { db: { auth: { getSession: async () => ({ data: payload }) } } },
  });
  assert.strictEqual(await m.sandbox._asistanToken(), 'tok-abc-123');
  payload = {}; // session yok
  assert.strictEqual(await m.sandbox._asistanToken(), null);
  payload = { session: {} }; // session var ama token yok
  assert.strictEqual(await m.sandbox._asistanToken(), null);
});

// ── _asistanCevapHtml ──────────────────────────────────────────
// Not: markdown→HTML dönüştürücü DEĞİL; escape + think-soyma + \n→<br> +
// opsiyonel katlanır SQL paneli üretir. Testler gerçeğe göre yazıldı.
test('_asistanCevapHtml: sql yoksa — escape + yeni satır → <br>', () => {
  assert.strictEqual(ai.sandbox._asistanCevapHtml('a\nb'), 'a<br>b');
  assert.strictEqual(ai.sandbox._asistanCevapHtml('<b>x</b>'), '&lt;b&gt;x&lt;/b&gt;');
  assert.strictEqual(ai.sandbox._asistanCevapHtml('x', null), 'x');
  assert.strictEqual(ai.sandbox._asistanCevapHtml('x', ''), 'x');
});

test('_asistanCevapHtml: think bloğu önce soyulur, sonra escape edilir', () => {
  assert.strictEqual(ai.sandbox._asistanCevapHtml('<think>t</think>hi'), 'hi');
  assert.strictEqual(ai.sandbox._asistanCevapHtml('<think>t</think><b>y</b>'), '&lt;b&gt;y&lt;/b&gt;');
  assert.strictEqual(ai.sandbox._asistanCevapHtml('  pad  '), 'pad'); // stripThink trim'i
});

test('_asistanCevapHtml: sql varsa — tam çıktı (katlanır details paneli)', () => {
  const out = ai.sandbox._asistanCevapHtml('a\nb', 'SELECT 1');
  assert.strictEqual(out,
    'a<br>b<details style="margin-top:8px"><summary style="cursor:pointer;color:var(--ink3);font-size:.75rem">▸ Çalıştırılan SQL</summary>\n      <pre style="white-space:pre-wrap;background:var(--bg2);padding:8px;border-radius:8px;font-size:.7rem;margin-top:4px">SELECT 1</pre></details>');
});

test('_asistanCevapHtml: sql panelinde sql escape edilir (<script> sızamaz)', () => {
  const out = ai.sandbox._asistanCevapHtml('x', '<script>alert(1)</script>');
  assert.ok(out.includes('&lt;script&gt;alert(1)&lt;/script&gt;'));
  assert.ok(!out.includes('<script>')); // ham script etiketi çıktıda yok
});

// ── _asistanBalon ──────────────────────────────────────────────
test('_asistanBalon: rol "user" → sağ/yeşil/beyaz balon', () => {
  const div = ai.sandbox._asistanBalon('user', 'X');
  assert.strictEqual(div.tagName, 'DIV');
  assert.ok(div.style.cssText.includes('align-self:flex-end'));
  assert.ok(div.style.cssText.includes('background:var(--green)'));
  assert.ok(div.style.cssText.includes('color:#fff'));
});

test('_asistanBalon: rol "assistant" → sol/kart/mürekkep balon', () => {
  const div = ai.sandbox._asistanBalon('assistant', 'Y');
  assert.ok(div.style.cssText.includes('align-self:flex-start'));
  assert.ok(div.style.cssText.includes('background:var(--card)'));
  assert.ok(div.style.cssText.includes('color:var(--ink)'));
});

test('_asistanBalon: html ham geçirilir — escape ÇAĞIRANIN sorumluluğu', () => {
  // _asistanBalon kendi escape yapmaz; html parametresi aynen innerHTML'e gider.
  // Mevcut sözleşme: çağıranlar _asistanEsc/_asistanCevapHtml çıktısı verir.
  const raw = '<b>kalın</b>';
  const div = ai.sandbox._asistanBalon('assistant', raw);
  assert.strictEqual(div.innerHTML, raw);
  // user dışındaki her rol (ör. 'system') sol balon sayılır
  assert.ok(ai.sandbox._asistanBalon('system', '').style.cssText.includes('flex-start'));
});

// ── _asistanUserBalon ──────────────────────────────────────────
test('_asistanUserBalon: dataset.role/text — encodeURIComponent round-trip', () => {
  const text = 'soru & cevap <tag> "tırnak"';
  const div = ai.sandbox._asistanUserBalon(text);
  assert.strictEqual(div.dataset.role, 'user');
  assert.strictEqual(div.dataset.text, encodeURIComponent(text));
  assert.strictEqual(decodeURIComponent(div.dataset.text), text);
});

test('_asistanUserBalon: içerik _asistanEsc üzerinden geçer (XSS yok)', () => {
  const div = ai.sandbox._asistanUserBalon('<img src=x onerror=alert(1)>');
  assert.strictEqual(div.innerHTML, '&lt;img src=x onerror=alert(1)&gt;');
  assert.ok(!div.innerHTML.includes('<img'));
  const bos = ai.sandbox._asistanUserBalon('');
  assert.strictEqual(bos.innerHTML, '');
  assert.strictEqual(bos.dataset.text, '');
});

test('_asistanUserBalon: "düzenle" butonu eklenir (tek çocuk, BUTTON, ✏️)', () => {
  const div = ai.sandbox._asistanUserBalon('selam');
  assert.strictEqual(div.children.length, 1);
  const btn = div.children[0];
  assert.strictEqual(btn.tagName, 'BUTTON');
  assert.strictEqual(btn.textContent, '✏️');
  assert.strictEqual(btn.title, 'Bu mesajı düzenle');
});

// ── _asistanKopyaEkle ──────────────────────────────────────────
test('_asistanKopyaEkle: falsy metin → no-op (buton eklenmez)', () => {
  for (const falsy of ['', null, undefined]) {
    const div = makeElement('div');
    ai.sandbox._asistanKopyaEkle(div, falsy);
    assert.strictEqual(div.children.length, 0, `girdi ${String(falsy)} için buton olmamalı`);
    assert.strictEqual(div.dataset.copy, undefined);
  }
});

test('_asistanKopyaEkle: dolu metin → dataset.copy kodlanır + kopyala butonu', () => {
  const div = makeElement('div');
  const temiz = 'cevap & <kelime> "alıntı"';
  ai.sandbox._asistanKopyaEkle(div, temiz);
  assert.strictEqual(div.dataset.copy, encodeURIComponent(temiz));
  assert.strictEqual(decodeURIComponent(div.dataset.copy), temiz);
  assert.strictEqual(div.children.length, 1);
  assert.strictEqual(div.children[0].tagName, 'BUTTON');
  assert.strictEqual(div.children[0].textContent, '📋 Kopyala');
  assert.strictEqual(div.children[0].title, 'Cevabı kopyala');
});

// ── _asistanPlanKarti (global escAttr + scrollIntoView stub gerekli) ──
// ŞÜPHELİ KUPLAJ NOTU: _asistanPlanKarti global `escAttr`'a başvurur
// (js/utils/helpers.js). ai-asistan.js helpers.js'siz yüklendiğinde bu
// çağrı ReferenceError atar — test, helpers.js'teki escAttr'ın birebir
// aynısını sandbox'a sağlar.
const escAttrMirror = (str) => String(str ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

function loadAiWithPlanDeps() {
  const doc = makeDomStub();
  const origCreate = doc.createElement;
  doc.createElement = (tag) => Object.assign(origCreate(tag), { scrollIntoView() {} });
  return loadBrowserModule('js/ai-asistan.js', { dom: doc, extra: { escAttr: escAttrMirror } });
}

test('_asistanPlanKarti: kart sınıfı + numaralı işlem satırları', () => {
  const m = loadAiWithPlanDeps();
  const box = makeElement('div');
  m.sandbox._asistanPlanKarti(box, { plan_id: 'p-1', onizleme: ['Sütten kes', 'Padok güncelle'] });
  assert.strictEqual(box.children.length, 1);
  const kart = box.children[0];
  assert.strictEqual(kart.className, 'asistan-plan-karti');
  assert.ok(kart.innerHTML.includes('📋 Onayına sunulan işlemler'));
  assert.ok(kart.innerHTML.includes('1.'));
  assert.ok(kart.innerHTML.includes('2.'));
});

test('_asistanPlanKarti: onizleme satırları _asistanEsc ile escape edilir', () => {
  const m = loadAiWithPlanDeps();
  const box = makeElement('div');
  m.sandbox._asistanPlanKarti(box, { plan_id: 'p-1', onizleme: ['<b>752</b> numara'] });
  const html = box.children[0].innerHTML;
  assert.ok(html.includes('&lt;b&gt;752&lt;/b&gt; numara'));
  assert.ok(!html.includes('<b>752</b>'));
});

test('_asistanPlanKarti: Onayla/Vazgeç butonları + plan_id escAttr üzerinden geçer', () => {
  const m = loadAiWithPlanDeps();
  const box = makeElement('div');
  m.sandbox._asistanPlanKarti(box, { plan_id: "p'1", onizleme: ['x'] });
  const html = box.children[0].innerHTML;
  assert.ok(html.includes('data-action="asistan-plan-onayla"'));
  assert.ok(html.includes('data-action="asistan-plan-vazgec"'));
  assert.ok(html.includes('data-pid="p&#39;1"')); // escAttr: tek tırnak kaçar — ham interpolasyon değil
  assert.ok(!html.includes("data-pid=\"p'1\""));
});

// ── modül export sözleşmesi ────────────────────────────────────
test('window export sözleşmesi: 13 asistan fonksiyonu window\'a bağlanır', () => {
  const EXPORTS = [
    'asistanGonder', 'asistanMesajDuzenle', 'asistanMesajKopyala',
    'asistanPlanOnayla', 'asistanPlanVazgec', 'asistanPlanGeriAl',
    'asistanYeniSohbet', 'asistanInit', 'asistanGecmisAc',
    'asistanDrawerKapat', 'asistanThreadAc', 'asistanThreadSil', 'asistanTumunuSil',
  ];
  for (const ad of EXPORTS) {
    assert.strictEqual(typeof ai.window[ad], 'function', `${ad} window exportı eksik`);
  }
});
