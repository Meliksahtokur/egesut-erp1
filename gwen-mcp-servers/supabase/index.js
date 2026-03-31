/**
 * Gwen Agent — Supabase MCP Server
 * EgeSüt ERP için Supabase veritabanı erişimi
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = "https://zqnexqbdfvbhlxzelzju.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const server = new McpServer({
  name: "gwen-mcp-supabase",
  version: "1.0.0"
});

// ──────────────────────────────────────────────────────────────────
// TOOLS
// ──────────────────────────────────────────────────────────────────

/**
 * SQL sorgusu çalıştır
 * Not: Supabase'de doğrudan SQL sorgusu için RPC fonksiyonu gerekli.
 * execute_sql RPC'si yoksa, bu araç kullanılamaz.
 * Alternatif: Doğrudan tablo sorguları için .from() kullanın.
 */
server.tool(
  "execute_sql",
  "Supabase veritabanında SQL sorgusu çalıştır (SELECT only) - REQUIRES RPC",
  {
    query: z.string().describe("SQL sorgusu (sadece SELECT)")
  },
  async ({ query }) => {
    try {
      // Güvenlik: Sadece SELECT sorgularına izin ver
      const upperQuery = query.trim().toUpperCase();
      if (!upperQuery.startsWith("SELECT")) {
        throw new Error("Gwen sadece SELECT sorguları çalıştırabilir. INSERT/UPDATE/DELETE için orchestrator onayı gerekli.");
      }

      // Supabase REST API üzerinden SQL sorgusu
      // Not: Supabase, doğrudan SQL sorgusunu desteklemez, RPC gerekir
      // Bu yüzden kullanıcıya alternatif öneriyoruz
      return {
        isError: true,
        content: [{
          type: "text",
          text: `⚠️ execute_sql RPC fonksiyonu veritabanında tanımlı değil.\n\n` +
                `Alternatifler:\n` +
                `1. .from('tablo_adi').select() kullanın\n` +
                `2. Veritabanına execute_sql RPC'si ekleyin (migration gerekli)\n\n` +
                `Örnek:\n` +
                `\`\`\`js\n` +
                `const { data } = await supabase.from('hayvanlar').select('*').limit(10);\n` +
                `\`\`\`\n\n` +
                `RPC eklemek için SQL:\n` +
                `\`\`\`sql\n` +
                `CREATE OR REPLACE FUNCTION execute_sql(p_query text)\n` +
                `RETURNS TABLE(result jsonb) AS $$\n` +
                `BEGIN\n` +
                `  RETURN QUERY EXECUTE p_query;\n` +
                `END;\n` +
                `$$ LANGUAGE plpgsql SECURITY DEFINER;\n` +
                `\`\`\``
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${err.message}` }]
      };
    }
  }
);

/**
 * Tablo şemasını getir
 * Not: information_schema Supabase client'ta cache'lenmediği için
 * doğrudan tablo sorgusu yapıyoruz ve ilk kayıttan kolonları çıkarıyoruz
 */
server.tool(
  "get_table_schema",
  "Belirtilen tablonun şema bilgisini getir (kolonlar, tipler, constraint'ler)",
  {
    tableName: z.string().describe("Tablo adı (örn: hayvanlar, tohumlama)")
  },
  async ({ tableName }) => {
    try {
      // İlk 1 kaydı çek ve kolon isimlerini göster
      const { data, error } = await supabase
        .from(tableName)
        .select('*')
        .limit(1);

      if (error) {
        return {
          isError: true,
          content: [{ type: "text", text: `Şema hatası: ${error.message}` }]
        };
      }

      if (!data || data.length === 0) {
        // Tablo boş olsa bile kolon bilgisi almak için SELECT * FROM limit 0 kullan
        const { data: emptyData, error: emptyError } = await supabase
          .from(tableName)
          .select('*')
          .limit(0);

        if (emptyError) {
          return {
            isError: true,
            content: [{ type: "text", text: `Şema hatası: ${emptyError.message}` }]
          };
        }

        if (emptyData && Object.keys(emptyData[0] || {}).length > 0) {
          const schema = Object.keys(emptyData[0]).map(key => `- ${key}: unknown`).join('\n');
          return {
            content: [{
              type: "text",
              text: `📋 ${tableName} şeması:\n\n${schema}\n\n⚠️ Tablo boş, tip bilgisi yok`
            }]
          };
        }

        return {
          content: [{
            type: "text",
            text: `📋 ${tableName} şeması:\n\n⚠️ Kolon bilgisi alınamadı`
          }]
        };
      }

      const columns = Object.keys(data[0]);
      const schema = columns.map(col => `- ${col}: unknown`).join('\n');

      return {
        content: [{
          type: "text",
          text: `📋 ${tableName} şeması:\n\n${schema}\n\n⚠️ Tip bilgisi için doğrudan SQL sorgusu gerekli`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${err.message}` }]
      };
    }
  }
);

/**
 * Tablo listesi getir
 * Not: information_schema Supabase client'ta cache'lenmediği için
 * bilinen tabloları manuel olarak döndürüyoruz
 */
server.tool(
  "list_tables",
  "Veritabanındaki tüm tabloları listele",
  {},
  async () => {
    try {
      // EgeSüt ERP bilinen tablolar
      const tables = [
        "hayvanlar",
        "tohumlama",
        "dogum",
        "hastalik_log",
        "tedavi",
        "kizginlik_log",
        "gorev_log",
        "stok",
        "stok_hareket",
        "diseases",
        "drugs",
        "drug_products",
        "drug_administrations",
        "treatment_days",
        "treatment_timeline",
        "cases",
        "bildirim_log",
        "islem_log",
        "cop_kutusu",
        "irk_esik",
        "tohumlanabilir_hayvanlar",
        "buzagi_takip",
        "hayvan_durum_view",
        "hayvan_durum_analizi",
        "hastalik_istatistik_view",
        "gebelik_ozet_view",
        "stok_tuketim_view",
        "tedavi_view",
        "vethek_tohumlamalar"
      ];

      return {
        content: [{
          type: "text",
          text: `📊 Tablolar (${tables.length}):\n\n${tables.map(t => `- ${t}`).join('\n')}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${err.message}` }]
      };
    }
  }
);

/**
 * Hayvanlar tablosundan veri çek
 */
server.tool(
  "get_animals",
  "Hayvanlar tablosundan filtrelenmiş veri çek",
  {
    limit: z.number().optional().default(50).describe("Maksimum kayıt sayısı"),
    durum: z.string().optional().describe("Durum filtresi (Aktif/Pasif)"),
    cinsiyet: z.string().optional().describe("Cinsiyet filtresi (Dişi/Erkek)")
  },
  async ({ limit, durum, cinsiyet }) => {
    try {
      let query = supabase.from('hayvanlar').select('*').limit(limit);

      if (durum) query = query.eq('durum', durum);
      if (cinsiyet) query = query.eq('cinsiyet', cinsiyet);

      const { data, error } = await query;

      if (error) {
        return {
          isError: true,
          content: [{ type: "text", text: `Hata: ${error.message}` }]
        };
      }

      return {
        content: [{
          type: "text",
          text: `🐄 ${data.length} hayvan bulundu.\n\n${JSON.stringify(data.slice(0, 5), null, 2)}\n\n... (${data.length - 5} daha)`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${err.message}` }]
      };
    }
  }
);

/**
 * DB Telemetry — Session bazlı değişiklikleri çek
 */
server.tool(
  "get_db_telemetry",
  "Test session'ındaki DB değişikliklerini çek (islem_log, stok_hareket, gorev_log, hayvanlar)",
  {
    startTime: z.string().describe("Başlangıç timestamp (ISO format)"),
    endTime: z.string().optional().describe("Bitiş timestamp (ISO format, varsayılan: şimdi)"),
    tables: z.array(z.string()).optional().describe("Tablolar (varsayılan: tüm kritik tablolar)")
  },
  async ({ startTime, endTime, tables }) => {
    try {
      const targetTables = tables || ['islem_log', 'stok_hareket', 'gorev_log', 'hayvanlar'];
      const endTs = endTime || new Date().toISOString();
      
      const results = {};
      const summary = {};
      
      // Her tablo için değişiklikleri çek
      for (const table of targetTables) {
        try {
          let query = supabase
            .from(table)
            .select('*')
            .gte('created_at', startTime)
            .lte('created_at', endTs)
            .order('created_at', { ascending: false })
            .limit(100); // Max 100 kayıt/tablo
          
          const { data, error } = await query;
          
          if (error) {
            results[table] = { error: error.message };
            summary[table] = 0;
          } else {
            results[table] = data;
            summary[table] = data?.length || 0;
          }
        } catch (err) {
          results[table] = { error: err.message };
          summary[table] = 0;
        }
      }
      
      // Özet + detay output
      const output = {
        session: {
          startTime,
          endTime: endTs,
          duration: new Date(endTs) - new Date(startTime)
        },
        summary,
        details: results
      };
      
      return {
        content: [{
          type: "text",
          text: `📊 DB Telemetry (Son Session)\n\n` +
                `⏱️ Süre: ${output.session.duration}ms\n\n` +
                `📋 Özet:\n` +
                `  - islem_log: ${summary.islem_log || 0} kayıt\n` +
                `  - stok_hareket: ${summary.stok_hareket || 0} değişiklik\n` +
                `  - gorev_log: ${summary.gorev_log || 0} görev\n` +
                `  - hayvanlar: ${summary.hayvanlar || 0} güncelleme\n\n` +
                `🔍 Detaylar için 'details' alanına bak.\n\n` +
                `💡 İpucu: "verify_transaction_integrity" ile bütünlük kontrolü yap.`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ DB Telemetry hatası: ${err.message}` }]
      };
    }
  }
);

/**
 * Transaction Integrity Check — Bütünlük kontrolü
 */
server.tool(
  "verify_transaction_integrity",
  "Yapılan işlemin DB bütünlüğünü kontrol et (trigger'lar, görevler, stok)",
  {
    transactionType: z.string().describe("İşlem tipi: TOHUMLAMA, DOGUM_KAYDI, ILAC_EKLE, etc."),
    refId: z.string().describe("Referans ID (örn: tohumlama_id, hayvan_id)"),
    expectedActions: z.array(z.string()).optional().describe("Beklenen aksiyonlar (örn: ['stok_dus', 'gorev_olustur'])")
  },
  async ({ transactionType, refId, expectedActions }) => {
    try {
      const issues = [];
      const checks = {};
      
      // 1. islem_log kontrolü
      const { data: islemLog } = await supabase
        .from('islem_log')
        .select('*')
        .eq('ref_id', refId)
        .order('created_at', { ascending: false })
        .limit(5);
      
      checks.islem_log = {
        found: islemLog?.length > 0,
        count: islemLog?.length || 0,
        logs: islemLog?.slice(0, 3) || []
      };
      
      if (!checks.islem_log.found) {
        issues.push({
          type: 'MISSING_ISLEM_LOG',
          severity: 'critical',
          description: `İşlem log'u bulunamadı (ref_id: ${refId})`
        });
      }
      
      // 2. Stok kontrolü (eğer bekleniyorsa)
      if (expectedActions?.includes('stok_dus')) {
        const { data: stokHareket } = await supabase
          .from('stok_hareket')
          .select('*')
          .eq('notlar', transactionType)
          .order('created_at', { ascending: false })
          .limit(5);
        
        checks.stok_hareket = {
          found: stokHareket?.length > 0,
          count: stokHareket?.length || 0
        };
        
        if (!checks.stok_hareket.found) {
          issues.push({
            type: 'STOK_LEDGER_BUG',
            severity: 'critical',
            description: 'Stok hareketi oluşmadı — Ledger hatası!'
          });
        }
      }
      
      // 3. Görev kontrolü (eğer bekleniyorsa)
      if (expectedActions?.includes('gorev_olustur')) {
        const { data: gorevLog } = await supabase
          .from('gorev_log')
          .select('*')
          .eq('ref_id', refId)
          .order('created_at', { ascending: false })
          .limit(10);
        
        checks.gorev_log = {
          found: gorevLog?.length > 0,
          count: gorevLog?.length || 0,
          tasks: gorevLog?.map(g => g.tip) || []
        };
        
        if (!checks.gorev_log.found) {
          issues.push({
            type: 'MISSING_GOREV',
            severity: 'high',
            description: 'Görev log\'u oluşmadı — Trigger hatası!'
          });
        }
      }
      
      // 4. Hayvan durumu kontrolü (tohumlama/doğum için)
      if (['TOHUMLAMA', 'DOGUM_KAYDI'].includes(transactionType)) {
        const { data: hayvan } = await supabase
          .from('hayvanlar')
          .select('id, kupe_no, tohumlama_durumu, gebelik_var')
          .eq('id', refId)
          .single();
        
        checks.hayvan_durum = {
          found: !!hayvan,
          durum: hayvan?.tohumlama_durumu || 'unknown'
        };
        
        if (transactionType === 'TOHUMLAMA' && hayvan?.tohumlama_durumu !== 'Tohumlandı') {
          issues.push({
            type: 'HAYVAN_STATUS_BUG',
            severity: 'high',
            description: `Hayvan durumu güncellenmedi: ${hayvan?.tohumlama_durumu}`
          });
        }
      }
      
      // Output
      const hasCriticalIssues = issues.some(i => i.severity === 'critical');
      const hasIssues = issues.length > 0;
      
      let status = '✅ TEMİZ';
      if (hasCriticalIssues) status = '❌ KRİTİK HATA';
      else if (hasIssues) status = '⚠️ SORUN VAR';
      
      return {
        content: [{
          type: "text",
          text: `🔍 Transaction Integrity Check\n\n` +
                `İşlem: ${transactionType}\n` +
                `Ref ID: ${refId}\n` +
                `Durum: ${status}\n\n` +
                `📊 Kontroller:\n` +
                `  - islem_log: ${checks.islem_log?.found ? '✅' : '❌'} (${checks.islem_log?.count} kayıt)\n` +
                `  - stok_hareket: ${checks.stok_hareket?.found !== undefined ? (checks.stok_hareket.found ? '✅' : '❌') : '⏭️'} (${checks.stok_hareket?.count || 0})\n` +
                `  - gorev_log: ${checks.gorev_log?.found !== undefined ? (checks.gorev_log.found ? '✅' : '❌') : '⏭️'} (${checks.gorev_log?.count || 0} görev)\n` +
                `  - hayvan_durum: ${checks.hayvan_durum?.found ? '✅' : '❌'} (${checks.hayvan_durum?.durum})\n\n` +
                (issues.length > 0 ? `❌ Sorunlar:\n${issues.map(i => `  - [${i.severity}] ${i.description}`).join('\n')}\n\n` : '') +
                (hasCriticalIssues ? `🚨 KRİTİK HATA: Fix öncesi bu sorunlar çözülmeli!` : '') +
                (hasIssues && !hasCriticalIssues ? `💡 ÖNERİ: Bu sorunları düzeltmek ister misin?` : '')
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ Integrity check hatası: ${err.message}` }]
      };
    }
  }
);

// Bağlan (tüm araçlar kaydedildikten sonra)
const transport = new StdioServerTransport();
await server.connect(transport);

console.error("✅ Gwen MCP Supabase Server başladı");
