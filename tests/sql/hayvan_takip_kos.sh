#!/usr/bin/env bash
# Hayvan Takip SQL testleri: dosyaları BEGIN ... ROLLBACK içinde kabul DB'ye verir.
#   [BOLUM=sema|rpc|guard] bash tests/sql/hayvan_takip_kos.sh <sql...>     rc = psql'in
#   KOS_MOD=topla ...  düşenleri toplar: sonda "DUSEN: KR.. KR.." (sıralı);
#                      etiketsiz ERROR (mutant ya da betik hatası) rc=2.
# OZET, "<id> PASS" NOTICE satırlarından sayılır; geri sarılan sayaç kullanılmaz.
set -u
[ "$#" -ge 1 ] || { echo "kullanım: $0 <sql...>" >&2; exit 64; }

if [ "${KOS_MOD:-}" = topla ]; then
  mod_args=(-v ON_ERROR_STOP=0 -v ON_ERROR_ROLLBACK=on)
else
  mod_args=(-v ON_ERROR_STOP=1)
fi

cikti=$(
  {
    echo 'BEGIN;'
    echo "SET LOCAL client_min_messages = notice; SET LOCAL lc_messages = 'C';"  # sayım ERROR/NOTICE metnine dayanır
    for f in "$@"; do printf '\\i %s\n' "$(realpath "$f")"; done
    echo 'ROLLBACK;'
  } | psql -h "${KOS_PGHOST:-127.0.0.1}" -U "${KOS_PGUSER:-lsp_user}" \
        -d egesut_ovsync_kabul -X -q "${mod_args[@]}" -v "bolum=${BOLUM:-hepsi}" -f - 2>&1
)
rc=$?
printf '%s\n' "$cikti"

echo "OZET: $(printf '%s\n' "$cikti" | grep -cE 'NOTICE:  [A-Za-z0-9_-]+ PASS$') PASS"

if [ "${KOS_MOD:-}" = topla ]; then
  hatalar=$(printf '%s\n' "$cikti" | grep -E '^psql:.*: ERROR:  ')
  echo "DUSEN: $(printf '%s\n' "$hatalar" | sed -nE 's/^psql:.*: ERROR:  (KR[0-9]+) FAIL: .*/\1/p' | sort -u | paste -sd' ')"
  [ "$rc" -ne 0 ] && exit "$rc"
  printf '%s\n' "$hatalar" | grep -E '^psql:' | grep -qvE ': ERROR:  KR[0-9]+ FAIL: ' && exit 2
  exit 0
fi
exit "$rc"
