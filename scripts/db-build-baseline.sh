#!/usr/bin/env bash
# db-build-baseline.sh — db-validation kapısının C1 fazı için İZOLE baseline DB kurar.
#
# Ne yapar:
#   FAZ-0  Ortam paritesi: Mgmt API'den (SALT-OKUNUR) prod PG sürümü, yüklü
#          extension listesi+versiyonları ve rol listesini çeker; yerel PG ile
#          karşılaştırır. Davranışı etkileyen fark (major sürüm farkı, eksik
#          extension) parite dosyasına yazılır — UYUMSUZLUK ÇIKIŞ BAŞARISI YAPMAZ
#          (karar db-validate.sh'indir; bu script yalnızca raporlar).
#   KURULUM dropdb --if-exists + createdb ile izole DB; önce NOLOGIN roller
#          (agent_readonly, authenticated, anon, service_role — pg_dump cluster
#          rollerini taşımaz); sonra egesut_lsp aynasından pg_dump --schema-only
#          --no-owner --no-privileges alıp ON_ERROR_STOP=1 ile yükle.
#          RESTORE HATASI = nonzero exit (sessiz devam YASAK).
#   PGTAP  pgtap.sql raw.githubusercontent.com/theory/pgtap/master/pgtap.sql'den
#          curl ile çekilip izole DB'ye yüklenir (CREATE EXTENSION gerekmez).
#          Çekilemez/yüklenmezse hata — sessiz atlama yok.
#
# Kullanım:
#   bash scripts/db-build-baseline.sh [--db-name <ad>] [--parite-out <dosya>] [--json]
#     --db-name     varsayılan egesut_val_tmp
#     --parite-out  parite özetinin yazılacağı dosya (db-validate.sh okur);
#                   varsayılan <tmp>/parite.txt
#     --json        son satırda makine-okur JSON özet
#
# Çıkış: 0 = baseline kuruldu (parite uyumsuz olsa bile); nonzero = kurulum
#        hatası ya da ortam hatası (token yok, PG yok, pgtap çekilemedi).
#
# Prod'a HİÇ yazma yok: Mgmt API yalnız SELECT/SHOW benzeri sorgular.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

DB_NAME="egesut_val_tmp"
JSON_MODE=0
PARITE_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-name)    DB_NAME="${2:?--db-name değer ister}"; shift 2 ;;
    --parite-out) PARITE_OUT="${2:?--parite-out değer ister}"; shift 2 ;;
    --json)       JSON_MODE=1; shift ;;
    -h|--help)    grep '^#' "$0" | head -30; exit 0 ;;
    *) printf '❌ Bilinmeyen argüman: %s\n' "$1" >&2; exit 64 ;;
  esac
done

# Geçici kök: sabit /tmp YASAK (kullanıcı kuralı) — TMPDIR/SS_TMP_ROOT zorunlu.
TMP_ROOT="${SS_TMP_ROOT:-${TMPDIR:-}}"
if [[ -z "$TMP_ROOT" ]]; then
  echo "❌ TMPDIR ya da SS_TMP_ROOT set değil — disk-tabanlı geçici kök gerekli." >&2
  exit 78
fi
OUT_DIR=$(mktemp -d "$TMP_ROOT/db-baseline.XXXXXXXX")
trap 'rm -rf "$OUT_DIR"' EXIT
# Varsayılan parite dosyası OUT_DIR'de YAŞAMAZ (trap siler; db-validate.sh sonra okur).
[[ -n "$PARITE_OUT" ]] || PARITE_OUT="$TMP_ROOT/parite-$DB_NAME.txt"

: "${LOCAL_LSP_URL:?LOCAL_LSP_URL missing — .env'i kontrol et}"
: "${SB_MGMT_TOKEN:?SB_MGMT_TOKEN missing — .env'i kontrol et}"
: "${SB_PROJECT_REF:=zqnexqbdfvbhlxzelzju}"

say()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

API="https://api.supabase.com/v1/projects/${SB_PROJECT_REF}/database/query"
# Mgmt API salt-okunur sorgu (supabase_migrate / refresh_lsp_schema.sh çağrı biçimi)
mgt_query() {
  curl -sS -X POST "$API" \
    -H "Authorization: Bearer ${SB_MGMT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$1" '{query:$q}')"
}

# ── FAZ-0: ORTAM PARİTESİ (salt-okunur) ───────────────────────────────
say "FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…"

PROD_VER=$(mgt_query "SELECT current_setting('server_version') AS v" | jq -r '.[0].v // empty')
if [[ -z "$PROD_VER" ]]; then
  warn "Mgmt API sürüm sorgusu boş döndü — parite 'bilinmiyor' olarak işaretlenir."
fi

PROD_EXT_JSON=$(mgt_query "SELECT extname, extversion FROM pg_extension ORDER BY extname" | jq -c '.')
PROD_ROLES_JSON=$(mgt_query "SELECT rolname FROM pg_roles WHERE rolcanlogin OR rolname IN ('anon','authenticated','service_role','agent_readonly','demo_reader') ORDER BY rolname" | jq -c '.')
# Prod canlı nesne sayıları — ayna tazelik kontrolü için (parite değil, tazelik).
PROD_CNT=$(mgt_query "
  SELECT
    (SELECT COUNT(*)::int FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE') AS t,
    (SELECT COUNT(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public') AS f,
    (SELECT COUNT(*)::int FROM information_schema.views WHERE table_schema='public') AS v" | jq -c '.[0] // empty')

LOCAL_VER=$(psql "$LOCAL_LSP_URL" -tAc "SELECT current_setting('server_version')" | tr -d ' ')
PROD_MAJOR="${PROD_VER%%.*}"; LOCAL_MAJOR="${LOCAL_VER%%.*}"

# Yerel aynada kurulu extension'lar (ayna gerçek PG kurulumu, prod farkı burada görünür)
LOCAL_EXT_JSON=$(psql "$LOCAL_LSP_URL" -tAc "SELECT json_agg(e ORDER BY e.extname) FROM (SELECT extname, extversion FROM pg_extension ORDER BY extname) e")

PARITE_DURUM="uyumlu"
PARITE_NOTLAR=()
if [[ -z "$PROD_VER" ]]; then
  PARITE_DURUM="bilinmiyor"
  PARITE_NOTLAR+=("Mgmt API'den prod sürümü alınamadı — parite doğrulanamadı")
else
  if [[ "$PROD_MAJOR" != "$LOCAL_MAJOR" ]]; then
    PARITE_DURUM="uyumsuz"
    PARITE_NOTLAR+=("PG major sürüm farkı: prod=${PROD_VER} yerel=${LOCAL_VER} — davranış farkı mümkün (ör. planner/strictness); migration sonucu prod'da farklılaşabilir")
  fi
  # Aynada kurulu ama prod'da olmayan / prod'da kurulu ama aynada olmayan extension'lar
  MISSING_IN_PROD=$(jq -rn --argjson local "$LOCAL_EXT_JSON" --argjson prod "$PROD_EXT_JSON" \
    '($local|map(.extname)) - ($prod|map(.extname)) | join(", ")')
  MISSING_IN_LOCAL=$(jq -rn --argjson local "$LOCAL_EXT_JSON" --argjson prod "$PROD_EXT_JSON" \
    '($prod|map(.extname)) - ($local|map(.extname)) | join(", ")')
  [[ -n "$MISSING_IN_PROD" ]] && { PARITE_DURUM="uyumsuz"; PARITE_NOTLAR+=("Aynada kurulu ama prod'da YOK: $MISSING_IN_PROD"); }
  # prod'da fazladan kurulu extension'lar bilgi amaçlı — baseline'ı etkilemez
  [[ -n "$MISSING_IN_LOCAL" ]] && PARITE_NOTLAR+=("Bilgi: prod'da kurulu ama aynada yok (etkisizse sorun değil): $MISSING_IN_LOCAL")
  # Versiyon farkları (major.minor seviyesinde) — yalnız uyarı
  while IFS=$'\t' read -r ext pv lv; do
    [[ -n "$ext" ]] || continue
    if [[ "$pv" != "$lv" ]]; then
      PARITE_NOTLAR+=("Bilgi: $ext versiyon farkı prod=$pv yerel=$lv")
    fi
  done < <(jq -rn --argjson local "$LOCAL_EXT_JSON" --argjson prod "$PROD_EXT_JSON" \
    '$prod[] as $p | ($local[] | select(.extname==$p.extname)) as $l | "\($p.extname)\t\($p.extversion)\t\($l.extversion)"')
fi

# Rol karşılaştırması: prod'da login'abilen/önemli rollerin isim listesi (bilgi amaçlı)
PROD_ROLES=$(echo "$PROD_ROLES_JSON" | jq -r '.[].rolname' | paste -sd, -)

# Parite dosyası (db-validate.sh FAZ-0 bunu okur)
{
  echo "parite_durum=$PARITE_DURUM"
  echo "prod_pg=$PROD_VER"
  echo "yerel_pg=$LOCAL_VER"
  echo "prod_roller=$PROD_ROLES"
  if [[ ${#PARITE_NOTLAR[@]} -gt 0 ]]; then
    echo "notlar:"
    for n in "${PARITE_NOTLAR[@]}"; do echo "  - $n"; done
  fi
} > "$PARITE_OUT"
say "  Parite: $PARITE_DURUM (prod=$PROD_VER yerel=$LOCAL_VER) → $PARITE_OUT"

# ── AYNA TAZELİĞİ ─────────────────────────────────────────────────────
# refresh_lsp_schema.sh'in koşma zamanı kayıtlı değil → nesne sayımla kıyas;
# eşleşmezse ya da prod sayımı alınamadıysa 'bilinmiyor' de (tahmin uydurma).
Tazelik="bilinmiyor"
# Ayna sayımı (tek satır, tab-separated) — alt-shell tuzağına düşmeden process-substitution ile oku
read -r N_T N_F N_V < <(psql "$LOCAL_LSP_URL" -tAc "
  SELECT
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE')||' '||
    (SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public')||' '||
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public')")
if [[ -n "$PROD_CNT" ]]; then
  P_T=$(echo "$PROD_CNT" | jq -r '.t'); P_F=$(echo "$PROD_CNT" | jq -r '.f'); P_V=$(echo "$PROD_CNT" | jq -r '.v')
  if [[ "$N_T" == "$P_T" && "$N_F" == "$P_F" && "$N_V" == "$P_V" ]]; then
    Tazelik="taze (nesne sayımı prod ile eşleşiyor: T=$N_T F=$N_F V=$N_V)"
  else
    Tazelik="bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=$N_T F=$N_F V=$N_V, prod T=$P_T F=$P_F V=$P_V; refresh_lsp_schema.sh koş)"
  fi
else
  warn "Prod canlı sayımı alınamadı — tazelik 'bilinmiyor'."
fi
say "  Ayna tazeliği: $Tazelik"

# ── İZOLE DB KURULUMU ─────────────────────────────────────────────────
say "İzole DB kuruluyor: $DB_NAME"
# Bağlantı URI'sını PG* env'ine ayrıştır (dropdb/createdb URI'yi dbname sanıp
# parolayı NOTICE ile sızdırabiliyor — env yolu temiz ve davranışı deterministik).
# Beklenen biçim: postgres://[kullanıcı[:parola]@]host[:port]/veritabanı
URI_BODY="${LOCAL_LSP_URL#*://}"
URI_NOPATH="${URI_BODY%%/*}"
URI_AUTH=""; URI_HOSTPORT="$URI_NOPATH"
if [[ "$URI_NOPATH" == *@* ]]; then
  URI_AUTH="${URI_NOPATH%%@*}"; URI_HOSTPORT="${URI_NOPATH#*@}"
fi
export PGHOST="${URI_HOSTPORT%%:*}"
export PGPORT="${URI_HOSTPORT##*:}"; [[ "$PGPORT" == "$URI_HOSTPORT" ]] && unset PGPORT
export PGUSER="${URI_AUTH%%:*}"
if [[ "$URI_AUTH" == *:* ]]; then export PGPASSWORD="${URI_AUTH#*:}"; fi
VAL_URL="postgres://${URI_NOPATH}/${DB_NAME}"
dropdb --if-exists "$DB_NAME"
createdb "$DB_NAME"

# Roller ÖNCE: pg_dump cluster rollerini taşımaz; migration'lar bu rollere
# GRANT edebiliyor → NOLOGIN yerel karşılıkları şart.
say "Roller kuruluyor (NOLOGIN)…"
psql "$VAL_URL" -v ON_ERROR_STOP=1 <<'SQL' || fail "Rol kurulumu başarısız — izole DB kurulamadı"
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='agent_readonly') THEN
    CREATE ROLE agent_readonly NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
SQL

# Aynadan şema-only dump + yükleme (restore hatası = nonzero, sessiz devam YASAK)
say "egesut_lsp aynasından pg_dump alınıyor…"
pg_dump --schema-only --no-owner --no-privileges "$LOCAL_LSP_URL" -f "$OUT_DIR/baseline.sql"

say "Baseline izole DB'ye yükleniyor (ON_ERROR_STOP=1)…"
if ! psql "$VAL_URL" -v ON_ERROR_STOP=1 -f "$OUT_DIR/baseline.sql" >"$OUT_DIR/restore.out" 2>"$OUT_DIR/restore.err"; then
  tail -20 "$OUT_DIR/restore.err" >&2 || true
  fail "RESTORE HATASI — baseline yüklenemedi (detay: $OUT_DIR/restore.err). Sessiz devam yasak."
fi

# ── PGTAP ─────────────────────────────────────────────────────────────
say "pgTAP çekiliyor…"
# Kaynak 1: repo kökünde üretilmiş pgtap.sql varsa (bazı dallarda var);
# Kaynak 2: GitHub latest release zip'i (pgtap.sql zip içinde üretilir olarak gelir).
if ! curl -fsSL --retry 2 -o "$OUT_DIR/pgtap.sql" \
  "https://raw.githubusercontent.com/theory/pgtap/master/pgtap.sql"; then
  warn "raw master pgtap.sql 404 (repo içinde üretilmiyor) — latest release zip'e düşülüyor…"
  PGTAP_REL_URL=$(curl -fsSL "https://api.github.com/repos/theory/pgtap/releases/latest" \
    | jq -r '.assets[]?.browser_download_url | select(endswith(".zip"))' | head -1)
  [[ -n "$PGTAP_REL_URL" ]] || fail "pgtap release zip bulunamadı (GitHub API) — sessiz atlama YASAK."
  curl -fsSL --retry 2 -o "$OUT_DIR/pgtap.zip" "$PGTAP_REL_URL" \
    || fail "pgtap release zip indirilemedi ($PGTAP_REL_URL) — sessiz atlama YASAK."
  python3 - "$OUT_DIR/pgtap.zip" "$OUT_DIR/pgtap-src" <<'PY' || fail "pgtap zip açılamadı — sessiz atlama YASAK."
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    z.extractall(sys.argv[2])
PY
  # Zip'te pgtap.sql üretilmiyor (kaynak .in şablonu) — make ile üret.
  PGTAP_MAKE_DIR=$(find "$OUT_DIR/pgtap-src" -maxdepth 1 -mindepth 1 -type d | head -1)
  [[ -n "$PGTAP_MAKE_DIR" ]] || fail "pgtap zip içeriği beklenmedik — sessiz atlama YASAK."
  (cd "$PGTAP_MAKE_DIR" && make sql/pgtap.sql >/dev/null) \
    || fail "make sql/pgtap.sql başarısız — sessiz atlama YASAK."
  cp "$PGTAP_MAKE_DIR/sql/pgtap.sql" "$OUT_DIR/pgtap.sql"
fi
[[ -s "$OUT_DIR/pgtap.sql" ]] || fail "pgtap.sql boş/eksik — sessiz atlama YASAK."
say "pgTAP yükleniyor ($(wc -c <"$OUT_DIR/pgtap.sql") byte, ayrı 'pgtap' şemasına)…"
# pgtap.sql nesneleri nitelemsiz yaratır → search_path ile kendi şemasına yönlendir;
# public şeması (baseline) kirletilmesin ki nesne sayımları anlamlı kalsın.
if ! psql "$VAL_URL" -v ON_ERROR_STOP=1 \
     -c "CREATE SCHEMA IF NOT EXISTS pgtap" \
     -c "SET search_path TO pgtap, public" \
     -f "$OUT_DIR/pgtap.sql" >"$OUT_DIR/pgtap.out" 2>"$OUT_DIR/pgtap.err"; then
  tail -20 "$OUT_DIR/pgtap.err" >&2 || true
  fail "pgTAP yüklemesi başarısız — izole baseline pgtap'siz bırakılamaz."
fi
# pgtap fonksiyon gövdeleri nitelemsiz çağrı yapar → DB seviyesinde search_path'e
# pgtap şemasını ekle (aynadaki extensions şeması yaklaşımıyla aynı desen).
psql "$VAL_URL" -v ON_ERROR_STOP=1 -c "ALTER DATABASE $DB_NAME SET search_path TO public, pgtap" \
  || fail "search_path ayarlanamadı (ALTER DATABASE)"

# ── SAYIM + ÖZET ──────────────────────────────────────────────────────
B_T=$(psql "$VAL_URL" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'")
B_F=$(psql "$VAL_URL" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'")
B_V=$(psql "$VAL_URL" -tAc "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public'")
PGTAP_FN=$(psql "$VAL_URL" -tAc "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='pgtap'")

if [[ "$JSON_MODE" -eq 1 ]]; then
  jq -nc \
    --arg db_name "$DB_NAME" \
    --argjson tablo "$B_T" --argjson fonksiyon "$B_F" --argjson view "$B_V" \
    --argjson pgtap_fn "$PGTAP_FN" \
    --arg parite_durum "$PARITE_DURUM" \
    --arg baseline_kaynak "egesut_lsp" \
    --arg tazelik "$Tazelik" \
    --arg parite_dosya "$PARITE_OUT" \
    --arg prod_pg "$PROD_VER" --arg yerel_pg "$LOCAL_VER" \
    '{db_name:$db_name, tablo:$tablo, fonksiyon:$fonksiyon, view:$view,
      pgtap_fn:$pgtap_fn, parite_durum:$parite_durum, baseline_kaynak:$baseline_kaynak,
      ayna_tazelik:$tazelik, parite_dosya:$parite_dosya,
      prod_pg:$prod_pg, yerel_pg:$yerel_pg}'
else
  printf '\033[1;32m✓ BASELINE OK\033[0m db=%s tablo=%s fonksiyon=%s view=%s pgtap_fn=%s | ayna_tazelik: %s | parite: %s (%s vs %s) | parite dosyası: %s\n' \
    "$DB_NAME" "$B_T" "$B_F" "$B_V" "$PGTAP_FN" "$Tazelik" "$PARITE_DURUM" "$PROD_VER" "$LOCAL_VER" "$PARITE_OUT"
fi
