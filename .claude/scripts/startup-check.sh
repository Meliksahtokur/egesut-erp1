#!/bin/bash
# EgeSüt ERP — Oturum Başlangıç Kontrolü
# Çıktı: JSON systemMessage → Claude'a enjekte edilir

CLAUDE_DIR="/root/egesut-erp1/.claude"
JS_DIR="/root/egesut-erp1/js"

ok="✓"
fail="✗"
warn="⚠"

lines=()
errors=0
warnings=0

# ─── AGENT KONTROLÜ ───────────────────────────────────────────
agents=("orchestrator" "erp-explorer" "erp-db-agent" "erp-frontend-dev" "erp-qa-agent" "erp-git-agent" "arge-analyst" "arge-web-researcher" "arge-local-reader")
missing_agents=()
for agent in "${agents[@]}"; do
  if [ ! -f "$CLAUDE_DIR/agents/$agent.md" ]; then
    missing_agents+=("$agent")
    ((errors++))
  fi
done

if [ ${#missing_agents[@]} -eq 0 ]; then
  lines+=("$ok Agents (9/9): orchestrator · explorer · db · frontend · qa · git · arge×3")
else
  lines+=("$fail Agents eksik: ${missing_agents[*]}")
fi

# ─── HOOK KONTROLÜ ────────────────────────────────────────────
hooks=("block-direct-writes" "protect-critical-files" "check-duplicates" "verify-before-done")
missing_hooks=()
for hook in "${hooks[@]}"; do
  if [ ! -f "$CLAUDE_DIR/hookify.$hook.local.md" ]; then
    missing_hooks+=("$hook")
    ((errors++))
  fi
done

if [ ${#missing_hooks[@]} -eq 0 ]; then
  lines+=("$ok Hooks (4/4): db-guard · file-guard · duplicate-guard · verify-guard")
else
  lines+=("$fail Hooks eksik: ${missing_hooks[*]}")
fi

# ─── REFERANS DOSYALARI ───────────────────────────────────────
ref_ok=true
[ ! -f "$CLAUDE_DIR/rpc-reference.md" ] && ref_ok=false && ((errors++))
[ ! -f "$CLAUDE_DIR/ui-map.md" ] && ref_ok=false && ((errors++))
[ ! -f "$CLAUDE_DIR/domain-rules.md" ] && ref_ok=false && ((errors++))

if $ref_ok; then
  lines+=("$ok Referanslar: rpc-reference · ui-map · domain-rules")
else
  lines+=("$fail Eksik referans dosyası var")
fi

# ─── JS MODÜL KONTROLÜ ────────────────────────────────────────
js_files=("ui.js" "forms.js" "app.js" "api.js" "state.js" "config.js")
syntax_errors=()
for f in "${js_files[@]}"; do
  result=$(node --check "$JS_DIR/$f" 2>&1)
  if [ $? -ne 0 ]; then
    syntax_errors+=("$f")
    ((warnings++))
  fi
done

if [ ${#syntax_errors[@]} -eq 0 ]; then
  lines+=("$ok JS Syntax (6/6): tüm modüller temiz")
else
  lines+=("$warn JS Syntax hatası: ${syntax_errors[*]}")
fi

# ─── GIT DURUM ────────────────────────────────────────────────
branch=$(git -C /root/egesut-erp1 branch --show-current 2>/dev/null)
uncommitted=$(git -C /root/egesut-erp1 status --porcelain 2>/dev/null | wc -l | tr -d ' ')

if [ "$uncommitted" -gt "0" ]; then
  lines+=("$warn Git: branch=$branch · $uncommitted uncommitted değişiklik")
  ((warnings++))
else
  lines+=("$ok Git: branch=$branch · temiz")
fi

# ─── ARGE DURUMU ──────────────────────────────────────────────
arge_agents=("arge-analyst" "arge-web-researcher" "arge-local-reader")
missing_arge=()
for agent in "${arge_agents[@]}"; do
  [ ! -f "$CLAUDE_DIR/agents/$agent.md" ] && missing_arge+=("$agent")
done

if [ ${#missing_arge[@]} -eq 0 ]; then
  # Bekleyen bulgu var mı?
  proposal_count=$(grep -c "^## \[" "$CLAUDE_DIR/knowledge/improvement-proposals.md" 2>/dev/null || echo 0)
  pending_flag=""
  [ -f "$CLAUDE_DIR/arge-pending.flag" ] && pending_flag=" · 🔔 yeni commit analiz bekliyor"

  if [ "$proposal_count" -gt "0" ]; then
    lines+=("🔬 ArGe: aktif · $proposal_count bekleyen öneri$pending_flag")
    ((warnings++))
  else
    lines+=("🔬 ArGe: aktif · öneri yok$pending_flag")
  fi
else
  lines+=("$warn ArGe: eksik agent → ${missing_arge[*]}")
  ((warnings++))
fi

# ─── AGENT FEEDBACK ───────────────────────────────────────────
feedback_total=0
if [ -d "$CLAUDE_DIR/feedback" ]; then
  feedback_total=$(grep -rh "^## \[" "$CLAUDE_DIR/feedback/"[a-z]*.md 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$feedback_total" -gt "0" ]; then
  lines+=("📬 Agent Feedback: $feedback_total bekleyen — 'rapor ver' ile göster")
  ((warnings++))
fi

# ─── ÖZET ─────────────────────────────────────────────────────
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
  status="🟢 SİSTEM HAZIR"
elif [ $errors -eq 0 ]; then
  status="🟡 SİSTEM HAZIR — $warnings uyarı"
else
  status="🔴 SİSTEM SORUNLU — $errors hata, $warnings uyarı"
fi

# ─── JSON ÇIKTI ───────────────────────────────────────────────
report=$(printf '%s\n' "${lines[@]}" | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//' | sed 's/|/\\n/g')

cat <<EOF
{"systemMessage": "EgeSÜT ERP — OTURUM BAŞLANGICI\n$status\n\n$report\n\nKullanım: '@orchestrator <görev>' ile başla veya direkt görev ver."}
EOF
