// ss-repo-map — egesut-erp1 icin paralel repo haritalama.
// Saf JS (TypeScript annotasyon YOK). Date.now / Math.random YASAK.

export const meta = {
  name: 'ss-repo-map',
  description:
    'egesut-erp1 yuzeyini paralel tarayip tek sentez ajaniyla bir repo haritasi uretir: giris noktalari, sicak dosyalar, DB katmani, test kapilari, koruma duvarlari.',
  phases: ['Scan', 'Synthesize']
};

const MAX_CONC = 6;

// Scan fazi acilari (en fazla 6; bir kismi bu repoya ozel).
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

export default async function (input) {
  const { target, question } = input;

  // ---- Scan: acilar paralel, ayni anda en fazla MAX_CONC ----
  const scanResults = [];
  for (let i = 0; i < SCAN_ANGLES.length; i += MAX_CONC) {
    const batch = SCAN_ANGLES.slice(i, i + MAX_CONC);
    const results = await Promise.all(
      batch.map((a) =>
        agents.run({
          prompt:
            'Repoyu (' + target + ') asagidaki acidan tara ve yuzey raporu uret. ' +
            'Uydurma YOK — sadece gordugun dosya/klasorleri yaz.\n' +
            'Aci: ' + a.id + '\nOdak: ' + a.focus + '\n' +
            (question ? 'Ozel soru: ' + question : ''),
          schema: SCAN_SCHEMA,
          label: 'scan:' + a.id
        })
      )
    );
    scanResults.push(...results);
  }

  const areas = scanResults.flatMap((r) => (r && r.areas ? r.areas : []));

  // ---- Synthesize: TEK ajan ----
  const synth = await agents.run({
    prompt:
      'Asagidaki paralel tarama raporlarini TEK tutarli repo haritasina sentezle. ' +
      'Cakisan ozetleri birlestir, tekrarlari at, riskleri one cikar.\n' +
      'Raporlar: ' + JSON.stringify(areas),
    schema: SYNTH_SCHEMA,
    label: 'synthesize'
  });

  return { map: synth && synth.map ? synth.map : null, areas };
}
