'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const { sqlBlok } = require('./support/sqlBlok.js');
const MIG = path.join(__dirname, '..', '..', 'supabase/migrations/20261013000002_pg_uzatir.sql');
test('pg-bypass-kapi-cagri-kilidi', () => {
  const sql = fs.readFileSync(MIG, 'utf8');
  for (const ad of ['treatment_day_tamamla', 'add_drug_administration', 'tedavi_sablon_uygula']) {
    const b = sqlBlok(sql, ad);
    assert.ok(sql.includes('DROP FUNCTION IF EXISTS public.' + ad + '('), ad + ': eski imza DROP');
    assert.ok(b.includes('_pg_kapi('), ad + ': kapı hesabı');
    assert.match(b, /p_pg_onay boolean DEFAULT NULL/, ad + ': p_pg_onay DEFAULT NULL');
    assert.match(b, /p_pg_gerekce text DEFAULT NULL/, ad + ': p_pg_gerekce DEFAULT NULL');
    assert.ok(new RegExp('GRANT EXECUTE ON FUNCTION public\\.' + ad + '\\([^)]*\\) TO authenticated').test(sql), ad + ': GRANT');
  }
  for (const ad of ['treatment_day_tamamla', 'add_drug_administration'])
    assert.ok(sqlBlok(sql, ad).includes('_pg_olay_isle('), ad + ': uygulama anında olay (+48 s TAI)');
  assert.ok(!sqlBlok(sql, 'tedavi_sablon_uygula').includes('_pg_olay_isle('), 'şablon planlar, olay gün tamamlanınca (çift olay YOK)');
  assert.match(sql, /ADD CONSTRAINT pg_application_event_source_type_check\n\s*CHECK \([^\n]*'TEDAVI_GUN'[^\n]*'ILAC_EKLE'/, 'CHECK yeni kaynaklar (ADD CONSTRAINT satırı)');
  assert.ok(!/GRANT\s+EXECUTE[^;]*\bTO\s+[^;]*\banon\b/.test(sql), 'anon GRANT YOK');
  assert.ok(!sqlBlok(sql, '_pg_olay_isle').includes('_vaka_kapat('), 'E3 kancası kalktı');
});
