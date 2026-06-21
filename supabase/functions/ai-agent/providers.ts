import { createOpenAICompatible } from "@ai-sdk/openai-compatible";

// MVP: tek model MiniMax-M3. Anthropic/OpenAI factory'leri Faz 6'da eklenir.
export function getModel(_name: string) {
  const minimax = createOpenAICompatible({
    name: "minimax",
    apiKey: Deno.env.get("MINIMAX_API_KEY") ?? "",
    baseURL: "https://api.minimax.io/v1",
  });
  return minimax.chatModel("MiniMax-M3");
}

export const DEFAULT_MODEL = "minimax-m3";
