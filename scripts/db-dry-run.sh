#!/usr/bin/env bash
# db-dry-run.sh — Migration SQL'i canlıya dokunmadan yerel şema aynasında çalıştır.
#
# Ayna = LOCAL_LSP_URL (refresh_lsp_schema.sh'nin TAZELEDİĞİ DB'nin aynısı;
# 2026-11-09'a dek deneme Neon'da koşuyordu → tazelenen ≠ denenen).
# Constraint-free: tablo+kolon+fonksiyon+view var; index/trigger/policy/
# constraint YOK, plpgsql gövdeleri derlenmez (gövde içi 42703 yakalanmaz).
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
# TMPDIR uyumu (Task 1.7 + F8): geçici kök SS_TMP_ROOT → TMPDIR sırayla
# çözülür; hiçbiri yoksa script HATA verir (kök yoksa fallback yoktur).
# Tüm geçici dosyalar o köke mktemp'lenir, çıkışta trap ile silinir.
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

# ── F6 (tur-1): kendi transaction kontrolünü içeren dosyayı reddet ───────
# Sarmalayıcı tek BEGIN…ROLLBACK açar; dosya içinden COMMIT/ROLLBACK/BEGIN
# sarmalayıcıyı kırar → kapanış ROLLBACK'i transaction DIŞINDA koşar ve DDL/
# backfill geri alınamaz. Guard statik greptir, fail-closed.
# Sınır: SQL `END;` (COMMIT eşanlamlısı) plpgsql `END;`'ten statik olarak
# ayırt edilemez → taranmaz; satır-başı transaction fiilleri taranır.
TX_HITS=$(grep -inE '^[[:space:]]*(BEGIN([[:space:]]+(WORK|TRANSACTION))?|START[[:space:]]+TRANSACTION|COMMIT([[:space:]]+(WORK|TRANSACTION|PREPARED))?|ROLLBACK([[:space:]]+(WORK|TRANSACTION|PREPARED))?)[[:space:]]*;' "$SQL_FILE" || true)
if [[ -n "$TX_HITS" ]]; then
  echo "❌ Migration dosyası kendi transaction kontrolünü içeriyor — dry-run sarmalayıcısı kırılır:" >&2
  echo "$TX_HITS" | sed 's/^/    satır /' >&2
  echo "   İç transaction deyimlerini kaldır (Supabase runner dosyayı zaten tek transaction'da koşar)." >&2
  exit 65
fi

# ── ENV ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  LOCAL_LSP_URL=$(grep -E "^LOCAL_LSP_URL=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
fi

: "${LOCAL_LSP_URL:?LOCAL_LSP_URL missing - .env dosyasini kontrol et}"
export LOCAL_LSP_URL   # refresh_lsp_schema.sh aynı DB'yi tazelesin

command -v psql >/dev/null || { echo "❌ psql yok"; exit 1; }

say()    { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn()   { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()    { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }
ok()     { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  DB Dry-Run — yerel şema aynası (constraint-free)"
echo "═══════════════════════════════════════════════════════════════"
echo "  SQL dosyası : $SQL_FILE"
echo "  Boyut       : $(wc -c <"$SQL_FILE") byte, $(wc -l <"$SQL_FILE") satır"
echo "  Hedef       : yerel ayna (LOCAL_LSP_URL; ROLLBACK — canlıya DOKUNMAZ)"
echo "═══════════════════════════════════════════════════════════════"
echo

# ── 1) AYNA TAZELE ─────────────────────────────────────────────────────
# F8 (root-gate): kök çözümlemesi — SS_TMP_ROOT → TMPDIR → hata (fail-closed).
TMP_ROOT="${SS_TMP_ROOT:-${TMPDIR:-}}"
if [[ -z "$TMP_ROOT" ]]; then
  echo "❌ TMPDIR ya da SS_TMP_ROOT set değil — disk-tabanlı geçici kök gerekli (F8)." >&2
  exit 78
fi
REFRESH_LOG=$(mktemp "$TMP_ROOT/dry-run-refresh.XXXXXX.log")
trap 'rm -f "${REFRESH_LOG:-}" "${OUT_TMP:-}" "${ERR_TMP:-}"' EXIT
# Kilit: tazeleme→deneme arasında başka bir refresh (ör. DDL hook'u) aynayı
# sıfırlarsa yarım aynada yanlış-yeşil olur → ikisi tek kilit altında.
exec 9>"$HOME/.cache/egesut-lsp-ayna.lock"
flock -w 600 9 || { err "Ayna kilidi 600 sn'de alınamadı (fail-closed)."; exit 67; }
export EGESUT_AYNA_KILITLI=1
say "1/2 Yerel ayna tazeleniyor (bayat ayna yanlış-pozitif verir)…"
if bash "${SCRIPT_DIR}/refresh_lsp_schema.sh" >"$REFRESH_LOG" 2>&1; then
  ok "Ayna tazelendi."
else
  # F5 (tur-1): bayat/KISMİ ayna ile dry-run kabul edilmez — fail-closed.
  err "Ayna tazeleme BAŞARISIZ — dry-run durduruldu (fail-closed)."
  tail -n 8 "$REFRESH_LOG" | sed 's/^/   | /' >&2   # log çıkışta silinir
  exit 66
fi

# ── 2) DRY-RUN (BEGIN; … ROLLBACK;) ───────────────────────────────────
say "2/2 Migration yerel aynada çalıştırılıyor (transaction içinde, rollback)…"

# Geçici dosyalar
OUT_TMP=$(mktemp "$TMP_ROOT/dry-run-out.XXXXXX")
ERR_TMP=$(mktemp "$TMP_ROOT/dry-run-err.XXXXXX")

# BEGIN/ROLLBACK tek psql çağrısıyla sar:
#   -c "BEGIN;" -f migration.sql -c "ROLLBACK;"
# psql'in exit kodu: son komutun durumu (ROLLBACK → 0 beklenir)
psql "$LOCAL_LSP_URL" -X \
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
# Yalnız ERROR/FATAL satırları: verbose NOTICE de kod basar (42701 "skipping",
# RAISE NOTICE 00000) ve temiz migration'ı yanlış-kırmızı yapıyordu. Hata
# yakalama zaten PSQL_EXIT'e de bağlı (ON_ERROR_STOP) → süzme fail-open değil.
ERR_TEXT=$(grep -aE '(ERROR|FATAL|PANIC|HATA): ' "$ERR_TMP" 2>/dev/null || true)

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
  ok "Hiçbir hata yakalanmadı. Migration yerel aynada temiz çalışıyor (ROLLBACK atıldı)."
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
warn "ÖNEMLİ — yerel ayna CONSTRAINT-FREE olduğu için:"
echo "   • FK ihlalleri (yanlış ref_tohumlama_id) burada YAKALANMAZ"
echo "   • Unique/PK ihlalleri burada YAKALANMAZ"
echo "   • Sadece kolon/tablo/fonksiyon VARLIK + TİP kontrolü çalışır"
echo "   • Index/trigger/policy/constraint adı çakışması (42710/42P07) YAKALANMAZ"
echo "   • plpgsql gövdesindeki olmayan kolon/tablo (42703/42P01) YAKALANMAZ"
echo "   • Migration canlıya uygulanmadan önce ayrıca gerçek DB'de de test et"
echo
echo "═══════════════════════════════════════════════════════════════"

exit "$EXIT_CODE"