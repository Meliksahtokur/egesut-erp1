#!/usr/bin/env bash
# db-dry-run.sh — Migration SQL'i canlıya dokunmadan Neon aynasında çalıştır.
#
# Neon = constraint-free şema aynası (sadece varlık/tip kontrolü, FK ihlali YOK).
# Hata kodları:
#   42703 → undefined_column (kolon yok)
#   42P01 → undefined_table (tablo yok)
#   42883 → undefined_function (fonksiyon yok)
#   42710 → duplicate_object (conflict — mevcut obje)
#   42P07 → duplicate_table
#   42704 → duplicate_object (type)
#
# Kullanım:
#   bash scripts/db-dry-run.sh <migration.sql>
#
# Akış:
#   1) refresh_lsp_schema.sh çağır (ayna taze olsun)
#   2) Migration'ı BEGIN/ROLLBACK transaction içinde psql ile çalıştır
#   3) Hata kodlarını ayıkla ve raporla

set -euo pipefail

# ── ARG ────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Kullanım: $0 <migration.sql>" >&2
  exit 64
fi
SQL_FILE="$1"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "❌ Dosya bulunamadı: $SQL_FILE" >&2
  exit 2
fi

# ── ENV ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  NEON_LSP_URL=$(grep -E "^NEON_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
fi

: "${NEON_LSP_URL:?NEON_LSP_URL missing - .env dosyasini kontrol et}"

command -v psql >/dev/null || { echo "❌ psql yok"; exit 1; }

# Neon URL'den PGPASSWORD parse (sql-lsp.sh ile aynı desen)
URL="$NEON_LSP_URL"
PGPASSWORD=$(python3 -c "import urllib.parse as u; p=u.urlparse('''$URL'''); print(p.password or '')")
export PGPASSWORD
export PGHOST PGUSER PGDATABASE PGPORT
PGHOST=$(python3 -c "import urllib.parse as u; p=u.urlparse('''$URL'''); print(p.hostname)")
PGPORT=$(python3 -c "import urllib.parse as u; p=u.urlparse('''$URL'''); print(p.port or 5432)")
PGUSER=$(python3 -c "import urllib.parse as u; p=u.urlparse('''$URL'''); print(p.username)")
PGDATABASE=$(python3 -c "import urllib.parse as u; p=u.urlparse('''$URL'''); print(p.path.lstrip('/'))")

say()    { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn()   { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()    { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }
ok()     { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  DB Dry-Run — Neon aynası (constraint-free)"
echo "═══════════════════════════════════════════════════════════════"
echo "  SQL dosyası : $SQL_FILE"
echo "  Boyut       : $(wc -c <"$SQL_FILE") byte, $(wc -l <"$SQL_FILE") satır"
echo "  Hedef       : Neon (Neon'da ROLLBACK — canlıya DOKUNMAZ)"
echo "═══════════════════════════════════════════════════════════════"
echo

# ── 1) AYNA TAZELE ─────────────────────────────────────────────────────
say "1/2 Neon aynası tazeleniyor (bayat ayna yanlış-pozitif verir)…"
if bash "${SCRIPT_DIR}/refresh_lsp_schema.sh" >/tmp/dry-run-refresh.log 2>&1; then
  ok "Ayna tazelendi."
else
  warn "Ayna tazeleme hatası (log: /tmp/dry-run-refresh.log). Mevcut ayna ile devam ediliyor."
fi

# ── 2) DRY-RUN (BEGIN; … ROLLBACK;) ───────────────────────────────────
say "2/2 Migration Neon'da çalıştırılıyor (transaction içinde, rollback)…"

# Geçici dosyalar
OUT_TMP=$(mktemp)
ERR_TMP=$(mktemp)
trap 'rm -f "$OUT_TMP" "$ERR_TMP"' EXIT

# BEGIN/ROLLBACK tek psql çağrısıyla sar:
#   -c "BEGIN;" -f migration.sql -c "ROLLBACK;"
# psql'in exit kodu: son komutun durumu (ROLLBACK → 0 beklenir)
psql "$NEON_LSP_URL" \
  -v ON_ERROR_STOP=1 \
  -v VERBOSITY=verbose \
  -c "BEGIN;" \
  -f "$SQL_FILE" \
  -c "ROLLBACK;" \
  > "$OUT_TMP" 2> "$ERR_TMP" || PSQL_EXIT=$?
PSQL_EXIT=${PSQL_EXIT:-0}

echo
echo "─────────────────────────────────────────────────────────────"
echo "  Migration çıktısı:"
echo "─────────────────────────────────────────────────────────────"
sed 's/^/    /' "$OUT_TMP"
if [[ -s "$ERR_TMP" ]]; then
  echo "─────────────────────────────────────────────────────────────"
  echo "  Hata çıktısı:"
  echo "─────────────────────────────────────────────────────────────"
  sed 's/^/    /' "$ERR_TMP"
fi
echo "─────────────────────────────────────────────────────────────"

# ── 3) HATA KODU AYIKLAMA ──────────────────────────────────────────────
echo
say "Hata kodu analizi…"

# psql hata mesajları genelde stderr'a "ERROR:" satırı olarak yazılır.
# VERBOSITY=verbose ile PostgreSQL SQLSTATE kodu görünür: "ERROR: 42703: ..." veya "ERROR: ... (42703)"
ERR_TEXT=$(cat "$ERR_TMP" 2>/dev/null || true)

declare -A ERR_LABELS=(
  ["42703"]="undefined_column  (kolon YOK)"
  ["42P01"]="undefined_table   (tablo YOK)"
  ["42883"]="undefined_function (fonksiyon/RPC YOK)"
  ["42710"]="duplicate_object  (conflict — obje zaten var)"
  ["42P07"]="duplicate_table   (CREATE TABLE mevcut)"
  ["42704"]="duplicate_object  (type/extension zaten var)"
  ["42P06"]="duplicate_schema  (şema zaten var)"
  ["0A000"]="feature_not_supported"
  ["42501"]="insufficient_privilege (yetki yok)"
)

FOUND_ERRORS=0
declare -A FOUND_CODES

# Hem "42703: ..." hem "(42703)" kalıplarını yakala
for CODE in 42703 42P01 42883 42710 42P07 42704 42P06 0A000 42501; do
  if echo "$ERR_TEXT" | grep -qE "(^|[^0-9A-Z])${CODE}([^0-9A-Z]|:)"; then
    FOUND_ERRORS=$((FOUND_ERRORS+1))
    FOUND_CODES[$CODE]="${ERR_LABELS[$CODE]}"
  fi
done

# Bilinmeyen hata kodlarını da raporla (verbose formatta "42703:" veya "42P01:" olarak görünür)
# "ERROR:" gibi 5-harfli kelimeleri dışla — sadece sayısal SQLSTATE'leri tut
UNKNOWN_CODES=$(echo "$ERR_TEXT" | grep -oE '\b[0-9A-Z]{5}:' | sort -u | tr -d ':' | grep -vE '^(42703|42P01|42883|42710|42P07|42704|42P06|0A000|42501|ERROR)$' || true)

if [[ "$FOUND_ERRORS" -eq 0 && -z "$UNKNOWN_CODES" && "$PSQL_EXIT" -eq 0 ]]; then
  ok "Hiçbir hata yakalanmadı. Migration Neon'da temiz çalışıyor (ROLLBACK atıldı)."
  echo
  printf '\033[1;32m✅ DRY-RUN: BAŞARILI\033[0m\n'
  EXIT_CODE=0
else
  if [[ "$FOUND_ERRORS" -gt 0 ]]; then
    printf '\033[1;31m🚨 %d hata kodu yakalandı:\033[0m\n' "$FOUND_ERRORS"
    for CODE in "${!FOUND_CODES[@]}"; do
      printf '   %s → %s\n' "$CODE" "${FOUND_CODES[$CODE]}"
    done
  fi
  if [[ -n "$UNKNOWN_CODES" ]]; then
    warn "Bilinmeyen hata kodları (incele):"
    echo "$UNKNOWN_CODES" | tr -d '()' | sed 's/^/     • /'
  fi
  echo
  printf '\033[1;31m❌ DRY-RUN: HATA\033[0m\n'
  EXIT_CODE=1
fi

# ── 4) ÖNEMLİ NOTLAR ──────────────────────────────────────────────────
echo
warn "ÖNEMLİ — Neon aynası CONSTRAINT-FREE olduğu için:"
echo "   • FK ihlalleri (yanlış ref_tohumlama_id) burada YAKALANMAZ"
echo "   • Unique/PK ihlalleri burada YAKALANMAZ"
echo "   • Sadece kolon/tablo/fonksiyon VARLIK + TİP kontrolü çalışır"
echo "   • Migration canlıya uygulanmadan önce ayrıca gerçek DB'de de test et"
echo
echo "═══════════════════════════════════════════════════════════════"

exit "$EXIT_CODE"