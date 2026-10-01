// ss-parallel-review — egesut-erp1 icin paralel kod incelemesi (ram-pool).
// Saf JS (TypeScript annotasyon YOK). Date.now / Math.random YASAK —
// script deterministik olmali; kosu kimligi (epoch) disaridan args.ramEpoch
// ile tasinir (§12.2 resume sozlesmesi).
// Paralellik sabit DEGIL: her fan-out fazi ram-pool grant'indan genislik
// alir — ramPlan → lanes → ramClose (§12.1-12.2).

export const meta = {
  name: 'ss-parallel-review',
  description:
    'egesut-erp1 icin cok-boyutlu paralel kod incelemesi: once bul (6 inceleme boyutu; paralellik ram-pool planindan gelir), sonra her taze bulguyu skepsis ajaniyla celistir, yalniz ayakta kalanlari raporla.',
  phases: ['Find', 'Verify']
};

// >>> ram-pool v1 sha=d8561f81b97c
// ram-pool v1 — kanonik blok başlangıcı. Aşağıdakiler workflow kapsamına
// tanımlanır: RAM_EXEC_NOTE, ramEpochGuard, ramPlan, parsePlan, lanes,
// ramClose (+ özel crc yardımcıları fnv1a32/canonicalJson).

const RAM_EXEC_NOTE = (
  'Agir komut (test/build) dogrudan Bash ile KOSULMAZ: ' +
  "`ram-ultracode exec --class test|build --sh '<ifade>'` sarmalayicisiyla kos - " +
  'slot ram-pool havuzundan gelir, pipefail aciktir (`false | true` → 1), cikis kodu ' +
  'ana komutundur, scope bosalmadan slot birakilmaz. Ifadeyi TEK TIRNAKLA sar; ' +
  'ifade icinde tek tirnak KULLANMA; komutu arka plana (&) atma - sarmalayici ' +
  'torunlar bitene dek bekler.'
)

// --- crc (§4.3; Python crc.py ile birebir — vektörler crc_vectors.json) ---
function canonicalJson(o) {
  if (o === null || typeof o !== 'object') return JSON.stringify(o)
  if (Array.isArray(o)) return '[' + o.map(canonicalJson).join(',') + ']'
  const keys = Object.keys(o).sort()
  return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonicalJson(o[k])).join(',') + '}'
}
function fnv1a32(str) {
  let h = 2166136261
  for (let i = 0; i < str.length; i++) {
    const c = str.charCodeAt(i)
    if (c < 0x20 || c > 0x7e) throw new Error('FAIL-CLOSED: ram crc yalniz ASCII ister')
    h ^= c
    h = Math.imul(h, 16777619) >>> 0
  }
  return h >>> 0
}

// --- seq: script içi monoton sayaç — her plan/replan/close çağrısında +1,
//     aynı koşuda cache anahtarları çakışmaz (§12.1).
let ramSeq = 0
function ramSeqNext() { return ++ramSeq }

function _ramAssert(cond, msg) { if (!cond) throw new Error(msg) }
function _isInt(v) { return typeof v === 'number' && Number.isInteger(v) && v >= 0 }
function _sekilOk(s) {
  return !!s && typeof s === 'object' && !Array.isArray(s) &&
    Object.values(s).every((n) => _isInt(n))
}
function _log(ctx, msg) {
  if (ctx && typeof ctx.log === 'function') ctx.log(msg)
  else if (typeof log === 'function') log(msg)  // workflow kapsamı (typeof: tanımsıza güvenli)
}
function _rawOf(out) {
  return (out && typeof out === 'object' && typeof out.raw === 'string') ? out.raw : out
}

// --- epoch zorunluluğu (§12.1, Codex R2-07): her koşu/resume yeni epoch ister.
function ramEpochGuard(args) {
  if (!args || !args.ramEpoch) {
    return { stopped: 'ram-epoch-missing', reason: 'her kosu/resume yeni args.ramEpoch ister' }
  }
  return null
}

// --- yanıt çözümleyici (§4.3): JSON.parse + kanonik stringify + FNV-1a crc.
function _parseResp(raw) {
  let resp
  try { resp = JSON.parse(String(raw)) } catch { throw new Error('FAIL-CLOSED: ram-plan yaniti json degil') }
  _ramAssert(resp && typeof resp === 'object' && !Array.isArray(resp),
    'FAIL-CLOSED: ram-plan yaniti nesne degil')
  const got = resp.crc
  _ramAssert(typeof got === 'number' && Number.isInteger(got),
    'FAIL-CLOSED: ram-plan crc alani yok')
  const body = { ...resp }
  delete body.crc
  const hesap = fnv1a32(canonicalJson(body))
  _ramAssert(hesap === got, 'FAIL-CLOSED: ram-plan crc uyusmazligi')
  return body
}

// parsePlan(raw): plan yanıtı → {grant:true,…} | {denied:true,reason} | throw.
function parsePlan(raw) {
  const body = _parseResp(raw)
  if (body.ok === false) {
    const err = body.err || {}
    return { denied: true, reason: (err.code || 'hata') + ': ' + (err.msg || 'bilinmeyen hata') }
  }
  _ramAssert(body.ok === true, 'FAIL-CLOSED: ram-plan yanitinda ok yok')
  _ramAssert(typeof body.grant_id === 'string' && body.grant_id.length > 0,
    'FAIL-CLOSED: ram-plan grant_id bozuk')
  _ramAssert(_sekilOk(body.shape), 'FAIL-CLOSED: ram-plan shape alani bozuk')
  _ramAssert(_sekilOk(body.target), 'FAIL-CLOSED: ram-plan target alani bozuk')
  return { grant: true, grant_id: body.grant_id, target: { ...body.target },
           shape: { ...body.shape }, granted_mb: body.granted_mb }
}

// --- ramPlan(run, asked, opts) — §12.1.
//     opts: {agent, epoch, supersedes?, maxConc?, log?}
//     · epoch yok → hiç ajan çağırmadan stopped (ramEpochGuard).
//     · tüm sınıflar 0 → {skipped:true} (plan ajanı doğmaz — boş faz).
//     · plan ajanı null → {denied:true} (remainder'a düşer, E12 g).
//     · args.maxConc sayı ise force_shape ile plan (override).
async function ramPlan(run, asked, opts = {}) {
  const stopped = ramEpochGuard({ ramEpoch: opts.epoch })
  if (stopped) return stopped
  const asked0 = {}
  for (const k of Object.keys(asked || {})) if (asked[k] > 0) asked0[k] = asked[k]
  if (Object.keys(asked0).length === 0) return { skipped: true }
  const agent = opts.agent
  _ramAssert(typeof agent === 'function', 'FAIL-CLOSED: ram-plan icin opts.agent gerekli')
  const force = Number.isInteger(opts.maxConc) && opts.maxConc > 0
  const agents = force ? opts.maxConc : (asked0.agent || 0)
  let cmd = 'ram-ultracode plan --run ' + run + ' --epoch ' + opts.epoch +
    ' --agents ' + agents + ' --test ' + (asked0.test || 0)
  if ((asked0.build || 0) > 0) cmd += ' --build ' + asked0.build
  if (opts.supersedes) cmd += ' --supersedes ' + opts.supersedes
  if (force) cmd += ' --force-shape'
  cmd += ' --json'
  const seq = ramSeqNext()
  const out = await agent(
    "Su komutu kos, stdout'u DEGISTIRMEDEN `raw` alanina koy: `" + cmd + '`',
    { effort: 'low', label: 'ram-plan:' + run + ':' + seq })
  if (out === null || out === undefined) {
    return { denied: true, reason: 'ram-plan ajani dogmadi/yanit yok' }
  }
  const parsed = parsePlan(_rawOf(out))
  if (parsed.denied) return parsed
  parsed._ctx = { agent, epoch: opts.epoch, run, asked: { ...asked0 }, log: opts.log }
  return parsed
}

// --- grant doğrulaması (Codex R2-08): lanes/ramClose yalnız gerçek grant.
function _grantOk(g) {
  return !!(g && g.grant === true && typeof g.grant_id === 'string' && g.grant_id &&
            g._ctx && typeof g._ctx.agent === 'function' && g._ctx.epoch)
}

// --- lanes(items, grant, fn, run) — §12.1 elastik havuz.
//     width = grant.shape.agent; her lane kuyruktan çeker. Faz ortası replan
//     YALNIZ işini yeni bitirmiş lane'de, her K = max(4, width) toplam
//     tamamlanmada bir kez, sonraki öğeyi ALMADAN önce (replan ajanı o lane'in
//     boşalttığı slotla doğar — §4.7 kontrol ayrıcalığı gerekmez; R11
//     release-bekleme adımı sahibin kararı BEKLİYOR: eklenmedi).
//     Büyüme → yeni lane; küçülme → laneIndex ≥ width olan lane eldeki işi
//     bitirip çıkar; null → mevcut şekil + log; not_found → yeni ramPlan.
//     F6 null politikası: fn null dönerse öğe failed'a kimliğiyle yazılır;
//     remainder = failed ∪ işlenmeyenler (sessiz eleme yok).
async function lanes(items, grant, fn, run) {
  _ramAssert(_grantOk(grant), 'FAIL-CLOSED: gecersiz grant')
  const ctx = grant._ctx
  items = Array.isArray(items) ? items : []
  const idOf = (item) => ((item && typeof item === 'object' && 'id' in item)
    ? item.id : JSON.stringify(item))
  const results = []
  const failed = []
  const islenen = new Set()
  const kuyruk = items.map((item, index) => ({ item, index }))
  let aktifGrant = grant
  let width = _isInt(grant.shape && grant.shape.agent) ? grant.shape.agent : 0
  let completed = 0
  const K = Math.max(4, width)
  let calisanLane = 0
  let dur = false            // kuyruk durdurma (not_found sonrası yeni plan da gelmezse)
  const tumPromptlar = []

  function yeniLaneAc() {
    for (let i = calisanLane; i < width; i++) {
      calisanLane++
      tumPromptlar.push(laneRunner(i))
    }
  }

  async function midReplan() {
    const asked0 = ctx.asked
    let cmd = 'ram-ultracode replan --grant ' + aktifGrant.grant_id +
      ' --agents ' + (asked0.agent || 0) + ' --test ' + (asked0.test || 0)
    if ((asked0.build || 0) > 0) cmd += ' --build ' + asked0.build
    cmd += ' --json'
    const seq = ramSeqNext()
    const out = await ctx.agent(
      "Su komutu kos, stdout'u DEGISTIRMEDEN `raw` alanina koy: `" + cmd + '`',
      { effort: 'low', label: 'ram-replan:' + run + ':' + seq })
    if (out === null || out === undefined) {
      _log(ctx, 'ram-pool: replan ajani dogmadi/yanit yok — mevcut sekil korunur')
      return
    }
    let body
    try { body = _parseResp(_rawOf(out)) } catch (e) {
      _log(ctx, 'ram-pool: replan yaniti bozuk (' + e.message + ') — mevcut sekil korunur')
      return
    }
    if (body.ok === false) {
      const err = body.err || {}
      if (err.code === 'not_found') {
        _log(ctx, 'ram-pool: replan not_found — yeni ramPlan (' + ctx.run + ')')
        const yeni = await ramPlan(ctx.run, ctx.asked,
          { agent: ctx.agent, epoch: ctx.epoch, log: ctx.log })
        if (yeni && yeni.grant === true) {
          aktifGrant = yeni
          width = _isInt(yeni.shape && yeni.shape.agent) ? yeni.shape.agent : width
          yeniLaneAc()
        } else {
          _log(ctx, 'ram-pool: yeni plan da gelmedi — kuyruk durur, kalanlar remainder')
          dur = true
        }
        return
      }
      _log(ctx, 'ram-pool: replan ' + (err.code || 'hata') + ': ' + (err.msg || '') +
        ' — mevcut sekil korunur')
      return
    }
    if (_sekilOk(body.shape)) {
      width = _isInt(body.shape.agent) ? body.shape.agent : width
      yeniLaneAc()           // büyümede yeni lane; küçülmede loop-başı kontrolü çıkarır
    }
  }

  async function laneRunner(laneIndex) {
    for (;;) {
      if (dur) return
      if (laneIndex >= width) return            // küçülen şekil: eldeki işi bitirip çık
      const next = kuyruk.shift()
      if (!next) return
      const res = await fn(next.item, next.index)
      completed++
      islenen.add(next.index)
      if (res === null || res === undefined) failed.push({ index: next.index, id: idOf(next.item) })
      else results.push(res)
      if (!dur && completed % K === 0 && kuyruk.length > 0) {
        await midReplan()                        // sonraki öğeyi ALMADAN önce (§12.1)
      }
    }
  }

  yeniLaneAc()
  // Büyüme sırasında midReplan yeni lane'leri SONRADAN ekler: küre kararlaşana
  // dek bekle (Promise.all tek çekirdek küreyle erken dönerdi).
  for (;;) {
    const beklenen = [...tumPromptlar]
    await Promise.all(beklenen)
    if (tumPromptlar.length === beklenen.length) break
  }
  const remainder = failed.map((f) => f.id)
    .concat(items.filter((it, i) => !islenen.has(i)).map(idOf))
  return { results, failed, remainder }
}

// --- ramClose(grant) — faz sonu (finally). Close temizliktir: hata fırlatmaz.
async function ramClose(grant) {
  _ramAssert(_grantOk(grant), 'FAIL-CLOSED: gecersiz grant')
  const ctx = grant._ctx
  const seq = ramSeqNext()
  const cmd = 'ram-ultracode close --grant ' + grant.grant_id + ' --json'
  const out = await ctx.agent(
    "Su komutu kos, stdout'u DEGISTIRMEDEN `raw` alanina koy: `" + cmd + '`',
    { effort: 'low', label: 'ram-close:' + ctx.run + ':' + seq })
  if (out === null || out === undefined) {
    return { closed: false, reason: 'ram-close ajani dogmadi/yanit yok' }
  }
  try {
    const body = _parseResp(_rawOf(out))
    if (body.ok === false) {
      const err = body.err || {}
      return { closed: false, reason: 'ram-close reddedildi: ' + (err.msg || err.code || '') }
    }
    return { closed: true }
  } catch (e) {
    return { closed: false, reason: e.message }
  }
}
// <<< ram-pool

const RUN = 'ss-parallel-review';

// Bu repoya OZEL inceleme boyutlari (Find fazi nufusu: 6 boyut).
const FIND_DIMENSIONS = [
  {
    id: 'silent-success',
    focus:
      'Hata yutmayan aktilar: catch blogu bos ya da sadece console.log; Supabase RPC hata/ null dondugunde sessizce devam eden yollar. Ozellikle js/api.js ve js/degisiklikler/ kuyruk islemede ara.'
  },
  {
    id: 'dry-run-guard',
    focus:
      'Toplu onarim / yazici RPC cagrilarinin p_dry_run korumasinin arkasinda kaldigini dogrula; kacak dogrudan UPDATE/DELETE/INSERT iceren migration veya fonksiyon tespit et. supabase/migrations/ + DB fonksiyonlari.'
  },
  {
    id: 'ui-monolith-regression',
    focus:
      'js/ui.js (10.6k satir) ve js/forms.js uzerinde yapisal riskler: global durum mutasyonu, ID cakismasi, geri-alma (js/gecmis.js) entegrasyonunun kirildigi degisiklik noktalari.'
  },
  {
    id: 'schema-drift',
    focus:
      'Migration ↔ live DB drift: scripts/ground-truth-audit.sh ciktilarina ve 99999999999999_ground_truth.sql ile kiyaslanan sema farklarina bak; eski migration duzenleme (append-only ihlali) ara.'
  },
  {
    id: 'offline-queue-ordering',
    focus:
      'offline-kuyruk senkron dogrulugu: istemci tarafinda siralama/idempotens kurallari; cakisan kuyruk ogeleri ve kayip yazma senaryolari. dogruluk-kritik, kirilgan bolge.'
  },
  {
    id: 'breeding-vaccination-logic',
    focus:
      'DB fonksiyonlarindaki asilama/tohumlama karar mantigi (ovsync zinciri: ovsync_pg_uygulama_kapisi, ovsync_vaka_kapanis, ilk_tohumulama_zinciri): sinir kosullari, cift sayim, yanlis hayvan durumu gecisleri.'
  }
];

// Her Find ciktisi bu semaya uymak zorunda.
const FIND_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['dimension', 'file', 'line', 'claim', 'evidence', 'severity'],
        properties: {
          dimension: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'integer' },
          claim: { type: 'string' },
          evidence: { type: 'string' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] }
        }
      }
    }
  }
};

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['verdict', 'reason'],
  properties: {
    verdict: { type: 'string', enum: ['confirmed', 'dropped'] },
    reason: { type: 'string' },
    corrected_claim: { type: 'string' }
  }
};

// Kalinti hesabi (§12.1 F6 null politikasi): lanes'in failed listesi +
// (results dizisi items ile hizaliysa) bos kalan slotlar. Kayip sessizce
// elenmez; remainder olarak rapor tasiyiciya gider.
function remainderOf(items, out) {
  const rem = Array.isArray(out && out.failed) ? out.failed.slice() : [];
  const known = new Set(
    rem.map((f) => (f && typeof f.index === 'number' ? f.index : null))
  );
  const results = out && out.results;
  if (Array.isArray(results) && results.length === items.length) {
    items.forEach((it, i) => {
      if (results[i] == null && !known.has(i)) {
        rem.push({ index: i, id: it && it.id });
      }
    });
  }
  return rem;
}

const input = args || {};
// §12.1 override: args.maxConc sayi ise force_shape ile o genislik istenir.
const maxConcOverride = typeof input.maxConc === 'number';
function askedFor(count) {
  return { agent: maxConcOverride ? input.maxConc : count };
}
function planOpts(extra) {
  const opts = extra || {};
  if (maxConcOverride) opts.force_shape = true;
  return opts;
}

const { diff, target } = input;

// ---- Find: boyutlari ram-pool genisliginde tara (ramPlan → lanes → ramClose) ----
const findPlan = await ramPlan(
  RUN,
  askedFor(FIND_DIMENSIONS.length),
  planOpts()
);
if (findPlan.stopped) {
  // ram-epoch-missing (§12.1): hicbir ajan acilmadan dur.
  return findPlan;
}
if (findPlan.denied) {
  return {
    stopped: 'ram-pool-denied',
    reason: findPlan.reason,
    remainder: FIND_DIMENSIONS.map((d, i) => ({ index: i, id: d.id, phase: 'Find' }))
  };
}

const findOne = (dim) =>
  agent(
    'Bu repoda (' + target + ') asagidaki boyutta kod incelemesi yap. ' +
    'Sadece KANITLA desteklenen bulgular uret; dosya+satir olmadan bulgu yazma. ' +
    'Boyut: ' + dim.id + '\nOdak: ' + dim.focus + '\n' +
    'Ek baglam: ' + (input.hedef || '') + '\n' +
    (diff ? 'Incelenecek degisiklik:\n' + diff : ''),
    { schema: FIND_SCHEMA, label: 'find:' + dim.id, phase: 'Find' }
  );

let findOut = { results: [], failed: [] };
if (findPlan.grant) {
  try {
    findOut = await lanes(FIND_DIMENSIONS, findPlan, findOne, RUN);
  } finally {
    await ramClose(findPlan);
  }
}
// findPlan.skipped → bos faz (§12.1): plan ajani bile acilmadan gecildi.

const fresh = (findOut.results || []).flatMap((r) => (r && r.findings ? r.findings : []));

// ---- Verify: her taze bulgu bir skepsis ajaniyla celisir ----
const verifyOne = async (f) => {
  const v = await agent(
    'SKEPSIS AJANI: Asagidaki bulgunun KANITINI kaynak kodda bizzat ac ve curut. ' +
    'Kanit dosya+satirda gercekten var mi? iddia gercek davranisla celisiyor mu? ' +
    'Zayif ya da yanlissa verdict=dropped ve nedenini yaz; saglamsa confirmed.\n' +
    'Bulgu: ' + JSON.stringify(f),
    { schema: VERIFY_SCHEMA, label: 'verify:' + f.dimension, phase: 'Verify' });
  if (!v || v.verdict !== 'confirmed') {
    return { dropped: true, finding: f, reason: v ? v.reason : 'verify-agent-bos-dondu' };
  }
  return {
    dropped: false,
    finding: Object.assign({}, f, {
      claim: v.corrected_claim || f.claim,
      evidence_tag: 'KANIT:skepsis-verified'
    })
  };
};

// Verify fazi nufusu: taze bulgular (deterministik kimlik; lanes failed
// listesi {index,id} tasiyacak sekilde).
const verifyItems = fresh.map((f, i) =>
  Object.assign({}, f, { id: (f.dimension || 'finding') + '-' + i })
);

let verifyOut = { results: [], failed: [] };
if (verifyItems.length > 0) {
  // Sonraki fazin plani onceki grant'i supersede eder (§12.1).
  const verifyPlan = await ramPlan(
    RUN,
    askedFor(verifyItems.length),
    planOpts(findPlan.grant ? { supersedes: findPlan.grant_id } : {})
  );
  if (verifyPlan.stopped) {
    return verifyPlan;
  }
  if (verifyPlan.denied) {
    return {
      stopped: 'ram-pool-denied',
      reason: verifyPlan.reason,
      remainder: verifyItems
        .map((f, i) => ({ index: i, id: f.id, phase: 'Verify' }))
        .concat(remainderOf(FIND_DIMENSIONS, findOut))
    };
  }
  if (verifyPlan.grant) {
    try {
      verifyOut = await lanes(verifyItems, verifyPlan, verifyOne, RUN);
    } finally {
      await ramClose(verifyPlan);
    }
  }
  // verifyPlan.skipped → bos faz (§12.1).
}

const verdicts = verifyOut.results || [];
const confirmed = verdicts
  .filter((v) => v && !v.dropped)
  .map((v) => v.finding);
const dropped = verdicts
  .filter((v) => v && v.dropped)
  .map((v) => ({ claim: v.finding.claim, file: v.finding.file, reason: v.reason }));

const remainder = remainderOf(FIND_DIMENSIONS, findOut).concat(
  remainderOf(verifyItems, verifyOut)
);

return { confirmed, dropped, remainder };
