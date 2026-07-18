#!/usr/bin/env bash
# ground-truth-audit.sh — efektif canonical envanteri canlı DB ile karşılaştırır.
#
# Kapsam:
#   - tools-bank altyapı tablo/fonksiyonları hariç domain tablo/view/fonksiyonları
#   - public şemadaki non-internal trigger adı + tablo + fonksiyon bağlantısı
#   - ground_truth içindeki CREATE/DROP sırası (yalnız CREATE satırı sayılmaz)

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
  curl --fail-with-body -sS -X POST "$API" \
    -H "Authorization: Bearer ${SB_MGMT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$1" '{query:$q}')"
}

line_count() {
  if [[ -z "$1" ]]; then
    echo 0
  else
    printf '%s\n' "$1" | grep -c .
  fi
}

# tools-bank / altyapı nesneleri canonical EgeSüt kapsamı dışındadır.
INFRA_TABLES=(_regen_fndefs agent_messages agent_threads chat code_embeddings entity_graph goose_embeddings memory_notes tasks)
INFRA_FNS=(agent_plans_prune agent_threads_prune search_code search_memory_notes)
INFRA_TABLE_RE=$(printf '%s|' "${INFRA_TABLES[@]}")
INFRA_TABLE_RE=${INFRA_TABLE_RE%|}
INFRA_FN_RE=$(printf '%s|' "${INFRA_FNS[@]}")
INFRA_FN_RE=${INFRA_FN_RE%|}

echo "═══════════════════════════════════════════════════════════════"
echo "  Ground Truth Audit — efektif canonical envanter"
echo "═══════════════════════════════════════════════════════════════"

echo
echo "▶ Canlı canonical envanter alınıyor…"
LIVE_TABLES=$(mgt_query "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name !~ '^(${INFRA_TABLE_RE})$' ORDER BY 1" \
  | jq -r '.[].table_name' | sort -u)
LIVE_VIEWS=$(mgt_query "SELECT table_name FROM information_schema.views WHERE table_schema='public' ORDER BY 1" \
  | jq -r '.[].table_name' | sort -u)
LIVE_FNS=$(mgt_query "SELECT DISTINCT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname !~ '^(${INFRA_FN_RE})$' ORDER BY 1" \
  | jq -r '.[].proname' | sort -u)
LIVE_TRIGGERS=$(mgt_query "SELECT t.tgname, c.relname AS table_name, p.proname AS function_name FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_proc p ON p.oid=t.tgfoid WHERE n.nspname='public' AND NOT t.tgisinternal ORDER BY t.tgname" \
  | jq -r '.[] | [.tgname,.table_name,.function_name] | @tsv' | sort -u)

echo "  → tablo=$(line_count "$LIVE_TABLES") view=$(line_count "$LIVE_VIEWS") fn=$(line_count "$LIVE_FNS") trigger=$(line_count "$LIVE_TRIGGERS")"

echo
echo "▶ Ground truth efektif envanteri hesaplanıyor…"
FILE_JSON=$(python3 - "$GT_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

# Canonical dosyadaki top-level DDL satırları satır başından başlar. CREATE/DROP
# olaylarını dosya sırasıyla işlemek, yalnız CREATE adlarını grep'lemekten farklı
# olarak son efektif durumu verir.
outside = text

states = {"TABLE": set(), "VIEW": set(), "FUNCTION": set()}
object_events = re.compile(
    r"(?im)^[ \t]*(?:"
    r"CREATE[ \t]+(?:OR[ \t]+REPLACE[ \t]+)?"
    r"(?P<create_kind>TABLE|VIEW|FUNCTION)[ \t]+"
    r"(?:IF[ \t]+NOT[ \t]+EXISTS[ \t]+)?(?:public\.)?"
    r"(?P<create_name>[A-Za-z_][A-Za-z0-9_]*)"
    r"|DROP[ \t]+(?P<drop_kind>TABLE|VIEW|FUNCTION)[ \t]+"
    r"(?:IF[ \t]+EXISTS[ \t]+)?(?:public\.)?"
    r"(?P<drop_name>[A-Za-z_][A-Za-z0-9_]*)"
    r")"
)
for event in object_events.finditer(outside):
    if event.group("create_kind"):
        states[event.group("create_kind").upper()].add(event.group("create_name"))
    else:
        states[event.group("drop_kind").upper()].discard(event.group("drop_name"))

triggers = {}
trigger_events = re.compile(
    r"(?ims)^[ \t]*(?:"
    r"DROP[ \t]+TRIGGER[ \t]+IF[ \t]+EXISTS[ \t]+"
    r"(?P<drop>[A-Za-z_][A-Za-z0-9_]*)[^;]*;"
    r"|CREATE[ \t]+TRIGGER[ \t]+"
    r"(?P<create>[A-Za-z_][A-Za-z0-9_]*)(?P<body>.*?;)"
    r")"
)
for event in trigger_events.finditer(outside):
    if event.group("drop"):
        triggers.pop(event.group("drop"), None)
        continue
    body = event.group("body")
    table_match = re.search(
        r"\bON[ \t\r\n]+(?:public\.)?([A-Za-z_][A-Za-z0-9_]*)",
        body,
        re.IGNORECASE,
    )
    function_match = re.search(
        r"\bEXECUTE[ \t\r\n]+FUNCTION[ \t\r\n]+"
        r"(?:public\.)?([A-Za-z_][A-Za-z0-9_]*)",
        body,
        re.IGNORECASE,
    )
    if table_match and function_match:
        triggers[event.group("create")] = [table_match.group(1), function_match.group(1)]

print(json.dumps({
    "tables": sorted(states["TABLE"]),
    "views": sorted(states["VIEW"]),
    "functions": sorted(states["FUNCTION"]),
    "triggers": [
        [name, table_name, function_name]
        for name, (table_name, function_name) in sorted(triggers.items())
    ],
}, ensure_ascii=False))
PY
)

FILE_TABLES=$(printf '%s\n' "$FILE_JSON" | jq -r '.tables[]' | grep -vE "^(${INFRA_TABLE_RE})$" | sort -u || true)
FILE_VIEWS=$(printf '%s\n' "$FILE_JSON" | jq -r '.views[]' | sort -u)
FILE_FNS=$(printf '%s\n' "$FILE_JSON" | jq -r '.functions[]' | grep -vE "^(${INFRA_FN_RE})$" | sort -u || true)
FILE_TRIGGERS=$(printf '%s\n' "$FILE_JSON" | jq -r '.triggers[] | @tsv' | sort -u)

echo "  → tablo=$(line_count "$FILE_TABLES") view=$(line_count "$FILE_VIEWS") fn=$(line_count "$FILE_FNS") trigger=$(line_count "$FILE_TRIGGERS")"

MISSING_T=$(comm -23 <(printf '%s\n' "$LIVE_TABLES") <(printf '%s\n' "$FILE_TABLES") || true)
EXTRA_T=$(comm -13 <(printf '%s\n' "$LIVE_TABLES") <(printf '%s\n' "$FILE_TABLES") || true)
MISSING_V=$(comm -23 <(printf '%s\n' "$LIVE_VIEWS") <(printf '%s\n' "$FILE_VIEWS") || true)
EXTRA_V=$(comm -13 <(printf '%s\n' "$LIVE_VIEWS") <(printf '%s\n' "$FILE_VIEWS") || true)
MISSING_F=$(comm -23 <(printf '%s\n' "$LIVE_FNS") <(printf '%s\n' "$FILE_FNS") || true)
EXTRA_F=$(comm -13 <(printf '%s\n' "$LIVE_FNS") <(printf '%s\n' "$FILE_FNS") || true)
MISSING_TRG=$(comm -23 <(printf '%s\n' "$LIVE_TRIGGERS") <(printf '%s\n' "$FILE_TRIGGERS") || true)
EXTRA_TRG=$(comm -13 <(printf '%s\n' "$LIVE_TRIGGERS") <(printf '%s\n' "$FILE_TRIGGERS") || true)

MISSING_T_N=$(line_count "$MISSING_T")
EXTRA_T_N=$(line_count "$EXTRA_T")
MISSING_V_N=$(line_count "$MISSING_V")
EXTRA_V_N=$(line_count "$EXTRA_V")
MISSING_F_N=$(line_count "$MISSING_F")
EXTRA_F_N=$(line_count "$EXTRA_F")
MISSING_TRG_N=$(line_count "$MISSING_TRG")
EXTRA_TRG_N=$(line_count "$EXTRA_TRG")
TOTAL_DIFF=$((MISSING_T_N + EXTRA_T_N + MISSING_V_N + EXTRA_V_N + MISSING_F_N + EXTRA_F_N + MISSING_TRG_N + EXTRA_TRG_N))

echo
echo "═══════════════════════════════════════════════════════════════"
printf "  Tablolar : canlı=%d dosya=%d eksik=%d fazla=%d\n" "$(line_count "$LIVE_TABLES")" "$(line_count "$FILE_TABLES")" "$MISSING_T_N" "$EXTRA_T_N"
printf "  Views    : canlı=%d dosya=%d eksik=%d fazla=%d\n" "$(line_count "$LIVE_VIEWS")" "$(line_count "$FILE_VIEWS")" "$MISSING_V_N" "$EXTRA_V_N"
printf "  Fns      : canlı=%d dosya=%d eksik=%d fazla=%d\n" "$(line_count "$LIVE_FNS")" "$(line_count "$FILE_FNS")" "$MISSING_F_N" "$EXTRA_F_N"
printf "  Triggers : canlı=%d dosya=%d eksik=%d fazla=%d\n" "$(line_count "$LIVE_TRIGGERS")" "$(line_count "$FILE_TRIGGERS")" "$MISSING_TRG_N" "$EXTRA_TRG_N"
echo "═══════════════════════════════════════════════════════════════"

[[ -n "$MISSING_T" ]] && { echo; echo "❌ Eksik tablolar:"; printf '%s\n' "$MISSING_T" | sed 's/^/   + /'; }
[[ -n "$EXTRA_T" ]] && { echo; echo "❌ Fazla tablolar:"; printf '%s\n' "$EXTRA_T" | sed 's/^/   - /'; }
[[ -n "$MISSING_V" ]] && { echo; echo "❌ Eksik view:"; printf '%s\n' "$MISSING_V" | sed 's/^/   + /'; }
[[ -n "$EXTRA_V" ]] && { echo; echo "❌ Fazla view:"; printf '%s\n' "$EXTRA_V" | sed 's/^/   - /'; }
[[ -n "$MISSING_F" ]] && { echo; echo "❌ Eksik fonksiyon:"; printf '%s\n' "$MISSING_F" | sed 's/^/   + /'; }
[[ -n "$EXTRA_F" ]] && { echo; echo "❌ Fazla fonksiyon:"; printf '%s\n' "$EXTRA_F" | sed 's/^/   - /'; }
[[ -n "$MISSING_TRG" ]] && { echo; echo "❌ Eksik trigger bağlantısı:"; printf '%s\n' "$MISSING_TRG" | sed $'s/\t/ -> /g; s/^/   + /'; }
[[ -n "$EXTRA_TRG" ]] && { echo; echo "❌ Fazla trigger bağlantısı:"; printf '%s\n' "$EXTRA_TRG" | sed $'s/\t/ -> /g; s/^/   - /'; }

echo
if [[ "$TOTAL_DIFF" -eq 0 ]]; then
  printf '\033[1;32m✓ AUDIT PASS\033[0m\n'
  echo "  Efektif eşleşme: $(line_count "$LIVE_TABLES") tablo · $(line_count "$LIVE_VIEWS") view · $(line_count "$LIVE_FNS") fn · $(line_count "$LIVE_TRIGGERS") trigger"
  exit 0
fi

printf '\033[1;31m✗ AUDIT FAIL — %d fark\033[0m\n' "$TOTAL_DIFF"
exit 1
