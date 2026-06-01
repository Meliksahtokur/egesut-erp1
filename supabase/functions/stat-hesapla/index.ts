import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface Tohumlama {
  id: string;
  hayvan_id: string;
  tarih: string;
  sonuc: string;
  deneme_no: number;
  sperma: string | null;
}

interface Hayvan {
  id: string;
  kupe_no: string;
  cinsiyet: string;
  grup: string;
  padok: string;
  durum: string;
  kisir: boolean;
  dogum_tarihi: string | null;
}

interface Dogum {
  anne_id: string;
}

function normalizeSperma(raw: string | null): string {
  if (!raw) return "bilinmiyor";
  return raw.split("|")[0].trim().toLowerCase().replace(/\s+/g, " ");
}

// Türkçe İ→i̇ unicode sorununu bypass: normalize + ASCII-safe karşılaştırma
function trLower(s: string): string {
  return s.replace(/İ/g, "i").replace(/I/g, "ı").toLowerCase();
}

function kategori(h: Hayvan, dogumYapanlar: Set<string>): "İnek" | "Düve" | "Bilinmiyor" {
  if (dogumYapanlar.has(h.id)) return "İnek";
  const g = trLower(h.grup);
  if (g.includes("düve") || g.includes("duve")) return "Düve";
  if (g.includes("inek") || g.includes("sağmal") || g.includes("sagmal") || g.includes("kuru") || g.includes("gebe"))
    return "İnek";
  return "Bilinmiyor";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const db = createClient(supabaseUrl, supabaseKey);

    const body = await req.json().catch(() => ({}));
    const padok: string | null = body.padok ?? null;
    const donemBaslangic: string = body.donem_baslangic ?? new Date(Date.now() - 365 * 86400000).toISOString().slice(0, 10);
    const donemBitis: string = body.donem_bitis ?? new Date().toISOString().slice(0, 10);
    const sonDonem: boolean = body.son_donem ?? true;

    // Ham veri çek — hesaplama burada yapılacak, SQL'de değil
    const [hayvanRes, tohRes, dogumRes] = await Promise.all([
      db.from("hayvanlar").select("id, kupe_no, cinsiyet, grup, padok, durum, kisir, dogum_tarihi")
        .eq("durum", "Aktif")
        .then(r => r),
      db.from("tohumlama").select("id, hayvan_id, tarih, sonuc, deneme_no, sperma")
        .gte("tarih", donemBaslangic)
        .lte("tarih", donemBitis)
        .then(r => r),
      db.from("dogum").select("anne_id").then(r => r),
    ]);

    if (hayvanRes.error) throw hayvanRes.error;
    if (tohRes.error) throw tohRes.error;
    if (dogumRes.error) throw dogumRes.error;

    const hayvanlar: Hayvan[] = hayvanRes.data ?? [];
    const tohumlamalar: Tohumlama[] = tohRes.data ?? [];
    const dogumlar: Dogum[] = dogumRes.data ?? [];

    const dogumYapanlar = new Set(dogumlar.map((d) => d.anne_id));
    const hayvanMap = new Map(hayvanlar.map((h) => [h.id, h]));

    // Padok filtresi
    const filteredHayvanlar = padok ? hayvanlar.filter((h) => h.padok === padok) : hayvanlar;
    const filteredIds = new Set(filteredHayvanlar.map((h) => h.id));

    // ── Demografik ──
    const demo = {
      toplam: filteredHayvanlar.length,
      inek: filteredHayvanlar.filter((h) => kategori(h, dogumYapanlar) === "İnek" && h.cinsiyet === "Dişi").length,
      duve: filteredHayvanlar.filter((h) => kategori(h, dogumYapanlar) === "Düve" && h.cinsiyet === "Dişi").length,
      buzagi: filteredHayvanlar.filter((h) => h.grup.toLowerCase().includes("buzağı") || h.grup.toLowerCase().includes("buzagi")).length,
      erkek: filteredHayvanlar.filter((h) => h.cinsiyet === "Erkek").length,
      kisir: filteredHayvanlar.filter((h) => h.kisir).length,
    };

    // ── Gebelik özet ──
    const disiTohumlamalar = tohumlamalar.filter((t) => {
      const h = hayvanMap.get(t.hayvan_id);
      return h && h.cinsiyet === "Dişi" && filteredIds.has(t.hayvan_id);
    });

    const sonuclu = disiTohumlamalar.filter((t) => t.sonuc !== "Bekliyor");
    const gebe = disiTohumlamalar.filter((t) => t.sonuc === "Gebe" || t.sonuc === "Doğum Yaptı");
    const bos = disiTohumlamalar.filter((t) => t.sonuc === "Boş");
    const abort = disiTohumlamalar.filter((t) => t.sonuc === "Abort");
    const bekleyen = disiTohumlamalar.filter((t) => t.sonuc === "Bekliyor");

    const gebelikOran = sonuclu.length > 0 ? Math.round((gebe.length / sonuclu.length) * 1000) / 10 : null;

    // ── Kategori bazlı ──
    const katMap = new Map<string, { toplam: number; gebe: number }>();
    for (const t of disiTohumlamalar) {
      const h = hayvanMap.get(t.hayvan_id);
      if (!h) continue;
      const kat = kategori(h, dogumYapanlar);
      if (!katMap.has(kat)) katMap.set(kat, { toplam: 0, gebe: 0 });
      const entry = katMap.get(kat)!;
      if (t.sonuc !== "Bekliyor") entry.toplam++;
      if (t.sonuc === "Gebe" || t.sonuc === "Doğum Yaptı") entry.gebe++;
    }
    const kategoriArr = Array.from(katMap.entries()).map(([ad, v]) => ({
      ad,
      toplam: v.toplam,
      gebe: v.gebe,
      oran: v.toplam > 0 ? Math.round((v.gebe / v.toplam) * 1000) / 10 : null,
    }));

    // ── Sperma performansı ──
    const spMap = new Map<string, { toplam: number; gebe: number }>();
    for (const t of sonuclu) {
      const sp = normalizeSperma(t.sperma);
      if (!spMap.has(sp)) spMap.set(sp, { toplam: 0, gebe: 0 });
      const entry = spMap.get(sp)!;
      entry.toplam++;
      if (t.sonuc === "Gebe" || t.sonuc === "Doğum Yaptı") entry.gebe++;
    }
    const spermaArr = Array.from(spMap.entries())
      .filter(([_, v]) => v.toplam >= 3)
      .map(([ad, v]) => ({
        ad,
        toplam: v.toplam,
        gebe: v.gebe,
        oran: v.toplam > 0 ? Math.round((v.gebe / v.toplam) * 1000) / 10 : null,
      }))
      .sort((a, b) => (b.oran ?? 0) - (a.oran ?? 0));

    // ── Deneme bazlı ──
    const denemeMap = new Map<number, { toplam: number; gebe: number }>();
    for (const t of sonuclu) {
      const no = t.deneme_no >= 3 ? 3 : t.deneme_no;
      if (!denemeMap.has(no)) denemeMap.set(no, { toplam: 0, gebe: 0 });
      const entry = denemeMap.get(no)!;
      entry.toplam++;
      if (t.sonuc === "Gebe" || t.sonuc === "Doğum Yaptı") entry.gebe++;
    }
    const denemeArr = Array.from(denemeMap.entries())
      .sort(([a], [b]) => a - b)
      .map(([no, v]) => ({
        no,
        toplam: v.toplam,
        gebe: v.gebe,
        oran: v.toplam > 0 ? Math.round((v.gebe / v.toplam) * 1000) / 10 : null,
      }));

    const result = {
      hayvan: demo,
      gebelik: {
        ozet: {
          toplam: sonuclu.length,
          gebe: gebe.length,
          bos: bos.length,
          abort: abort.length,
          bekleyen: bekleyen.length,
          oran: gebelikOran,
        },
        kategori: kategoriArr,
        sperma: spermaArr,
        deneme: denemeArr,
      },
      meta: {
        donem: { baslangic: donemBaslangic, bitis: donemBitis },
        padok,
        hesaplama: "edge-function",
        tarih: new Date().toISOString(),
      },
    };

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
