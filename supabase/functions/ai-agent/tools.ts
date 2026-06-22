import { tool } from "ai";
import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";

// db: kullanıcı JWT'siyle oluşturulmuş supabase client (RLS bağlamı)
export function buildTools(db: SupabaseClient, audit: (t: string, a: unknown) => void) {
  return {
    sql_sorgula: tool({
      description:
        "Canlı veritabanına salt-okuma SQL SELECT çalıştırır (hayvan, aşı, tedavi, tohumlama, görev, stok). Veriye dayanan her soruda gönül rahatlığıyla kullan; gerekirse arka arkaya birkaç kez. Sayım/oran için COUNT/GROUP BY ile özet çıkar. Sadece SELECT.",
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

    aksiyon_plani: tool({
      description:
        "Yazma işlemi için ONAY PLANI oluşturur — HİÇBİR ŞEY YAZMAZ, sadece önizleme döner. " +
        "Veriyi/ID'leri önce sql_sorgula ile çöz, sonra tipli adımları buraya ver. " +
        "Kullanıcıya tek konsolide önizleme gösterilir; onaylarsa ayrı adımda uygulanır. " +
        "adimlar: [{tip, parametreler}]. Bağımlı adımda önceki çıktıya '$N.anahtar' ile başvur (N=1'den).",
      inputSchema: z.object({
        adimlar: z.array(z.object({
          tip: z.string(),
          parametreler: z.record(z.any()),
        })).describe("Tipli adım listesi"),
      }),
      execute: async ({ adimlar }) => {
        const { data, error } = await db.rpc("asistan_plan_olustur", {
          p_thread_id: null, p_adimlar: adimlar,
        });
        const sonuc = error ? { hata: error.message } : data;
        audit("aksiyon_plani", { adimlar, sonuc });
        return sonuc;
      },
    }),

    plani_uygula: tool({
      description:
        "SADECE kullanıcı önizlemeyi onayladığını AÇIKÇA söylediğinde çağır. Verilen plan_id'yi atomik uygular. " +
        "Kullanıcı onaylamadıysa ASLA çağırma.",
      inputSchema: z.object({
        plan_id: z.string().describe("aksiyon_plani'nin döndürdüğü plan_id"),
      }),
      execute: async ({ plan_id }) => {
        const { data, error } = await db.rpc("asistan_plan_uygula", { p_plan_id: plan_id });
        const sonuc = error ? { hata: error.message } : data;
        audit("plani_uygula", { plan_id, sonuc });
        return sonuc;
      },
    }),
  };
}
