const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const JS = path.join(__dirname, '../../vendor/chart.umd.min.js');
const LIC = path.join(__dirname, '../../vendor/chart.js.LICENSE.md');
const bas = () => fs.readFileSync(JS).subarray(0, 300).toString('utf8');

test('vendor dosyası var, başlık Chart.js v4.', () => {
  assert.ok(fs.existsSync(JS), 'chart.umd.min.js yok');
  assert.match(bas(), /Chart\.js v4\./);
});

test('vm bağlamında Chart fonksiyon ve sürüm 4.x', () => {
  const ctx = {};
  ctx.window = ctx.self = ctx.globalThis = ctx;
  vm.createContext(ctx);
  vm.runInContext(fs.readFileSync(JS, 'utf8'), ctx);
  assert.strictEqual(vm.runInContext('typeof Chart', ctx), 'function');
  assert.match(vm.runInContext('Chart.version', ctx), /^4\./);
});

test('lisans MIT ve aynı sürüm', () => {
  const lic = fs.readFileSync(LIC, 'utf8');
  const s = bas().match(/Chart\.js v(4\.\d+\.\d+)/)[1];
  assert.match(lic, /MIT/);
  assert.ok(lic.includes(s));
});
