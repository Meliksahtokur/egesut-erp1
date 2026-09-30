// tests/concurrency/ovsync-takip-t72b.mjs
// T-87 / T-72b — çapraz deadlock provası (§10h H7 SONUÇ ORACLE'I; plan v7 P2b/P3b).
//
// Sabit 5 çift (v7 NİHAİ — eski-yol çiftleri prova DIŞI, B9):
//   Ç1 sarmal tohumlama_bos_ve_devam × tohumlama_kaydet
//   Ç2 sarmal × start_first_service_protocol (düzeltilmiş gövde)
//   Ç3 sarmal × seans_tamamla
//   Ç4 sarmal × vaka_toplu_ac
//   Ç5 kapanış tetikleyicisi (tohumlama INSERT yolu) × sarmal
//
// Yöntem: her çift için İKİ GERÇEK DB BAĞLANTISI (psql alt-süreçleri; dış npm dep yok),
// N=30 eşzamanlı tur, her bağlantıda `SET lock_timeout='5s'` + `statement_timeout='30s'`.
//
// PASS ORACLE'I (H7): (a) hiçbir turda SQLSTATE 40P01 / 55P03 yok; (b) her sonucu çiftin
// İZİNLİ sonlu kümesinde (başarı ya da belgelenmiş iş hatası). BILINMEYEN kod, timeout (57014)
// ve 40P01/55P03 ASLA PASS DEĞİL. "Önce kırmızı" şartı YOK (H7).
//
// KOŞUM (demo; PROD'A KOŞULMAZ — betik URL'de demo proje ref'i görmezse durur):
//   export T72B_DB_URL='postgresql://postgres.vtzqjmazsvurxdeondmi:<PAROLA>@aws-0-eu-west-1.pooler.supabase.com:5432/postgres'
//   node tests/concurrency/ovsync-takip-t72b.mjs                 # tüm çiftler, N=30
//   node tests/concurrency/ovsync-takip-t72b.mjs --pairs=1,4 --rounds=10
//   Ç3 (seans) fixture sözleşmesi AÇIK (fail-closed): koşum için mevcut bir seans uygulama
//   satırı gerekir → `--seans-uygulama-id <uuid>` ver; verilmezse BLOKE raporlanır.
//   T72B_ALLOW_ANY_HOST=1 hedef denetimini aşar (sahip kapısı — demo dışı hedef için).
//
// FIXTURE/TEMİZLİK: E2E-T72B- marker'lı hayvan/görev/tohumlama/vaka; her tur sonunda ve finally'de
// silinir (gorev_log → tohumlama → treatment_day_uygulamalar/treatment_days/cases/protokol_instance
// (TRY ile) → hayvanlar). islem_log izleri bilinçli silinmez (log tablosu; demo reset'i toplar).
//
// Durum kodları: PASS / RED(beklenen) (yeni yol P2b/P3a/P3b yok) / FAIL (oracle ihlali) / BLOKE.
// Çıkış kodu: PASS=0, FAIL=1, RED(beklenen)/BLOKE=2.

import { spawn } from 'node:child_process';

const DEMO_REF = 'vtzqjmazsvurxdeondmi';
const DB_URL = process.env.T72B_DB_URL || '';
const ROUNDS = Math.max(1, parseInt(argVal('--rounds') ?? '30', 10) || 30);
const PAIRS_REQ = (argVal('--pairs') ?? '1,2,3,4,5').split(',').map(s => parseInt(s, 10)).filter(Boolean);
const SEANS_UYGULAMA_ID = argVal('--seans-uygulama-id');

function argVal(name) {
  // İki biçim de kabul: `--name value` ve `--name=value`
  const eq = process.argv.find(a => a.startsWith(name + '='));
  if (eq) return eq.slice(name.length + 1);
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : null;
}

// ── psql alt-süreç = gerçek DB bağlantı katmanı ─────────────────────────────
// Protokol: her istek tek stdout akışında yanıtlanır (sonuç satırı + benzersiz marker
// AYNI SELECT'te) → stderr/stdout yarışı yoktur.
class Psql {
  constructor(tag) { this.tag = tag; this.buf = ''; this.waiters = []; }
  async start() {
    this.proc = spawn('psql', [DB_URL, '-X', '-qAt', '-v', 'ON_ERROR_STOP=0'], { stdio: ['pipe', 'pipe', 'pipe'] });
    this.proc.stdout.setEncoding('utf8');
    this.proc.stdout.on('data', d => this._onData(d));
    this.proc.stderr.setEncoding('utf8');
    this.proc.stderr.on('data', d => { this.lastErr = (this.lastErr + d).slice(-4000); });
    await this.exec(
      `CREATE TEMP TABLE IF NOT EXISTS _t72b_res(sonuc text); SET lock_timeout='5s'; SET statement_timeout='30s';`,
      'READY');
  }
  _onData(d) {
    this.buf += d;
    this.waiters = this.waiters.filter(w => {
      const i = this.buf.indexOf(w.marker);
      if (i < 0) return true;
      const lineStart = this.buf.lastIndexOf('\n', i) + 1;
      const line = this.buf.slice(lineStart, i);                 // işaretçi satırı (exec protokolü)
      const prefix = this.buf.slice(0, Math.max(0, lineStart - 1)); // işaretçiden ÖNCEKİ çıktı (execRows)
      this.buf = this.buf.slice(i + w.marker.length);
      clearTimeout(w.timer);
      w.resolve({ line, prefix });
      return false;
    });
  }
  exec(sql, tag = 'R') {
    const marker = `<<${tag}:${Math.random().toString(36).slice(2, 10)}>>`;
    return new Promise((resolve, reject) => {
      const w = { marker, resolve, reject, timer: setTimeout(() => reject(new Error(`psql zaman aşımı (${this.tag}/${tag})`)), 60000) };
      this.waiters.push(w);
      const q = sql.trimEnd().endsWith(';') ? sql : sql + ';';
      this.proc.stdin.write(`${q}\nSELECT (SELECT coalesce(sonuc,'(bos)') FROM _t72b_res ORDER BY ctid DESC LIMIT 1), '${marker}';\n`);
    });
  }
  // Salt satır sorgusu (fixture/inv): işaretçiden önceki çıktıyı döndürür.
  execRows(sql, tag = 'R') {
    const marker = `<<${tag}:${Math.random().toString(36).slice(2, 10)}>>`;
    return new Promise((resolve, reject) => {
      const w = { marker, resolve, reject, timer: setTimeout(() => reject(new Error(`psql zaman aşımı (${this.tag}/${tag})`)), 60000) };
      this.waiters.push(w);
      const q = sql.trimEnd().endsWith(';') ? sql : sql + ';';
      this.proc.stdin.write(`${q}\nSELECT '(rows)', '${marker}';\n`);
    });
  }
  kill() { try { this.proc?.kill(); } catch { /* sessiz */ } }
}

// Aksiyon sarmalı: hatayı yakalayıp _t72b_res'e "OK|<dönüş>" ya da "ERR|<sqlstate>|<mesaj>" yazar.
const guard = (innerSql) => `
DO $gx$
DECLARE _msg text; _st text; _ok boolean := FALSE; _out text := '';
BEGIN
  BEGIN
    ${innerSql}
    _ok := TRUE;
  EXCEPTION WHEN OTHERS THEN
    _st := SQLSTATE; _msg := SQLERRM;
  END;
  INSERT INTO _t72b_res(sonuc) VALUES (
    CASE WHEN _ok THEN 'OK|'||COALESCE(_out,'') ELSE 'ERR|'||COALESCE(_st,'')||'|'||COALESCE(_msg,'') END);
END
$gx$;`;

async function outcome(sess, sql, tag) {
  const { line } = await sess.exec(guard(sql), tag);
  if (line.startsWith('OK|')) return { cls: 'OK', msg: line.slice(3) };
  if (line.startsWith('ERR|')) {
    const [, st, ...rest] = line.split('|');
    return { cls: 'ERR', st: st || '?', msg: rest.join('|') };
  }
  return { cls: 'ERR', st: 'NO_OUTPUT', msg: line.slice(0, 120) };
}

// ── İzinli sonlu kümeler (kaynak: plan P2b sözleşmesi + mevcut gövdeler) ────
const ALLOWED = [
  ['sarmal', /^(TOH_SONUCLU|TAKIP_ACIK|TAKIP_KAPALI|TAKIP_UZADI|GIRIS_CIFT_ANLAMLI|MUAYENE_GOREV_TIPI_UYUMSUZ|SECIM_TANIMSIZ|OZELLIK_KAPALI|OVSYNC_SECIM_KISIR|OVSYNC_SECIM_ERKEN|TAKIP_YENIDEN_SECILEMEZ|TAKIP_HAYVAN_YOK|BOS_DUZELTME_KOSUL|PG_KAPI|PG_ZAMAN_GECERSIZ)/],
  ['kaydet', /^(VWP_VIOLATION|ABORT_VWP_VIOLATION):/],
  ['start',  /^(OZELLIK_KAPALI|GOREV_BULUNAMADI|GOREV_TIPI_UYUMSUZ|OVSYNC_ERKEN|OVSYNC_SABLON_BELIRSIZ|OVSYNC_HASTALIK_BELIRSIZ|OVSYNC_VAKA_ACILAMADI|OVSYNC_SABLON_UYGULANAMADI|OVSYNC_TAI_OLUSMADI|TAKIP_ACIK)/], // [20260926000002:49-166] + P3b
  ['seans',  /^(PG_KAPI|PG_KAPI_IC_HATA|PG_ZAMAN_GECERSIZ|TAKIP_ACIK)/],
  ['bulk',   /^TAKIP_ONAY_KUME_UYUMSUZ/], // satır hataları jsonb içinde; RAISE yalnız onay-küme uyumsuzluğu
  ['trigger', /^$/], // tohumlama INSERT: iş hatası beklenmez (hata=oracle ihlali)
];
const isAllowed = (family, st, msg) =>
  (ALLOWED.find(([f]) => f === family) ?? [null, /^$/])[1].test(`${st} ${msg}`);

// ── Pair tanımları (fixture getter'larıyla parametrik) ──────────────────────
function pairDefs(fx) {
  return {
    1: {
      ad: 'Ç1 sarmal × tohumlama_kaydet', setup: () => fx.setupBekliyor(),
      a: { family: 'sarmal', sql: `SELECT public.tohumlama_bos_ve_devam(p_tohumlama_id=>'${fx.toh}', p_secim=>'TAKIP', p_gun=>7) INTO _out;` },
      b: { family: 'kaydet', sql: `SELECT public.tohumlama_kaydet('${fx.hayvan}', CURRENT_DATE, 'E2E-T72B-SPERMA') INTO _out;` },
    },
    2: {
      ad: 'Ç2 sarmal × start_first_service_protocol', setup: () => fx.setupBaslatGorev(),
      a: { family: 'sarmal', sql: `SELECT public.tohumlama_bos_ve_devam(p_tohumlama_id=>'${fx.toh}', p_secim=>'OVSYNC', p_onay=>TRUE) INTO _out;` },
      b: { family: 'start', sql: `SELECT public.start_first_service_protocol('${fx.gorev}'::uuid, p_takip_onay=>TRUE) INTO _out;` },
    },
    3: {
      ad: 'Ç3 sarmal × seans_tamamla', setup: () => fx.setupBekliyor(),
      bloke: 'seans fixture sözleşmesi açık: koşum için --seans-uygulama-id <mevcut uygulama satırı uuid> gerekir (rereview5 ÖNEMLİ notları — fail-closed).',
      a: SEANS_UYGULAMA_ID ? { family: 'sarmal', sql: `SELECT public.tohumlama_bos_ve_devam(p_tohumlama_id=>'${fx.toh}', p_secim=>'TAKIP', p_gun=>7) INTO _out;` } : null,
      b: SEANS_UYGULAMA_ID ? { family: 'seans', sql: `SELECT public.seans_tamamla('${SEANS_UYGULAMA_ID}'::uuid, FALSE, 'E2E-T72B', FALSE, NULL, TRUE) INTO _out;` } : null,
    },
    4: {
      ad: 'Ç4 sarmal × vaka_toplu_ac', setup: () => fx.setupBulk(),
      a: { family: 'sarmal', sql: `SELECT public.tohumlama_bos_ve_devam(p_tohumlama_id=>'${fx.toh}', p_secim=>'OVSYNC', p_onay=>TRUE) INTO _out;` },
      b: { family: 'bulk', sql: `SELECT public.vaka_toplu_ac(ARRAY['${fx.hayvan}','${fx.hayvan2}']::text[], '${fx.disease}'::uuid, NULL, NULL, 'E2E-T72B bulk', CURRENT_DATE, FALSE, NULL, NULL, NULL) INTO _out;` },
    },
    5: {
      ad: 'Ç5 kapanış tetikleyicisi (tohumlama INSERT) × sarmal', setup: () => fx.setupAcikTakip(),
      a: { family: 'trigger', sql: `INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler) VALUES (gen_random_uuid(), '${fx.hayvan}', CURRENT_DATE, 'Bekliyor', 1, '[]'::jsonb);` },
      b: { family: 'sarmal', sql: `SELECT public.tohumlama_bos_ve_devam(p_tohumlama_id=>'${fx.toh}', p_secim=>'OVSYNC', p_onay=>TRUE) INTO _out;` },
    },
  };
}

// ── Ana akış ────────────────────────────────────────────────────────────────
async function main() {
  console.log('=== T-72b çapraz deadlock provası (§10h H7 sonuç oracle) ===');
  if (!DB_URL) {
    console.error('BLOKE: T72B_DB_URL tanımsız — iki gerçek bağlantı kurulamaz (UNMEASURED).');
    process.exit(2);
  }
  if (!DB_URL.includes(DEMO_REF) && process.env.T72B_ALLOW_ANY_HOST !== '1') {
    console.error(`BLOKE: hedef demo değil (ref ${DEMO_REF} yok) — fail-closed. (T72B_ALLOW_ANY_HOST=1: sahip kapısı)`);
    process.exit(2);
  }

  const ctl = new Psql('ctl');
  await ctl.start();

  const inv = {};
  for (const [ad, sql] of Object.entries({
    sarmal: "SELECT count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='tohumlama_bos_ve_devam'",
    takip_kolon: "SELECT count(*)::text FROM information_schema.columns WHERE table_schema='public' AND table_name='gorev_log' AND column_name='takip_kapanis_nedeni'",
    tetik: "SELECT count(*)::text FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal AND t.tgname ILIKE '%takip%'",
    disease: "SELECT count(*)::text FROM diseases WHERE name IN ('Ovsync','Ovsync Protokol')",
  })) {
    const out = await ctl.execRows(sql, 'inv');
    inv[ad] = out.prefix.split('\n').filter(Boolean)[0]?.trim() ?? '?';
  }
  console.log(`Envanter: sarmal=${inv.sarmal} takip_kolon=${inv.takip_kolon} tetik=${inv.tetik} disease=${inv.disease}`);
  for (const [k, v] of Object.entries(inv)) {
    if (!/^\d+$/.test(v)) { ctl.kill(); console.error(`BLOKE: envanter ölçümü sayısal değil (${k}='${v}') — fail-closed.`); process.exit(2); }
  }
  const sarmalYok = inv.sarmal === '0';
  const kolonYok = inv.takip_kolon === '0';

  const fx = fixture(ctl);
  const rapor = [];
  const bilinmeyenKayit = [];

  for (const no of PAIRS_REQ) {
    const def = pairDefs(fx)[no];
    if (!def) { ctl.kill(); console.error(`BILINMEYEN çift: ${no}`); process.exit(2); }

    if (def.bloke && (!def.a || !def.b)) {
      rapor.push({ cift: no, ad: def.ad, sonuc: 'BLOKE', neden: def.bloke, histogram: {} });
      continue;
    }
    if (sarmalYok || (no === 5 && inv.tetik === '0') || (no === 4 && inv.disease === '0')) {
      rapor.push({
        cift: no, ad: def.ad, sonuc: 'RED(beklenen)',
        neden: `yeni yol yok: sarmal=${inv.sarmal} takip_kolon=${inv.takip_kolon} tetik=${inv.tetik} disease=${inv.disease} — P2b/P3a/P3b bekleniyor; N=${ROUNDS} tur koşulmadı (fail-closed)`,
        histogram: {},
      });
      continue;
    }
    if (kolonYok) { // takip kolonu yoksa sarmal çağrısı zaten anlamsız
      rapor.push({ cift: no, ad: def.ad, sonuc: 'RED(beklenen)', neden: 'takip_kapanis_nedeni kolonu yok (P2a)', histogram: {} });
      continue;
    }

    const A = new Psql(`A${no}`), B = new Psql(`B${no}`);
    await A.start(); await B.start();
    const histogram = new Map();
    let lockSayac = 0, timeoutSayac = 0, bilinmeyen = 0, izinli = 0, basari = 0;
    try {
      for (let i = 0; i < ROUNDS; i++) {
        await def.setup();
        // barrier: iki aksiyon arka arkaya yazılır; psql'ler eşzamanlı işler
        const [ra, rb] = await Promise.all([outcome(A, def.a.sql, `P${no}A`), outcome(B, def.b.sql, `P${no}B`)]);
        for (const [r, meta] of [[ra, def.a], [rb, def.b]]) {
          const key = r.cls === 'OK' ? `${meta.family}:OK` : `${meta.family}: ${r.st} ${r.msg.slice(0, 50)}`;
          histogram.set(key, (histogram.get(key) || 0) + 1);
          if (r.cls === 'OK') { basari++; continue; }
          if (r.st === '40P01' || r.st === '55P03') { lockSayac++; continue; }
          if (r.st === '57014') { timeoutSayac++; continue; }
          if (isAllowed(meta.family, r.st, r.msg)) { izinli++; continue; }
          bilinmeyen++;
          bilinmeyenKayit.push({ cift: no, fam: meta.family, st: r.st, msg: r.msg.slice(0, 200) });
        }
        await fx.teardown();
      }
    } finally {
      A.kill(); B.kill();
      await fx.teardown();
    }

    let sonuc, neden;
    if (lockSayac || timeoutSayac || bilinmeyen) {
      sonuc = 'FAIL';
      neden = `oracle ihlali: lock(40P01/55P03)=${lockSayac} timeout=${timeoutSayac} bilinmeyen=${bilinmeyen}`;
    } else {
      sonuc = 'PASS';
      neden = `her sonuç izinli kümede: başarı=${basari} izinli_iş_hatası=${izinli}, lock=0, timeout=0`;
    }
    rapor.push({ cift: no, ad: def.ad, sonuc, neden, histogram: Object.fromEntries(histogram) });
  }

  console.log(`\n=== TUR RAPORU (${ROUNDS} tur/çift) ===`);
  for (const r of rapor) {
    console.log(`Ç${r.cift} ${r.ad}`);
    console.log(`  SONUÇ: ${r.sonuc} — ${r.neden}`);
    for (const [k, v] of Object.entries(r.histogram || {})) console.log(`    ${v}× ${k}`);
  }
  if (bilinmeyenKayit.length) {
    console.log('\nBILINMEYEN kodlar (izinli kümeye girmedi — open-contract, FAIL katkısı):');
    for (const b of bilinmeyenKayit) console.log(`  Ç${b.cift} [${b.fam}] ${b.st} ${b.msg}`);
  }
  const fail = rapor.some(r => r.sonuc === 'FAIL');
  const bloke = rapor.some(r => r.sonuc === 'BLOKE');
  const red = rapor.some(r => r.sonuc === 'RED(beklenen)');
  const verdict = fail ? 'FAIL' : bloke ? 'BLOKE' : red ? 'RED(beklenen)' : 'PASS';
  console.log(`\nSONUÇ: ${verdict}${red && !fail && !bloke ? ' — yeni yol P2b/P3a/P3b bekleniyor (H7: önkırmızı şartı yok; bu RED PASS sayılmaz)' : ''}`);
  await fx.teardown();
  ctl.kill();
  process.exit(fail ? 1 : (bloke || red) ? 2 : 0);
}

// ── Fixture kurucular (ctl bağlantısı; E2E-T72B- marker'lı; tip gerçekleri: hayvanlar.id text,
//    tohumlama.id uuid + hayvan_id text, gorev_log.id uuid + hayvan_id text — demo ölçüm 2026-09-29)
function fixture(ctl) {
  const yeniHayvan = () => `E2E-T72B-H-${Math.random().toString(36).slice(2, 8)}`;
  let H = yeniHayvan(), H2 = yeniHayvan(), TOH = null, GOREV = null, DISEASE = null;

  const temizle = async () => {
    const TRYSQL = (inner) => `DO $cl$ BEGIN ${inner} EXCEPTION WHEN OTHERS THEN NULL; END $cl$;`;
    for (const sql of [
      `DELETE FROM gorev_log WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-T72B-%');`,
      `DELETE FROM tohumlama WHERE hayvan_id IN (SELECT id FROM hayvanlar WHERE kupe_no LIKE 'E2E-T72B-%');`,
      TRYSQL(`DELETE FROM treatment_day_uygulamalar WHERE treatment_day_id IN (SELECT td.id FROM treatment_days td JOIN cases c ON c.id::text = td.case_id::text WHERE c.hayvan_id LIKE 'E2E-T72B-%');`),
      TRYSQL(`DELETE FROM treatment_days WHERE case_id IN (SELECT id FROM cases WHERE hayvan_id LIKE 'E2E-T72B-%');`),
      TRYSQL(`DELETE FROM cases WHERE hayvan_id LIKE 'E2E-T72B-%';`),
      TRYSQL(`DELETE FROM protokol_instance WHERE kaynak_ref IN (SELECT 'TOH-'||id FROM tohumlama WHERE hayvan_id LIKE 'E2E-T72B-%');`),
      `DELETE FROM hayvanlar WHERE kupe_no LIKE 'E2E-T72B-%';`,
    ]) { try { await ctl.execRows(sql, 'cln'); } catch { /* TRY temizlik: sırada devam */ } }
  };

  return {
    get hayvan() { return H; },
    get hayvan2() { return H2; },
    get toh() { return TOH; },
    get gorev() { return GOREV; },
    get disease() { return DISEASE; },
    async setupBekliyor() {
      await temizle();
      H = yeniHayvan();
      TOH = (await ctl.execRows(
        `WITH h AS (INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup) VALUES ('${H}','${H}','Dişi', CURRENT_DATE-400, 'Sağmal (Laktasyonda)') RETURNING id),
              t AS (INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler) SELECT gen_random_uuid(), id, CURRENT_DATE, 'Bekliyor', 1, '[]'::jsonb FROM h RETURNING id)
         SELECT id::text FROM t;`, 'fx1')).prefix.trim();
    },
    async setupBaslatGorev() {
      await this.setupBekliyor();
      GOREV = (await ctl.execRows(
        `INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
         VALUES (gen_random_uuid(), '${H}', 'OVSYNC_BASLAT', 'E2E-T72B baslat', CURRENT_DATE, false, false, 'ILK-TOH-E2E') RETURNING id::text;`, 'fx2')).prefix.trim();
    },
    async setupBulk() {
      await temizle();
      H = yeniHayvan(); H2 = yeniHayvan();
      await ctl.execRows(
        `INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
         VALUES ('${H}','${H}','Dişi', CURRENT_DATE-400, 'Sağmal (Laktasyonda)'),
                ('${H2}','${H2}','Dişi', CURRENT_DATE-400, 'Sağmal (Laktasyonda)');`, 'fx3');
      await ctl.execRows(
        `INSERT INTO tohumlama(id, hayvan_id, tarih, sonuc, deneme_sayisi, denemeler)
         VALUES (gen_random_uuid(),'${H}', CURRENT_DATE, 'Bekliyor', 1, '[]'::jsonb);`, 'fx3b');
      TOH = (await ctl.execRows(`SELECT id::text FROM tohumlama WHERE hayvan_id='${H}' LIMIT 1;`, 'fx3c')).prefix.trim();
      await ctl.execRows(
        `INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
         VALUES (gen_random_uuid(), '${H}', 'TAKIP_MUAYENE', 'E2E-T72B takip', CURRENT_DATE+7, false, false, 'TAKIP:E2E');`, 'fx3d');
      DISEASE = (await ctl.execRows(`SELECT id::text FROM diseases WHERE name IN ('Ovsync','Ovsync Protokol') LIMIT 1;`, 'fx3e')).prefix.trim();
    },
    async setupAcikTakip() {
      await this.setupBekliyor();
      await ctl.execRows(
        `INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
         VALUES (gen_random_uuid(), '${H}', 'TAKIP_MUAYENE', 'E2E-T72B takip', CURRENT_DATE+7, false, false, 'TAKIP:E2E');`, 'fx4');
    },
    async teardown() { await temizle(); },
  };
}

main().catch(e => { console.error('HATA:', e?.message ?? e); process.exit(2); });
