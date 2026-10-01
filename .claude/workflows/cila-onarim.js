// cila-onarim — Ovsync cila dalı onarım turu (ram-pool).
// Saf JS (TypeScript annotasyon YOK). Date.now / Math.random YASAK; kosu
// kimligi (epoch) disaridan args.ramEpoch ile tasinir (§12.2 resume sozlesmesi).
// Paralellik sabit DEGIL: her fan-out fazi ram-pool grant'indan genislik alir
// — ramPlan → lanes → ramClose (§12.1-12.2).

export const meta = {
  name: 'cila-onarim',
  description: 'Ovsync cila dalı onarım turu — F1 plan, F2 uygulama, F3 review, F4 onarım (GOREV zarfı sabiti)',
  phases: [
    { title: 'F1-Plan', detail: 'P-DB / P-UI / R-ARAŞTIRMA plan dosyaları' },
    { title: 'F1-G1', detail: 'plan dosyaları + K1..K12 referans kapısı' },
    { title: 'F2-Uygulama', detail: 'I-DB sirali // I-UI(K9,K7) // K10; sonra K8' },
    { title: 'F2-Kapilar', detail: 'G2 govde 0-fark + db-validate; G3 unit yeni-fail 0; tek onarim turu' },
    { title: 'F3-Review', detail: '4 bagimsiz lens (code-reviewer)' },
    { title: 'F3-Verify', detail: 'bulgu basina supheci dogrulama (genislik ram-pool grantindan)' },
    { title: 'F4-Onarim', detail: 'dogrulanmis bulgular -> sahip kulvar tek tur' },
    { title: 'F4-Dogrulama', detail: 'G2+G3 yeniden kosum (ikinci review YOK)' },
  ],
}

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

const A = args || {}
const WT = A.wt, ENV = A.env, CRUMBS = A.crumbs, PLANS = A.plans, BASE = A.base

const PSQL = "bash -c 'set -a; source /home/melik/egesut-erp1/.env; set +a; PGPASSWORD=\"$SUPABASE_DEMO_DB_PASSWORD\" psql \"postgresql://postgres.${SUPABASE_DEMO_REF}:${SUPABASE_DEMO_DB_PASSWORD}@${SUPABASE_DEMO_POOLER}:6543/postgres\" -X ...'"

const RULES = [
  'ORTAK KURALLAR (ihlal = teslim reddi; otorite zarfın Kendi kuralları bölümü):',
  '- ÖNCE OKU: ' + ENV + ' (K1..K12 kabul ölçütleri + tüm kurallar + DONE biçimi). Zarfı okumadan iş başlama.',
  '- Çalışma ağacı: ' + WT + ' — tüm repo yazmaları bunun altında. /home/melik/egesut-erp1 ana checkout repoya YALNIZ .crumbs/ .ss/ mutlak yolları için dokunulur.',
  '- PROD YASAK: tools-bank supabase_* ve supabase_migrate MCP araçları PROD bağlantısıdır — ASLA kullanma. DB erişimi yalnız demo psql: ' + PSQL,
  '- psql yazmadan önce ref doğrula: demo ref = ' + A.demoRef + ' (prod = ' + A.prodRef + ' YASAK; echo $SUPABASE_DEMO_REF ile bak).',
  '- Playwright KOŞMA; demo sahip şifresine dokunma; push YOK; main merge YOK.',
  '- Git: yalnız açık dosya yollarıyla add (git add -A / git add . YASAK; izlenmeyen runs/ süpürülmez, commit edilmez). Commit mesajı sonu: Co-Authored-By: Claude Code <noreply@anthropic.com>. index.lock hatasında 5 sn bekle, en çok 3 dene. Anlamlı her adım sonrası commit.',
  '- Kırıntı: her karar/ölçüm/kapıda ' + CRUMBS + ' dosyasına TEK SATIR JSON ekle: {"ts":"ISO","role":"<ROL-ETİKETİN>","session":"-","workspace":"cila-onarim","type":"decision|measurement|gate|open_item|assumption","text":"...","evidence":"..."}.',
  '- JS/SQL sembol değişikliğinden ÖNCE gitnexus impact: mcp__gitnexus__impact, repo="' + WT + '" (iki egesut repo var, ad aynı — MUTLAKA yol ver). Commit öncesi mcp__gitnexus__detect_changes (repo=yol).',
  '- Unit: cd ' + WT + ' && NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit — baz 1112/1109, 3 bilinen fail (bc-tarih ×2, LUNA-3); yeni fail 0 şart.',
  '- Skill: gerektiğinde Skill aracıyla yükle; araç yoksa ilkeyi uygula ve kırıntıya not düş.',
].join('\n')

// ---------- Şemalar ----------
const PLAN_S = { type: 'object', properties: {
  ok: { type: 'boolean' }, plan_files: { type: 'array', items: { type: 'string' } },
  k_covered: { type: 'array', items: { type: 'string' } }, k8_needs_rpc: { type: 'boolean' },
  notes: { type: 'string' } }, required: ['ok', 'plan_files', 'k_covered', 'notes'] }
const RAR_S = { type: 'object', properties: {
  ok: { type: 'boolean' }, plan_files: { type: 'array', items: { type: 'string' } },
  k_covered: { type: 'array', items: { type: 'string' } }, k10_blocker: { type: 'string' },
  k12_fix_narrow: { type: 'boolean' }, notes: { type: 'string' } },
  required: ['ok', 'plan_files', 'k_covered', 'k12_fix_narrow', 'notes'] }
const G1_S = { type: 'object', properties: {
  pass: { type: 'boolean' }, missing_files: { type: 'array', items: { type: 'string' } },
  missing_k: { type: 'array', items: { type: 'string' } }, evidence: { type: 'string' } },
  required: ['pass', 'missing_files', 'missing_k', 'evidence'] }
const IDB_S = { type: 'object', properties: {
  ok: { type: 'boolean' },
  migrations: { type: 'array', items: { type: 'object', properties: {
    file: { type: 'string' }, db_validate: { type: 'string' }, demo_applied: { type: 'boolean' },
    statements_ok: { type: 'boolean' }, commit: { type: 'string' } },
    required: ['file', 'db_validate', 'demo_applied', 'statements_ok'] } },
  k8_rpc_created: { type: 'string' }, k12_fix_applied: { type: 'boolean' },
  k2_script: { type: 'string' }, reapply_000007: { type: 'boolean' }, notes: { type: 'string' } },
  required: ['ok', 'migrations', 'k2_script', 'reapply_000007', 'notes'] }
const IMPL_S = { type: 'object', properties: {
  ok: { type: 'boolean' },
  items: { type: 'array', items: { type: 'object', properties: {
    k: { type: 'string' }, status: { type: 'string' }, test: { type: 'string' }, commit: { type: 'string' } },
    required: ['k', 'status'] } }, notes: { type: 'string' } }, required: ['ok', 'items', 'notes'] }
const K10_S = { type: 'object', properties: {
  ok: { type: 'boolean' }, deferred_count: { type: 'number' }, remaining_overdue: { type: 'number' },
  blocker: { type: 'string' }, evidence: { type: 'string' } }, required: ['ok', 'deferred_count', 'remaining_overdue', 'evidence'] }
const G2_S = { type: 'object', properties: {
  pass: { type: 'boolean' }, diffs: { type: 'number' },
  validations: { type: 'array', items: { type: 'object', properties: {
    file: { type: 'string' }, pass: { type: 'boolean' } }, required: ['file', 'pass'] } },
  statements_ok: { type: 'boolean' }, details: { type: 'string' } },
  required: ['pass', 'diffs', 'validations', 'statements_ok', 'details'] }
const G3_S = { type: 'object', properties: {
  pass: { type: 'boolean' }, total: { type: 'number' }, passed: { type: 'number' },
  failed: { type: 'number' }, new_failures: { type: 'array', items: { type: 'string' } },
  raw_tail: { type: 'string' } }, required: ['pass', 'total', 'passed', 'failed', 'new_failures'] }
const REPAIR_S = { type: 'object', properties: {
  ok: { type: 'boolean' }, fixed: { type: 'array', items: { type: 'string' } },
  commits: { type: 'array', items: { type: 'string' } }, notes: { type: 'string' } },
  required: ['ok', 'fixed', 'notes'] }
const FINDINGS_S = { type: 'object', properties: {
  findings: { type: 'array', items: { type: 'object', properties: {
    k_item: { type: 'string' }, lane: { type: 'string' }, file: { type: 'string' },
    line: { type: 'number' }, severity: { type: 'string' }, claim: { type: 'string' },
    evidence: { type: 'string' }, proposed_fix: { type: 'string' } },
    required: ['k_item', 'lane', 'file', 'severity', 'claim', 'evidence'] } } }, required: ['findings'] }
const VERDICT_S = { type: 'object', properties: {
  verdict: { type: 'string', enum: ['CONFIRMED', 'DROPPED'] }, evidence: { type: 'string' } },
  required: ['verdict', 'evidence'] }

// ---------- ram-pool: faz koşucusu (§12.1) ----------
const RUN = 'cila-onarim'
// §12.1 override: args.maxc sayı ise force_shape ile o genişlik istenir.
const maxConcOverride = typeof A.maxc === 'number'
function askedFor(count) {
  return { agent: maxConcOverride ? A.maxc : count }
}
function planOpts(extra) {
  const opts = extra || {}
  if (maxConcOverride) opts.force_shape = true
  return opts
}
// Sonraki fazın planı önceki grant'ı supersede eder (§12.1).
let prevGrantId = null
// F6 null politikası: işlenemeyen öğeler sessizce elenmez; faz bazında
// toplanıp dönüş değerinde remainder olarak taşınır.
const ramRemainder = []
function kalintiEkle(faz, ids) {
  for (const id of ids) ramRemainder.push({ phase: faz, id: id })
}
const byId = (out, id) => {
  const r = ((out && out.results) || []).find((x) => x && x.id === id)
  return r ? r.out : null
}
// fanOut — bir fan-out fazının tam koşucusu:
// ramPlan(run, asked, opts) → lanes(items, grant, fn, run) → finally ramClose(grant).
// stopped (ram-epoch-missing) ve denied fail-closed döner; skipped boş fazdır.
async function fanOut(faz, items, fn) {
  const plan = await ramPlan(RUN, askedFor(items.length), planOpts(prevGrantId ? { supersedes: prevGrantId } : {}))
  if (plan.stopped) return { stop: plan }
  if (plan.denied) {
    kalintiEkle(faz, items.map((it) => it && it.id))
    return { deny: { stopped: 'ram-pool-denied', phase: faz, reason: plan.reason, remainder: ramRemainder.slice() } }
  }
  let out = { results: [], failed: [] }
  if (plan.grant) {
    prevGrantId = plan.grant_id
    try {
      out = await lanes(items, plan, fn, RUN)
    } finally {
      await ramClose(plan)
    }
  }
  // plan.skipped → boş faz (§12.1): plan ajanı bile açılmadan geçildi.
  kalintiEkle(faz, (out && out.remainder) || [])
  return { out: out }
}

// ---------- F1: Planlama ----------
phase('F1-Plan')
log('F1: üç kulvar ajanı paralel planlıyor (P-DB, P-UI, R-ARAŞTIRMA)')
const F1_KULVARLAR = [
  { id: 'P-DB', schema: PLAN_S, prompt: RULES + '\n\nSen P-DB\'sin (F1 planlama kulvarı — DB). ROL ETİKETİ "P-DB".\nYAZABİLECEĞİN: ' + WT + '/' + PLANS + '/plan-db.md (+ kırıntı). Başka repo dosyasına yazma.\nSkill\'ler: writing-plans, code-change-precheck, db-validation — planlama sırasında uygula.\nGÖREV: plan-db.md yaz — kapsam: K1, K3, K4, K5, K6, K12 dar-fix değerlendirmesi, K2 doğrulama betiğinin tasarımı, K8\'in olası RPC gereksinimi (sözleşme taslağı: ad/imza/dönen kolonlar).\nPlan şartları (zarf F1):\n- Mermaid diyagram; her adım bir K-numarasına bağlı; adım başına KABUL ÖLÇÜTÜ (komut/sorgu ile ölçülebilir).\n- I-DB uygulama sırası: 000007 demo re-apply (K2 öncülü) → K1 → K5 → K6 → K3 → K4 → [K8-RPC] → [K12-fix] → K2 betiği. Yeni dosyalar supabase/migrations/20260925000009_*.sql ve sonrası; 000001..000008 DÜZENLENMEZ.\n- KRİTİK (000008 tuzağı): yeniden tanımlanan her fonksiyonun CANLI DEMO gövdesini psql pg_get_functiondef ile ÇEK, dosya gövdesiyle diff\'i plana koy; önceki TÜM migration değişiklikleri korunur (000008\'in protocol_family guard\'ı canlıda VAR — korunacak).\n- Denetim notları: K5 öznesi protokol_ayar_guncelle(text,numeric) + gorev_tamamla(text,text,boolean) (ureme_temizlik_reconcile K6\'nın öznesidir, canlıda zaten tırnaksız search_path\'li). K5 migration yorumunda 000004:25-26\'daki yanlış "aynı semantik" iddiasının düzeltildiği belirtilir. K3 kontrol hayvanı "açık OVSYNC_BASLAT\'sız + uygunluk-yeterli" seçilir. K4: ölçülen 12/12 aktif Ovsync vakası protocol_family NULL — backfill betiği demo\'ya özel, migration DEĞİL.\nÖlçümlerini kırıntıya yaz (measurement). ÇIKTI şemaya: ok / plan_files / k_covered / k8_needs_rpc / notes.' },
  { id: 'P-UI', schema: PLAN_S, prompt: RULES + '\n\nSen P-UI\'sin (F1 planlama kulvarı — UI). ROL "P-UI".\nYAZABİLECEĞİN: ' + WT + '/' + PLANS + '/plan-ui.md (+ kırıntı).\nSkill\'ler: writing-plans, code-change-precheck.\nGÖREV: plan-ui.md yaz — kapsam K7, K8, K9 (uygulama sırası K9 → K7 → K8; K8\'i ayrı ajan koşar).\nPlan şartları: Mermaid; adım başına K-numarası + ölçülebilir kabul ölçütü; TDD adımları (red eden test önce).\n- K9 (ui.js flushPendingDone ~601-616, kanıtlı: await penceresinde eklenenler clear() ile siliniyor, kilit yok): tek-uçuş kilidi + dönüş sırasında eklenenleri silmeme + kalıcı hatada tekrar toast bastırmama. Unit: eşzamanlı iki çağrı tek gönderim; uçuşta eklenen kalem korunur.\n- K7 (BUG-UREME-SEKMESI-FILTRE; kök kanıtlı: ui.js:56 TEDAVI_SEANS tedavi kategorisinde; ui.js:696-705 tarih süzmesi kategoriden önce; index.html:692 varsayılan Bugün): Üreme kategorisi, hastalık kategorisi Üreme olan vakanın TEDAVI_SEANS/TEDAVI_GUN görevlerini kapsar + ileri tarihli planlı üreme görevleri için ASI_PLANLI 7-gün penceresi benzeri istisna. Unit: fixture Üreme+Bugün en az bir ovsync seansı + yaklaşan OVSYNC_BASLAT gösterir; Tedavi sekmesi çift saymaz.\n- K8 (BUG-PROTOKOL-OVSYNC-AYRIK): başlamış ovsync zincirinin gecikmiş/yaklaşan seansları panele + _rozetTopla\'ya; bildirimKontrol parent_id\'li seansları ve gecikmeyi kapsar; hedef_saat okunur. Veri kaynağı K4 protocol_family — yeni RPC gerekiyorsa sözleşmeyi yaz, k8_needs_rpc=true dön.\n- ?v= damgası TEK DEĞER kuralı; damga-izleyen testler güncellenir; index.html damga bump plana girer.\nÇIKTI: ok / plan_files / k_covered / k8_needs_rpc / notes.' },
  { id: 'R-ARAŞTIRMA', schema: RAR_S, prompt: RULES + '\n\nSen R-ARAŞTIRMA\'sın (F1 — salt-okunur kulvar). ROL "R-ARAŞTIRMA".\nYAZABİLECEĞİN: ' + WT + '/' + PLANS + '/plan-erteleme-genel.md, k12-sablon-belirsiz.md, k10-envanter.md (+ kırıntı). KOD YAZMA YASAK; demo\'da yalnız SELECT (UPDATE YASAK).\nSkill: writing-plans.\n1) plan-erteleme-genel.md (K11 — SADECE PLAN, implementasyon YOK): tohumlama/aşı/tedavi + UI için genel erteleme; spec + mermaid; sahip onayına sunulacak riskler/alternatifler. Kaynaklar: /home/melik/Masaüstü/EGESUT-ERP1 NOTLARI/yurutme-haritasi-ss-research-2026-09-23.md (2c maddesi) + worktree BUGS.md içindeki BUG-ERTELEME-KURAL-GENEL kaydı.\n2) k12-sablon-belirsiz.md (K12): demo\'da aktif ovsync şablon sayısını ölç, hatanın üretildiği guard\'ı kodda izle, kök neden + dar-fix önerisi; dar ve güvenliyse k12_fix_narrow=true (I-DB uygular), değilse yalnız rapor.\n3) k10-envanter.md (K10): demo\'da hedef tarihi geçmiş açık ovsync görevlerinin envanteri (sayı+tip+örnek id\'ler), mevcut erteleme mekanizması neyi destekliyor (RPC/fonksiyon envanteri), tip kilidi engeli var mı — exec ajanına NET talimat: hangi sorgu/RPC ile ertelenir, engel varsa nasıl raporlanır.\nÇIKTI: ok / plan_files / k_covered / k10_blocker / k12_fix_narrow / notes.' },
]
const f1One = async (it) => ({ id: it.id, out: await agent(it.prompt, { label: it.id, phase: 'F1-Plan', schema: it.schema }) })
const f1 = await fanOut('F1-Plan', F1_KULVARLAR, f1One)
if (f1.stop) return f1.stop
if (f1.deny) return f1.deny
const pdb = byId(f1.out, 'P-DB'), pui = byId(f1.out, 'P-UI'), rar = byId(f1.out, 'R-ARAŞTIRMA')

// ---------- F1-G1: deterministik plan kapısı ----------
phase('F1-G1')
const g1Prompt = RULES + '\n\nSen G1 kapı ajanısın (deterministik dosya kontrolü). ROL "G1". Repo yazması YOK (kırıntı serbest).\nBash ile ' + WT + ' içinde:\n1) Bu dosyalar var mı: ' + PLANS + '/plan-db.md, plan-ui.md, plan-erteleme-genel.md, k12-sablon-belirsiz.md (test -f).\n2) K=1..12 için: grep -rE "K' + "' + '" + 'K([^0-9]|$)" yerine K-sayısını yerleştir: grep -rlE "\\"K1([^0-9]|$)|K1\\"' + '" gibi değil — DOĞRUSU: her K için grep -rlE "K<N>([^0-9]|$)" ' + PLANS + '/ — boş çıktı = eksik.\n3) plans dizinin dosya listesini de evidence\'a yaz.\nÇIKTI: pass / missing_files / missing_k / evidence.'
let g1 = await agent(g1Prompt, { label: 'G1-kapi', phase: 'F1-G1', schema: G1_S, effort: 'low' })
let g1_retried = false
if (!g1 || !g1.pass) {
  g1_retried = true
  const miss = ((g1 && g1.missing_k) || []).join(',')
  const missFiles = (g1 && g1.missing_files) || []
  const laneRetry = (laneName, prompt, label) => ({ id: label, prompt: prompt })
  const retries = []
  const dbBad = missFiles.some(f => f.includes('plan-db')) || /(^|,)K[13456](,|$)/.test(',' + miss + ',')
  const uiBad = missFiles.some(f => f.includes('plan-ui')) || /(^|,)K[789](,|$)/.test(',' + miss + ',')
  const rarBad = missFiles.some(f => f.includes('erteleme') || f.includes('k12')) || /(^|,)K1[012](,|$)/.test(',' + miss + ',')
  if (dbBad) retries.push(laneRetry('P-DB', RULES + '\n\nP-DB TEKRAR TURU (G1 düştü: ' + miss + ' / ' + missFiles.join(';') + '). plan-db.md\'yi eksikleri kapatacak şekilde TAMAMLA — zarf F1 şartlarına ve önceki prompttaki kapsama göre. Yalnız plan-db.md yaz. ÇIKTI şemaya.', 'P-DB-retry'))
  if (uiBad) retries.push(laneRetry('P-UI', RULES + '\n\nP-UI TEKRAR TURU (G1 düştü: ' + miss + ' / ' + missFiles.join(';') + '). plan-ui.md\'yi eksikleri kapatacak şekilde TAMAMLA. Yalnız plan-ui.md yaz. ÇIKTI şemaya.', 'P-UI-retry'))
  if (rarBad) retries.push(laneRetry('R-ARAŞTIRMA', RULES + '\n\nR-ARAŞTIRMA TEKRAR TURU (G1 düştü: ' + miss + ' / ' + missFiles.join(';') + '). Eksik dosyayı/kapsamı tamamla (salt-okunur). ÇIKTI şemaya.', 'RAR-retry'))
  if (retries.length) {
    const retryOne = async (it) => ({ id: it.id, out: await agent(it.prompt, { label: it.id, phase: 'F1-G1', schema: PLAN_S }) })
    const gr = await fanOut('F1-G1', retries, retryOne)
    if (gr.stop) return gr.stop
    if (gr.deny) return gr.deny
  }
  g1 = await agent(g1Prompt + ' (ikinci koşum)', { label: 'G1-kapi-2', phase: 'F1-G1', schema: G1_S, effort: 'low' })
}
log('G1: ' + (g1 && g1.pass ? 'PASS' : 'FAIL (devam ediliyor — kayıt DONE\'a)'))

// ---------- F2: Uygulama ----------
phase('F2-Uygulama')
const k8rpc = (pdb && pdb.k8_needs_rpc) || (pui && pui.k8_needs_rpc) ? true : false
const k12fixHint = rar && rar.k12_fix_narrow ? true : false
log('F2 aşama 1: I-DB (sıralı DB kulvarı) // I-UI (K9,K7) // K10-exec — paralel')
const F2_KULVARLAR = [
  { id: 'I-DB', schema: IDB_S, prompt: RULES + '\n\nSen I-DB\'sin (F2 uygulama — DB kulvarı, TEK YAZICI, kulvar içi SIRALI). ROL "I-DB".\nYAZABİLECEĞİN: supabase/migrations/20260925000009_*.sql ve sonrası; scripts/ altında gövde-doğrulama betiği + demo backfill betiği (+ kırıntı). js/ dosyalarına YAZMA.\nSkill\'ler: executing-plans, db-validation, test-driven-development (kabul probe\'unu migration\'dan ÖNCE koş).\nÖNCE OKU: ' + ENV + ' ve ' + WT + '/' + PLANS + '/plan-db.md (planı harfi harfine uygula; eksik görürsen zarf kurallarıyla doldur, kırıntıya decision yaz).\nSIRA (zarf F2 — değişmez):\n0) K2-öncül: 000007\'yi demo\'ya yeniden uygula (plan-db talimatı; schema_migrations statements DOLU kayıt).\n1) K1 — 000009: sessiz_hayvanlar_reconcile canlı gövdesinden başla; eşik 55→50 ÜRET ve KAPAT bacaklarında; 000008 protokol-guard\'ı KORUNUR; başlık yorumu düzeltilir.\n2) K5 — protokol_ayar_guncelle(text,numeric) tırnaksız search_path + ALTER FUNCTION gorev_tamamla(text,text,boolean) SET search_path = public, pg_temp (gövde değişmez); migration yorumunda 000004:25-26 yanlış iddiasının düzeltme notu.\n3) K6 — 000005 GRANT düzeltmesi: REVOKE EXECUTE ON ureme_temizlik_reconcile FROM authenticated (ve PUBLIC/anon kontrolü), EXECUTE yalnız service_role.\n4) K3 — kısır+Aktif+Dişi guard\'ı zincirin EN ALT ORTAK HALKASINDA tek nokta (_ovsync_baslat_gorev_kur) + ilk_tohumlama_zamanlayici dry-run baslatilacaklar kısır filtresi.\n5) K4 — start_first_service_protocol yolunda cases.protocol_family doldurma (migration) + mevcut aktif Ovsync vakaları için demo backfill betiği (tek-seferlik script, migration DEĞİL).\n6) K8-RPC: ' + (k8rpc ? 'GEREKLİ — plan-db\'deki RPC sözleşmesine göre migration (I-UI-K8 kullanacak; adını k8_rpc_created alanına DÖN).' : 'gerekmiyor (planlar öyle diyor).') + '\n7) K12-fix: R-ARAŞTIRMA k12_fix_narrow=' + k12fixHint + ' — plan-db K12 bölümüyle çelişiyorsa GÜVENLİ OLANI seç (uygulama ya da yalnız rapor), gerekçeyi kırıntıya yaz.\n8) K2 — scripts/ altında gövde-doğrulama betiği: 000001..son dosyaların HER fonksiyonunun canlı demo gövdesiyle karşılaştırması (kümülatif son-yazan semantiği; plan-db tasarımı). Koş, fark sayısını kırıntıya yaz.\nHER MİGRATION İÇİN (zarf kuralı): taslak → bash scripts/db-validate.sh <taslak> PASS → demo apply (ÖNCE ref doğrula) → schema_migrations statements DOLU → canlı gövde dosyayla aynı → commit. db-validate taslakta VE final dosyada koşulur.\nKabul probe\'ları (demo, BEGIN…ROLLBACK ile ölç, kanıtı kırıntıya yaz): K1: gövdede >= 50 ×2, >= 55 ×0, protocol_family guard VAR. K3: kısır hayvana doğum/abort → açık OVSYNC_BASLAT 0; plan-db\'deki uygun kontrol hayvanında 1. K4: aktif Ovsync protocol_family NULL = 0; AKTIF_SENKRONIZASYON probe\'u ikinci başlatmayı reddeder. K5: iki fonksiyonda proconfig search_path=public, pg_temp. K6: has_function_privilege(\'authenticated\',…)=f.\nÇIKTI: ok / migrations[...] / k8_rpc_created / k12_fix_applied / k2_script (repo-göreli yol) / reapply_000007 / notes.' },
  { id: 'I-UI-K9K7', schema: IMPL_S, prompt: RULES + '\n\nSen I-UI\'sin (F2 — UI kulvarı ilk ajanı; K9→K7). ROL "I-UI".\nYAZABİLECEĞİN: js/ui.js, index.html (?v= damgası), ilgili unit test dosyaları (+ kırıntı). K8 ŞİMDİLİK YOK (sonraki ajanın).\nSkill\'ler: executing-plans, test-driven-development, code-change-precheck (flushPendingDone ve görev-listesi üretim fonksiyonları için mcp__gitnexus__impact, repo=' + WT + ').\nÖNCE OKU: ' + ENV + ' ve ' + WT + '/' + PLANS + '/plan-ui.md.\nSIRA: K9 (flushPendingDone yarışı) → K7 (Üreme sekmesi filtresi). Her kalemde: ÖNCE red eden unit test → implement → test geçer → unit koşumu (yeni fail 0) → commit. ?v= damga bump TEK SEFER (K7 sonunda); damga-izleyen testleri güncelle.\nK9 kabul: eşzamanlı iki çağrı tek gönderim; uçuşta eklenen kalem korunur; kalıcı hatada tekrar toast yok.\nK7 kabul: fixture Üreme+Bugün en az bir ovsync seansı + yaklaşan OVSYNC_BASLAT gösterir; Tedavi sekmesi çift saymaz.\nÇIKTI: ok / items[{k,status,test,commit}] / notes.' },
  { id: 'K10-exec', schema: K10_S, prompt: RULES + '\n\nSen K10-exec\'sin. ROL "K10-exec".\nYAZABİLECEĞİN: ' + WT + '/' + PLANS + '/k10-sonuc.md (+ kırıntı). Demo VERİ değişikliği (UPDATE/RPC) serbest — şema/migration YASAK, JS YASAK.\nÖNCE OKU: ' + WT + '/' + PLANS + '/k10-envanter.md' + (rar && rar.k10_blocker ? ' (R-ARAŞTIRMA engel notu: ' + rar.k10_blocker + ')' : '') + '.\nGÖREV (talimat 2b): demo\'daki hedef tarihi geçmiş açık ovsync görevleri/seanslarını YARINA ertele — envanterdeki mevcut erteleme mekanizmasıyla. Tip kilidi engelliyorsa erteleme zorunlu DEĞİL: k10-sonuc.md\'ye engel gerekçesini kanıtıyla yaz, kırıntıya type:"assumption" ekle.\nKABUL: demo\'da hedef tarihi geçmiş açık ovsync görevi 0 (sorgu çıktısı kanıt) YA DA engel gerekçeli rapor. k10-sonuc.md\'yi commit et.\nÇIKTI: ok / deferred_count / remaining_overdue / blocker / evidence.' },
]
const f2One = async (it) => ({ id: it.id, out: await agent(it.prompt, { label: it.id, phase: 'F2-Uygulama', schema: it.schema }) })
const f2 = await fanOut('F2-Uygulama', F2_KULVARLAR, f2One)
if (f2.stop) return f2.stop
if (f2.deny) return f2.deny
const idb = byId(f2.out, 'I-DB'), iui = byId(f2.out, 'I-UI-K9K7'), k10 = byId(f2.out, 'K10-exec')

log('F2 aşama 2: I-UI-K8 (I-DB tamamlandı)')
const idbRpcNote = idb && idb.k8_rpc_created
  ? 'I-DB şu RPC\'yi oluşturdu: ' + idb.k8_rpc_created + ' — sözleşmesini kullan.'
  : 'I-DB yeni RPC oluşturmadı — plan-ui\'deki mevcut veri kaynağıyla (protocol_family / mevcut RPC) ilerle.'
const ik8 = await agent(RULES + '\n\nSen I-UI-K8\'sin (UI kulvarı devamı; K8). ROL "I-UI-K8".\nYAZABİLECEĞİN: js/ui.js, index.html (damga TEK DEĞER — I-UI bump ettiyse AYNI değeri koru), ilgili testler (+ kırıntı).\nÖNCE OKU: ' + ENV + ' ve ' + WT + '/' + PLANS + '/plan-ui.md (K8 bölümü). ' + idbRpcNote + '\nGÖREV (BUG-PROTOKOL-OVSYNC-AYRIK): başlamış ovsync zincirinin gecikmiş/yaklaşan seansları protokol paneline + _rozetTopla\'ya; bildirimKontrol parent_id\'li seansları ve gecikmeyi kapsar; hedef_saat okunur.\nTDD: red eden test önce. Unit kabul: fixture\'da gecikmiş ovsync seansları panel kaynağında görünür. Demo kanıt: RPC çıktısında gecikmiş seanslar görünür — ölçtüğün SAYIYI kaydet (8\'e sabit değil, anlık veri; kırıntıya measurement).\nUnit: yeni fail 0. Anlamlı adım sonrası commit.\nÇIKTI: ok / items / notes (ölçülen demo sayısı dahil).', { label: 'I-UI-K8', phase: 'F2-Uygulama', schema: IMPL_S })

// ---------- F2: Kapılar G2/G3 + tek onarım turu ----------
phase('F2-Kapilar')
const k2script = idb && idb.k2_script ? idb.k2_script : ''
const g2Prompt = (n) => RULES + '\n\nSen G2 kapı ajanısın (koşum ' + n + '). ROL "G2". Repo yazması YOK (kırıntı serbest).\nKOŞ (bash, ' + WT + ' içinde):\n1) K2 gövde-doğrulama betiği: ' + (k2script ? k2script : 'yolu plan-db.md\'den bul') + ' → çıktıdaki FARK SAYISI 0 olmalı.\n2) Yeni migration\'ların her birinde bash scripts/db-validate.sh <dosya> → PASS. Dosya listesi: git diff --name-only ' + BASE + '..HEAD -- supabase/migrations/ ile çıkar.\n3) Demo psql: yeni uygulanan sürümlerde statements DOLU mu (SELECT version, statements IS NULL OR statements = \'\' AS bos FROM schema_migrations ORDER BY version DESC LIMIT 8).\nÇIKTI: pass / diffs / validations / statements_ok / details (komut+çıktı özeti).'
const g3Prompt = (n) => RULES + '\n\nSen G3 kapı ajanısın (koşum ' + n + '). ROL "G3". Repo yazması YOK.\nKOŞ: cd ' + WT + ' && NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit (timeout 600s+).\nDeğerlendir: baz 1112 test / 1109 geç / 3 bilinen fail (bc-tarih ×2, LUNA-3 — AD ile eşleş). Yeni fail = geçmeyenlerden bilinenlerle eşleşmeyenler. Test sayısı artabilir (K7/K8/K9 testleri) — ölçüt YENİ FAIL = 0.\nÇIKTI: pass / total / passed / failed / new_failures[] / raw_tail.'
const repairPrompt = (laneLabel, ownership, gateName, gateJson) => RULES + '\n\nSen ' + laneLabel + ' onarım ajanısın — TEK TUR. ROL "' + laneLabel + '".\nDosya sahipliği: ' + ownership + ' (+ kırıntı).\nKAPI DÜŞTÜ (' + gateName + ') — kanıt:\n' + JSON.stringify(gateJson, null, 1) + '\nplan-db.md/plan-ui.md + zarf kurallarıyla onar; her düzeltmenin kabulünü ÖLÇ (db-validate / demo sorgusu / unit); commit at. Kapı yeniden koşumu senin dışında yapılacak.\nÇIKTI: ok / fixed[] / commits[] / notes.'
const DB_OWN = 'supabase/migrations/20260925000009_*.sql ve sonrası, scripts/ altındaki betikler'
const UI_OWN = 'js/ui.js, index.html, ilgili unit test dosyaları'

async function gateLoop(gatePromptFn, gateLabel, laneLabel, ownership, schema) {
  let g = await agent(gatePromptFn(1), { label: gateLabel, phase: 'F2-Kapilar', schema: schema })
  if (g && g.pass) return { gate: g, repaired: false, repair: null, first: null }
  const rep = await agent(repairPrompt(laneLabel, ownership, gateLabel, g), { label: gateLabel + '-onarim', phase: 'F2-Kapilar', schema: REPAIR_S })
  const g2 = await agent(gatePromptFn(2), { label: gateLabel + '-2', phase: 'F2-Kapilar', schema: schema })
  return { gate: g2, repaired: true, repair: rep, first: g }
}
log('F2 kapılar: G2 (DB) ve G3 (unit) — onarım turları kulvar ayrık paralel')
const KAPI_KULVARLAR = [
  { id: 'G2-kapi', gatePromptFn: g2Prompt, gateLabel: 'G2-kapi', laneLabel: 'G2-onarim-DB', ownership: DB_OWN, schema: G2_S },
  { id: 'G3-kapi', gatePromptFn: g3Prompt, gateLabel: 'G3-kapi', laneLabel: 'G3-onarim-UI', ownership: UI_OWN, schema: G3_S },
]
const kapiOne = async (it) => ({ id: it.id, out: await gateLoop(it.gatePromptFn, it.gateLabel, it.laneLabel, it.ownership, it.schema) })
const kp = await fanOut('F2-Kapilar', KAPI_KULVARLAR, kapiOne)
if (kp.stop) return kp.stop
if (kp.deny) return kp.deny
const r2 = byId(kp.out, 'G2-kapi'), r3 = byId(kp.out, 'G3-kapi')
let partial = false
if (!r2 || !r2.gate || !r2.gate.pass) partial = true
if (!r3 || !r3.gate || !r3.gate.pass) partial = true
log('G2: ' + (r2 && r2.gate && r2.gate.pass ? 'PASS' : 'FAIL') + (r2 && r2.repaired ? ' (onarım turu sonrası)' : '') + ' · G3: ' + (r3 && r3.gate && r3.gate.pass ? 'PASS' : 'FAIL') + (r3 && r3.repaired ? ' (onarım turu sonrası)' : ''))

// ---------- F3: Bağımsız review ----------
phase('F3-Review')
const LENSES = [
  { key: 'a-db', focus: 'DB DOĞRULUK + YENİDEN-TANIM KAYBI: her yeni migration canlı gövdeden mi başladı; 000008 protokol-guard\'ı ve önceki TÜM değişiklikler korunmuş mu; K1/K3/K4/K5/K6 zarf ölçütlerini gerçekten sağlıyor mu; BEGIN…COMMIT bütünlüğü; schema_migrations statements; 000007 re-apply doğru mu.' },
  { key: 'b-guvenlik', focus: 'GÜVENLİK: SECURITY DEFINER\'larda tırnaksız SET search_path = public, pg_temp; TO anon / TO PUBLIC GRANT yok; REVOKE … FROM PUBLIC, anon VAR; SQL injection yüzeyi (yeni betiklerde parametre kullanımı); demo betiklerinde prod sızıntısı riski (ref kontrolü).' },
  { key: 'c-ui', focus: 'UI/JS REGRESYON: K7 üreme filtresi kategori/tarih sırası doğru mu, Tedavi sekmesiyle çift sayma var mı; K9 kilidi lost-update/deadlock bırakıyor mu, kalıcı hata toast davranışı; K8 parent_id/hedef_saat mantığı, _rozetTopla; ?v= damga tek değer; testler anlamlı mı (fixture gerçek senaryoyu temsil ediyor mu, assertion zayıf mı).' },
  { key: 'd-zarf', focus: 'ZARF↔TESLİM UYUMU: K1..K12 TEK TEK — kabul ölçütü kanıtlanmış mı (diff + plan + kanıt dosyaları + kırıntılar); kanıtsız TAMAM iddiası BULGUDUR; kapsam dışına taşma var mı (3c düve eşiği, prod dokunuşu, mevcut migration dosyalarının düzenlenmesi, Playwright koşumu).' },
]
const lensItems = LENSES.map((l) => Object.assign({ id: l.key }, l))
const reviewOne = async (l) => ({ id: l.key, out: await agent(
  RULES + '\n\nSen bağımsız review ajanısın — LENS ' + l.key + '. ROL "review-' + l.key + '". Repo yazması YOK (kırıntı serbest). KUSUR AVI — bulgu yoksa findings BOŞ döner; uydurma bulgu ÜRETME.\nGİRDİ: cd ' + WT + ' && git diff ' + BASE + '...HEAD (+ commit\'lenmemiş iş varsa O da bulgu) + ' + ENV + ' (K1..K12 kabul ölçütleri) + ' + WT + '/' + PLANS + '/ altındaki plan/kanıt dosyaları.\nLENS ' + l.focus + '\nHer bulgu: k_item, lane (DB|UI|DOCS), file, line, severity (KRITIK|YUKSEK|ORTA|DUSUK), claim (tek cümle), evidence (dosya:satır / sorgu / komut), proposed_fix.\nÇIKTI: findings[].',
  { label: 'review:' + l.key, phase: 'F3-Review', schema: FINDINGS_S, agentType: 'code-reviewer' }) })
const rv = await fanOut('F3-Review', lensItems, reviewOne)
if (rv.stop) return rv.stop
if (rv.deny) return rv.deny
let findings = []
const rvRes = (rv.out && rv.out.results) || []
rvRes.forEach((r) => { if (r && r.out && r.out.findings) r.out.findings.forEach((f) => findings.push(Object.assign({ lens: r.id }, f))) })
const seen = new Set()
const uniq = []
for (const f of findings) { const key = (f.file || '?') + ':' + (f.line || 0); if (!seen.has(key)) { seen.add(key); uniq.push(f) } }
log('F3: ' + findings.length + ' bulgu → dedup sonrası ' + uniq.length + ' → şüpheci doğrulama')

phase('F3-Verify')
const verified = []
let dropped = 0
const verifyItems = uniq.map((f, i) => ({ id: 'skeptic-' + i, f: f }))
const skepticOne = async (it, idx) => ({ id: it.id, f: it.f, v: await agent(
    RULES + '\n\nSen şüpheci doğrulama ajanısın. ROL "skeptic". Repo yazması YOK; demo\'da yalnız SELECT.\nBULGU:\n' + JSON.stringify(it.f, null, 1) + '\nGÖREVİN BU BULGUYU ÇÜRÜTMEK: iddia kanıtla (kod satırı, demo sorgusu, test çıktısı) uyuşmuyor mu? Belirsiz/kontrol edilemiyorsa DROPPED. Yalnız kanıt birebir tutuyorsa CONFIRMED.\nÇIKTI: verdict + evidence.',
    { label: 'skeptic-' + idx, phase: 'F3-Verify', schema: VERDICT_S }) })
if (verifyItems.length > 0) {
  const vr = await fanOut('F3-Verify', verifyItems, skepticOne)
  if (vr.stop) return vr.stop
  if (vr.deny) return vr.deny
  const vrRes = (vr.out && vr.out.results) || []
  vrRes.forEach((r) => {
    if (r && r.v && r.v.verdict === 'CONFIRMED') verified.push(Object.assign({}, r.f, { skeptic_evidence: r.v.evidence }))
    else dropped++
  })
}
log('Şüpheci: ' + verified.length + ' CONFIRMED, ' + dropped + ' DROPPED')

// ---------- F4: Onarım + kapı yeniden koşumu ----------
phase('F4-Onarim')
const kulvarlar = { DB: [], UI: [], DOCS: [] }
for (const f of verified) {
  let lane = (f.lane || '').toUpperCase()
  if (!kulvarlar[lane]) lane = /supabase|scripts\//.test(f.file || '') ? 'DB' : (/js\/|index\.html|tests?/.test(f.file || '') ? 'UI' : 'DOCS')
  kulvarlar[lane].push(f)
}
const f4Items = Object.keys(kulvarlar).filter((k) => kulvarlar[k].length).map((k) => ({ id: 'F4-' + k, k: k }))
const repairList = []
if (f4Items.length) {
const f4One = async (it) => {
  const k = it.k
  return { id: it.id, out: await agent(
  RULES + '\n\nSen F4 onarım ajanısın — ' + k + ' kulvarı, TEK TUR. ROL "F4-' + k + '".\nDosya sahipliği: ' + (k === 'DB' ? DB_OWN : k === 'UI' ? UI_OWN : PLANS + '/ altındaki dosyalar') + ' (+ kırıntı).\nDOĞRULANMIŞ BULGULAR (şüpheci onaylı — HEPSİNİ işle):\n' + JSON.stringify(kulvarlar[k], null, 1) + '\nZarf kuralları + ilgili plan dosyasıyla düzelt; her düzeltme sonrası kendi kabul ölçütünü ölç; commit. Kapı yeniden koşumu dışarıda — sen düzelt+ölç+commit.\nÇIKTI: ok / fixed[] / commits[] / notes.',
  { label: 'F4-' + k, phase: 'F4-Onarim', schema: REPAIR_S }) }
}
const f4 = await fanOut('F4-Onarim', f4Items, f4One)
if (f4.stop) return f4.stop
if (f4.deny) return f4.deny
const f4Res = (f4.out && f4.out.results) || []
f4Res.forEach((r) => { if (r && r.out) repairList.push(r.out) })
}

phase('F4-Dogrulama')
let fg2 = null, fg3 = null
if (kulvarlar.DB.length) fg2 = await agent(g2Prompt('F4'), { label: 'G2-final', phase: 'F4-Dogrulama', schema: G2_S })
if (kulvarlar.UI.length) fg3 = await agent(g3Prompt('F4'), { label: 'G3-final', phase: 'F4-Dogrulama', schema: G3_S })
if ((fg2 && !fg2.pass) || (fg3 && !fg3.pass)) partial = true

return {
  f1: {
    pdb: pdb && { ok: pdb.ok, files: pdb.plan_files, k: pdb.k_covered, k8_rpc: pdb.k8_needs_rpc },
    pui: pui && { ok: pui.ok, files: pui.plan_files, k: pui.k_covered, k8_rpc: pui.k8_needs_rpc },
    rar: rar && { ok: rar.ok, files: rar.plan_files, k: rar.k_covered, k10_blocker: rar.k10_blocker, k12_narrow: rar.k12_fix_narrow },
    g1: g1 && { pass: g1.pass, missing_k: g1.missing_k, retried: g1_retried },
  },
  f2: {
    idb: idb, iui: iui, k10: k10, ik8: ik8,
  },
  gates: {
    g2: r2 && r2.gate, g2_repaired: !!(r2 && r2.repaired), g2_repair: r2 ? r2.repair : null,
    g3: r3 && r3.gate, g3_repaired: !!(r3 && r3.repaired), g3_repair: r3 ? r3.repair : null,
  },
  review: {
    raw: findings.length, unique: uniq.length,
    confirmed: verified.map(f => ({ k: f.k_item, lane: f.lane, file: f.file, line: f.line, sev: f.severity, claim: f.claim, skeptic: f.skeptic_evidence })),
    dropped: dropped,
  },
  f4: { repairs: repairList, final_g2: fg2, final_g3: fg3 },
  partial: partial,
  remainder: ramRemainder,
}