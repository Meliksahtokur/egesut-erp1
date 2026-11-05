// Ağ taklidi (subprocess.run sahte): gerçek istek ya da yazma denemesi yok.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const BETIK = path.join(__dirname, '..', '..', 'scripts', 'veri-eslesme-kontrol.py');
const SURUCU = `
import importlib.util, json, os, pathlib, subprocess, sys, tempfile
spec = importlib.util.spec_from_file_location("vek", sys.argv[1])
vek = importlib.util.module_from_spec(spec); spec.loader.exec_module(vek)
y = json.loads(sys.argv[3]); s = {"n": 0}; uyku = []
def run(argv, **kw):
    i = min(s["n"], len(y) - 1); s["n"] += 1
    return subprocess.CompletedProcess(argv, *y[i])
vek.subprocess.run = run; vek.time.sleep = uyku.append
taban = os.environ.get("TMPDIR") or os.path.expanduser("~/tmp")
os.makedirs(taban, exist_ok=True)
gecici = tempfile.TemporaryDirectory(dir=taban)
db = vek.Db("t", "ref", "tok", pathlib.Path(gecici.name)); sonuc, rc = None, 0
try:
    sonuc = vek.selftest_readonly(db) if sys.argv[2] == "selftest" else db.sql("SELECT 1;", "L")
except SystemExit as e:
    rc = e.code
print("@@" + json.dumps({"sonuc": sonuc, "rc": rc, "cagri": s["n"], "uyku": uyku, "hata": db.errors}))
`;
function kos(mod, y) {
  const r = spawnSync('python3', ['-c', SURUCU, BETIK, mod, JSON.stringify(y)], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, r.stderr);
  return { ...JSON.parse(r.stdout.split('\n').find(l => l.startsWith('@@')).slice(2)), cikti: r.stdout };
}
const RED = [0, '{"message":"ERROR: 25006: cannot execute CREATE TABLE in a read-only transaction"}', ''];

test('selftest: read-only reddi OK; başarılı yazma yanıtı PANIK rc=2', () => {
  assert.strictEqual(kos('selftest', [RED]).sonuc, true);
  const p = kos('selftest', [[0, '[]', '']]);
  assert.strictEqual(p.rc, 2);
  assert.match(p.cikti, /PANIK/);
});

for (const [ad, y] of [
  ['boş', [0, '', '']], ['curl 35', [35, '', 'c']], ['curl 28', [28, '', 'c']],
  ['HTML', [0, '<html>', '']], ['proje kapalı', [0, '{"message":"paused"}', '']],
]) {
  test(`selftest: ${ad} PANIK değil, ayrı mesaj ve rc=3`, () => {
    const s = kos('selftest', [y]);
    assert.strictEqual(s.rc, 3);
    assert.doesNotMatch(s.cikti, /PANIK/);
    assert.match(s.cikti, /BAGLANTI HATASI/);
    assert.match(s.cikti, /ölçülemedi/);
    assert.doesNotMatch(s.cikti, /yazma kabulü YOK/);
  });
}

test('sql: curl 28/35 ve boş yanıtta geri çekilerek yeniden dener', () => {
  const s = kos('sql', [[28, '', 'a'], [35, '', 'b'], [0, '', ''], [0, '[{"n":1}]', '']]);
  assert.deepStrictEqual(s.sonuc, [{ n: 1 }]);
  assert.deepStrictEqual(s.uyku, [5, 15, 30]);
  assert.deepStrictEqual(s.hata, []);
});

test('sql: üst sınırda durur, None + rc taşıyan hata (HATA ayrımı korunur); API hatası yeniden denenmez', () => {
  const s = kos('sql', [[35, '', 'c']]);
  assert.strictEqual(s.sonuc, null);
  assert.strictEqual(s.cagri, 4);
  assert.match(s.hata[0], /^L: .*rc=35/);
  assert.strictEqual(kos('sql', [[0, '{"message":"syntax error"}', '']]).cagri, 1);
});
