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

// Bağlan (tüm araçlar kaydedildikten sonra)
const transport = new StdioServerTransport();
await server.connect(transport);

console.error("✅ Gwen MCP Supabase Server başladı");
