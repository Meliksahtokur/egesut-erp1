/**
 * Gwen Agent — Exa MCP Server
 * Exa API için wrapper (stdio transport)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import Exa from "exa-js";

const EXA_API_KEY = process.env.EXA_API_KEY || "";

const server = new McpServer({
  name: "gwen-mcp-exa",
  version: "1.0.0"
});

// Exa client oluştur
const exa = new Exa(EXA_API_KEY);

/**
 * Web search yap
 */
server.tool(
  "web_search_exa",
  "Web'de arama yap (Exa API)",
  {
    query: z.string().describe("Arama sorgusu"),
    limit: z.number().optional().default(10).describe("Sonuç sayısı")
  },
  async ({ query, limit }) => {
    try {
      const result = await exa.searchAndContents(query, {
        numResults: limit,
        text: true
      });

      if (!result.results || result.results.length === 0) {
        return {
          content: [{ type: "text", text: `🔍 "${query}" için sonuç bulunamadı.` }]
        };
      }

      const results = result.results.map((r, i) =>
        `${i + 1}. **${r.title || 'Başlıksız'}**\n   ${r.url}\n   ${r.text?.substring(0, 200) || 'Özet yok'}...`
      ).join('\n\n');

      return {
        content: [{
          type: "text",
          text: `🔍 "${query}" için sonuçlar:\n\n${results}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Exa Hatası: ${err.message}` }]
      };
    }
  }
);

/**
 * URL içeriğini al
 */
server.tool(
  "get_content_exa",
  "Web sayfasının içeriğini al",
  {
    url: z.string().describe("Sayfa URL'i")
  },
  async ({ url }) => {
    try {
      const result = await exa.getContents([url]);

      if (!result.results || result.results.length === 0) {
        return {
          content: [{ type: "text", text: `📄 ${url} için içerik alınamadı.` }]
        };
      }

      const content = result.results[0];
      return {
        content: [{
          type: "text",
          text: `📄 ${url}\n\n${content.text?.substring(0, 2000) || 'İçerik yok'}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `Exa Hatası: ${err.message}` }]
      };
    }
  }
);

// Bağlan
const transport = new StdioServerTransport();
await server.connect(transport);

console.error("✅ Gwen MCP Exa Server başladı");
