#!/bin/bash
# EgeSüt ERP — Oturum Başlangıç Kontrolü
# Çıktı: JSON systemMessage → Claude'a enjekte edilir

CLAUDE_DIR="/root/egesut-erp1/.claude"

ok="✓"
fail="✗"
warn="⚠"

lines=()
detail_lines=()   # Hata detayları — ayrı bölümde gösterilir
errors=0
warnings=0

# ─── AGENT KONTROLÜ (4-agent mimari) ──────────────────────────
agents=("orchestrator" "erp-implementer" "erp-qa-git" "erp-explorer")
missing_agents=()
for agent in "${agents[@]}"; do
  if [ ! -f "$CLAUDE_DIR/agents/$agent.md" ]; then
    missing_agents+=("$agent")
    ((errors++))
  fi
done

total_agents=${#agents[@]}
found_agents=$((total_agents - ${#missing_agents[@]}))

if [ ${#missing_agents[@]} -eq 0 ]; then
  lines+=("$ok Agents ($total_agents/$total_agents): orchestrator · implementer · qa-git · explorer")
else
  lines+=("$fail Agents ($found_agents/$total_agents): ${#missing_agents[@]} eksik")
  for a in "${missing_agents[@]}"; do
    detail_lines+=("   ✗ AGENT EKSİK: $CLAUDE_DIR/agents/$a.md")
  done
fi

# ─── HOOK KONTROLÜ ────────────────────────────────────────────
hooks=("block-direct-writes" "protect-critical-files" "check-duplicates" "verify-before-done")
missing_hooks=()
disabled_hooks=()
for hook in "${hooks[@]}"; do
  fpath="$CLAUDE_DIR/hookify.$hook.local.md"
  if [ ! -f "$fpath" ]; then
    missing_hooks+=("$hook")
    ((errors++))
  else
    if grep -q "^enabled: false" "$fpath" 2>/dev/null; then
      disabled_hooks+=("$hook")
    fi
  fi
done

if [ ${#missing_hooks[@]} -eq 0 ]; then
  if [ ${#disabled_hooks[@]} -gt 0 ]; then
    lines+=("$warn Hooks (4/4) — devre dışı: ${disabled_hooks[*]}")
    ((warnings++))
  else
    lines+=("$ok Hooks (4/4): db-guard · file-guard · duplicate-guard · verify-guard")
  fi
else
  lines+=("$fail Hooks eksik: ${#missing_hooks[@]}")
  for h in "${missing_hooks[@]}"; do
    detail_lines+=("   ✗ HOOK EKSİK: $CLAUDE_DIR/hookify.$h.local.md")
  done
fi

# ─── REFERANS DOSYALARI ───────────────────────────────────────
declare -A ref_files=(
  ["rpc-reference"]="$CLAUDE_DIR/rpc-reference.md"
  ["ui-map"]="$CLAUDE_DIR/ui-map.md"
  ["domain-rules"]="$CLAUDE_DIR/domain-rules.md"
)
missing_refs=()
for name in "${!ref_files[@]}"; do
  if [ ! -f "${ref_files[$name]}" ]; then
    missing_refs+=("$name")
    ((errors++))
  fi
done

if [ ${#missing_refs[@]} -eq 0 ]; then
  lines+=("$ok Referanslar: rpc-reference · ui-map · domain-rules")
else
  lines+=("$fail Referans eksik: ${missing_refs[*]}")
  for r in "${missing_refs[@]}"; do
    detail_lines+=("   ✗ DOSYA EKSİK: ${ref_files[$r]}")
  done
fi

# ─── GIT DURUM ────────────────────────────────────────────────
branch=$(git -C /root/egesut-erp1 branch --show-current 2>/dev/null)
uncommitted_files=$(git -C /root/egesut-erp1 status --porcelain 2>/dev/null)
uncommitted=$(echo "$uncommitted_files" | grep -c '[^ ]' 2>/dev/null || echo 0)
uncommitted="${uncommitted//[[:space:]]/}"
[ -z "$uncommitted" ] && uncommitted=0

if [ "$uncommitted" -gt "0" ]; then
  lines+=("$warn Git: branch=$branch · $uncommitted uncommitted değişiklik")
  ((warnings++))
  while IFS= read -r line && [ "${#detail_lines[@]}" -lt 30 ]; do
    [ -z "$line" ] && continue
    detail_lines+=("   ⚠ GIT: $line")
  done < <(echo "$uncommitted_files" | head -5)
  [ "$uncommitted" -gt "5" ] && detail_lines+=("   ⚠ GIT: ... ve $((uncommitted-5)) dosya daha")
else
  lines+=("$ok Git: branch=$branch · temiz")
fi

# ─── BUG SİNYALLERİ ───────────────────────────────────────────
bug_critical=0
if [ -f "$CLAUDE_DIR/knowledge/bugs.md" ]; then
  bug_critical=$(grep -A5 "^## \[" "$CLAUDE_DIR/knowledge/bugs.md" 2>/dev/null | grep -c "Önem: kritik" || echo 0)
fi

active_bugs=$(grep -c "Durum: yeni\|Durum: inceleniyor" "$CLAUDE_DIR/knowledge/bugs.md" 2>/dev/null || echo 0)
active_bugs="${active_bugs//[[:space:]]/}"
[ -z "$active_bugs" ] && active_bugs=0

if [ "$active_bugs" -gt "0" ]; then
  critical_note=""
  [ "$bug_critical" -gt "0" ] && critical_note=" · ⚠ $bug_critical kritik"
  lines+=("🐛 Bugs: $active_bugs aktif$critical_note — 'bug raporu' ile göster")
  ((warnings++))
else
  lines+=("$ok Bugs: temiz")
fi

# ─── İYİLEŞTİRME ÖNERİLERİ ───────────────────────────────────
pending_proposals=0
if [ -f "$CLAUDE_DIR/knowledge/improvement-proposals.md" ]; then
  pending_proposals=$(grep -c "Durum:\*\* bekliyor\|Durum: bekliyor" "$CLAUDE_DIR/knowledge/improvement-proposals.md" 2>/dev/null || echo 0)
  pending_proposals="${pending_proposals//[[:space:]]/}"
  [ -z "$pending_proposals" ] && pending_proposals=0
fi

if [ "$pending_proposals" -gt "0" ]; then
  lines+=("💡 Öneriler: $pending_proposals bekliyor — 'öneri raporu' ile göster")
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

# ─── DETAY BLOĞU ──────────────────────────────────────────────
detail_block=""
if [ ${#detail_lines[@]} -gt 0 ]; then
  detail_block="\n\n── Hata Detayları ──"
  for d in "${detail_lines[@]}"; do
    detail_block="$detail_block\n$d"
  done
fi

# ─── JSON ÇIKTI ───────────────────────────────────────────────
report=$(printf '%s\n' "${lines[@]}" | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//' | sed 's/|/\\n/g')
detail_escaped=$(echo "$detail_block" | sed 's/"/\\"/g')

cat <<EOF
{"systemMessage": "EgeSÜT ERP — OTURUM BAŞLANGICI\n$status\n\n$report$detail_escaped\n\nBriefing için bekle — orkestratör durumu özetleyecek."}
EOF
