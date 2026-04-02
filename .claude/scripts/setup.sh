#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# EgeSüt ERP — Yeni Makine Kurulum Scripti
# Kullanım: bash .claude/scripts/setup.sh
# ═══════════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     EgeSüt ERP — Kurulum Scripti         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─── PROJE KÖK DIZINI ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

info "Proje dizini: $PROJECT_ROOT"
echo ""

# ─── 1. ÖN KOŞULLAR ──────────────────────────────────────────
echo "── Ön Koşullar ──────────────────────────────────────────"

# Node.js
if ! command -v node &>/dev/null; then
  fail "Node.js bulunamadı. Önce Node.js 18+ kur: https://nodejs.org"
fi
NODE_VER=$(node -e "console.log(process.versions.node.split('.')[0])")
if [ "$NODE_VER" -lt 18 ]; then
  fail "Node.js 18+ gerekli, mevcut: $(node --version)"
fi
ok "Node.js $(node --version)"

# npm
command -v npm &>/dev/null && ok "npm $(npm --version)" || fail "npm bulunamadı"

# git
command -v git &>/dev/null && ok "git $(git --version | awk '{print $3}')" || fail "git bulunamadı"

echo ""

# ─── 2. CLAUDE CODE CLI ───────────────────────────────────────
echo "── Claude Code CLI ──────────────────────────────────────"

if command -v claude &>/dev/null; then
  ok "Claude Code zaten kurulu: $(claude --version 2>/dev/null || echo 'versiyon alınamadı')"
else
  info "Claude Code kuruluyor..."
  npm install -g @anthropic/claude-code
  ok "Claude Code kuruldu"
fi

echo ""

# ─── 3. GITHUB CLI (gh) ───────────────────────────────────────
echo "── GitHub CLI (gh) ──────────────────────────────────────"

GH_INSTALLED=false
if command -v gh &>/dev/null; then
  GH_VER=$(gh --version 2>&1 | head -1)
  if [ $? -eq 0 ] && [ -n "$GH_VER" ]; then
    ok "GitHub CLI kurulu: $GH_VER"
    GH_INSTALLED=true
  else
    warn "gh komutu bulundu ama çalışmıyor (binary uyumsuzluğu)"
  fi
fi

if [ "$GH_INSTALLED" = false ]; then
  info "GitHub CLI kurulumu deneniyor..."
  
  # npm ile dene
  if command -v npm &>/dev/null; then
    npm install -g gh 2>/dev/null && ok "GitHub CLI npm ile kuruldu" || true
  fi
  
  # Binary ile dene
  if ! command -v gh &>/dev/null; then
    info "GitHub CLI binary indiriliyor..."
    curl -sL -o /tmp/gh.tar.gz "https://github.com/cli/cli/releases/download/v2.69.0/gh_2.69.0_linux_amd64.tar.gz" 2>/dev/null && \
    tar xzf /tmp/gh.tar.gz -C /tmp/ 2>/dev/null && \
    cp /tmp/gh_2.69.0_linux_amd64/bin/gh /usr/local/bin/ 2>/dev/null && \
    ok "GitHub CLI binary olarak kuruldu" || \
    warn "GitHub CLI kurulumu başarısız — GitHub MCP token ile çalışır (CLI opsiyonel)"
  fi
fi

# gh auth kontrolü
if command -v gh &>/dev/null; then
  GH_AUTH=$(gh auth status 2>&1)
  if echo "$GH_AUTH" | grep -q "Logged in"; then
    ok "GitHub CLI auth durumu: Aktif"
  else
    warn "GitHub CLI auth gerekli: gh auth login"
  fi
fi

echo ""

# ─── 4. API ANAHTARLARI ───────────────────────────────────────
echo "── API Anahtarları ──────────────────────────────────────"
echo "  (boş bırakırsan atlanır, oturum içinde sonradan eklenebilir)"
echo ""

# Supabase Token
read -rp "  Supabase Access Token (sbp_...) [Enter=atla]: " SUPABASE_TOKEN
if [ -z "$SUPABASE_TOKEN" ]; then
  warn "Supabase token atlandı — DB MCP çalışmaz (sonradan .mcp.json'a ekle)"
  SUPABASE_TOKEN="SUPABASE_TOKEN_BURAYA"
else
  ok "Supabase token alındı"
fi

# GitHub Token
read -rp "  GitHub Personal Access Token (ghp_...) [Enter=atla]: " GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
  warn "GitHub token atlandı — GitHub MCP çalışmaz (sonradan .mcp.json'a ekle)"
  GITHUB_TOKEN="GITHUB_TOKEN_BURAYA"
else
  ok "GitHub token alındı"
fi

echo ""

# ─── 5. ~/.claude/settings.json ───────────────────────────────
echo "── Global Claude Ayarları (~/.claude/settings.json) ─────"

mkdir -p "$CLAUDE_DIR"

if [ -f "$CLAUDE_DIR/settings.json" ]; then
  warn "settings.json zaten var — üzerine yazılıyor"
fi

cat > "$CLAUDE_DIR/settings.json" <<EOF
{
  "permissions": {
    "allow": [
      "Read", "Grep", "Glob", "WebFetch",
      "Bash(grep:*)", "Bash(rg:*)", "Bash(curl:*)", "Bash(wget:*)",
      "Bash(cat:*)", "Bash(ls:*)", "Bash(find:*)", "Bash(echo:*)",
      "Bash(head:*)", "Bash(tail:*)", "Bash(wc:*)", "Bash(sort:*)",
      "Bash(uniq:*)", "Bash(which:*)", "Bash(pwd:*)", "Bash(whoami:*)",
      "Bash(ps:*)", "Bash(df:*)", "Bash(du:*)",
      "Bash(git log:*)", "Bash(git status:*)", "Bash(git diff:*)",
      "Bash(git branch:*)", "Bash(git show:*)",
      "Bash(python3 -c:*)", "Bash(python -c:*)",
      "Bash(jq:*)", "Bash(awk:*)"
    ],
    "additionalDirectories": ["$HOME/.claude"]
  },
  "enabledPlugins": {
    "github@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "supabase@claude-plugins-official": true,
    "hookify@claude-plugins-official": true,
    "coderabbit@claude-plugins-official": true
  }
}
EOF

ok "~/.claude/settings.json oluşturuldu"
echo ""

# ─── 6. .mcp.json ─────────────────────────────────────────────
echo "── MCP Sunucu Konfigürasyonu (.mcp.json) ─────────────────"

cat > "$PROJECT_ROOT/.mcp.json" <<EOF
{
  "mcpServers": {
    "supabase": {
      "type": "http",
      "url": "https://mcp.supabase.com/mcp",
      "headers": {
        "Authorization": "Bearer $SUPABASE_TOKEN"
      }
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$GITHUB_TOKEN"
      }
    }
  }
}
EOF

ok ".mcp.json oluşturuldu"
echo ""

# ─── 7. .claude/settings.local.json ──────────────────────────
echo "── Proje İzinleri (.claude/settings.local.json) ──────────"

mkdir -p "$PROJECT_ROOT/.claude"

cat > "$PROJECT_ROOT/.claude/settings.local.json" <<EOF
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(node --check:*)",
      "Bash(node:*)",
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(python3:*)",
      "Bash(bash $PROJECT_ROOT/.claude/scripts/startup-check.sh)",
      "Bash(chmod:*)",
      "Skill(commit-commands:commit-push-pr)",
      "mcp__supabase__list_projects",
      "mcp__supabase__execute_sql",
      "mcp__supabase__list_migrations",
      "mcp__supabase__apply_migration",
      "mcp__supabase__get_advisors",
      "mcp__supabase__get_logs",
      "mcp__supabase__list_tables",
      "mcp__supabase__list_extensions",
      "mcp__supabase__get_project",
      "mcp__supabase__get_project_url",
      "mcp__supabase__search_docs",
      "mcp__supabase__generate_typescript_types",
      "mcp__github__create_issue",
      "mcp__github__get_issue",
      "mcp__github__list_issues",
      "mcp__github__add_issue_comment",
      "mcp__github__update_issue",
      "mcp__github__get_pull_request",
      "mcp__github__list_pull_requests",
      "mcp__github__get_pull_request_status",
      "mcp__github__get_pull_request_files",
      "mcp__github__get_pull_request_comments",
      "mcp__github__create_pull_request",
      "mcp__github__list_commits",
      "mcp__github__get_file_contents",
      "mcp__github__search_code",
      "mcp__context7__resolve-library-id",
      "mcp__context7__query-docs",
      "mcp__plugin_context7_context7__resolve-library-id",
      "mcp__plugin_context7_context7__query-docs"
    ]
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["supabase"],
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $PROJECT_ROOT/.claude/scripts/startup-check.sh"
          }
        ]
      }
    ],
    "PostToolUse": []
  }
}
EOF

ok ".claude/settings.local.json oluşturuldu"
echo ""

# ─── 8. SCRIPT İZİNLERİ ───────────────────────────────────────
chmod +x "$PROJECT_ROOT/.claude/scripts/"*.sh 2>/dev/null || true
ok "Script izinleri ayarlandı"
echo ""

# ─── 9. QWEN SKILLS/AGENTS SYNC ───────────────────────────────
echo "── Qwen Skills & Agents Sync ─────────────────────────────"

# ~/.qwen dizini oluştur
mkdir -p "$HOME/.qwen/skills" "$HOME/.qwen/agents"

# .agents/qwen/ varsa sync et
if [ -d "$PROJECT_ROOT/.agents/qwen" ]; then
  info ".agents/qwen/ dizininden ~/.qwen/ kopyalanıyor..."
  
  # Skills sync
  if [ -d "$PROJECT_ROOT/.agents/qwen/skills" ]; then
    for skill in "$PROJECT_ROOT/.agents/qwen/skills"/*; do
      if [ -d "$skill" ]; then
        skill_name=$(basename "$skill")
        cp -r "$skill" "$HOME/.qwen/skills/$skill_name"
        ok "Skill: $skill_name"
      fi
    done
  fi
  
  # Agents sync
  if [ -d "$PROJECT_ROOT/.agents/qwen/agents" ]; then
    for agent in "$PROJECT_ROOT/.agents/qwen/agents"/*.md; do
      if [ -f "$agent" ]; then
        agent_name=$(basename "$agent" .md)
        cp "$agent" "$HOME/.qwen/agents/$agent_name.md"
        ok "Agent: $agent_name"
      fi
    done
  fi
else
  warn ".agents/qwen/ dizini bulunamadı — skills/agents kopyalanmadı"
fi

echo ""

# ─── 10. DOĞRULAMA ─────────────────────────────────────────────
echo "── Doğrulama ─────────────────────────────────────────────"
[ -f "$CLAUDE_DIR/settings.json" ]             && ok "~/.claude/settings.json" || warn "settings.json eksik"
[ -f "$PROJECT_ROOT/.mcp.json" ]               && ok ".mcp.json" || warn ".mcp.json eksik"
[ -f "$PROJECT_ROOT/.claude/settings.local.json" ] && ok ".claude/settings.local.json" || warn "settings.local.json eksik"

# GitHub token kontrolü
if grep -q "ghp_" "$PROJECT_ROOT/.mcp.json" 2>/dev/null; then
  ok ".mcp.json: GitHub token ayarlı"
else
  warn ".mcp.json: GitHub token PLACEHOLDER"
fi

# gh CLI kontrolü
if command -v gh &>/dev/null && gh --version &>/dev/null; then
  ok "GitHub CLI (gh) çalışıyor"
else
  warn "GitHub CLI (gh) çalışmıyor — opsiyonel, GitHub MCP token ile çalışır"
fi

# Qwen skills kontrolü
info "Qwen Skills kontrolü..."
required_skills=("egesut-fullstack" "fix-ui" "gwen-self-improvement" "session-rules" "rpc-contract")
missing_skills=0
for skill in "${required_skills[@]}"; do
  [ ! -d "$HOME/.qwen/skills/$skill" ] && ((missing_skills++))
done
found_skills=$((${#required_skills[@]} - missing_skills))
[ "$missing_skills" -eq 0 ] && ok "Skills mevcut (5/5): egesut-fullstack · fix-ui · gwen-self-improvement · session-rules · rpc-contract" || warn "Skill eksik ($found_skills/5)"

# Qwen agents kontrolü
info "Qwen Agents kontrolü..."
required_agents=("gwen" "gwen-reviewer" "gwen-architect" "gwen-researcher" "gwen-analyst" "gwen-coder" "gwen-tester" "gwen-telemetry" "gwen-performance")
missing_agents=0
for agent in "${required_agents[@]}"; do
  [ ! -f "$HOME/.qwen/agents/$agent.md" ] && ((missing_agents++))
done
found_agents=$((${#required_agents[@]} - missing_agents))
[ "$missing_agents" -eq 0 ] && ok "Agents mevcut (9/9): gwen · gwen-reviewer · gwen-architect · gwen-researcher · gwen-analyst · gwen-coder · gwen-tester · gwen-telemetry · gwen-performance" || warn "Agent eksik ($found_agents/9)"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║           Kurulum Tamamlandı!            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Sonraki adım:"
echo "  cd $PROJECT_ROOT"
echo "  claude"
echo ""
echo "Token eklemek istersen:"
echo "  nano .mcp.json  →  SUPABASE_TOKEN_BURAYA / GITHUB_TOKEN_BURAYA kısımlarını değiştir"
echo ""
