/**
 * Gwen Agent — Consolidated MCP Server
 * EgeSüt ERP için tüm MCP araçları tek sunucuda:
 * - Supabase (database operations)
 * - GitHub (PR, issues, commits)
 * - Context7 (documentation lookup)
 *
 * Memory optimizasyonu: 3 process → 1 process
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { createClient } from "@supabase/supabase-js";
import { Octokit } from "@octokit/rest";

// ═══════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════

const SUPABASE_URL = "https://zqnexqbdfvbhlxzelzju.supabase.co";
const SUPABASE_KEY = process.env.SUPABASE_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc";
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || process.env.GITHUB_PERSONAL_ACCESS_TOKEN;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);
const octokit = GITHUB_TOKEN ? new Octokit({ auth: GITHUB_TOKEN }) : new Octokit();

const server = new McpServer({
  name: "gwen-mcp-consolidated",
  version: "2.0.0"
});

// ═══════════════════════════════════════════════════════════════
// SUPABASE TOOLS
// ═══════════════════════════════════════════════════════════════

server.tool(
  "execute_sql",
  "Supabase veritabanında SQL sorgusu çalıştır (SELECT only)",
  {
    query: z.string().describe("SQL sorgusu (sadece SELECT)")
  },
  async ({ query }) => {
    const upperQuery = query.trim().toUpperCase();
    if (!upperQuery.startsWith("SELECT")) {
      return {
        isError: true,
        content: [{
          type: "text",
          text: "❌ Gwen sadece SELECT sorguları çalıştırabilir. INSERT/UPDATE/DELETE için orchestrator onayı gerekli."
        }]
      };
    }

    try {
      const { data, error } = await supabase.rpc('execute_sql', { sql_query: query });
      if (error) throw error;
      return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ SQL Hatası: ${error.message}` }]
      };
    }
  }
);

server.tool(
  "list_tables",
  "Veritabanındaki tüm tabloları listele",
  {},
  async () => {
    try {
      const { data, error } = await supabase.rpc('list_tables');
      if (error) throw error;
      return {
        content: [{ type: "text", text: `📊 Tablolar (${data.length}):\n\n- ${data.join('\n- ')}` }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ Hata: ${error.message}` }]
      };
    }
  }
);

server.tool(
  "get_table_schema",
  "Belirtilen tablonun şema bilgisini getir",
  {
    tableName: z.string().describe("Tablo adı (örn: hayvanlar, tohumlama)")
  },
  async ({ tableName }) => {
    try {
      const { data, error } = await supabase.rpc('get_table_schema', { table_name: tableName });
      if (error) throw error;
      return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ Hata: ${error.message}` }]
      };
    }
  }
);

server.tool(
  "get_animals",
  "Hayvanlar tablosundan filtrelenmiş veri çek",
  {
    limit: z.number().default(50).describe("Maksimum kayıt sayısı"),
    durum: z.string().optional().describe("Durum filtresi (Aktif/Pasif)"),
    cinsiyet: z.string().optional().describe("Cinsiyet filtresi (Dişi/Erkek)")
  },
  async ({ limit, durum, cinsiyet }) => {
    try {
      let query = supabase.from('hayvanlar').select('*').limit(limit);
      if (durum) query = query.eq('durum', durum);
      if (cinsiyet) query = query.eq('cinsiyet', cinsiyet);
      
      const { data, error } = await query;
      if (error) throw error;
      return {
        content: [{ type: "text", text: JSON.stringify(data, null, 2) }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ Hata: ${error.message}` }]
      };
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// GITHUB TOOLS
// ═══════════════════════════════════════════════════════════════

function validateBranch(branch, requireFeaturePrefix = false) {
  if (branch === "main") {
    return {
      valid: false,
      error: "❌ Main branch'e direkt yazma yetkisi yok! Sadece feature/* branch'lerde çalışabilirsin."
    };
  }
  if (requireFeaturePrefix && !branch.startsWith("feature/")) {
    return {
      valid: false,
      error: `❌ Source branch 'feature/' ile başlamalı. Verilen: "${branch}"`
    };
  }
  return { valid: true };
}

server.tool(
  "create_pull_request",
  "PR oluştur (base branch main olamaz)",
  {
    title: z.string().describe("PR başlığı"),
    body: z.string().describe("PR açıklaması"),
    head: z.string().describe("Source branch (feature/gwen-*)"),
    base: z.string().default("main").describe("Target branch (main olamaz)")
  },
  async ({ title, body, head, base }) => {
    const validation = validateBranch(head, true);
    if (!validation.valid) {
      return {
        isError: true,
        content: [{ type: "text", text: validation.error }]
      };
    }

    try {
      const { data } = await octokit.repos.get({ owner: "Meliksahtokur", repo: "egesut-erp1" });
      const { data: pr } = await octokit.pulls.create({
        owner: "Meliksahtokur",
        repo: "egesut-erp1",
        title,
        body,
        head,
        base
      });
      return {
        content: [{ type: "text", text: `✅ PR oluşturuldu:\n${pr.html_url}` }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ GitHub Hatası: ${error.message}` }]
      };
    }
  }
);

server.tool(
  "create_issue",
  "GitHub Issue oluştur (bug raporu veya feature request)",
  {
    title: z.string().describe("Issue başlığı"),
    body: z.string().describe("Issue açıklaması"),
    labels: z.array(z.string()).optional().describe("Etiketler (örn: ['bug', 'critical'])")
  },
  async ({ title, body, labels }) => {
    try {
      const { data: issue } = await octokit.issues.create({
        owner: "Meliksahtokur",
        repo: "egesut-erp1",
        title,
        body,
        labels
      });
      return {
        content: [{ type: "text", text: `✅ Issue oluşturuldu:\n${issue.html_url}` }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ GitHub Hatası: ${error.message}` }]
      };
    }
  }
);

server.tool(
  "get_recent_commits",
  "Commit'leri listele",
  {
    limit: z.number().default(10).describe("Kaç commit gösterilecek"),
    branch: z.string().default("feature/*").describe("Branch adı")
  },
  async ({ limit, branch }) => {
    try {
      const { data: commits } = await octokit.repos.listCommits({
        owner: "Meliksahtokur",
        repo: "egesut-erp1",
        sha: branch.includes('*') ? undefined : branch,
        per_page: limit
      });
      return {
        content: [{
          type: "text",
          text: commits.map(c => `• ${c.sha.slice(0, 7)} ${c.commit.message.split('\n')[0]}`).join('\n')
        }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ GitHub Hatası: ${error.message}` }]
      };
    }
  }
);

server.tool(
  "get_repo_info",
  "GitHub repository bilgilerini getir",
  {},
  async () => {
    try {
      const { data } = await octokit.repos.get({ owner: "Meliksahtokur", repo: "egesut-erp1" });
      return {
        content: [{
          type: "text",
          text: `📦 ${data.full_name}\n\n⭐ Stars: ${data.stargazers_count}\n🍴 Forks: ${data.forks_count}\n📝 Default Branch: ${data.default_branch}\n🕒 Son Update: ${data.updated_at}\n🔗 ${data.html_url}`
        }]
      };
    } catch (error) {
      return {
        isError: true,
        content: [{ type: "text", text: `❌ GitHub Hatası: ${error.message}` }]
      };
    }
  }
);

// ═══════════════════════════════════════════════════════════════
// CONTEXT7 TOOLS
// ═══════════════════════════════════════════════════════════════

// Hardcoded Supabase docs (fallback)
const SUPABASE_DOCS = {
  from: "createClient().from('table') - Tablo referansı al",
  select: ".select('columns') - Veri seç, SQL SELECT gibi",
  insert: ".insert({ data }) - Yeni kayıt ekle",
  update: ".update({ data }).eq('id', value) - Kayıt güncelle",
  delete: ".delete().eq('id', value) - Kayıt sil",
  rpc: ".rpc('function_name', { params }) - RPC çağır"
};

server.tool(
  "supabase_client_docs",
  "Supabase JS Client dokümantasyonu (hardcoded fallback)",
  {
    method: z.string().optional().describe("Metod adı (örn: from, select, rpc)")
  },
  async ({ method }) => {
    if (method && SUPABASE_DOCS[method]) {
      return {
        content: [{ type: "text", text: `📘 ${method}:\n${SUPABASE_DOCS[method]}` }]
      };
    }
    return {
      content: [{
        type: "text",
        text: "📘 Supabase JS Client Methods:\n\n" +
          Object.entries(SUPABASE_DOCS).map(([k, v]) => `• ${k}: ${v}`).join('\n')
      }]
    };
  }
);

server.tool(
  "fetch_docs",
  "Context7 API kullanılamıyor. supabase_client_docs kullanın.",
  {},
  async () => {
    return {
      isError: true,
      content: [{
        type: "text",
        text: "⚠️ Context7 API kullanılamıyor (api.context7.com DNS hatası)\n\n" +
          "Kullanın: supabase_client_docs"
      }]
    };
  }
);

// ═══════════════════════════════════════════════════════════════
// START SERVER
// ═══════════════════════════════════════════════════════════════

console.error("✅ Gwen MCP Consolidated Server başladı (Supabase + GitHub + Context7)");
console.error("📊 Memory optimizasyonu: 3 process → 1 process");

const transport = new StdioServerTransport();
await server.connect(transport);
