#!/usr/bin/env bash
# db-dry-run.test.sh — scripts/db-dry-run.sh kabul testi (uçtan uca, yerel ayna).
#
# Ne ölçer:
#   T1 statik: dry-run'ın denediği DB = refresh_lsp_schema.sh'nin tazelediği DB
#      (ikisi de LOCAL_LSP_URL; NEON_LSP_URL yok).
#   T2 temiz fixture (yeni kolon + view'a bakan SQL fonksiyonu) → rc 0, BAŞARILI.
#   T3 bozuk fixture (olmayan kolon) → rc≠0 ve çıktıda 42703.
#   T4 çıktıda LOCAL_LSP_URL parolası geçmez.
# Gereken ortam: SB_MGMT_TOKEN, LOCAL_LSP_URL (repo .env ya da ortam), TMPDIR.
# Prod'a yalnız OKUMA (Mgmt API, refresh); yazma yerel egesut_lsp aynasına.
# Fixture'lar TMPDIR altında mktemp'lenir, commitlenmez, çıkışta silinir.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY="$SCRIPT_DIR/db-dry-run.sh"
REF="$SCRIPT_DIR/refresh_lsp_schema.sh"
FAILS=0
pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; FAILS=$((FAILS+1)); }

# ── T1 statik: hedef tutarlılığı ───────────────────────────────────────
if grep -q 'NEON_LSP_URL' "$DRY"; then
  fail "T1 db-dry-run.sh hâlâ NEON_LSP_URL kullanıyor (tazelenen ≠ denenen)"
elif grep -q 'psql "\$LOCAL_LSP_URL"' "$DRY" && grep -q 'psql "\$LOCAL_LSP_URL"' "$REF"; then
  pass "T1 dry-run ve refresh aynı hedef (LOCAL_LSP_URL)"
else
  fail "T1 dry-run hedefi LOCAL_LSP_URL değil"
fi

# ── Ortam ──────────────────────────────────────────────────────────────
TMP_ROOT="${SS_TMP_ROOT:-${TMPDIR:-}}"
[[ -n "$TMP_ROOT" ]] || { echo "FAIL ortam: TMPDIR yok"; exit 1; }
FX=$(mktemp -d "$TMP_ROOT/dryrun-test.XXXXXX")
trap 'rm -rf "$FX"' EXIT
if [[ -z "${LOCAL_LSP_URL:-}" && -f "$SCRIPT_DIR/../.env" ]]; then
  LOCAL_LSP_URL=$(grep -E '^LOCAL_LSP_URL=' "$SCRIPT_DIR/../.env" | cut -d= -f2- | tr -d "\"'")
fi
[[ -n "${LOCAL_LSP_URL:-}" ]] || { echo "FAIL ortam: LOCAL_LSP_URL yok"; exit 1; }
PW=$(python3 -I -c 'import sys,urllib.parse as u; print(u.urlparse(sys.argv[1]).password or "")' "$LOCAL_LSP_URL")

cat >"$FX/temiz.sql" <<'SQL'
ALTER TABLE public.cases ADD COLUMN zz_dryrun_test integer;
CREATE OR REPLACE FUNCTION public.zz_dryrun_t() RETURNS integer LANGUAGE sql
AS $$ SELECT count(*)::int FROM public.v_stat_saglik_vaka $$;
SQL
cat >"$FX/bozuk.sql" <<'SQL'
UPDATE public.cases SET zz_olmayan_kolon = 1 WHERE false;
SQL

# ── T2 temiz ───────────────────────────────────────────────────────────
bash "$DRY" "$FX/temiz.sql" >"$FX/temiz.out" 2>&1; RC=$?
if [[ $RC -eq 0 ]] && grep -q 'DRY-RUN: BAŞARILI' "$FX/temiz.out"; then
  pass "T2 temiz fixture rc=0"
else
  fail "T2 temiz fixture rc=$RC"; tail -15 "$FX/temiz.out"
fi

# ── T3 bozuk ───────────────────────────────────────────────────────────
bash "$DRY" "$FX/bozuk.sql" >"$FX/bozuk.out" 2>&1; RC=$?
if [[ $RC -ne 0 ]] && grep -q '42703' "$FX/bozuk.out" && ! grep -q 'Ayna tazeleme BAŞARISIZ' "$FX/bozuk.out"; then
  pass "T3 bozuk fixture rc=$RC + 42703"
else
  fail "T3 bozuk fixture rc=$RC (42703 bekleniyordu)"; tail -15 "$FX/bozuk.out"
fi

# ── T5 yalnız NOTICE (kodlu) taşıyan temiz migration → rc 0 ─────────────
cat >"$FX/notice.sql" <<'SQL'
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS zz_n integer;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS zz_n integer;
DO $$ BEGIN RAISE NOTICE 'bilgi'; END $$;
SQL
bash "$DRY" "$FX/notice.sql" >"$FX/notice.out" 2>&1; RC=$?
if [[ $RC -eq 0 ]] && grep -q '42701' "$FX/notice.out"; then
  pass "T5 NOTICE-only migration rc=0 (42701 NOTICE hata sayılmadı)"
else
  fail "T5 NOTICE-only migration rc=$RC"; grep -aE 'NOTICE|ERROR|DRY-RUN|•' "$FX/notice.out" | head -8
fi

# ── T4 parola sızıntısı ────────────────────────────────────────────────
if [[ -n "$PW" ]] && cat "$FX"/*.out | grep -qF -- "$PW"; then
  fail "T4 çıktıda LOCAL_LSP_URL parolası var"
else
  pass "T4 çıktıda parola yok"
fi

echo "SONUÇ: $FAILS hata"
[[ $FAILS -eq 0 ]]
