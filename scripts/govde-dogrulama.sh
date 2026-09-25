#!/usr/bin/env bash
# govde-dogrulama.sh — cila-onarım K2 gövde doğrulama kapısı.
#
# 20260925 serisi migration dosyalarındaki HER fonksiyonun (kümülatif
# son-yazan semantiği) ve v_eligible görünümünün canlı DEMO gövdesiyle
# eşitliğini sınar; ayrıca DROP edilmiş imzaların yokluğunu ve
# supabase_migrations.schema_migrations statements doluluğunu kontrol eder.
#
# Kullanım:
#   bash scripts/govde-dogrulama.sh [--files '<glob>']   # negatif test: geçici dosya
#
# Bağlantı: demo psql (/home/melik/egesut-erp1/.env; ref DOĞRULAMALI:
# vtzqjmazsvurxdeondmi — prod zqnexqbdfvbhlxzelzju YASAK).
# Çıkış: satır satır OK/DIFF + son satır "GOVDE_FARK: <n>"; exit 0 yalnız n=0.

set -euo pipefail
export LC_ALL=C LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
PY="$SCRIPT_DIR/lib/govde_karsilastir.py"

EXTRA_FILES=""
if [[ "${1:-}" == "--files" ]]; then
  EXTRA_FILES="$2"; shift 2
fi

# ── Ortam + ref doğrulama ──────────────────────────────────────────────
set -a; source /home/melik/egesut-erp1/.env; set +a
REF="${SUPABASE_DEMO_REF:-UNSET}"
if [ "$REF" != "vtzqjmazsvurxdeondmi" ]; then
  echo "REF DOGRULAMASI BASARISIZ: '$REF' (beklenen vtzqjmazsvurxdeondmi) — DUR" >&2
  exit 99
fi

TMPROOT="${SS_TMP_ROOT:-${TMPDIR:-}}"
[[ -n "$TMPROOT" ]] || { echo "TMPDIR/SS_TMP_ROOT gerekli" >&2; exit 78; }
WORK="$(mktemp -d "$TMPROOT/govde.XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

DBURL="postgresql://postgres.${SUPABASE_DEMO_REF}:${SUPABASE_DEMO_DB_PASSWORD}@${SUPABASE_DEMO_POOLER}:6543/postgres"

# ── Faz 1: dosya taraması → beklenen nesne listesi + canlı çekim SQL'i ─
LIST_ARGS=(--repo "$REPO" --list-objects)
CMP_LIVE_ARGS=()
if [[ -n "$EXTRA_FILES" ]]; then
  LIST_ARGS+=(--files "$EXTRA_FILES")
fi
python3 "$PY" "${LIST_ARGS[@]}" > "$WORK/objects.json"

LIVE_SQL=$(python3 "$PY" --repo "$REPO" --emit-sql < "$WORK/objects.json")

# ── Faz 2: canlı tarafı çek (yalnız taranan adlar) ─────────────────────
PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql "$DBURL" -X -qAt -v ON_ERROR_STOP=1 \
  -c "$LIVE_SQL" > "$WORK/live.json"

# ── Faz 3: karşılaştır ─────────────────────────────────────────────────
CMP_ARGS=(--repo "$REPO" --live "$WORK/live.json")
if [[ -n "$EXTRA_FILES" ]]; then
  CMP_ARGS+=(--files "$EXTRA_FILES")
fi
python3 "$PY" "${CMP_ARGS[@]}"
