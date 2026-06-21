import { generateText } from "ai";
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const minimax = createOpenAICompatible({
      name: "minimax",
      apiKey: Deno.env.get("MINIMAX_API_KEY") ?? "",
      baseURL: "https://api.minimax.io/v1",
    });
    const { text } = await generateText({
      model: minimax.chatModel("MiniMax-M3"),
      prompt: "Tek kelimeyle cevap ver: Türkiye'nin başkenti?",
    });
    return new Response(JSON.stringify({ ok: true, text }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
