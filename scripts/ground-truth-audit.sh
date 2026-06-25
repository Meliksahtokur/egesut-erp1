#!/usr/bin/env bash
# ground-truth-audit.sh — Dosya envanteri vs canlı envanter karşılaştırması.
#
# Kanun harici (EgeSüt kanonik) beklenti:
#   - tools-bank/altyapı 9 tablo HARİÇ
#   - set_deneme_no() HARİÇ (canlıda gövdesi bozuk)
#
# Kullanım:
#   bash scripts/ground-truth-audit.sh
#
# Çıktı:
#   ✓ 41 tablo · 12 view · X fn eşleşti  → PASS
#   ✗ eksik/fazla listesi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
GT_FILE="${SCRIPT_DIR}/../supabase/migrations/99999999999999_ground_truth.sql"

if [[ -f "$ENV_FILE" ]]; then
  SB_MGMT_TOKEN=$(grep -E "^SB_MGMT_TOKEN=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
  SB_PROJECT_REF=$(grep -E "^SB_PROJECT_REF=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
fi
: "${SB_MGMT_TOKEN:?SB_MGMT_TOKEN missing}"
: "${SB_PROJECT_REF:=zqnexqbdfvbhlxzelzju}"

API="https://api.supabase.com/v1/projects/${SB_PROJECT_REF}/database/query"
mgt_query() {
  curl -sS -X POST "$API" \
    -H "Authorization: Bearer ${SB_MGMT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$1" '{query:$q}')"
}

# tools-bank / altyapı tablolar
INFRA_TABLES=(_regen_fndefs agent_messages agent_threads chat code_embeddings entity_graph goose_embeddings memory_notes tasks)
INFRA_RE=$(printf '%s|' "${INFRA_TABLES[@]}" | sed 's/|$//')

# Altyapı fonksiyonları (audit whitelist — "fazla" listesinde beklenen)
INFRA_FNS=(agent_plans_prune agent_threads_prune search_code search_memory_notes set_deneme_no)

echo "═══════════════════════════════════════════════════════════════"
echo "  Ground Truth Audit — kanonik envanter (canlı vs dosya)"
echo "═══════════════════════════════════════════════════════════════"

# ── CANLI (kanonik beklenti: tools-bank 9 tablo HARİÇ) ──────────────────
echo
echo "▶ Canlı kanonik tablo (50 - 9 altyapı = 41 beklenen)…"
LIVE_TABLES=$(mgt_query "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name !~ '^(${INFRA_RE})$' ORDER BY 1" \
  | jq -r '.[].table_name' | sort -u)
LIVE_TABLES_COUNT=$(echo "$LIVE_TABLES" | wc -l)
echo "  → canlı kanonik tablo: $LIVE_TABLES_COUNT"

echo "▶ Canlı view (12 beklenen)…"
LIVE_VIEWS=$(mgt_query "SELECT table_name FROM information_schema.views WHERE table_schema='public' ORDER BY 1" \
  | jq -r '.[].table_name' | sort -u)
LIVE_VIEWS_COUNT=$(echo "$LIVE_VIEWS" | wc -l)
echo "  → canlı view: $LIVE_VIEWS_COUNT"

echo "▶ Canlı fonksiyon (set_deneme_no HARİÇ, tekil ad)…"
LIVE_FNS=$(mgt_query "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname <> 'set_deneme_no' ORDER BY 1" \
  | jq -r '.[].proname' | sort -u)
LIVE_FNS_COUNT=$(echo "$LIVE_FNS" | wc -l)
echo "  → canlı kanonik fn (tekil ad): $LIVE_FNS_COUNT"

# ── DOSYA ENVANTERİ ──────────────────────────────────────────────────
echo
echo "▶ Dosya envanteri (ground_truth.sql)…"
# Tablolar: CREATE TABLE [IF NOT EXISTS] public.<name>
FILE_TABLES=$(grep -oE "^CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?(public\.|)(\w+)" "$GT_FILE" \
  | sed -E 's/^CREATE[[:space:]]+TABLE[[:space:]]+(IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+)?(public\.|)//' \
  | sort -u)
FILE_TABLES_COUNT=$(echo "$FILE_TABLES" | wc -l)
echo "  → dosya tablo (unique): $FILE_TABLES_COUNT"

FILE_VIEWS=$(grep -oE "^CREATE\s+(OR\s+REPLACE\s+)?VIEW\s+(public\.|)(\w+)" "$GT_FILE" \
  | sed -E 's/^CREATE[[:space:]]+(OR[[:space:]]+REPLACE[[:space:]]+)?VIEW[[:space:]]+(public\.|)//' \
  | sort -u)
FILE_VIEWS_COUNT=$(echo "$FILE_VIEWS" | wc -l)
echo "  → dosya view (unique): $FILE_VIEWS_COUNT"

FILE_FNS=$(grep -oE "^CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+(public\.|)(\w+)" "$GT_FILE" \
  | sed -E 's/^CREATE[[:space:]]+(OR[[:space:]]+REPLACE[[:space:]]+)?FUNCTION[[:space:]]+(public\.|)//' \
  | sort -u)
FILE_FNS_COUNT=$(echo "$FILE_FNS" | wc -l)
echo "  → dosya fn (tekil ad): $FILE_FNS_COUNT"

# ── DİFF ─────────────────────────────────────────────────────────────
echo
echo "▶ Diff…"
MISSING_T=$(comm -23 <(echo "$LIVE_TABLES") <(echo "$FILE_TABLES") || true)
EXTRA_T=$(comm -13 <(echo "$LIVE_TABLES") <(echo "$FILE_TABLES") || true)
MISSING_V=$(comm -23 <(echo "$LIVE_VIEWS") <(echo "$FILE_VIEWS") || true)
EXTRA_V=$(comm -13 <(echo "$LIVE_VIEWS") <(echo "$FILE_VIEWS") || true)
MISSING_F=$(comm -23 <(echo "$LIVE_FNS") <(echo "$FILE_FNS") || true)
EXTRA_F=$(comm -13 <(echo "$LIVE_FNS") <(echo "$FILE_FNS") || true)

# ── RAPOR ────────────────────────────────────────────────────────────
echo
echo "═══════════════════════════════════════════════════════════════"
printf "  Tablolar: canlı=%d  dosya=%d  eksik=%d  fazla=%d\n" \
  "$LIVE_TABLES_COUNT" "$FILE_TABLES_COUNT" \
  "$(echo "$MISSING_T" | grep -c .)" "$(echo "$EXTRA_T" | grep -c .)"
printf "  Views  : canlı=%d  dosya=%d  eksik=%d  fazla=%d\n" \
  "$LIVE_VIEWS_COUNT" "$FILE_VIEWS_COUNT" \
  "$(echo "$MISSING_V" | grep -c .)" "$(echo "$EXTRA_V" | grep -c .)"
printf "  Fns    : canlı=%d  dosya=%d  eksik=%d  fazla=%d\n" \
  "$LIVE_FNS_COUNT" "$FILE_FNS_COUNT" \
  "$(echo "$MISSING_F" | grep -c .)" "$(echo "$EXTRA_F" | grep -c .)"
echo "═══════════════════════════════════════════════════════════════"

# Bilinen istisnaları whitelist'ten düş
WHITELIST_RE=$(printf '%s|' "${INFRA_FNS[@]}" | sed 's/|$//')
MISSING_F_REAL=$(echo "$MISSING_F" | grep -vE "^(${WHITELIST_RE})$" || true)
EXTRA_F_REAL=$(echo "$EXTRA_F" | grep -vE "^(${WHITELIST_RE})$" || true)

TOTAL_DIFF=0
[[ -n "$MISSING_T" ]] && { echo; echo "❌ Eksik tablolar:"; echo "$MISSING_T" | sed 's/^/   + /'; TOTAL_DIFF=$((TOTAL_DIFF+$(echo "$MISSING_T"|grep -c .))); }
[[ -n "$EXTRA_T" ]] && { echo; echo "❌ Fazla tablolar:"; echo "$EXTRA_T" | sed 's/^/   - /'; TOTAL_DIFF=$((TOTAL_DIFF+$(echo "$EXTRA_T"|grep -c .))); }
[[ -n "$MISSING_V" ]] && { echo; echo "❌ Eksik view:"; echo "$MISSING_V" | sed 's/^/   + /'; TOTAL_DIFF=$((TOTAL_DIFF+$(echo "$MISSING_V"|grep -c .))); }
[[ -n "$EXTRA_V" ]] && { echo; echo "❌ Fazla view:"; echo "$EXTRA_V" | sed 's/^/   - /'; TOTAL_DIFF=$((TOTAL_DIFF+$(echo "$EXTRA_V"|grep -c .))); }
if [[ -n "$MISSING_F_REAL" ]]; then
  FC=$(echo "$MISSING_F_REAL" | grep -c .)
  echo
  echo "❌ Eksik fn (whitelist hariç, toplam $FC):"
  echo "$MISSING_F_REAL" | head -10 | sed 's/^/   + /'
  TOTAL_DIFF=$((TOTAL_DIFF+FC))
fi
if [[ -n "$EXTRA_F_REAL" ]]; then
  FC=$(echo "$EXTRA_F_REAL" | grep -c .)
  echo
  echo "❌ Fazla fn (whitelist hariç, toplam $FC):"
  echo "$EXTRA_F_REAL" | head -10 | sed 's/^/   - /'
  TOTAL_DIFF=$((TOTAL_DIFF+FC))
fi

# whitelist'te olan fn'leri sadece bilgi ver
WL_MISSING=$(echo "$MISSING_F" | grep -E "^(${WHITELIST_RE})$" || true)
WL_EXTRA=$(echo "$EXTRA_F" | grep -E "^(${WHILIST_RE:-${WHITELIST_RE}})$" || true)
[[ -n "$WL_MISSING" || -n "$WL_EXTRA" ]] && {
  echo
  printf '\033[1;36mℹ Bilinen whitelist (altyapı fn):\033[0m\n'
  [[ -n "$WL_MISSING" ]] && echo "  canlıda var, dosyada yok (altyapı):" && echo "$WL_MISSING" | sed 's/^/    + /'
  [[ -n "$WL_EXTRA" ]] && echo "  dosyada var, canlıda yok (altyapı):" && echo "$WL_EXTRA" | sed 's/^/    - /'
}

echo
if [[ "$TOTAL_DIFF" -eq 0 ]]; then
  printf '\033[1;32m✓ AUDIT PASS\033[0m\n'
  echo "  Birebir eşleşme: ${LIVE_TABLES_COUNT} tablo · ${LIVE_VIEWS_COUNT} view · ${LIVE_FNS_COUNT} fn"
  exit 0
else
  printf '\033[1;31m✗ AUDIT FAIL — %d fark\033[0m\n' "$TOTAL_DIFF"
  exit 1
fi