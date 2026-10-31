#!/usr/bin/env bash
# hayvan_takip_muayene_vaka eşzamanlılık testi: kabul DB'den geçici kopyada iki gerçek oturum.
#   K1 kapanış önce: bağ bekler, sonra HT_VAKA_UYUMSUZ; görev açık kalır.
#   K2 bağ önce: kapanış bağın işlemi bitene kadar bekler; bağ kurulur.
#   K3 vaka kilidi → hayvan FK KEY SHARE tutan oturumla deadlock yok.
# KILIT_M5=<dosya> 5. migration yerine verilir (mutant). Kabul DB'ye yazmaz; kopya sonda silinir.
set -u
kok=$(cd "$(dirname "$0")/../.." && pwd)
m="$kok/supabase/migrations"
db="ht_kilit_$$"
P=(-h "${KOS_PGHOST:-127.0.0.1}" -U "${KOS_PGUSER:-lsp_user}" -X -q -At)
trap 'psql "${P[@]}" -d postgres -c "DROP DATABASE IF EXISTS $db" >/dev/null 2>&1' EXIT
psql "${P[@]}" -d postgres -c "CREATE DATABASE $db TEMPLATE egesut_ovsync_kabul" || exit 2
for f in "$m"/2026103120000[1-4]_*.sql "${KILIT_M5:-$m/20261031200005_hayvan_takip_muayene_vaka.sql}"; do
  { echo 'BEGIN;'; printf '\\i %s\n' "$f"; echo 'COMMIT;'; } | psql "${P[@]}" -d "$db" -v ON_ERROR_STOP=1 -f - >/dev/null || exit 2
done

q() { psql "${P[@]}" -d "$db" -v ON_ERROR_STOP=1 -c "$1" 2>&1; }
id() { printf '00000000-0000-4000-8%03d-%012d' "$1" "$2"; }
dus=0
sonuc() { if [ "$2" = "$3" ]; then echo "$1 PASS"; else echo "$1 FAIL: beklenen [$3] gerçek [$2]"; dus=1; fi; }

kur() { # $1 senaryo no
  local h c t g; h=$(id "$1" 1); c=$(id "$1" 2); t=$(id "$1" 3); g=$(id "$1" 4)
  q "INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, dogum_tarihi, durum, irk, grup, padok)
       VALUES ('$h', 'E2E-HT-K-$1', 'Dişi', CURRENT_DATE - 1500, 'Aktif', 'Holstein', 'Sağmal', 'P1');
     INSERT INTO public.cases (id, animal_id, disease_id, notes)
       VALUES ('$c', '$h', (SELECT id FROM public.diseases ORDER BY id LIMIT 1), 'E2E-HT-K');
     INSERT INTO public.hayvan_takip (id, hayvan_id, sebep_kodu) VALUES ('$t', '$h', 'TOPALLIK');
     INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, ref_takip_id)
       VALUES ('$g', '$h', 'HAYVAN_TAKIP_MUAYENE', 'E2E-HT-K', CURRENT_DATE + 7, '$t');" >/dev/null || exit 2
}
bagla() { echo "SELECT public.hayvan_takip_muayene_vaka('$(id "$1" 4)', '$(id "$1" 2)') ->> 'ok';"; }

# K1
kur 1
q "BEGIN; UPDATE public.cases SET status = 'closed', closed_at = now() WHERE id = '$(id 1 2)'; SELECT pg_sleep(1); COMMIT;" >/dev/null &
sleep 0.3
b=$(q "$(bagla 1)" | grep -oE 'HT_[A-Z_]+|^t(rue)?$' | head -1); wait
sonuc K1-red "$b" HT_VAKA_UYUMSUZ
sonuc K1-gorev "$(q "SELECT tamamlandi FROM public.gorev_log WHERE id = '$(id 1 4)'")" f

# K2
kur 2
q "BEGIN; $(bagla 2) SELECT pg_sleep(1); COMMIT;" >/dev/null &
sleep 0.3
t0=$(date +%s%N)
q "UPDATE public.cases SET status = 'closed', closed_at = now() WHERE id = '$(id 2 2)'" >/dev/null
gecen=$(( ($(date +%s%N) - t0) / 1000000 )); wait
[ "$gecen" -ge 400 ] && bekledi=evet || bekledi="hayir(${gecen}ms)"
sonuc K2-bekledi "$bekledi" evet
sonuc K2-bag "$(q "SELECT kapanis_nedeni, kapatan_vaka_id FROM public.hayvan_takip WHERE id = '$(id 2 3)'")" "VAKA|$(id 2 2)"

# K3: mevcut RPC'lerin vaka kilidi + FK kalıbı (ovsync_hastalik_gunu_ekle, _vaka_kapat)
kur 3
cikti_a="$(mktemp -p "${TMPDIR:-$HOME/tmp}")"
q "BEGIN; SELECT 1 FROM public.cases WHERE id = '$(id 3 2)' FOR UPDATE; SELECT pg_sleep(0.8);
   SELECT 1 FROM public.hayvanlar WHERE id = '$(id 3 1)' FOR KEY SHARE; COMMIT;" >"$cikti_a" 2>&1 &
sleep 0.3
b=$(psql "${P[@]}" -d "$db" -c "SET deadlock_timeout = '300ms'; $(bagla 3)" 2>&1); wait
a=$(cat "$cikti_a"); rm -f "$cikti_a"
if printf '%s\n%s\n' "$a" "$b" | grep -q 'deadlock detected'; then k3=deadlock; else k3=yok; fi
sonuc K3-deadlock "$k3" yok
sonuc K3-bag "$(printf '%s\n' "$b" | tail -1)" true

exit "$dus"
