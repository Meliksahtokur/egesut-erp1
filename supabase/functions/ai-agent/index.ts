import { streamText, stepCountIs } from "ai";
import { createClient } from "@supabase/supabase-js";
import { getModel, DEFAULT_MODEL } from "./providers.ts";
import { SYSTEM_PROMPT } from "./prompt.ts";
import { buildTools } from "./tools.ts";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_ANON = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Expose-Headers": "X-Thread-Id",
};

// MiniMax-M3 düşünce bloklarını nihai metinden temizle (eşli + öksüz etiketler)
function thinkTemizle(s: string): string {
  return (s ?? "")
    .replace(/<think>[\s\S]*?<\/think>/g, "")
    .replace(/<\/?think>/g, "")
    .trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Oturum gerekli" }), {
      status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Kullanıcının JWT'siyle client → RLS bağlamı korunur
  const db = createClient(SB_URL, SB_ANON, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData } = await db.auth.getUser();
  if (!userData?.user) {
    return new Response(JSON.stringify({ error: "Geçersiz oturum" }), {
      status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const userId = userData.user.id;

  let body: { mesaj: string; thread_id?: string };
  try { body = await req.json(); } catch {
    return new Response(JSON.stringify({ error: "Geçersiz istek" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const userMesaj = (body.mesaj ?? "").trim();
  if (!userMesaj) {
    return new Response(JSON.stringify({ error: "Boş mesaj" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Thread: yoksa oluştur
  let threadId = body.thread_id;
  if (!threadId) {
    const { data: t } = await db.from("agent_threads")
      .insert({ kullanici_id: userId, baslik: userMesaj.slice(0, 40) })
      .select("id").single();
    threadId = t?.id;
  }

  // Geçmişi yükle (son 20 mesaj)
  const { data: gecmis } = await db.from("agent_messages")
    .select("rol, icerik").eq("thread_id", threadId)
    .order("created_at", { ascending: true }).limit(20);

  const messages = [
    ...(gecmis ?? []).map((m) => ({ role: m.rol as "user" | "assistant", content: m.icerik })),
    { role: "user" as const, content: userMesaj },
  ];

  // Kullanıcı mesajını kaydet
  await db.from("agent_messages").insert({ thread_id: threadId, rol: "user", icerik: userMesaj });

  // Audit (çalıştırılan tool/SQL'i metadata için sakla)
  const auditKayit: { tool: string; args: unknown }[] = [];
  const audit = (t: string, a: unknown) => auditKayit.push({ tool: t, args: a });

  const result = streamText({
    model: getModel(DEFAULT_MODEL),
    system: SYSTEM_PROMPT,
    messages,
    tools: buildTools(db, audit),
    temperature: 0.5,        // doğal/akıcı ton — çok düşük sıcaklık robotik yapıyordu
    stopWhen: stepCountIs(8),
    onFinish: async ({ text }) => {
      const sonSql = auditKayit.filter((a) => a.tool === "sql_sorgula").pop() as
        { args?: { sql?: string } } | undefined;
      const sonPlan = auditKayit.filter((a) => a.tool === "aksiyon_plani").pop() as
        { args?: { sonuc?: { ok?: boolean; plan_id?: string; onizleme?: string[] } } } | undefined;
      await db.from("agent_messages").insert({
        thread_id: threadId,
        rol: "assistant",
        icerik: thinkTemizle(text),
        metadata: {
          model: DEFAULT_MODEL,
          sql: sonSql?.args?.sql ?? null,
          plan: sonPlan?.args?.sonuc ?? null,
        },
      });
      await db.from("agent_threads").update({ updated_at: new Date().toISOString() }).eq("id", threadId);
    },
  });

  // SSE stream + thread_id header
  const resp = result.toTextStreamResponse();
  const headers = new Headers(resp.headers);
  Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));
  headers.set("X-Thread-Id", threadId ?? "");
  return new Response(resp.body, { status: resp.status, headers });
});
