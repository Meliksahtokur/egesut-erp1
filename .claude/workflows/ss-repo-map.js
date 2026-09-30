// ss-repo-map — egesut-erp1 icin paralel repo haritalama (ram-pool).
// Saf JS (TypeScript annotasyon YOK). Date.now / Math.random YASAK; kosu
// kimligi (epoch) disaridan args.ramEpoch ile tasinir (§12.2).
// Scan fazi ram-pool grant'indan genislik alir (ramPlan → lanes → ramClose);
// Synthesize TEK ajandir, fan-out'a bolunmez.

export const meta = {
  name: 'ss-repo-map',
  description:
    'egesut-erp1 yuzeyini paralel tarayip tek sentez ajaniyla bir repo haritasi uretir: giris noktalari, sicak dosyalar, DB katmani, test kapilari, koruma duvarlari.',
  phases: ['Scan', 'Synthesize']
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

const RUN = 'ss-repo-map';

// Scan fazi acilari (nufus: 6 aci; bir kismi bu repoya ozel).
const SCAN_ANGLES = [
  {
    id: 'entrypoints',
    focus: 'Statik site girisleri: index.html, js/ modul yukleme sirasi, GitHub Pages dagitimi, serve:local akisi.'
  },
  {
    id: 'hot-paths',
    focus: 'Sicak dosyalar: js/ui.js (10.6k satir) ve js/forms.js icinde islevsel bolgeler — hangi sorumluluk hangi bolgede, dokumante edilmemis bagimliliklar.'
  },
  {
    id: 'db-layer',
    focus: 'supabase/ katmani: 220+ migration kronolojisi, 180 fonksiyon ve 35 triggerin islevsel gruplari (asilama, tohumlama/ovsync, degisiklik gunlugu), api.js uzerinden hangi RPCler tuketiliyor.'
  },
  {
    id: 'offline-sync',
    focus: 'offline-kuyruk sistemi: istemci kuyrugu, senkron siralamasi, js/degisiklikler/ + gecmis.js geri-alma mimarisi.'
  },
  {
    id: 'test-gates',
    focus: 'Test katmani: tests/kritik-akis.spec.js ve tests/harness E2E kapisi, unit testler, test:local / test:docker senaryolari, canli DB bagimliligi.'
  },
  {
    id: 'guards-conventions',
    focus: 'Koruma duvarlari ve team konvansiyonlari: .claude hookify guardlari (block-direct-writes, protect-critical-files, blast-radius-guard), scripts/ground-truth-audit.sh drift kapisi, migration append-only kurali.'
  }
];

const SCAN_SCHEMA = {
  type: 'object',
  required: ['areas'],
  properties: {
    areas: {
      type: 'array',
      items: {
        type: 'object',
        required: ['angle', 'summary', 'key_files'],
        properties: {
          angle: { type: 'string' },
          summary: { type: 'string' },
          key_files: { type: 'array', items: { type: 'string' } },
          conventions: { type: 'array', items: { type: 'string' } }
        }
      }
    }
  }
};

const SYNTH_SCHEMA = {
  type: 'object',
  required: ['map'],
  properties: {
    map: {
      type: 'object',
      required: ['overview', 'areas', 'risks'],
      properties: {
        overview: { type: 'string' },
        areas: {
          type: 'array',
          items: {
            type: 'object',
            required: ['title', 'summary', 'key_files'],
            properties: {
              title: { type: 'string' },
              summary: { type: 'string' },
              key_files: { type: 'array', items: { type: 'string' } }
            }
          }
        },
        risks: { type: 'array', items: { type: 'string' } }
      }
    }
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

const { target, question } = input;

// ---- Scan: acilari ram-pool genisliginde tara (ramPlan → lanes → ramClose) ----
const scanPlan = await ramPlan(
  RUN,
  askedFor(SCAN_ANGLES.length),
  planOpts()
);
if (scanPlan.stopped) {
  // ram-epoch-missing (§12.1): hicbir ajan acilmadan dur.
  return scanPlan;
}
if (scanPlan.denied) {
  return {
    stopped: 'ram-pool-denied',
    reason: scanPlan.reason,
    remainder: SCAN_ANGLES.map((a, i) => ({ index: i, id: a.id, phase: 'Scan' }))
  };
}

const scanOne = (a) =>
  agent(
    'Repoyu (' + target + ') asagidaki acidan tara ve yuzey raporu uret. ' +
    'Uydurma YOK — sadece gordugun dosya/klasorleri yaz.\n' +
    'Aci: ' + a.id + '\nOdak: ' + a.focus + '\n' +
    (question ? 'Ozel soru: ' + question : ''),
    { schema: SCAN_SCHEMA, label: 'scan:' + a.id, phase: 'Scan' }
  );

let scanOut = { results: [], failed: [] };
if (scanPlan.grant) {
  try {
    scanOut = await lanes(SCAN_ANGLES, scanPlan, scanOne, RUN);
  } finally {
    await ramClose(scanPlan);
  }
}
// scanPlan.skipped → bos faz (§12.1): plan ajani bile acilmadan gecildi.

const areas = (scanOut.results || []).flatMap((r) => (r && r.areas ? r.areas : []));

// ---- Synthesize: TEK ajan (fan-out'a bolunmez) ----
const synth = await agent(
  'Asagidaki paralel tarama raporlarini TEK tutarli repo haritasina sentezle. ' +
  'Cakisan ozetleri birlestir, tekrarlari at, riskleri one cikar.\n' +
  'Raporlar: ' + JSON.stringify(areas),
  { schema: SYNTH_SCHEMA, label: 'synthesize', phase: 'Synthesize' }
);

return {
  map: synth && synth.map ? synth.map : null,
  areas,
  remainder: remainderOf(SCAN_ANGLES, scanOut)
};
