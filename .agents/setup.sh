#!/usr/bin/env bash
# EgeSüt ERP — Agent Kurulum Scripti
# Yeni cihazda: bash .agents/setup.sh
set -e

REPO_PATH="$(cd "$(dirname "$0")/.." && pwd)"
echo "📁 Repo: $REPO_PATH"

# ── 1. Context7 MCP bağımlılıkları ──────────────────
echo "📦 Context7 MCP bağımlılıkları kuruluyor..."
cd "$REPO_PATH/.agents/mcp/context7"
if ! command -v node &>/dev/null; then
  echo "❌ Node.js bulunamadı. Önce node kur."
  exit 1
fi
npm install --silent 2>/dev/null || true

# ── 2. Qwen agent'larını kur ────────────────────────
echo "🤖 Qwen agent'ları kuruluyor..."
mkdir -p ~/.qwen/agents ~/.qwen/skills
cp "$REPO_PATH/.agents/qwen/agents/"* ~/.qwen/agents/
cp -r "$REPO_PATH/.agents/qwen/skills/"* ~/.qwen/skills/
cp "$REPO_PATH/.agents/qwen/QWEN.md" ~/.qwen/

# settings.json — varsa MCP path güncelle, yoksa template'den oluştur
SETTINGS="$HOME/.qwen/settings.json"
if [ ! -f "$SETTINGS" ]; then
  sed "s|REPO_PATH|$REPO_PATH|g" "$REPO_PATH/.agents/qwen/settings.template.json" > "$SETTINGS"
  echo "   ✅ settings.json oluşturuldu (auth için: qwen auth qwen-oauth)"
else
  # Sadece context7 path güncelle
  python3 -c "
import json, sys
with open('$SETTINGS') as f: s = json.load(f)
s.setdefault('mcpServers', {})['context7'] = {
  'command': 'node',
  'args': ['$REPO_PATH/.agents/mcp/context7/index.js']
}
with open('$SETTINGS','w') as f: json.dump(s, f, indent=2)
print('   ✅ settings.json güncellendi (context7 path)')
"
fi

# ── 3. Pre-commit hook kur ─────────────────────────
echo "🔒 Git hook kuruluyor..."
GWEN_WORKTREE="$REPO_PATH/../$(basename $REPO_PATH | sed 's/-main//')"
if [ -d "$GWEN_WORKTREE/.git" ]; then
  cp "$REPO_PATH/.agents/pre-commit.hook" "$GWEN_WORKTREE/.git/hooks/pre-commit"
  chmod +x "$GWEN_WORKTREE/.git/hooks/pre-commit"
  echo "   ✅ pre-commit hook: $GWEN_WORKTREE"
else
  echo "   ⚠️  Gwen worktree bulunamadı: $GWEN_WORKTREE (manuel kur)"
fi

# ── 4. gwen/dev ve gwen/arge branch kontrolü ──────
echo "🌿 Branch'ler kontrol ediliyor..."
cd "$REPO_PATH"
git fetch origin --quiet
for branch in gwen/dev gwen/arge; do
  if ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git push origin "main:$branch" --quiet
    echo "   ✅ $branch oluşturuldu"
  else
    echo "   ✅ $branch mevcut"
  fi
done

echo ""
echo "✅ Kurulum tamamlandı!"
echo ""
echo "Sonraki adımlar:"
echo "  1. qwen auth qwen-oauth   (Qwen hesabına giriş)"
echo "  2. İki terminal aç:"
echo "     Terminal 1 (DEV):  cd $(dirname $REPO_PATH)/$(basename $REPO_PATH | sed 's/-main//') && git checkout gwen/dev && qwen"
echo "     Terminal 2 (ARGE): cd $(dirname $REPO_PATH)/$(basename $REPO_PATH | sed 's/-main//') && git checkout gwen/arge && qwen"
