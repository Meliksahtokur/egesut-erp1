#!/usr/bin/env bash
# db_validate_buyuk_dosya_test.sh — db-validate Faz A büyük dosya kapısı (F2 P1).
# sqlfluff varsayılanı 20000 bayt üstü dosyayı WARNING ile atlar (rc=0); parse
# denetimi sessizce PASS oluyordu. Beklenen:
#   (a) >20000 bayt, sonda 'selec broken from;' → exit 1 ve A.sqlfluff-parse FAIL
#   (b) aynı boyutta temiz dosya               → exit 0 ve A.sqlfluff-parse PASS
#   (c) sqlfluff yine de atlarsa (sahte sqlfluff skip WARNING + rc 0) → exit 1, A FAIL
# Exit kodu tek başına yetmez: (a) C1 apply'da da düşer; Faz A satırı ayrıca okunur.
# DBVAL_SH: doğrulanan betik (vars. repo scripts/db-validate.sh). .env'siz worktree'de
#   .env'li bir aynadaki (symlink) betiğe işaret ettirilir.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DBVAL_SH="${DBVAL_SH:-$REPO/scripts/db-validate.sh}"
TMPROOT="${SS_TMP_ROOT:-${TMPDIR:-}}"
[[ -n "$TMPROOT" ]] || { echo "FAIL: TMPDIR/SS_TMP_ROOT set değil"; exit 1; }
T=$(mktemp -d "$TMPROOT/dbval-buyuk.XXXXXXXX"); trap 'rm -rf "$T"' EXIT

{ yes 'select 1;' | head -n 2100; echo 'selec broken from;'; } > "$T/a_bozuk.sql"
yes 'select 1;' | head -n 2102 > "$T/b_temiz.sql"

FAILS=0
kontrol() { # $1 etiket, $2 dosya, $3 beklenen exit, $4 beklenen A.sqlfluff-parse, $5 PATH öneki
  local boyut out rc rapor a
  boyut=$(stat -c %s "$2")
  out=$(env PATH="${5:-}$PATH" bash "$DBVAL_SH" "$2" 2>&1); rc=$?
  rapor=$(sed -n 's/^ Rapor: //p' <<<"$out" | tail -1)
  a=$(grep -m1 '^| A.sqlfluff-parse |' "$rapor" 2>/dev/null | awk -F'|' '{gsub(/ /,"",$3); print $3}')
  if [[ $boyut -gt 20000 && $rc -eq $3 && "$a" == "$4" ]]; then
    echo "PASS $1: boyut=$boyut exit=$rc A.sqlfluff-parse=$a"
  else
    echo "FAIL $1: boyut=$boyut exit=$rc (beklenen $3) A.sqlfluff-parse=${a:-yok} (beklenen $4)"
    grep -m1 '^| A.sqlfluff-parse |' "$rapor" 2>/dev/null || tail -5 <<<"$out"
    FAILS=$((FAILS + 1))
  fi
}

kontrol "(a) büyük+bozuk" "$T/a_bozuk.sql" 1 FAIL
kontrol "(b) büyük+temiz" "$T/b_temiz.sql" 0 PASS
mkdir -p "$T/bin"
printf '#!/bin/sh\necho "WARNING Length of file is over the limit of 20000 bytes. Skipping to avoid parser lock."\nexit 0\n' > "$T/bin/sqlfluff"
chmod +x "$T/bin/sqlfluff"
kontrol "(c) atlama ibaresi" "$T/b_temiz.sql" 1 FAIL "$T/bin:"
[[ $FAILS -eq 0 ]] && { echo "SONUÇ: PASS"; exit 0; }
echo "SONUÇ: FAIL ($FAILS)"; exit 1
