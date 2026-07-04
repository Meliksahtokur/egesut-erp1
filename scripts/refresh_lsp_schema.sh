#!/usr/bin/env bash
# refresh_lsp_schema.sh — Canlı Supabase şemasını çekip yerel Postgres'e (bu makine) yükler (Management API).
# ŞİFRE YOK: SB_MGMT_TOKEN (anon olmayan, sadece tools-bank/.env'den okunur).
# Kullanım: bash scripts/refresh_lsp_schema.sh
#
# Akış:
#   1) Canlıdan sayım al (50 tablo / 169 fonksiyon / 12 view — bugünkü gerçek).
#   2) Tipleri çek (enum yok ama best-effort, ileride enum eklenirse hazır).
#   3) Tabloları constraint-free olarak çek.
#   4) Fonksiyonları pg_get_functiondef ile çek (2 geçiş: ilki aggregate 100KB+ sınırı için).
#   5) View'ları CREATE OR REPLACE VIEW olarak çek.
#   6) Yerel Postgres'te public schema'yı yeniden kur + roller.
#   7) Sıralı yükle: tipler → tablolar → fonksiyonlar (2 geçiş) → view'lar.
#   8) Sayım karşılaştırması + eksik raporu.
#
# Çıktı dosyaları (debug): /tmp/refresh_lsp/*.sql
set -euo pipefail

# ── ENV ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

: "${SB_MGMT_TOKEN:?SB_MGMT_TOKEN missing — .env'i kontrol et}"
: "${SB_PROJECT_REF:=zqnexqbdfvbhlxzelzju}"
: "${LOCAL_LSP_URL:?LOCAL_LSP_URL missing — .env'i kontrol et}"

OUT_DIR="/tmp/refresh_lsp"
mkdir -p "$OUT_DIR"

API="https://api.supabase.com/v1/projects/${SB_PROJECT_REF}/database/query"
mgt_query() {
  curl -sS -X POST "$API" \
    -H "Authorization: Bearer ${SB_MGMT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$1" '{query:$q}')"
}

say() { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# ── 1) CANLI SAYIM ─────────────────────────────────────────────────────
say "1/7 Canlı sayım alınıyor…"
LIVE_T=$(mgt_query "SELECT COUNT(*)::int AS n FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'" | jq -r '.[0].n')
LIVE_F=$(mgt_query "SELECT COUNT(*)::int AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'" | jq -r '.[0].n')
LIVE_V=$(mgt_query "SELECT COUNT(*)::int AS n FROM information_schema.views WHERE table_schema='public'" | jq -r '.[0].n')
LIVE_E=$(mgt_query "SELECT COUNT(*)::int AS n FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public' AND t.typtype='e'" | jq -r '.[0].n')
LIVE_D=$(mgt_query "SELECT COUNT(*)::int AS n FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public' AND t.typtype='d'" | jq -r '.[0].n')
LIVE_C=$(mgt_query "SELECT COUNT(*)::int AS n FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public' AND t.typtype='c' AND (t.typrelid=0 OR t.typrelid IS NULL)" | jq -r '.[0].n')
echo "  Tablo=$LIVE_T Fonksiyon=$LIVE_F View=$LIVE_V Enum=$LIVE_E Domain=$LIVE_D StandaloneComposite=$LIVE_C"

# ── 2) TYPES (enum) ───────────────────────────────────────────────────
say "2/7 Enum/composite/DDL üretiliyor…"
TYPES_DDL="-- (enum=0, domain=0, standalone composite=0 — şu an boş)"
if [[ "$LIVE_E" -gt 0 ]]; then
  TYPES_DDL=$(mgt_query "
    SELECT string_agg('CREATE TYPE public.'||quote_ident(t.typname)||' AS ENUM ('||lbl||');', E'\n')
    FROM (
      SELECT t.typname,
             string_agg(quote_literal(e.enumlabel), ',' ORDER BY e.enumsortorder) AS lbl
      FROM pg_type t
      JOIN pg_enum e   ON e.enumtypid=t.oid
      JOIN pg_namespace n ON n.oid=t.typnamespace
      WHERE n.nspname='public'
      GROUP BY t.typname
    ) t" | jq -r '.[0].string_agg // ""')
fi
echo "$TYPES_DDL" > "$OUT_DIR/types.sql"
echo "  types.sql: $(wc -c <"$OUT_DIR/types.sql") byte"

# ── 3) TABLOLAR (constraint-free, BASE TABLE filtresi) ─────────────────
say "3/7 Tablolar üretiliyor (constraint-free, BASE TABLE only)…"
TABLES_DDL=$(mgt_query "
  SELECT string_agg(stmt, E'\n')
  FROM (
    SELECT 'CREATE TABLE public.'||quote_ident(c.table_name)||' ('||
           string_agg(
             quote_ident(c.column_name)||' '||
             CASE
               WHEN c.data_type='USER-DEFINED' THEN c.udt_name
               WHEN c.data_type='ARRAY' THEN 'text[]'
               WHEN c.character_maximum_length IS NOT NULL
                    AND c.data_type IN ('character varying','character','text')
                 THEN c.data_type||'('||c.character_maximum_length||')'
               ELSE c.data_type
             END||
             CASE WHEN c.is_nullable='NO' THEN ' NOT NULL' ELSE '' END,
             ', ' ORDER BY c.ordinal_position
           )||');' AS stmt
    FROM information_schema.columns c
    WHERE c.table_schema='public'
      AND c.table_name IN (
        SELECT table_name FROM information_schema.tables
        WHERE table_schema='public' AND table_type='BASE TABLE'
      )
    GROUP BY c.table_name
  ) t" | jq -r '.[0].string_agg // ""')
echo "$TABLES_DDL" > "$OUT_DIR/tables.sql"
TABLES_GEN=$(grep -c '^CREATE TABLE' "$OUT_DIR/tables.sql" || echo 0)
echo "  tables.sql: $(wc -c <"$OUT_DIR/tables.sql") byte, $TABLES_GEN CREATE TABLE"

# ── 4) FONKSİYONLAR (pg_get_functiondef, satır başına 1 fn) ───────────
# string_agg gövde içinde $$/CREATE kelimesi yüzünden bozuluyor → her fn'i ayrı satır olarak çek.
say "4/7 Fonksiyonlar üretiliyor (her biri ayrı satır)…"
# Her fonksiyonu JSON array olarak çek (gövde bozulmasın)
FN_JSON=$(mgt_query "
  SELECT json_agg(pg_get_functiondef(p.oid) ORDER BY p.oid)
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'" | jq -c '.[0].json_agg // []')
FN_COUNT=$(echo "$FN_JSON" | jq 'length')
echo "  $FN_COUNT fonksiyon JSON array olarak alındı"

# 100'lü partiler halinde dosyaya yaz (script'in ikinci yarısı psql -f ile yükleyecek)
PART_SIZE=50
PARTS_DIR="$OUT_DIR/fn_parts"
mkdir -p "$PARTS_DIR"
for ((i=0; i<FN_COUNT; i+=PART_SIZE)); do
  PART=$(( i / PART_SIZE ))
  PART_FILE="$PARTS_DIR/fn_part_${PART}.sql"
  # Her fonksiyonun sonuna ';' ekle (pg_get_functiondef koymuyor, psql parser kırılıyor)
  echo "$FN_JSON" | jq -r ".[${i}:${i}+${PART_SIZE}] | .[] | . + \"\n;\"" > "$PART_FILE"
  ACTUAL=$(grep -c '^CREATE OR REPLACE FUNCTION\|^CREATE FUNCTION' "$PART_FILE" || echo 0)
  echo "  Part $PART: $(wc -c <"$PART_FILE") byte, ~$ACTUAL fn"
done

# ── 5) VIEW'LAR ───────────────────────────────────────────────────────
say "5/7 View'lar üretiliyor…"
VIEWS_DDL=$(mgt_query "
  SELECT string_agg(
    'CREATE OR REPLACE VIEW public.'||quote_ident(table_name)||
    ' AS '||view_definition,
    E'\n\n' ORDER BY table_name
  )
  FROM information_schema.views WHERE table_schema='public'" | jq -r '.[0].string_agg // ""')
echo "$VIEWS_DDL" > "$OUT_DIR/views.sql"
VIEWS_GEN=$(grep -c '^CREATE OR REPLACE VIEW' "$OUT_DIR/views.sql" || echo 0)
echo "  views.sql: $(wc -c <"$OUT_DIR/views.sql") byte, $VIEWS_GEN view"

# ── 6) YEREL: RESET public + ROLLER ────────────────────────────────────
say "6/7 Yerel 'public' şeması sıfırlanıyor + roller…"
psql "$LOCAL_LSP_URL" -v ON_ERROR_STOP=0 <<'SQL' >/dev/null 2>&1 || true
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;

-- RLS'i kapatan yardımcı roller (anon/authenticated/service_role/postgres)
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='service_role') THEN
    CREATE ROLE service_role NOLOGIN BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='postgres') THEN
    CREATE ROLE postgres NOLOGIN BYPASSRLS;
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;

-- vector extension: prod'da 'extensions' şemasında yaşıyor (public'te DEĞİL) —
-- aynısını burada da yapmazsak pg_proc(public) sayımı ~118 fazladan vector
-- fonksiyonuyla şişer ve canlı sayımla eşleşmez.
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO public, anon, authenticated, service_role;
CREATE EXTENSION IF NOT EXISTS vector SCHEMA extensions;
ALTER DATABASE egesut_lsp SET search_path TO public, extensions;
SQL
say "  Yerel public + vector extension hazır."

# ── 7) YÜKLE (sıralı, ON_ERROR_STOP=0) ────────────────────────────────
say "7/7 Yerel Postgres'e yükleniyor (sıralı, hata toplama modu)…"
LOAD_ERRORS=0
load_sql() {
  local f="$1" label="$2"
  if [[ -s "$f" ]]; then
    if ! psql "$LOCAL_LSP_URL" -v ON_ERROR_STOP=0 -f "$f" >"$OUT_DIR/${label}.out" 2>"$OUT_DIR/${label}.err"; then
      LOAD_ERRORS=$((LOAD_ERRORS+1))
    fi
    local err_lines
    err_lines=$(wc -l <"$OUT_DIR/${label}.err")
    echo "  $label: $err_lines hata satırı"
  else
    echo "  $label: boş, atlandı"
  fi
}

load_sql "$OUT_DIR/types.sql"   types
load_sql "$OUT_DIR/tables.sql"  tables
# fn parts (50'li partiler)
for f in "$OUT_DIR"/fn_parts/fn_part_*.sql; do
  [[ -s "$f" ]] || continue
  LABEL=$(basename "$f" .sql)
  load_sql "$f" "$LABEL"
done
load_sql "$OUT_DIR/views.sql"   views

# ── 8) SAYIM + RAPOR ──────────────────────────────────────────────────
say "Yerel sayım…"
N_T=$(psql "$LOCAL_LSP_URL" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")
N_F=$(psql "$LOCAL_LSP_URL" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'")
N_V=$(psql "$LOCAL_LSP_URL" -tAc "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public'")
echo "  Canlı:   T=$LIVE_T F=$LIVE_F V=$LIVE_V"
echo "  Yerel:   T=$N_T F=$N_F V=$N_V"
if [[ "$N_T" == "$LIVE_T" && "$N_F" == "$LIVE_F" && "$N_V" == "$LIVE_V" ]]; then
  echo -e "\033[1;32m✓ Birebir eşleşti.\033[0m"
else
  warn "Fark var — fn_part2.out ve fn_part1.out incele."
fi

echo
say "Özet: load_errors=$LOAD_ERRORS  (0 olması hedef; 1-2 FK bağımlılığı tipik)"
ls -la "$OUT_DIR"
