#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════
// EgeSüt Supabase Query Tool — Node.js + @supabase/supabase-js
// Kullanım: node supa-query.js "SELECT * FROM hayvanlar LIMIT 5"
// ═══════════════════════════════════════════════════════════════

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_KEY || 'sbp_235a8cfe38b40eb8c5f9bde9e31301d97cbc89c9';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function runQuery(sql) {
  console.log('→ SQL çalıştırılıyor...\n');
  
  try {
    // Supabase RPC ile SQL çalıştır
    const { data, error } = await supabase.rpc('execute_sql', { p_sql: sql });
    
    if (error) {
      console.error('❌ Hata:', error.message);
      process.exit(1);
    }
    
    console.log('✓ Sonuç:');
    console.table(data);
    console.log('\n✓ Sorgu tamamlandı');
  } catch (err) {
    console.error('❌ Hata:', err.message);
    process.exit(1);
  }
}

// Ana program
const sql = process.argv[2];

if (!sql) {
  console.error('Kullanım: node supa-query.js "<SQL sorgusu>"');
  console.error('Örnek: node supa-query.js "SELECT * FROM hayvanlar LIMIT 5"');
  process.exit(1);
}

runQuery(sql);
