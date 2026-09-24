// ss-parallel-review — egesut-erp1 icin paralel kod incelemesi.
// Saf JS (TypeScript annotasyon YOK). Date.now / Math.random YASAK —
// script deterministik olmali, ayni input ayni plani uretmeli.

export const meta = {
  name: 'ss-parallel-review',
  description:
    'egesut-erp1 icin cok-boyutlu paralel kod incelemesi: once bul (<=6 boyut, MAX_CONC=6), sonra her taze bulguyu skepsis ajaniyla celistir, yalniz ayakta kalanlari raporla.',
  phases: ['Find', 'Verify']
};

const MAX_CONC = 6;

// Bu repoya OZEL inceleme boyutlari (Find fazi, en fazla 6).
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

async function main(input) {
  const { diff, target } = input;

  // ---- Find: boyutlari paralel tara, ayni anda en fazla MAX_CONC ----
  const findResults = [];
  for (let i = 0; i < FIND_DIMENSIONS.length; i += MAX_CONC) {
    const batch = FIND_DIMENSIONS.slice(i, i + MAX_CONC);
    const batchResults = await Promise.all(
      batch.map((dim) =>
        agent(
          'Bu repoda (' + target + ') asagidaki boyutta kod incelemesi yap. ' +
          'Sadece KANITLA desteklenen bulgular uret; dosya+satir olmadan bulgu yazma. ' +
          'Boyut: ' + dim.id + '\nOdak: ' + dim.focus + '\n' +
          'Ek baglam: ' + (input.hedef || '') + '\n' +
          (diff ? 'Incelenecek degisiklik:\n' + diff : ''),
          { schema: FIND_SCHEMA, label: 'find:' + dim.id, phase: 'Find' }
        )
      )
    );
    findResults.push(...batchResults);
  }

  const fresh = findResults.flatMap((r) => (r && r.findings ? r.findings : []));

  // ---- Verify: her taze bulgu bir skepsis ajaniyla celisir ----
  const verify = async (f) => {
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

  const verdicts = [];
  for (let i = 0; i < fresh.length; i += MAX_CONC) {
    const batch = fresh.slice(i, i + MAX_CONC);
    const results = await Promise.all(batch.map(verify));
    verdicts.push(...results);
  }

  const confirmed = verdicts.filter((v) => !v.dropped).map((v) => v.finding);
  const dropped = verdicts.filter((v) => v.dropped)
    .map((v) => ({ claim: v.finding.claim, file: v.finding.file, reason: v.reason }));

  return { confirmed, dropped };
}

return await main(args);
