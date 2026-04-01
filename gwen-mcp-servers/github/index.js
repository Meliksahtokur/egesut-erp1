/**
 * Gwen Agent — GitHub MCP Server
 * GitHub işlemleri (Issue, PR, Commit)
 * 
 * ⚠️ BRANCH KORUMA KURALLARI:
 * - Main branch'e direkt yazma yasak (sadece orchestrator Claude için)
 * - Sadece feature/* branch'lerde çalışabilirsin
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Octokit } from "@octokit/rest";

const GITHUB_TOKEN = process.env.GITHUB_TOKEN || process.env.GITHUB_PERSONAL_ACCESS_TOKEN;

const octokit = GITHUB_TOKEN ? new Octokit({ auth: GITHUB_TOKEN }) : new Octokit();

const server = new McpServer({
  name: "gwen-mcp-github",
  version: "1.0.0"
});

// ──────────────────────────────────────────────────────────────────
// VALIDATION HELPERS
// ──────────────────────────────────────────────────────────────────

/**
 * Branch name validation for Gwen Agent
 * @param {string} branch - Branch name to validate
 * @param {boolean} requireFeaturePrefix - If true, must start with "feature/"
 * @returns {{ valid: boolean, error?: string }}
 */
function validateBranch(branch, requireFeaturePrefix = false) {
  // Main branch koruma: Gwen Agent main branch'e direkt yazamaz
  if (branch === "main") {
    return {
      valid: false,
      error: "❌ Main branch'e direkt yazma yetkisi yok! Sadece feature/* branch'lerde çalışabilirsin. Main branch sadece orchestrator Claude içindir."
    };
  }

  // Feature branch prefix kontrolü
  if (requireFeaturePrefix && !branch.startsWith("feature/")) {
    return {
      valid: false,
      error: `❌ Source branch 'feature/' ile başlamalı (örn: feature/gwen-task). Verilen: "${branch}"`
    };
  }

  return { valid: true };
}

// ──────────────────────────────────────────────────────────────────
// TOOLS
// ──────────────────────────────────────────────────────────────────

/**
 * Repository bilgisi getir
 */
server.tool(
  "get_repo_info",
  "GitHub repository bilgilerini getir",
  {
    owner: z.string().optional().describe("Repo sahibi (varsayılan: mevcut repo)"),
    repo: z.string().optional().describe("Repo adı (varsayılan: mevcut repo)")
  },
  async ({ owner, repo }) => {
    try {
      // Varsayılan: egesut-erp1
      const o = owner || "Meliksahtokur";
      const r = repo || "egesut-erp1";

      const { data } = await octokit.repos.get({ owner: o, repo: r });

      return {
        content: [{
          type: "text",
          text: `📦 ${data.full_name}\n\n` +
                `⭐ Stars: ${data.stargazers_count}\n` +
                `🍴 Forks: ${data.forks_count}\n` +
                `📝 Default Branch: ${data.default_branch}\n` +
                `🕒 Son Update: ${data.updated_at}\n` +
                `🔗 ${data.html_url}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `GitHub Hatası: ${err.message}` }]
      };
    }
  }
);

/**
 * Pull Request oluştur (base branch main olamaz)
 * ⚠️ Gwen Agent sadece feature/* branch'lerden PR açabilir
 */
server.tool(
  "create_pull_request",
  "PR oluştur (base branch main olamaz)",
  {
    title: z.string().describe("PR başlığı"),
    body: z.string().describe("PR açıklaması"),
    head: z.string().describe("Source branch (feature/gwen-*)"),
    base: z.string().default("main").describe("Target branch (main olamaz - orchestrator onayı gerekir)")
  },
  async ({ title, body, head, base }) => {
    try {
      // Validation: head branch feature/ ile başlamalı
      const headValidation = validateBranch(head, true);
      if (!headValidation.valid) {
        return {
          isError: true,
          content: [{ type: "text", text: headValidation.error }]
        };
      }

      // Validation: base branch main olamaz
      if (base === "main") {
        return {
          isError: true,
          content: [{ type: "text", text: "❌ Main branch'e direkt yazma yetkisi yok! Sadece feature/* branch'lerde çalışabilirsin. Main branch sadece orchestrator Claude içindir." }]
        };
      }

      const { data } = await octokit.pulls.create({
        owner: "Meliksahtokur",
        repo: "egesut-erp1",
        title,
        body,
        head,
        base
      });

      return {
        content: [{
          type: "text",
          text: `✅ PR oluşturuldu!\n\n` +
                `#${data.number} — ${data.title}\n` +
                `🔗 ${data.html_url}\n` +
                `📊 Durum: ${data.state}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `GitHub Hatası: ${err.message}` }]
      };
    }
  }
);

/**
 * Issue oluştur
 */
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
      const { data } = await octokit.issues.create({
        owner: "Meliksahtokur",
        repo: "egesut-erp1",
        title,
        body,
        labels: labels || []
      });

      return {
        content: [{
          type: "text",
          text: `✅ Issue oluşturuldu!\n\n` +
                `#${data.number} — ${data.title}\n` +
                `🔗 ${data.html_url}\n` +
                `🏷️ Etiketler: ${(data.labels || []).map(l => l.name).join(', ') || 'yok'}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `GitHub Hatası: ${err.message}` }]
      };
    }
  }
);

/**
 * Son commit'leri listele (main branch için orchestrator onayı gerekir)
 * ⚠️ Varsayılan branch "main" yerine feature/* pattern'i kullanır
 */
server.tool(
  "get_recent_commits",
  "Commit'leri listele (main branch için orchestrator onayı gerekir)",
  {
    limit: z.number().optional().default(10).describe("Kaç commit gösterilecek"),
    branch: z.string().optional().default("feature/*").describe("Branch adı (varsayılan: feature/*, main için onay gerekir)")
  },
  async ({ limit, branch }) => {
    try {
      // Validation: main branch koruması
      if (branch === "main") {
        return {
          isError: true,
          content: [{ type: "text", text: "❌ Main branch'e direkt yazma yetkisi yok! Sadece feature/* branch'lerde çalışabilirsin. Main branch sadece orchestrator Claude içindir." }]
        };
      }

      // feature/* pattern'i için GitHub API'de geçerli branch bulmaya çalış
      let targetBranch = branch;
      if (branch === "feature/*") {
        // En son güncellenen feature branch'i bul
        const { data: branches } = await octokit.repos.listBranches({
          owner: "Meliksahtokur",
          repo: "egesut-erp1",
          per_page: 100
        });

        const featureBranches = branches.filter(b => b.name.startsWith("feature/"));
        if (featureBranches.length === 0) {
          return {
            isError: true,
            content: [{ type: "text", text: "❌ Hiç feature/* branch bulunamadı. Önce bir feature branch oluştur." }]
          };
        }

        // En son güncellenen feature branch'i kullan
        const latestFeatureBranch = featureBranches[0].name;
        targetBranch = latestFeatureBranch;
        console.error(`ℹ️ feature/* pattern için en son branch kullanılıyor: ${latestFeatureBranch}`);
      }

      const { data } = await octokit.repos.listCommits({
        owner: "Meliksahtokur",
        repo: "egesut-erp1",
        sha: targetBranch,
        per_page: limit
      });

      const commits = data.map(c =>
        `- ${c.sha.substring(0, 7)} — ${c.commit.message.split('\n')[0]} (${c.commit.author.name})`
      ).join('\n');

      return {
        content: [{
          type: "text",
          text: `📝 Son ${limit} commit (${targetBranch}):\n\n${commits}`
        }]
      };
    } catch (err) {
      return {
        isError: true,
        content: [{ type: "text", text: `GitHub Hatası: ${err.message}` }]
      };
    }
  }
);

// Bağlan (tüm araçlar kaydedildikten sonra)
const transport = new StdioServerTransport();
await server.connect(transport);

console.error("✅ Gwen MCP GitHub Server başladı (branch koruma aktif)");
