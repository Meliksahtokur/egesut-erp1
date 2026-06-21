import { tool } from "ai";
import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";

// db: kullanıcı JWT'siyle oluşturulmuş supabase client (RLS bağlamı)
export function buildTools(db: SupabaseClient, audit: (t: string, a: unknown) => void) {
  return {
    sql_sorgula: tool({
      description:
        "Veritabanına salt-okuma SQL SELECT sorgusu çalıştırır. Hayvan, aşı, tedavi, tohumlama, görev, stok verileri için kullan. Sadece SELECT. Sonuçları yorumlamadan önce ham veriyi al.",
      inputSchema: z.object({
        sql: z.string().describe("Çalıştırılacak SELECT sorgusu (tek statement)"),
      }),
      execute: async ({ sql }) => {
        audit("sql_sorgula", { sql });
        const { data, error } = await db.rpc("asistan_sql_calistir", { p_sql: sql });
        if (error) return { hata: error.message, sql };
        return { satirlar: data, sql };
      },
    }),

    hayvan_detay: tool({
      description:
        "Tek bir hayvanın tüm geçmişini (bilgi, tohumlama, tedavi, görev, işlem) küpe no veya ID ile getirir.",
      inputSchema: z.object({
        kupe_no: z.string().optional(),
        hayvan_id: z.string().optional(),
      }),
      execute: async ({ kupe_no, hayvan_id }) => {
        audit("hayvan_detay", { kupe_no, hayvan_id });
        const { data, error } = await db.rpc("asistan_hayvan_detay", {
          p_kupe: kupe_no ?? null,
          p_id: hayvan_id ?? null,
        });
        if (error) return { hata: error.message };
        return data;
      },
    }),
  };
}
