#!/usr/bin/env bash
# db-validate.sh — SQL migration doğrulama kapısı (SPEC: docs/plans/2026-09-24-db-validation-kapisi-spec.md).
#
# Bir migration dosyasını izole yerel PostgreSQL'de GERÇEKTEN uygulayıp doğrular.
# Prod'a HİÇ yazma yok; Mgmt API erişimi yalnız alt bileşen (db-build-baseline.sh)
# üzerinden ve salt-okunur sözleşmeyle.
#
# Kullanım:
#   bash scripts/db-validate.sh <migration.sql> [--data-mode auto|off|on] [--keep-db]
#
# FAZLAR (SPEC §3):
#   A  Statik risk     sqlfluff --dialect postgres (parse hatası = FAIL; stil = uyarı)
#                      + squawk (varsayılan kurallar; istisna listesi aşağıda gerekçeli)
#   B  Şema uyum (yardımcı, kesin hüküm YOK): migration-IÇİ yaratılan nesneler önce
#                      çıkarılır; kalan FROM/JOIN/ALTER referansları egesut_lsp
#                      information_schema'ya karşı kontrol; bulunamayan → 'C1'e bırakıldı'
#   C1 SCHEMA MODE     db-build-baseline.sh --json (stdout SON SATIR JSON) → izole DB'ye
#                      psql -v ON_ERROR_STOP=1 ile uygula → post-check (nesne var mı,
#                      RLS relrowsecurity ön/son karşılaştırması)
#   C2 DATA MODE       DML/UNIQUE/FK/NOT NULL içeren migration'da zorunlu: ikinci izole
#                      baseline DB'de sentetik satır tohumla → migration'ı uygula →
#                      veri bütünlüğü ihlali (unique/fk) tespiti
#   D  RAPOR           reports/db-validation-<sha8>.md (reports/ gitignore'lı)
#
# Çıkış kodları: 0=PASS 1=FAIL 2=INCONCLUSIVE (sessiz varsayım YOK — bilinmeyen
# durumda nonzero exit + açık hata mesajı).
#
# Geçici dosyalar: TMPROOT (SS_TMP_ROOT → TMPDIR) altında mktemp -d, trap ile silinir.
# --keep-db yoksa oluşturulan izole DB'ler trap ile drop edilir.

set -euo pipefail

# tr_TR yerelinde grep -i Türkçe I/ı kıvrımı yapar ve ASCII desenleri kırar
# [OBSERVED: tr_TR.UTF-8 altında 'public.dbval_...' → 'publ' eşleşmesi]; C yereli zorla.
export LC_ALL=C LANG=C

# ── ARG ────────────────────────────────────────────────────────────────
SQL_FILE=""
DATA_MODE="auto"   # auto | off | on
KEEP_DB=0

usage() { echo "Kullanım: $0 <migration.sql> [--data-mode auto|off|on] [--keep-db]" >&2; exit 64; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-mode)
      [[ $# -ge 2 ]] || usage
      DATA_MODE="$2"; shift 2 ;;
    --data-mode=*) DATA_MODE="${1#*=}"; shift ;;
    --keep-db) KEEP_DB=1; shift ;;
    -h|--help) usage ;;
    *)
      [[ -z "$SQL_FILE" ]] || { echo "❌ Fazla konum argümanı: $1" >&2; usage; }
      SQL_FILE="$1"; shift ;;
  esac
done
[[ -n "$SQL_FILE" ]] || usage
case "$DATA_MODE" in auto|off|on) ;; *) echo "❌ Geçersiz --data-mode: $DATA_MODE" >&2; exit 64;; esac
[[ -f "$SQL_FILE" ]] || { echo "❌ Dosya bulunamadı: $SQL_FILE" >&2; exit 64; }

# ── ORTAM ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
LOCAL_LSP_URL=""
if [[ -f "$ENV_FILE" ]]; then
  LOCAL_LSP_URL=$(grep -E "^LOCAL_LSP_URL=" "$ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")
fi
: "${LOCAL_LSP_URL:?LOCAL_LSP_URL missing — .env dosyasını kontrol et (egesut_lsp şema aynası bağlantısı)}"
command -v sqlfluff >/dev/null || { echo "❌ sqlfluff PATH'te değil (~/.local/bin)" >&2; exit 78; }
command -v squawk  >/dev/null || { echo "❌ squawk PATH'te değil (~/.local/bin)"  >&2; exit 78; }
command -v psql    >/dev/null || { echo "❌ psql PATH'te değil" >&2; exit 78; }
command -v python3 >/dev/null || { echo "❌ python3 PATH'te değil (JSON ayrıştırma için)" >&2; exit 78; }

# F8 uyumu: sabit /tmp YOK; SS_TMP_ROOT → TMPDIR, yoksa hata (fallback yok).
TMPROOT="${SS_TMP_ROOT:-${TMPDIR:-}}"
[[ -n "$TMPROOT" ]] || { echo "❌ TMPDIR ya da SS_TMP_ROOT set değil — disk-tabanlı geçici kök gerekli." >&2; exit 78; }
WORK=$(mktemp -d "$TMPROOT/dbval.XXXXXXXX")

# Bakım bağlantısı (DB yaratma/drop için): aynayla aynı küme, postgres DB.
MAINT_URL="$(echo "$LOCAL_LSP_URL" | sed -E 's#/[^//?]+$#/postgres#')"

# Oluşturduğumuz izole DB'ler (trap'te drop edilir).
declare -a OWN_DBS=()
cleanup() {
  local rc=$?
  if [[ $KEEP_DB -eq 0 && ${#OWN_DBS[@]} -gt 0 ]]; then
    for db in "${OWN_DBS[@]}"; do
      # Drop edemediysek BILINÇLİ bildir (sessiz artık YOK).
      psql "$MAINT_URL" -v ON_ERROR_STOP=0 -qc "DROP DATABASE IF EXISTS \"$db\"" \
        || echo "⚠️ İzole DB drop edilemedi, ARTIK KALDI: $db (elle silinmeli)" >&2
    done
  fi
  rm -rf "$WORK"
  exit $rc
}
trap cleanup EXIT INT TERM

SQL_ABS="$(readlink -f "$SQL_FILE")"
SHA256=$(sha256sum "$SQL_ABS" | awk '{print $1}')
SHA8="${SHA256:0:8}"
REPORT_DIR="${SCRIPT_DIR}/../reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/db-validation-$SHA8.md"

# Sonuç kayıtları: her kriter satırı "kriter|durum|not" biçiminde.
RESULT_FILE="$WORK/results.tsv"; : > "$RESULT_FILE"
log_result() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RESULT_FILE"; }
CMDS_FILE="$WORK/commands.log"; : > "$CMDS_FILE"
log_cmd() { printf '$ %s\n' "$1" >> "$CMDS_FILE"; }

# psql yardımcı: psql_q <db-url> <sql> — hata akışı dosyaya, exit kodu döner.
psql_q() {
  local url="$1" sql="$2" outf="$3"
  psql "$url" -v ON_ERROR_STOP=1 -qAt -c "$sql" > "$outf" 2>&1
}

# ══════════════════════════════════════════════════════════════════════
# FAZ A — Statik risk (sqlfluff + squawk)
# ══════════════════════════════════════════════════════════════════════
FAZA_OUT="$WORK/sqlfluff.out"
log_cmd "sqlfluff lint --dialect postgres '$SQL_ABS'"
# sqlfluff exit 1 = kural ihlali, 2+ = hata. PRS kodu = parse hatası → FAIL;
# diğer ihlaller stil düzeyi → uyarı (SPEC: yalnız parse hatası FAIL).
SQLFLUFF_RC=0
sqlfluff lint --dialect postgres "$SQL_ABS" > "$FAZA_OUT" 2>&1 || SQLFLUFF_RC=$?
PARSE_ERRS=$(grep -cE '\bPRS[0-9]*\b' "$FAZA_OUT" || true)
STYLE_ERRS=$(( $(grep -cE '^\s*L['"'"']?[0-9]+' "$FAZA_OUT" || true) - PARSE_ERRS ))
[[ $STYLE_ERRS -lt 0 ]] && STYLE_ERRS=0
if [[ $SQLFLUFF_RC -ge 2 && $PARSE_ERRS -eq 0 ]]; then
  log_result "A.sqlfluff-parse" "FAIL" "sqlfluff arızası (rc=$SQLFLUFF_RC), PRS dışı"
elif [[ $PARSE_ERRS -gt 0 ]]; then
  log_result "A.sqlfluff-parse" "FAIL" "$PARSE_ERRS parse hatası (PRS)"
else
  log_result "A.sqlfluff-parse" "PASS" "parse hatası yok (stil uyarısı: $STYLE_ERRS)"
fi

# squawk istisna listesi (SPEC §5: varsayılan kurallar + gerekçeli kayıtlı istisna;
# geçerli kural adları squawk 2.66 --exclude doğrulamasıyla sabitlendi [OBSERVED]):
# - require-concurrent-index-creation: kapı izole yerel DB'de tek kullanıcılı koşar;
#   CREATE INDEX CONCURRENTLY transaction İÇİNDE koşamaz → kapıda her migration FAIL
#   olurdu. Prod kilitleme riski sahip apply kapısının konusudur.
# - ban-drop-table: şema temizliği migration'ları (orphan tablo DROP gibi, bkz.
#   2026-07-07 orphan RLS fix) meşru; engellemek spec dışı politika olurdu.
SQUAWK_EXCLUDE="require-concurrent-index-creation,ban-drop-table"
FAZA_SQ="$WORK/squawk.out"
log_cmd "squawk --exclude=$SQUAWK_EXCLUDE '$SQL_ABS'"
SQUAWK_RC=0
# ANSI renk (SGR) + OSC-8 hyperlink kodları rapora sızmaz (strip).
squawk --exclude="$SQUAWK_EXCLUDE" "$SQL_ABS" 2>&1 \
  | sed 's/\x1b\][^\x07\x1b]*\(\x07\|\x1b\\\)//g; s/\x1b\[[0-9;]*m//g' > "$FAZA_SQ" || SQUAWK_RC=${PIPESTATUS[0]}
if [[ $SQUAWK_RC -eq 0 ]]; then
  log_result "A.squawk" "PASS" "varsayılan kurallar (istisna: $SQUAWK_EXCLUDE) ihlal yok"
elif [[ $SQUAWK_RC -eq 1 ]]; then
  # Squawk ihlalleri warning düzeyinde olabilir (prefer-robust-stmts, require-lock-timeout vb.).
  # Politika (sahip 2026-09-24, varsayılan kurallar): ERROR düzeyi ihlal = FAIL;
  # WARNING düzeyi = rapora kaydedilir ama FAIL DEĞİLDİR (masum migration'ları düşürmez,
  # sessiz de geçilmez — raporda görünür kalır).
  SQ_ERRORS=$(grep -c '^\[error\[\|error\[' "$FAZA_SQ" || true)
  SQ_WARN=$(grep -c 'warning\[' "$FAZA_SQ" || true)
  if [[ ${SQ_ERRORS:-0} -gt 0 ]]; then
    log_result "A.squawk" "FAIL" "squawk ERROR düzeyi ihlal(ler) (bkz. rapor çıktısı)"
  else
    log_result "A.squawk" "INCONCLUSIVE" "squawk yalnız WARNING düzeyi bulgu (${SQ_WARN} adet) — FAIL değil, rapora kaydedildi (bkz. çıktı)"
  fi
else
  log_result "A.squawk" "FAIL" "squawk arızası (rc=$SQUAWK_RC)"
fi

# ══════════════════════════════════════════════════════════════════════
# FAZ B — Yardımcı şema-uyumluluk (kesin hüküm YOK)
# ══════════════════════════════════════════════════════════════════════
# Migration metninde yaratılan nesne isimlerini çıkar (ilk satır-başı isim token'ı).
CREATED_FILE="$WORK/created.txt"
grep -ioE '^[[:space:]]*CREATE[[:space:]]+(OR[[:space:]]+REPLACE[[:space:]]+)?(UNIQUE[[:space:]]+)?(TABLE|INDEX|FUNCTION|VIEW|MATERIALIZED[[:space:]]+VIEW|TYPE|SCHEMA|TRIGGER|POLICY|EXTENSION|SEQUENCE)[[:space:]]+(IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" \
  | awk '{print $NF}' | tr '[:upper:]' '[:lower:]' | sed 's/^public\.//' | sort -u > "$CREATED_FILE" || true
# IF NOT EXISTS durumunda son iki token yakalanabilir; isim sütunu NF doğru kalır
# (IF NOT EXISTS satırı da dahil edildi). Ek temizlik:
sed -i -E 's/^(if|not|exists)$//' "$CREATED_FILE"

# Kalan dış referanslar: FROM/JOIN/ALTER TABLE ... / REFERENCES ... hedef isimleri.
REFS_FILE="$WORK/refs.txt"
{
  grep -ioE '(FROM|JOIN)[[:space:]]+(ONLY[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true
  grep -ioE 'ALTER[[:space:]]+TABLE[[:space:]]+(IF[[:space:]]+EXISTS[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true
  grep -ioE 'REFERENCES[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true
} | awk '{print $NF}' | tr '[:upper:]' '[:lower:]' | sed 's/^public\.//' | sort -u > "$REFS_FILE" || true

# egesut_lsp aynasındaki tablo+view+routine isimleri.
LSP_OBJS="$WORK/lsp_objects.txt"
log_cmd "psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)"
if psql_q "$LOCAL_LSP_URL" "
  SELECT lower(table_name) FROM information_schema.tables WHERE table_schema='public'
  UNION
  SELECT lower(routine_name) FROM information_schema.routines WHERE routine_schema='public'
  UNION
  SELECT lower(typname) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname='public' AND t.typtype IN ('e','c','d','r')
" "$LSP_OBJS.full"; then
  grep -E '^[a-z0-9_]+$' "$LSP_OBJS.full" | sort -u > "$LSP_OBJS"
  # Referanslardan migration-içi yaratılanlar ve aynada olanlar düşer; kalan = çözülemedi.
  KNOWN="$WORK/known.txt"; sort -u "$LSP_OBJS" "$CREATED_FILE" > "$KNOWN"
  UNRESOLVED=$(comm -23 "$REFS_FILE" "$KNOWN")
  if [[ -n "$UNRESOLVED" ]]; then
    log_result "B.sema-uyum" "INCONCLUSIVE" "statik çözülemedi (C1'e bırakıldı): $(echo "$UNRESOLVED" | tr '\n' ' ')"
  else
    log_result "B.sema-uyum" "PASS" "tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi)"
  fi
else
  # Faz B yardımcıdır; ayna okunamadıysa sessiz varsayım YASAK → açık not, C1 karar verir.
  log_result "B.sema-uyum" "INCONCLUSIVE" "egesut_lsp information_schema okunamadı — hüküm C1'e bırakıldı (ayna erişim hatası rapora eklendi)"
  cp "$LSP_OBJS.full" "$LSP_OBJS.err" 2>/dev/null || true
fi

# ══════════════════════════════════════════════════════════════════════
# DATA MODE ihtiyacı tespiti (SPEC: DML/UNIQUE/FOREIGN KEY/NOT NULL/SET NOT NULL)
# ══════════════════════════════════════════════════════════════════════
DATA_MARKERS=$(grep -icE '\b(INSERT[[:space:]]+INTO|UPDATE[[:space:]]+[A-Za-z_]+[[:space:]]+SET|DELETE[[:space:]]+FROM|DELETE[[:space:]]+FROM|UNIQUE|FOREIGN[[:space:]]+KEY|REFERENCES|NOT[[:space:]]+NULL|SET[[:space:]]+NOT[[:space:]]+NULL)\b' "$SQL_ABS" || true)
DATA_NEEDED=0
if [[ "$DATA_MODE" == "on" ]]; then DATA_NEEDED=1
elif [[ "$DATA_MODE" == "auto" && $DATA_MARKERS -gt 0 ]]; then DATA_NEEDED=1
fi
DATA_STATUS="koşulmadı (migration veri dokmuyor, --data-mode=$DATA_MODE)"
if [[ "$DATA_MODE" == "off" && $DATA_MARKERS -gt 0 ]]; then
  DATA_STATUS="ZORUNLUYDU AMA KOŞULMADI (--data-mode=off; $DATA_MARKERS veri-marker eşleşmesi)"
  DATA_NEEDED=0
fi

# ══════════════════════════════════════════════════════════════════════
# FAZ C1 — SCHEMA MODE (izole DB'de gerçek uygulama)
# ══════════════════════════════════════════════════════════════════════
BASELINE_SH="${SCRIPT_DIR}/db-build-baseline.sh"
BASELINE_OUT="$WORK/baseline.out"
C1_DB=""
PARITE="bilinmiyor"
BASELINE_META="(meta alınamadı)"

# run_baseline: baseline script'ini çağır, stdout SON SATIR JSON'ını ayrıştır.
# Beklenen sözleşme alanları: db_name, obje sayıları, parite_durumu.
run_baseline() { # $1 = ek etiket (log)
  local tag="$1" out_json
  # timeout 900: baseline'in Mgmt API çağrısı takılırsa sonsuz bekleme YOK — fail-closed.
  if ! log_cmd "timeout 900 bash '$BASELINE_SH' --json  # ($tag)" || \
     ! timeout 900 bash "$BASELINE_SH" --json > "$BASELINE_OUT" 2>&1; then
    echo "❌ Baseline kurulumu başarısız ($tag) — restore hatası = FAIL (SPEC C1)." >&2
    log_result "C1.baseline-restore-$tag" "FAIL" "db-build-baseline.sh hata verdi; çıktı raporda"
    return 1
  fi
  out_json=$(tail -1 "$BASELINE_OUT")
  if ! echo "$out_json" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
    echo "❌ Baseline stdout son satırı geçerli JSON değil ($tag)." >&2
    log_result "C1.baseline-restore-$tag" "FAIL" "sözleşme ihlali: son satır JSON değil"
    return 1
  fi
  C1_DB=$(echo "$out_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("db_name",""))')
  if [[ -z "$C1_DB" ]]; then
    echo "❌ Baseline JSON'da db_name yok ($tag)." >&2
    log_result "C1.baseline-restore-$tag" "FAIL" "sözleşme ihlali: db_name eksik"
    return 1
  fi
  OWN_DBS+=("$C1_DB")
  PARITE=$(echo "$out_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("parite_durum","bilinmiyor"))')
  BASELINE_META=$(echo "$out_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print({k:v for k,v in d.items() if k!="db_name"})')
  log_result "C1.baseline-restore-$tag" "PASS" "db=$C1_DB parite=$PARITE meta=$BASELINE_META"
  return 0
}

C1_OK=0
if run_baseline "schema"; then
  C1_OK=1
  ISO_URL="$(echo "$LOCAL_LSP_URL" | sed -E "s#/[^//?]+(\?.*)?\$#/$C1_DB#")"

  # Etkilenen tablolar: ALTER TABLE hedefleri + CREATE TABLE isimleri.
  AFFECTED=$( { cat "$CREATED_FILE"; { grep -ioE 'ALTER[[:space:]]+TABLE[[:space:]]+(IF[[:space:]]+EXISTS[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true; } | awk '{print $NF}' | tr '[:upper:]' '[:lower:]' | sed 's/^public\.//'; } | sort -u )

  # RLS ÖN-durum (migration öncesi relrowsecurity).
  RLS_BEFORE="$WORK/rls_before.txt"
  psql_q "$ISO_URL" "SELECT c.relname||'='||c.relrowsecurity::int FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' ORDER BY 1" "$RLS_BEFORE" || true

  # Migration'ı uygula: herhangi bir hata = FAIL + hatalı satır/SQLSTATE.
  APPLY_OUT="$WORK/apply.out"
  log_cmd "psql -v ON_ERROR_STOP=1 -f '$SQL_ABS'  # db=$C1_DB"
  if psql "$ISO_URL" -v ON_ERROR_STOP=1 -f "$SQL_ABS" > "$APPLY_OUT" 2>&1; then
    log_result "C1.migration-apply" "PASS" "psql ON_ERROR_STOP ile hatasız uygulandı"

    # Post-check 1: yaratılan nesneler gerçekten var mı?
    MISSING=""
    while read -r obj; do
      [[ -z "$obj" ]] && continue
      FOUND=$(psql "$ISO_URL" -qAt -c "
        SELECT count(*) FROM (
          SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname='public' AND c.relname='$obj'
          UNION SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public' AND p.proname='$obj'
          UNION SELECT 1 FROM information_schema.views WHERE table_schema='public' AND table_name='$obj'
          UNION SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='$obj'
          UNION SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
            WHERE n.nspname='public' AND t.typname='$obj'
          UNION SELECT 1 FROM pg_policies WHERE schemaname='public' AND policyname='$obj'
          UNION SELECT 1 FROM pg_trigger t JOIN pg_class rc ON rc.oid=t.tgrelid
            JOIN pg_namespace rn ON rn.oid=rc.relnamespace
            WHERE rn.nspname='public' AND t.tgname='$obj' AND NOT t.tgisinternal
        ) x" 2>/dev/null || echo 0)
      [[ "$FOUND" == "0" ]] && MISSING="$MISSING $obj"
    done < "$CREATED_FILE"
    if [[ -n "$MISSING" ]]; then
      log_result "C1.postcheck-nesne" "FAIL" "yaratılması beklenen nesne yok:$MISSING"
    else
      log_result "C1.postcheck-nesne" "PASS" "migration-içi yaratılan tüm nesneler izole DB'de mevcut"
    fi

    # Post-check 2: etkilenen tablolar için RLS ön/son karşılaştırması.
    RLS_AFTER="$WORK/rls_after.txt"
    psql_q "$ISO_URL" "SELECT c.relname||'='||c.relrowsecurity::int FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind='r' ORDER BY 1" "$RLS_AFTER" || true
    RLS_DIFF=$(diff "$RLS_BEFORE" "$RLS_AFTER" | grep -E '^[<>]' || true)
    RLS_TBL_NOTES=""
    for t in $AFFECTED; do
      b=$(grep -E "^$t=" "$RLS_BEFORE" | cut -d= -f2 || true)
      a=$(grep -E "^$t=" "$RLS_AFTER" | cut -d= -f2 || true)
      [[ -n "$a" ]] && RLS_TBL_NOTES="$RLS_TBL_NOTES $t:$b→$a"
    done
    log_result "C1.postcheck-rls" "PASS" "RLS farkları: ${RLS_DIFF:-yok}; etkilenen tablolar relrowsecurity:${RLS_TBL_NOTES:- (yeni tablo ya da aynada yok)}"

    # Parite: uyumsuz → tam PASS verilmez (en fazla INCONCLUSIVE).
    if [[ "$PARITE" == "uyumsuz" ]]; then
      log_result "C1.ortam-paritesi" "INCONCLUSIVE" "baseline parite_durumu=uyumsuz — tam-uyum PASS verilmez (SPEC Faz 0)"
    else
      log_result "C1.ortam-paritesi" "PASS" "baseline parite_durumu=$PARITE"
    fi
  else
    # Hatalı satır + SQLSTATE'i psql çıktısından ayıkla (ERROR/LINE/DETAIL bloğu).
    ERR_EXC=$(awk '/ERROR:/{p=8} p&&p--' "$APPLY_OUT" | head -8)
    SQLSTATE=$(grep -oE 'SQLSTATE [0-9A-Z]+' "$APPLY_OUT" | tail -1 || true)
    log_result "C1.migration-apply" "FAIL" "psql hatası ${SQLSTATE:-}; ayrıntı raporda"
    echo "❌ C1 apply başarısız:" >&2; echo "$ERR_EXC" >&2
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# FAZ C2 — DATA MODE (veri dokuran migration için zorunlu)
# ══════════════════════════════════════════════════════════════════════
C2_RAN=0
BASELINE_FAILED=0
if [[ $DATA_NEEDED -eq 1 && $C1_OK -ne 1 ]]; then
  # C1 baseline'i kurulamadıysa C2 tekrar denemez — aynı nedenle kırılır (bağımlılık).
  BASELINE_FAILED=1
fi
if [[ $DATA_NEEDED -eq 1 && $BASELINE_FAILED -eq 1 ]]; then
  C2_RAN=1
  log_result "C2.veri-uyumluluk" "FAIL" "DATA MODE zorunluydu ama C1 baseline kurulamadı — veri senaryosu koşulamadı"
elif [[ $DATA_NEEDED -eq 1 ]]; then
  C2_RAN=1
  # DML hedef tabloları: INSERT INTO/UPDATE/DELETE FROM + NOT NULL/UNIQUE/FK etkilenenleri.
  DML_TABLES=$( {
    { grep -ioE 'INSERT[[:space:]]+INTO[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true; } | awk '{print $NF}'
    { grep -ioE 'UPDATE[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*[[:space:]]+SET' "$SQL_ABS" || true; } | awk '{print $2}'
    { grep -ioE 'DELETE[[:space:]]+FROM[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true; } | awk '{print $NF}'
    { grep -ioE 'ALTER[[:space:]]+TABLE[[:space:]]+(IF[[:space:]]+EXISTS[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true; } | awk '{print $NF}'
    { grep -ioE 'CREATE[[:space:]]+(UNIQUE[[:space:]]+)?(TABLE|INDEX)[[:space:]]+(IF[[:space:]]+NOT[[:space:]]+EXISTS[[:space:]]+)?[A-Za-z_][A-Za-z0-9_.]*' "$SQL_ABS" || true; } | awk '{print $NF}'
  } | tr '[:upper:]' '[:lower:]' | sed 's/^public\.//' | sort -u )

  C2_OK=0
  if run_baseline "data"; then
    C2_OK=1
    C2_URL="$(echo "$LOCAL_LSP_URL" | sed -E "s#/[^//?]+(\?.*)?\$#/$C1_DB#")"

    # Sentetik tohumlama: NOT NULL kolonları information_schema'dan oku (kolon adı
    # UYDURMA); default'u olanlar atlanır; değer tip bazlı üretilir; farm_id varsa
    # önce gerçek bir farm satırı seç, yoksa farm'a da satır ekle (tenant bütünlüğü).
    SEED_LOG="$WORK/seed.log"; : > "$SEED_LOG"
    SEED_FAIL=0
    for t in $DML_TABLES; do
      # Tablo izole DB'de var mı? (yeni CREATE edilmiş olabilir — baseline sonrası yoksa C2 tohumlaması C1 apply sonrası anlamına gelir;
      # bu durumda migration'ın kendisi tabloyu yaratır → tohumlamayı apply sonrasına bırakamayız, tablo yoksa 'yeni tablo' notu düş.)
      TBL_OK=$(psql "$C2_URL" -qAt -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='$t'" 2>/dev/null || echo 0)
      if [[ "$TBL_OK" != "1" ]]; then
        echo "$t: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır" >> "$SEED_LOG"
        continue
      fi
      COLS_SQL="SELECT string_agg(format('%I', column_name), ', ') FROM information_schema.columns WHERE table_schema='public' AND table_name='$t' AND is_nullable='NO' AND column_default IS NULL"
      COLS=$(psql "$C2_URL" -qAt -c "$COLS_SQL" 2>/dev/null || true)
      [[ -z "$COLS" ]] && { echo "$t: zorunlu-default'suz kolon yok" >> "$SEED_LOG"; continue; }
      # Değer ifadeleri: tip bazlı; kolon adları ŞEMADAN geldi (uydurma yok). farm_id → gerçek farm.
      VALS_SQL="SELECT string_agg(CASE
          WHEN column_name IN ('farm_id') THEN COALESCE((SELECT min(f.id)::text) FROM public.farm f), '1')
          WHEN data_type='integer' OR data_type='bigint' OR data_type='smallint' OR data_type='numeric' THEN '1'
          WHEN data_type='boolean' THEN 'false'
          WHEN data_type='date' THEN 'CURRENT_DATE'
          WHEN data_type LIKE 'timestamp%' THEN 'now()'
          WHEN data_type='uuid' THEN 'gen_random_uuid()'
          WHEN data_type='jsonb' OR data_type='json' THEN '\'{}\''
          ELSE format('''dbval_%s''', column_name)
        END, ', ') FROM information_schema.columns WHERE table_schema='public' AND table_name='$t' AND is_nullable='NO' AND column_default IS NULL"
      VALS=$(psql "$C2_URL" -qAt -c "$VALS_SQL" 2>/dev/null || true)
      if psql "$C2_URL" -v ON_ERROR_STOP=1 -qc "INSERT INTO public.$t ($COLS) VALUES ($VALS)" >> "$SEED_LOG" 2>&1; then
        echo "$t: sentetik satır eklendi ($COLS)" >> "$SEED_LOG"
      else
        echo "$t: sentetik satır EKLENEMEDİ (bkz. hata yukarıda)" >> "$SEED_LOG"
        SEED_FAIL=1
      fi
    done

    # Tohumlanmış veri üzerinde migration'ı uygula → unique/fk ihlali yakala.
    C2_APPLY="$WORK/c2_apply.out"
    log_cmd "psql -v ON_ERROR_STOP=1 -f '$SQL_ABS'  # C2 db=$C1_DB (tohumlu)"
    if psql "$C2_URL" -v ON_ERROR_STOP=1 -f "$SQL_ABS" > "$C2_APPLY" 2>&1; then
      if [[ $SEED_FAIL -eq 1 ]]; then
        log_result "C2.sentetik-tohum" "INCONCLUSIVE" "bazı tablolara sentetik satır eklenemedi (seed.log); veri senaryosu kısmi"
        log_result "C2.veri-uyumluluk" "INCONCLUSIVE" "tohumlama kısmi — veri uyumluluğu tam kanıtlanmadı"
      else
        log_result "C2.sentetik-tohum" "PASS" "etkilenen tablolara sentetik satır eklendi"
        log_result "C2.veri-uyumluluk" "PASS" "sentetik veri üzerinde migration hatasız; unique/fk ihlali yok"
      fi
    else
      C2ERR=$(awk '/ERROR:/{p=8} p&&p--' "$C2_APPLY" | head -8)
      if grep -qiE 'duplicate key|unique|violates foreign key' "$C2_APPLY"; then
        log_result "C2.veri-uyumluluk" "FAIL" "veri senaryosunda unique/fk ihlali; ayrıntı raporda"
      else
        log_result "C2.veri-uyumluluk" "FAIL" "tohumlu veri üzerinde apply hatası; ayrıntı raporda"
      fi
      echo "❌ C2 apply başarısız:" >&2; echo "$C2ERR" >&2
    fi
  else
    log_result "C2.veri-uyumluluk" "FAIL" "DATA MODE zorunluydu ama ikinci baseline kurulamadı"
  fi
else
  if [[ "$DATA_STATUS" == ZORUNLUYDU* ]]; then
    log_result "C2.veri-uyumluluk" "INCONCLUSIVE" "$DATA_STATUS"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# FAZ D — RAPOR + çıkış kodu
# ══════════════════════════════════════════════════════════════════════
# Genel sonuç: FAIL > INCONCLUSIVE > PASS. Test edilmeyen kriter PASS YAZILAMAZ
# (log_result ile yalnız koşulan kriterler kaydedilir).
OVERALL="PASS"
FAILS=$(awk -F'\t' '$2=="FAIL"' "$RESULT_FILE" | wc -l)
INCONC=$(awk -F'\t' '$2=="INCONCLUSIVE"' "$RESULT_FILE" | wc -l)
[[ $FAILS  -gt 0 ]] && OVERALL="FAIL"
[[ $FAILS -eq 0 && $INCONC -gt 0 ]] && OVERALL="INCONCLUSIVE"
# Data mode zorunluyken koşulmadıysa tam PASS yok.
if [[ "$OVERALL" == "PASS" && "$DATA_STATUS" == ZORUNLUYDU* ]]; then OVERALL="INCONCLUSIVE"; fi

TS=$(date '+%Y-%m-%d %H:%M:%S%z')
# Raporda 'VERİ UYUMLULUĞU DOĞRULANMADI' notu: data mode koşulmadıysa yazılır (aşağıda).
# Sinyal tuzağı: validator dışarıdan kesilirse raporsuz sessiz çıkış (fail-open) YASAK —
# o ana kadarki sonuçlarla FAIL raporu yaz ve exit 1.
yaz_rapor() {
  {
  echo "# DB Validation Raporu — $SHA8"
  echo ""
  echo "- Tarih: $TS"
  echo "- Migration: \`$SQL_ABS\`"
  echo "- SHA-256: \`$SHA256\`"
  echo "- Baseline (C1): ${BASELINE_META:-alınamadı} · parite: $PARITE"
  echo "- Data mode: $DATA_STATUS"
  echo "- Genel sonuç: **$OVERALL**"
  echo ""
  echo "## Faz bazlı sonuç tablosu"
  echo ""
  echo "| Kriter | Sonuç | Not |"
  echo "|---|---|---|"
  awk -F'\t' '{printf "| %s | %s | %s |\n", $1, $2, $3}' "$RESULT_FILE"
  echo ""
  if [[ $C2_RAN -eq 0 && "$DATA_STATUS" != ZORUNLUYDU* ]]; then
    echo "> VERİ UYUŞUMLULUĞU DOĞRULANMADI (data-mode=$DATA_MODE, veri dokan migration deseni saptanmadı: $DATA_MARKERS eşleşme)."
    echo ""
  fi
  if [[ "$DATA_STATUS" == ZORUNLUYDU* ]]; then
    echo "> VERİ UYUŞUMLULUĞU DOĞRULANMADI — DATA MODE zorunluydu ama \`--data-mode=off\` ile atlandı."
    echo ""
  fi
  echo "## Uygulanan komutlar"
  echo ""
  echo '```bash'
  cat "$CMDS_FILE"
  echo '```'
  echo ""
  echo "## Çıktı parçaları"
  for f in sqlfluff.out:"FAZ A sqlfluff" squawk.out:"FAZ A squawk" baseline.out:"C1/C2 baseline" apply.out:"C1 apply" c2_apply.out:"C2 apply (tohumlu)" seed.log:"C2 sentetik tohum"; do
    fn="${f%%:*}"; label="${f#*:}"
    if [[ -s "$WORK/$fn" ]]; then
      echo ""
      echo "### $label (\`$fn\`)"
      echo '```'
      head -40 "$WORK/$fn"
      echo '```'
    fi
  done
} > "$REPORT"
}
trap 'log_result "D.kesinti" "FAIL" "validator sinyalle kesildi — kanıt tamamlanmadı (fail-open kapatıldı)"; FAILS=1; OVERALL="FAIL"; yaz_rapor 2>/dev/null; exit 1' INT TERM HUP
yaz_rapor

echo ""
echo "════════════════════════════════════════════════"
echo " SONUÇ: $OVERALL"
echo " Rapor: $REPORT"
if [[ $KEEP_DB -eq 1 ]]; then
  echo " İzole DB'ler TUTULDU (--keep-db): ${OWN_DBS[*]:-yok}"
else
  echo " İzole DB'ler drop edildi: ${OWN_DBS[*]:-yok}"
fi
echo "════════════════════════════════════════════════"

case "$OVERALL" in
  PASS) exit 0 ;;
  FAIL) exit 1 ;;
  INCONCLUSIVE) exit 2 ;;
  *) echo "❌ Bilinmeyen sonuç durumu: $OVERALL — bu bir bug" >&2; exit 3 ;;
esac
