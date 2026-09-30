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

// >>> ram-pool v<N> sha=<sha256[:12]>
// ram-pool kanonik snippet YUVASI (§12.1-12.2; arayuz PLAN Task 15'te kilitli:
// ramPlan(run, asked, opts) / parsePlan(raw) / lanes(items, grant, fn, run) /
// ramClose(grant) / RAM_EXEC_NOTE — kanon:
// tools-bank/.superset/lib/ram-pool/workflow-snippet.js).
// Bu bloktaki govde YEREL TUTUCUDUR: `ram-ultracode sync-workflows` isaretler
// arasini kanonik snippet ile degistirir (§12.3) ve isaret satirini v/sha ile
// kanoniklestirir. Tutucu fail-closed atar; sync ONCESI kosum K6 ile yasak.
const RAM_EXEC_NOTE =
  'Test/build kosan ajan komutlari yalniz `ram-ultracode exec --class test|build --` ile ve tek tirnakli --sh sarmasiyla kosar (§7/§12.1).';
async function ramPlan(run, asked, opts) {
  throw new Error(
    'FAIL-CLOSED: ram-pool kanonik snippet sync edilmemis — once ram-ultracode sync-workflows (§12.3)'
  );
}
function parsePlan(raw) {
  throw new Error(
    'FAIL-CLOSED: ram-pool kanonik snippet sync edilmemis — once ram-ultracode sync-workflows (§12.3)'
  );
}
async function lanes(items, grant, fn, run) {
  throw new Error(
    'FAIL-CLOSED: ram-pool kanonik snippet sync edilmemis — once ram-ultracode sync-workflows (§12.3)'
  );
}
async function ramClose(grant) {
  throw new Error(
    'FAIL-CLOSED: ram-pool kanonik snippet sync edilmemis — once ram-ultracode sync-workflows (§12.3)'
  );
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
