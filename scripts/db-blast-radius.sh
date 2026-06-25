#!/usr/bin/env bash
# db-blast-radius.sh — Bir DB objesini (tablo/kolon/fonksiyon) değiştirmeden önce
# ona bağımlı her şeyi canlıdan listele.
#
# İki katmanlı tarama:
#   1) Structural  → pg_depend ailesi (view/FK/trigger/default)
#   2) Textual     → pg_proc.prosrc + pg_views.definition ILIKE grep
#                    (PL/pgSQL gövdeleri opak olduğu için pg_depend'in
#                    GÖREMEDİĞİ kolon/RPC referanslarını yakalar)
#
# Kaynak: canlı Supabase (Management API, şifresiz). Neon'a DOKUNMAZ.
#
# Kullanım:
#   bash scripts/db-blast-radius.sh <obje_adı> [kolon_adı]
#
# Örnekler:
#   bash scripts/db-blast-radius.sh hayvanlar
#   bash scripts/db-blast-radius.sh tohumlama case_id
#   bash scripts/db-blast-radius.sh hayvan_ekle
#
# Çıktı: okunur özet + risk seviyesi.
#   0 bağımlı         → düşük
#   1-4 bağımlı       → orta
#   5+ bağımlı        → yüksek (HIGH — kullanıcıya bildir)

set -euo pipefail

# ── ARG ────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Kullanım: $0 <obje_adı> [kolon_adı]" >&2
  echo "  obje_adı  : tablo, view veya fonksiyon adı (public şeması)" >&2
  echo "  kolon_adı : opsiyonel — kolon-seviye textual tarama için" >&2
  exit 64
fi
OBJE="$1"
KOLON="${2:-}"

# ── ENV ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  # sql-lsp.sh deseni: source yerine grep+cut (daha güvenli, quote escape sorunları yok)
  SB_MGMT_TOKEN=$(grep -E "^SB_MGMT_TOKEN=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
  SB_PROJECT_REF=$(grep -E "^SB_PROJECT_REF=" "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")
fi

: "${SB_MGMT_TOKEN:?SB_MGMT_TOKEN missing - .env dosyasini kontrol et}"
: "${SB_PROJECT_REF:=zqnexqbdfvbhlxzelzju}"

command -v jq >/dev/null || { echo "❌ jq yok — apt install jq"; exit 1; }

# ── HELPERS ────────────────────────────────────────────────────────────
API="https://api.supabase.com/v1/projects/${SB_PROJECT_REF}/database/query"
mgt_query() {
  curl -sS -X POST "$API" \
    -H "Authorization: Bearer ${SB_MGMT_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$1" '{query:$q}')"
}

# mgt_query response → array of row objects; ilk satırın ilk kolonu.
# Bazı sorgularda string_agg/json_agg döner — .[0].<key> veya .[0].<col>.
mgt_scalar() {
  # $1=SQL, $2=key (string_agg, json_agg, n, vs.)
  local q="$1" key="$2"
  local res
  res=$(mgt_query "$q")
  # null/empty → ""
  echo "$res" | jq -r "if (.[0] // null) == null then \"\" else (.[0].${key} // \"\" | tostring) end"
}

# mgt_query response → her satırı "kolon1|kolon2|..." bas.
mgt_rows() {
  # $1=SQL, $2=separator (default "|")
  local q="$1" sep="${2:-|}"
  mgt_query "$q" | jq -r --arg sep "$sep" \
    '.[] | (to_entries | map(.value|tostring) | join($sep))'
}

say()  { printf '\033[1;34m▶ %s\033[0m\n' "$*"; }
hdr()  { printf '\n\033[1;36m═══ %s ═══\033[0m\n' "$*"; }
warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$*"; }
err()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }

# ── BAŞLANGIÇ ──────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "  DB Blast Radius — ${OBJE}${KOLON:+ .$KOLON}"
echo "═══════════════════════════════════════════════════════════════"

# Önce objenin ne olduğunu anla (tablo/view/function)
say "Obje tipi belirleniyor…"
TIP=$(mgt_scalar "
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                 WHERE n.nspname='public' AND c.relname='${OBJE}' AND c.relkind IN ('r','v','m')) THEN
      CASE WHEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                        WHERE n.nspname='public' AND c.relname='${OBJE}' AND c.relkind='v')
           THEN 'view' ELSE 'table' END
    WHEN EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='${OBJE}') THEN 'function'
    ELSE 'unknown'
  END" "case")
case "$TIP" in
  table)  echo "  → tip: TABLO (veya materialized view)" ;;
  view)   echo "  → tip: VIEW" ;;
  function) echo "  → tip: FONKSİYON" ;;
  *)
    err "Obje bulunamadı: public.${OBJE}"
    echo "  → public şemasında 'tablo', 'view' veya 'fonksiyon' olarak yok."
    exit 2
    ;;
esac

# Sayaçlar
COUNT_VIEW=0
COUNT_FN_TEXTUAL=0
COUNT_TRIGGER=0
COUNT_FK=0
COUNT_VIEW_TEXTUAL=0
TOTAL=0

# ── A) STRUCTURAL (pg_depend ailesi) ───────────────────────────────────
hdr "A) Structural bağımlılıklar (pg_depend)"

# A.1 — Bağımlı view/rule (pg_rewrite + pg_depend)
say "A.1 View/rule bağımlılıkları…"
VIEWS_TMP=$(mktemp)
mgt_query "
  SELECT DISTINCT dependent_ns.nspname||'.'||dependent.relname AS bagimli_obje,
         dependent.relkind::text AS tur
  FROM pg_depend d
  JOIN pg_rewrite r ON r.oid=d.objid
  JOIN pg_class dependent ON dependent.oid=r.ev_class
  JOIN pg_namespace dependent_ns ON dependent_ns.oid=dependent.relnamespace
  JOIN pg_class src ON src.oid=d.refobjid
  JOIN pg_namespace src_ns ON src_ns.oid=src.relnamespace
  WHERE src_ns.nspname='public' AND src.relname='${OBJE}'
    AND dependent.relname <> '${OBJE}'
  ORDER BY 1" > "$VIEWS_TMP" 2>/dev/null || echo "[]" > "$VIEWS_TMP"

if [[ -s "$VIEWS_TMP" ]] && [[ "$(cat "$VIEWS_TMP")" != "[]" ]]; then
  COUNT_VIEW=$(jq 'length' "$VIEWS_TMP")
  echo "  📋 ${COUNT_VIEW} view/rule bağımlısı:"
  jq -r '.[] | "     • \(.bagimli_obje) (\(.tur))"' "$VIEWS_TMP" | sed 's/(v)/view/;s/(m)/materialized view/'
else
  echo "  · view/rule bağımlısı yok"
fi
rm -f "$VIEWS_TMP"

# A.2 — Bağımlı FK constraint
say "A.2 Foreign key constraint bağımlılıkları…"
FKS_TMP=$(mktemp)
mgt_query "
  SELECT con.conname AS constraint_adi,
         con.conrelid::regclass AS tablo,
         pg_get_constraintdef(con.oid) AS tanim
  FROM pg_constraint con
  WHERE con.confrelid='public.${OBJE}'::regclass AND con.contype='f'
  ORDER BY 2,1" > "$FKS_TMP" 2>/dev/null || echo "[]" > "$FKS_TMP"

if [[ -s "$FKS_TMP" ]] && [[ "$(cat "$FKS_TMP")" != "[]" ]]; then
  COUNT_FK=$(jq 'length' "$FKS_TMP")
  echo "  🔗 ${COUNT_FK} FK constraint:"
  jq -r '.[] | "     • \(.tablo) → \(.constraint_adi)\n       \(.tanim)"' "$FKS_TMP"
else
  echo "  · FK constraint yok"
fi
rm -f "$FKS_TMP"

# A.3 — Bağımlı trigger (bu tablo üzerinde tanımlı)
say "A.3 Trigger bağımlılıkları…"
TRIG_TMP=$(mktemp)
mgt_query "
  SELECT t.tgname AS trigger_adi,
         t.tgrelid::regclass AS tablo,
         pg_get_triggerdef(t.oid) AS tanim
  FROM pg_trigger t
  WHERE t.tgrelid='public.${OBJE}'::regclass
    AND NOT t.tgisinternal
  ORDER BY 1" > "$TRIG_TMP" 2>/dev/null || echo "[]" > "$TRIG_TMP"

if [[ -s "$TRIG_TMP" ]] && [[ "$(cat "$TRIG_TMP")" != "[]" ]]; then
  COUNT_TRIGGER=$(jq 'length' "$TRIG_TMP")
  echo "  ⚡ ${COUNT_TRIGGER} trigger:"
  jq -r '.[] | "     • \(.tablo) → \(.trigger_adi)"' "$TRIG_TMP"
else
  echo "  · trigger yok"
fi
rm -f "$TRIG_TMP"

# ── B) TEXTUAL (gövde taraması) ────────────────────────────────────────
hdr "B) Textual referans taraması (gövde ILIKE grep)"

# Kolon verildiyse hem tablo hem kolon adını tara (kolon adı daha spesifik).
if [[ -n "$KOLON" ]]; then
  HEDEF="$KOLON"
  HEDEF_NOTE="kolon '${KOLON}' (tablo '${OBJE}' üzerinde)"
  # Tablo adı da geçebileceği için OR ile iki arama birleştirilir
  SEARCH_PATTERN="${OBJE} OR '${KOLON}'"
  EXTRA_WHERE="AND (p.prosrc ILIKE '%${OBJE}%' OR p.prosrc ILIKE '%${KOLON}%')"
  EXTRA_VIEW_WHERE="AND (v.definition ILIKE '%${OBJE}%' OR v.definition ILIKE '%${KOLON}%')"
else
  HEDEF="$OBJE"
  HEDEF_NOTE="obje '${OBJE}'"
  EXTRA_WHERE="AND p.prosrc ILIKE '%${OBJE}%'"
  EXTRA_VIEW_WHERE="AND v.definition ILIKE '%${OBJE}%'"
fi

# B.1 — Fonksiyon gövdelerinde ara
say "B.1 Fonksiyon gövdelerinde '${HEDEF}' aranıyor…"
FN_TMP=$(mktemp)
mgt_query "
  SELECT p.proname AS fonksiyon,
         p.oid::regprocedure AS imza,
         length(p.prosrc) AS govde_boyut
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    ${EXTRA_WHERE}
  ORDER BY 1" > "$FN_TMP" 2>/dev/null || echo "[]" > "$FN_TMP"

if [[ -s "$FN_TMP" ]] && [[ "$(cat "$FN_TMP")" != "[]" ]]; then
  COUNT_FN_TEXTUAL=$(jq 'length' "$FN_TMP")
  echo "  🔧 ${COUNT_FN_TEXTUAL} fonksiyon gövdesinde '${HEDEF}' geçiyor:"
  jq -r '.[] | "     • \(.imza)   (gövde \(.govde_boyut) byte)"' "$FN_TMP"
  echo "  ⚠ Yanlış-pozitif olabilir (yorum/iç değişken adı). Kapsayıcı tutuldu."
else
  echo "  · fonksiyon gövdesinde '${HEDEF}' yok"
fi
rm -f "$FN_TMP"

# B.2 — View tanımlarında ara
say "B.2 View tanımlarında '${HEDEF}' aranıyor…"
VW_TMP=$(mktemp)
mgt_query "
  SELECT viewname AS view_adi,
         viewowner AS sahip
  FROM pg_views v
  WHERE schemaname='public'
    ${EXTRA_VIEW_WHERE}
  ORDER BY 1" > "$VW_TMP" 2>/dev/null || echo "[]" > "$VW_TMP"

if [[ -s "$VW_TMP" ]] && [[ "$(cat "$VW_TMP")" != "[]" ]]; then
  COUNT_VIEW_TEXTUAL=$(jq 'length' "$VW_TMP")
  echo "  👁  ${COUNT_VIEW_TEXTUAL} view tanımında '${HEDEF}' geçiyor:"
  jq -r '.[] | "     • \(.view_adi) (owner: \(.sahip))"' "$VW_TMP"
else
  echo "  · view tanımında '${HEDEF}' yok"
fi
rm -f "$VW_TMP"

# ── ÖZET + RİSK ────────────────────────────────────────────────────────
TOTAL=$((COUNT_VIEW + COUNT_FN_TEXTUAL + COUNT_TRIGGER + COUNT_FK + COUNT_VIEW_TEXTUAL))

hdr "Özet"
echo "  Hedef       : ${OBJE}${KOLON:+ .$KOLON} (${HEDEF_NOTE})"
echo "  Tip         : ${TIP}"
echo "  ────────────────────────────────"
printf "  📋 View (pg_depend)        : %d\n" "$COUNT_VIEW"
printf "  🔧 Fonksiyon (textual)     : %d\n" "$COUNT_FN_TEXTUAL"
printf "  ⚡ Trigger (pg_depend)     : %d\n" "$COUNT_TRIGGER"
printf "  🔗 FK (pg_constraint)      : %d\n" "$COUNT_FK"
printf "  👁  View (textual)         : %d\n" "$COUNT_VIEW_TEXTUAL"
echo "  ────────────────────────────────"
printf "  🎯 TOPLAM bağımlı          : %d\n" "$TOTAL"

echo
if [[ "$TOTAL" -eq 0 ]]; then
  printf '\033[1;32m✅ RİSK: DÜŞÜK (0 bağımlı) — güvenle değiştirilebilir.\033[0m\n'
  echo
  echo "  Not: textual tarama boş döndüyse 'ILIKE' küçük-büyük harf duyarsız."
  echo "       Fonksiyon adı argüman olarak verildiyse gövde taraması isimle değil"
  echo "       gövdedeki metinle eşleşir — yorumda geçen isimleri de yakalar."
elif [[ "$TOTAL" -le 5 ]]; then
  printf '\033[1;33m⚠ RİSK: ORTA (%d bağımlı) — yukarıdaki listeyi gözden geçir, etkilenen yerleri test et.\033[0m\n' "$TOTAL"
else
  printf '\033[1;31m🚨 RİSK: YÜKSEK (%d bağımlı) — kullanıcıya bildir!\033[0m\n' "$TOTAL"
  printf '\033[1;31m   Migration öncesi tüm %d bağımlıyı ayrı ayrı doğrula.\033[0m\n' "$TOTAL"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Kaynak: canlı Supabase (Management API · sadece SELECT)"
echo "═══════════════════════════════════════════════════════════════"