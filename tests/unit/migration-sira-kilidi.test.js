'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const { execFileSync } = require('node:child_process');
const KOK = path.join(__dirname, '..', '..');
const TABAN = '20261013000001'; // paket başlarken main'deki son damga (24c29f1)
const PAKET = ['_pg_uzatir.sql', '_alt_vaka.sql', '_k8_gorev_senkron.sql', '_s4_devam_rozeti.sql'];
test('migration-sira-kilidi', (t) => {
  const paket = fs.readdirSync(path.join(KOK, 'supabase/migrations')).filter(d => PAKET.some(s => d.endsWith(s)));
  assert.ok(paket.length >= 1, 'en az bir paket migration dosyası var');
  for (const d of paket) assert.ok(d.slice(0, 14) > TABAN, 'damga tabandan büyük: ' + d);
  const git = (...a) => execFileSync('git', a, { cwd: KOK }).toString().trim();
  let taban = ''; try { taban = git('rev-parse', '--verify', '--quiet', '24c29f1^{commit}'); } catch { /* sığ klon */ }
  if (!taban) t.diagnostic('sığ klon: 24c29f1 yok — yalnız çalışma ağacı (HEAD) denetlendi');
  const degisen = git('diff', '--name-only', '--diff-filter=MDR', taban || 'HEAD', '--', 'supabase/migrations');
  assert.strictEqual(degisen, '', 'eski migration Modify/Delete YOK');
});
