/**
 * Gwen Agent — Context7 MCP Server
 * API dokümantasyonu erişimi (Supabase JS Client, Web APIs, etc.)
 * 
 * Not: api.context7.com DNS çözümlenemediği için fetch_docs devre dışı.
 * Hardcoded dokümantasyon fallback kullanılıyor.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "gwen-mcp-context7",
  version: "1.0.0"
});

// ──────────────────────────────────────────────────────────────────
// TOOLS
// ──────────────────────────────────────────────────────────────────

/**
 * API dokümantasyonunu getir
 * DEVRE DIŞI: api.context7.com DNS çözümlenemiyor
 * Alternatif: supabase_client_docs kullanın
 */
server.tool(
  "fetch_docs",
  "Dokümantasyon servisi şu anda kullanılamıyor. supabase_client_docs kullanın.",
  {
    library: z.string().describe("Kütüphane adı (örn: @supabase/supabase-js, indexeddb)"),
    topic: z.string().optional().describe("Özel konu (örn: from, select, rpc)")
  },
  async ({ library, topic }) => {
    return {
      isError: true,
      content: [{
        type: "text",
        text: `⚠️ Context7 API kullanılamıyor (api.context7.com DNS hatası)\n\n` +
              `Alternatifler:\n` +
              `1. supabase_client_docs kullanın (Supabase JS Client için)\n` +
              `2. MDN Web Docs: https://developer.mozilla.org\n` +
              `3. Supabase Docs: https://supabase.com/docs\n\n` +
              `Örnek: .supabase_client_docs({ method: "from" })`
      }]
    };
  }
);

/**
 * Supabase JS Client referansı
 * Hardcoded fallback - Context7 API çalışmadığı için kullanılıyor
 */
server.tool(
  "supabase_client_docs",
  "Supabase JavaScript Client API referansı (hardcoded fallback)",
  {
    method: z.string().optional().describe("Metod adı (örn: from, select, rpc, insert, update, delete, eq, neq, gt, gte, lt, lte, like, ilike, is, in, contains, containedBy, rangeEq, rangeGt, rangeGte, rangeLt, rangeLte, rangeAdjacent, overlaps, fullText, textSearch, match, order, limit, offset, range, maybeSingle, single, throwOnError)")
  },
  async ({ method }) => {
    const docs = {
      // Core Methods
      from: `
.from(table: string) → QueryBuilder
Tablo seçimi için kullanılır. Tüm sorgular bu metodla başlar.

Örnek:
\`\`\`js
const { data, error } = await supabase
  .from('hayvanlar')
  .select('*')
  .eq('cinsiyet', 'Dişi');
\`\`\`
      `,
      select: `
.select(columns?: string) → QueryBuilder
Kolon seçimi ve filtreleme. JOIN işlemleri için de kullanılır.

Örnek:
\`\`\`js
// Tüm kolonlar
const { data } = await supabase.from('hayvanlar').select('*');

// Spesifik kolonlar
const { data } = await supabase
  .from('hayvanlar')
  .select('kupe_no, ad, dogum_tarihi');

// JOIN (foreign key ile)
const { data } = await supabase
  .from('tohumlama')
  .select('*, hayvanlar(kupe_no, ad)');
\`\`\`
      `,
      rpc: `
.rpc(functionName: string, params?: object) → QueryBuilder
PostgreSQL RPC (fonksiyon) çağrısı. Stored procedure'leri çalıştırır.

Örnek:
\`\`\`js
// Parametreli RPC
const { data } = await supabase
  .rpc('tohumlama_kaydet', {
    p_hayvan_id: 123,
    p_tarih: '2024-01-15',
    p_sonuc: 'Gebe'
  });

// Parametresiz RPC
const { data } = await supabase
  .rpc('hayvan_durum_analizi');
\`\`\`
      `,
      insert: `
.insert(data: object | object[]) → QueryBuilder
Yeni kayıt ekleme. Tek veya birden fazla kayıt eklenebilir.

Örnek:
\`\`\`js
// Tek kayıt
const { data } = await supabase
  .from('gorev_log')
  .insert({
    gorev_tipi: 'ILAC',
    aciklama: 'Aşı yapıldı',
    tarih: '2024-01-15'
  });

// Birden fazla kayıt
const { data } = await supabase
  .from('stok_hareket')
  .insert([
    { urun_id: 1, miktar: 10, tip: 'GIRIS' },
    { urun_id: 2, miktar: 5, tip: 'CIKIS' }
  ]);
\`\`\`
      `,
      update: `
.update(data: object) → QueryBuilder
Kayıt güncelleme. .eq() ile filtreleme yapılmalıdır.

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .update({ durum: 'Pasif' })
  .eq('kupe_no', 'TR123456789');
\`\`\`
      `,
      delete: `
.delete() → QueryBuilder
Kayıt silme. .eq() ile filtreleme yapılmalıdır.

Örnek:
\`\`\`js
const { data } = await supabase
  .from('kizginlik_log')
  .delete()
  .eq('id', 123);
\`\`\`
      `,
      
      // Filter Methods
      eq: `
.eq(column: string, value: any) → QueryBuilder
Eşitlik filtresi (WHERE column = value)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .eq('cinsiyet', 'Dişi')
  .eq('durum', 'Aktif');
\`\`\`
      `,
      neq: `
.neq(column: string, value: any) → QueryBuilder
Eşit olmama filtresi (WHERE column != value)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .neq('durum', 'Pasif');
\`\`\`
      `,
      gt: `
.gt(column: string, value: any) → QueryBuilder
Büyüktür filtresi (WHERE column > value)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .gt('dogum_tarihi', '2020-01-01');
\`\`\`
      `,
      gte: `
.gte(column: string, value: any) → QueryBuilder
Büyük eşittir filtresi (WHERE column >= value)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('tohumlama')
  .select('*')
  .gte('tarih', '2024-01-01');
\`\`\`
      `,
      lt: `
.lt(column: string, value: any) → QueryBuilder
Küçüktür filtresi (WHERE column < value)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .lt('dogum_tarihi', '2022-01-01');
\`\`\`
      `,
      lte: `
.lte(column: string, value: any) → QueryBuilder
Küçük eşittir filtresi (WHERE column <= value)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('tohumlama')
  .select('*')
  .lte('tarih', '2024-12-31');
\`\`\`
      `,
      like: `
.like(column: string, pattern: string) → QueryBuilder
LIKE filtresi (case-sensitive, % wildcard)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .like('kupe_no', 'TR%');
\`\`\`
      `,
      ilike: `
.ilike(column: string, pattern: string) → QueryBuilder
ILIKE filtresi (case-insensitive, % wildcard)

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .ilike('ad', '%siyah%');
\`\`\`
      `,
      is: `
.is(column: string, value: null|boolean) → QueryBuilder
NULL veya boolean kontrolü

Örnek:
\`\`\`js
// NULL kontrolü
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .is('dogum_tarihi', null);

// Boolean kontrolü
const { data } = await supabase
  .from('tohumlama')
  .select('*')
  .is('gebelik_durumu', true);
\`\`\`
      `,
      in: `
.in(column: string, values: any[]) → QueryBuilder
IN filtresi (WHERE column IN (values))

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .in('cinsiyet', ['Dişi', 'Erkek']);
\`\`\`
      `,
      contains: `
.contains(column: string, value: any) → QueryBuilder
JSONB contains veya array contains

Örnek:
\`\`\`js
// JSONB contains
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .contains('ozellikler', { 'renk': 'siyah' });

// Array contains
const { data } = await supabase
  .from('hastalik_log')
  .select('*')
  .contains('belirtiler', ['ates', 'oksuruks']);
\`\`\`
      `,
      
      // Result Modifiers
      single: `
.single() → Promise<{ data, error }>
Tek kayıt bekleniyor. Hata fırlatmaz, null dönebilir.

Örnek:
\`\`\`js
const { data, error } = await supabase
  .from('hayvanlar')
  .select('*')
  .eq('kupe_no', 'TR123456789')
  .single();
\`\`\`
      `,
      maybeSingle: `
.maybeSingle() → Promise<{ data, error }>
Tek kayıt bekleniyor (0 veya 1 sonuç). multiple sonuçta hata verir.

Örnek:
\`\`\`js
const { data, error } = await supabase
  .from('hayvanlar')
  .select('*')
  .eq('id', 123)
  .maybeSingle();
\`\`\`
      `,
      limit: `
.limit(count: number) → QueryBuilder
Maksimum kayıt sayısı

Örnek:
\`\`\`js
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .limit(10);
\`\`\`
      `,
      offset: `
.offset(count: number) → QueryBuilder
Kayıt atla (pagination için limit ile kullanılır)

Örnek:
\`\`\`js
// Sayfa 2, 10'ar kayıt
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .limit(10)
  .offset(10);
\`\`\`
      `,
      order: `
.order(column: string, options?: { ascending?: boolean, nullsFirst?: boolean }) → QueryBuilder
Sıralama

Örnek:
\`\`\`js
// Artan sıralama
const { data } = await supabase
  .from('hayvanlar')
  .select('*')
  .order('dogum_tarihi', { ascending: true });

// Azalan sıralama
const { data } = await supabase
  .from('tohumlama')
  .select('*')
  .order('tarih', { ascending: false });
\`\`\`
      `,
      throwOnError: `
.throwOnError() → QueryBuilder
Hata durumunda exception fırlatır (error yerine)

Örnek:
\`\`\`js
try {
  const { data } = await supabase
    .from('hayvanlar')
    .select('*')
    .eq('id', 99999)
    .single()
    .throwOnError();
} catch (err) {
  console.error('Hata:', err.message);
}
\`\`\`
      `
    };

    if (method && docs[method]) {
      return {
        content: [{
          type: "text",
          text: `📚 Supabase.${method}()\n${docs[method]}`
        }]
      };
    }

    if (method && !docs[method]) {
      return {
        isError: true,
        content: [{
          type: "text",
          text: `⚠️ "${method}" metodu bulunamadı.\n\n` +
                `Mevcut metodlar: ${Object.keys(docs).join(', ')}\n\n` +
                `Örnek: .supabase_client_docs({ method: "from" })`
        }]
      };
    }

    const allDocs = Object.entries(docs)
      .map(([m, d]) => `### ${m}\n${d}`)
      .join('\n---\n');

    return {
      content: [{
        type: "text",
        text: `📚 Supabase JS Client Reference\n\n` +
              `Kullanılabilir metodlar: ${Object.keys(docs).join(', ')}\n\n` +
              `Detay için: .supabase_client_docs({ method: "methodName" })\n\n` +
              `---\n${allDocs}`
      }]
    };
  }
);

// Bağlan (tüm araçlar kaydedildikten sonra)
const transport = new StdioServerTransport();
await server.connect(transport);

console.error("✅ Gwen MCP Context7 Server başladı (hardcoded docs mode)");
