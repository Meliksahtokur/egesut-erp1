// db betikleri: oturuma benzersiz izole DB + rapor maskesi. Sahte PATH: gerçek DB/ağ yok.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SCRIPTS = path.join(__dirname, '..', '..', 'scripts');
const AD = /^egesut_val_\d+_[0-9a-f]{8}$/;
const SIR = 'gizliparola';
const STUB_BASELINE = `echo "$*" >> "$SAHTE_LOG.b"
echo "postgres://u:pa@ss@h/db"; echo "dsn host=h password=gizli1 user=u"; echo "postgres://h:5432/db?x=a@b"
n=""; while [[ $# -gt 0 ]]; do [[ "$1" == --db-name ]] && n="$2"; shift; done
[[ -z "\${BASELINE_BOZUK:-}" ]] || exit 1
echo "{\\"db_name\\":\\"$n\\",\\"parite_durum\\":\\"uyumlu\\"}"
`;

function kur(t, gercekBaseline) {
  const taban = process.env.TMPDIR || path.join(os.homedir(), 'tmp');
  fs.mkdirSync(taban, { recursive: true });
  const kok = fs.mkdtempSync(path.join(taban, 'dbval-test-'));
  t.after(() => fs.rmSync(kok, { recursive: true, force: true }));
  const [bin, sc, log] = ['bin', 'scripts', 'log'].map(a => path.join(kok, a));
  fs.mkdirSync(bin); fs.mkdirSync(sc);
  const sahte = (ad, g) => fs.writeFileSync(path.join(bin, ad),
    `#!/usr/bin/env bash\necho "$(basename "$0") $*" >> "$SAHTE_LOG"\n${g}\n`, { mode: 0o755 });
  sahte('psql', `case "$*" in *json_agg*) echo '[]';; *) echo 1;; esac`);
  for (const ad of ['dropdb', 'createdb', 'sqlfluff', 'squawk']) sahte(ad, '');
  sahte('pg_dump', '[[ -z "${PG_DUMP_SINYAL:-}" ]] || kill -"$PG_DUMP_SINYAL" "$PPID"\n[[ -z "${PG_DUMP_BOZUK:-}" ]]');
  sahte('curl', `while [[ $# -gt 0 ]]; do [[ "$1" == -o ]] && echo '-- pgtap' > "$2"; shift; done\necho '[{"v":"17.6"}]'`);
  fs.writeFileSync(path.join(kok, '.env'),
    `LOCAL_LSP_URL=postgres://u:${SIR}@h:1/ayna\nVAL_DB_URL=postgres://postgres:${SIR}@h:2/postgres\nSB_MGMT_TOKEN=t\n`);
  fs.copyFileSync(path.join(SCRIPTS, 'db-validate.sh'), path.join(sc, 'db-validate.sh'));
  if (gercekBaseline) fs.copyFileSync(path.join(SCRIPTS, 'db-build-baseline.sh'), path.join(sc, 'db-build-baseline.sh'));
  else fs.writeFileSync(path.join(sc, 'db-build-baseline.sh'), STUB_BASELINE);
  const sql = path.join(kok, 'm.sql');
  fs.writeFileSync(sql, 'CREATE TABLE t(i int);\n');
  const kos = (betik, args, ek = {}) => spawnSync('bash', [path.join(sc, betik), ...args], {
    encoding: 'utf8', timeout: 60000,
    env: { ...process.env, PATH: `${bin}:${process.env.PATH}`, TMPDIR: kok, SS_TMP_ROOT: kok, SAHTE_LOG: log, VAL_DB_URL: '', ...ek },
  });
  const oku = f => (fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : '');
  const rapor = () => fs.readdirSync(path.join(kok, 'reports')).map(f => oku(path.join(kok, 'reports', f))).join('\n');
  return { sql, kos, rapor, log: () => oku(log), blog: () => oku(`${log}.b`) };
}
const dusen = l => [...l.matchAll(/DROP DATABASE IF EXISTS "([^"]+)"/g)].map(m => m[1]);
const adlar = l => [...l.matchAll(/--db-name (\S+)/g)].map(m => m[1]);
const jsonAd = r => JSON.parse(r.stdout.trim().split('\n').pop()).db_name;

test('db-validate: baseline başına benzersiz ad, trap yalnız onları siler, rapor parola taşımaz', t => {
  const k = kur(t, false);
  const r = k.kos('db-validate.sh', [k.sql, '--data-mode', 'on']);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const ad = adlar(k.blog());
  assert.strictEqual(new Set(ad).size, 2);
  ad.forEach(a => assert.match(a, AD));
  assert.deepStrictEqual(dusen(k.log()).sort(), [...ad].sort());
  assert.ok(!k.rapor().includes(SIR));
  assert.match(k.rapor(), /postgres:\*\*\*@h:2/);
});

test('db-validate raporu: @ içeren parola ve password= maskelenir, parolasız URL bozulmaz', t => {
  const k = kur(t, false);
  k.kos('db-validate.sh', [k.sql, '--data-mode', 'off']);
  const r = k.rapor();
  assert.ok(r.includes('postgres://u:***@h/db'));
  assert.ok(!r.includes('pa@ss') && !r.includes('ss@h'));
  assert.ok(r.includes('dsn host=h password=*** user=u'));
  assert.ok(!r.includes('gizli1'));
  assert.ok(r.includes('postgres://h:5432/db?x=a@b'));
});

test('db-validate: baseline yarıda düşerse kendi adını siler, sabit ada dokunmaz', t => {
  const k = kur(t, false);
  k.kos('db-validate.sh', [k.sql, '--data-mode', 'off'], { BASELINE_BOZUK: '1' });
  assert.deepStrictEqual(dusen(k.log()), adlar(k.blog()));
  assert.strictEqual(dusen(k.log()).length, 1);
  assert.ok(!k.log().includes('egesut_val_tmp'));
});

test('baseline: --db-name yoksa benzersiz ad; verilirse arayüz aynı', t => {
  const k = kur(t, true);
  const ad = [1, 2].map(() => jsonAd(k.kos('db-build-baseline.sh', ['--json'])));
  assert.notStrictEqual(ad[0], ad[1]);
  ad.forEach(a => assert.match(a, AD));
  assert.strictEqual(jsonAd(k.kos('db-build-baseline.sh', ['--json', '--db-name', 'ozel_ad'])), 'ozel_ad');
});

test('baseline: kurulum düşerse yalnız kendi ürettiği DB silinir, verilen ada dokunulmaz', t => {
  const k = kur(t, true);
  assert.notStrictEqual(k.kos('db-build-baseline.sh', ['--json'], { PG_DUMP_BOZUK: '1' }).status, 0);
  const ad = k.log().match(/createdb (\S+)/)[1];
  assert.match(ad, AD);
  assert.ok(k.log().includes(`dropdb --if-exists ${ad}`));
  const k2 = kur(t, true);
  k2.kos('db-build-baseline.sh', ['--json', '--db-name', 'ozel_ad'], { PG_DUMP_BOZUK: '1' });
  assert.strictEqual([...k2.log().matchAll(/dropdb/g)].length, 1, 'yalnız açılıştaki --if-exists');
});

for (const [sinyal, rc] of [['TERM', 143], ['INT', 130]]) {
  test(`baseline: --db-name yokken ${sinyal} kendi DB'sini siler, rc=${rc}`, t => {
    const k = kur(t, true);
    const r = k.kos('db-build-baseline.sh', ['--json'], { PG_DUMP_SINYAL: sinyal });
    assert.strictEqual(r.status, rc);
    const ad = k.log().match(/createdb (\S+)/)[1];
    assert.strictEqual(k.log().split(`dropdb --if-exists ${ad}`).length, 3, 'açılış + sinyal temizliği');
  });
}
