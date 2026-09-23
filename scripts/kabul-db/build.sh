#!/usr/bin/env bash
# build.sh — egesut_ovsync_kabul: canlı prod public şemasının VERİSİZ yerel kopyası
# (tablo + constraint + index + trigger + fonksiyon + view + RLS/policy + ACL + cron kaydı)
# ve yalnız katalog/ayar referans verisi.
#
# Kaynak: canlı katalog (Supabase Management API, yalnız SELECT). Canlıya YAZMAZ.
# Hedef : 127.0.0.1:5432 / lsp_user — yalnız egesut_ovsync_kabul DROP+CREATE edilir.
#
# Kullanım:  ./build.sh            (canlıdan taze çek + kur + doğrula)
#            KABUL_OFFLINE=1 ./build.sh   (cache/ içindeki son çekimle kur; ağ yok)
# Çıkış kodu: 0 = temiz; 1 = doğrulama farkı / eksik nesne; 2 = önkoşul hatası.
set -euo pipefail

K="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${EGESUT_REPO:-/home/melik/egesut-erp1}"
DB="egesut_ovsync_kabul"
PGH=(-h 127.0.0.1 -p 5432 -U lsp_user)
PSQL=(psql "${PGH[@]}" -X -q -v ON_ERROR_STOP=1)
WORK="${KABUL_WORK:-$HOME/tmp/egesut-kabul-db}"   # önbellek/çıktı repoya yazılmaz
CACHE="$WORK/cache"
OUT="$WORK/out"
OFFLINE="${KABUL_OFFLINE:-0}"
# Referans (katalog/ayar) tabloları — FK sırasına göre. Hayvan/tohumlama/stok hareketi KOPYALANMAZ.
REF_TABLES=(stok_kategorileri drug_classes drug_products diseases tedavi_sablonu tedavi_sablonu_kalem sablon_hastalik_eslem protokol_ayar)
T0=$(date +%s)
mkdir -p "$CACHE" "$OUT"

log(){ printf '[%3ss] %s\n' "$(( $(date +%s) - T0 ))" "$*"; }
die(){ echo "HATA: $*" >&2; exit 2; }

# ── 0. önkoşullar ────────────────────────────────────────────────────────────
for b in psql jq curl; do command -v "$b" >/dev/null || die "$b yok"; done
"${PSQL[@]}" -d postgres -Atc 'select 1' >/dev/null || die "yerel Postgres'e bağlanılamadı (127.0.0.1:5432 lsp_user)"
CAN=$("${PSQL[@]}" -d postgres -Atc "select (rolcreatedb or rolsuper)::int from pg_roles where rolname=current_user")
[[ "$CAN" == 1 ]] || die "lsp_user'ın CREATEDB (veya superuser) yetkisi yok — durduruldu"
SUPER=$("${PSQL[@]}" -d postgres -Atc "select rolsuper::int from pg_roles where rolname=current_user")
[[ "$SUPER" == 1 ]] || die "lsp_user superuser değil: CREATE EXTENSION / session_replication_role gerekir — durduruldu"

# ── 1. canlıdan çek (salt-okunur) ────────────────────────────────────────────
live(){  # stdin: SQL → stdout: JSON dizi; API hata mesajında 1 döner
  local r
  r=$(jq -Rs '{query:.}' | curl -sS --max-time 180 -X POST "$API" \
        -H "Authorization: Bearer ${SB_MGMT_TOKEN}" -H "Content-Type: application/json" -d @-)
  if ! jq -e 'type=="array"' >/dev/null 2>&1 <<<"$r"; then echo "API hatası: ${r:0:500}" >&2; return 1; fi
  printf '%s' "$r"
}

if [[ "$OFFLINE" != 1 ]]; then
  set -a; source "$REPO/.env"; set +a
  [[ -n "${SB_MGMT_TOKEN:-}" ]] || die "SB_MGMT_TOKEN .env'de yok"
  API="https://api.supabase.com/v1/projects/${SB_PROJECT_REF:-zqnexqbdfvbhlxzelzju}/database/query"
  NEW="$CACHE/.new"; rm -rf "$NEW"; mkdir -p "$NEW"
  log "canlı katalog çekiliyor (DDL)"
  live < "$K/sql/gen_ddl.sql" | jq '.[0].ddl' > "$NEW/ddl.json"
  log "canlı parmak izi çekiliyor"
  live < "$K/sql/fingerprint.sql" | jq '.[0].fp' > "$NEW/fp_live.json"
  log "referans verisi çekiliyor: ${REF_TABLES[*]}"
  for t in "${REF_TABLES[@]}"; do
    echo "select coalesce(json_agg(x), '[]'::json) j from public.$t x" | live | jq '.[0].j' > "$NEW/data_$t.json"
  done
  # tedavi_sablonu_kalem.stok_id → stok FK'sı: yalnız şablonların referans verdiği stok KATALOG satırları
  echo "select coalesce(json_agg(s), '[]'::json) j from public.stok s where s.id in (select stok_id from public.tedavi_sablonu_kalem where stok_id is not null)" \
    | live | jq '.[0].j' > "$NEW/data_stok_ref.json"
  date -Iseconds > "$NEW/fetched_at"
  rm -rf "$CACHE/live"; mv "$NEW" "$CACHE/live"
fi
L="$CACHE/live"
[[ -s "$L/ddl.json" && -s "$L/fp_live.json" ]] || die "cache boş — önce çevrim-içi koş"
log "kaynak çekim zamanı: $(cat "$L/fetched_at")  ($(jq length "$L/ddl.json") DDL deyimi)"

# ── 2. DB'yi sıfırdan yarat (YALNIZ $DB) ─────────────────────────────────────
log "DROP/CREATE DATABASE $DB"
"${PSQL[@]}" -d postgres -c "DROP DATABASE IF EXISTS $DB WITH (FORCE)"
"${PSQL[@]}" -d postgres -c "CREATE DATABASE $DB TEMPLATE template0 ENCODING 'UTF8'"
"${PSQL[@]}" -d postgres -c "ALTER DATABASE $DB SET search_path TO \"\$user\", public, extensions"
"${PSQL[@]}" -d postgres -c "COMMENT ON DATABASE $DB IS 'ovsync kabul: canli prod public semasi (verisiz) — $(cat "$L/fetched_at") — build.sh'"

# ── 3. stub'lar + DDL uygula ─────────────────────────────────────────────────
log "Supabase stub'ları (roller, extensions, auth, cron)"
"${PSQL[@]}" -d "$DB" -f "$K/sql/stubs.sql" 2>&1 | grep -v '^NOTICE:  extension' || true
log "DDL yükleniyor + uygulanıyor (bağımlılık için çok geçişli)"
"${PSQL[@]}" -d "$DB" <<EOF
\\set ddl \`cat "$L/ddl.json"\`
INSERT INTO kabul_meta.ddl (phase, ord, kind, name, sql)
SELECT phase, ord, kind, name, sql FROM json_to_recordset(:'ddl'::json) AS x(phase int, ord text, kind text, name text, sql text);
EOF
"${PSQL[@]}" -d "$DB" -f "$K/sql/apply.sql" 2>&1 | grep -Ev 'ivfflat|little data|low recall|^(AYRINTI|DETAIL|İPUCU|HINT):' | sed 's/^.*NOTICE:  /    /' || true
"${PSQL[@]}" -d "$DB" -At -F $'\t' -c "select kind, name, err from kabul_meta.ddl where status<>'ok' order by phase, ord" > "$OUT/ddl_failures.tsv"
NFAIL=$(wc -l < "$OUT/ddl_failures.tsv")
if (( NFAIL > 0 )); then
  log "UYGULANAMAYAN DDL: $NFAIL (bkz. $OUT/ddl_failures.tsv)"; cut -c1-220 "$OUT/ddl_failures.tsv" | sed 's/^/    /'
  while IFS=$'\t' read -r kind name err; do
    "${PSQL[@]}" -d "$DB" -c "insert into kabul_meta.atlanan values ($(printf "%s" "ddl $kind $name" | sed "s/'/''/g;s/^/'/;s/$/'/"), $(printf "%s" "$err" | sed "s/'/''/g;s/^/'/;s/$/'/")) on conflict do nothing"
  done < "$OUT/ddl_failures.tsv"
else
  log "tüm DDL deyimleri uygulandı"
fi

# ── 4. referans verisi (trigger'lar susturulmuş: session_replication_role=replica) ──
log "referans verisi yükleniyor"
{
  echo "SET session_replication_role = replica;"
  echo "BEGIN;"
  for t in stok_ref "${REF_TABLES[@]}"; do
    tbl=$t; [[ $t == stok_ref ]] && tbl=stok
    echo "\\set j \`cat '$L/data_$t.json'\`"
    echo "INSERT INTO public.$tbl SELECT * FROM json_populate_recordset(NULL::public.$tbl, :'j');"
  done
  echo "COMMIT;"
  echo "SET session_replication_role = origin;"
  # sahipli sequence'leri yüklenen veriye hizala
  cat <<'EOF'
DO $$ DECLARE r record; m bigint; BEGIN
  FOR r IN SELECT s.relname seq, t.relname tbl, a.attname col FROM pg_depend d
    JOIN pg_class s ON s.oid = d.objid AND s.relkind = 'S' JOIN pg_class t ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    WHERE d.deptype IN ('a','i') AND t.relnamespace = 'public'::regnamespace LOOP
    EXECUTE format('SELECT max(%I)::bigint FROM public.%I', r.col, r.tbl) INTO m;
    IF m IS NOT NULL THEN PERFORM setval(format('public.%I', r.seq), m); END IF;
  END LOOP; END $$;
EOF
} | "${PSQL[@]}" -d "$DB"
# FK bütünlüğü (replica modunda denetlenmedi → burada doğrula)
ORPHANS=$("${PSQL[@]}" -d "$DB" -At <<'EOF'
DO $$ DECLARE r record; n bigint; BEGIN
  CREATE TEMP TABLE _orphan(con text, n bigint);
  FOR r IN SELECT co.conname, co.conrelid::regclass src, co.confrelid::regclass dst,
      (SELECT string_agg(format('c.%I = p.%I', a.attname, b.attname), ' AND ')
         FROM unnest(co.conkey, co.confkey) k(c, p)
         JOIN pg_attribute a ON a.attrelid = co.conrelid AND a.attnum = k.c
         JOIN pg_attribute b ON b.attrelid = co.confrelid AND b.attnum = k.p) cond,
      (SELECT string_agg(format('c.%I IS NOT NULL', a.attname), ' AND ')
         FROM unnest(co.conkey) k(c) JOIN pg_attribute a ON a.attrelid = co.conrelid AND a.attnum = k.c) nn
    FROM pg_constraint co WHERE co.contype = 'f' AND co.connamespace = 'public'::regnamespace LOOP
    EXECUTE format('SELECT count(*) FROM %s c WHERE %s AND NOT EXISTS (SELECT 1 FROM %s p WHERE %s)', r.src, r.nn, r.dst, r.cond) INTO n;
    IF n > 0 THEN INSERT INTO _orphan VALUES (r.conname, n); END IF;
  END LOOP; END $$;
SELECT string_agg(con || '=' || n, ', ') FROM _orphan;
EOF
)
"${PSQL[@]}" -d "$DB" -At -c "select string_agg(t || '=' || n, ' ') from (
  select 'stok' t, count(*) n from public.stok union all
  $(for t in "${REF_TABLES[@]}"; do printf "select '%s', count(*) from public.%s union all " "$t" "$t"; done | sed 's/ union all $//')) s" \
  | sed 's/^/    satırlar: /'
LIVE_ROWS=$(for t in stok_ref "${REF_TABLES[@]}"; do printf '%s=%s ' "$t" "$(jq length "$L/data_$t.json")"; done)
echo "    canlı çekim: $LIVE_ROWS"

# ── 5. doğrulama: canlı ↔ yerel ─────────────────────────────────────────────
log "doğrulama"
"${PSQL[@]}" -d "$DB" -At -f "$K/sql/fingerprint.sql" > "$OUT/fp_local.json"
FP_L="$L/fp_live.json"; FP_Y="$OUT/fp_local.json"
echo
printf '    %-12s %8s %8s\n' NESNE CANLI YEREL
jq -r --slurpfile y "$FP_Y" '
  (.counts | keys) as $k | $k[] as $x | [$x, (.counts[$x]|tostring), (($y[0].counts[$x] // 0)|tostring)] | @tsv' "$FP_L" \
  | while IFS=$'\t' read -r k a b; do printf '    %-12s %8s %8s %s\n' "$k" "$a" "$b" "$([[ $a == "$b" ]] && echo ok || echo FARK)"; done
jq -r --slurpfile y "$FP_Y" '
  (.objects | map({key: (.[0]+" "+.[1]), value: .[2]}) | from_entries) as $c
  | ($y[0].objects | map({key: (.[0]+" "+.[1]), value: .[2]}) | from_entries) as $l
  | ([$c|keys[] | select($l[.] == null) | "EKSIK   " + .]
     + [$l|keys[] | select($c[.] == null) | "FAZLA   " + .]
     + [$c|keys[] | select($l[.] != null and $l[.] != $c[.]) | "FARKLI  " + .]) | .[]' "$FP_L" > "$OUT/diff.txt"
MISSING=$("${PSQL[@]}" -d "$DB" -At -f "$K/sql/must_exist.sql" | grep -v '^SET$' || true)
echo
echo "    nesne-düzeyi fark (tanım md5): $(wc -l < "$OUT/diff.txt") satır → $OUT/diff.txt"
sed 's/^/      /' "$OUT/diff.txt" | head -40
echo "    zorunlu nesneler: $([[ -z "$MISSING" ]] && echo 'hepsi VAR' || echo "EKSİK → $MISSING")"
echo "    FK yetim satır: ${ORPHANS:-yok}"
echo "    atlanan/stub'lanan:"
"${PSQL[@]}" -d "$DB" -At -F ' — ' -c "select nesne, neden from kabul_meta.atlanan order by 1" | sed 's/^/      - /'
echo "    süre: $(( $(date +%s) - T0 )) sn"

if [[ -s "$OUT/diff.txt" || -n "$MISSING" || -n "$ORPHANS" ]]; then
  echo "SONUÇ: FARK VAR (çıkış 1)"; exit 1
fi
echo "SONUÇ: TEMİZ — $DB canlı public şemasıyla nesne-düzeyinde eş"
