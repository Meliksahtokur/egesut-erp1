#!/usr/bin/env bash
# Hayvan Takip eşzamanlılık testi: kabul DB'den geçici kopyada iki gerçek oturum.
#   K1 kapanış önce: bağ bekler, sonra HT_VAKA_UYUMSUZ; görev açık kalır.
#   K2 bağ önce: kapanış bağın işlemi bitene kadar bekler; bağ kurulur.
#   K3 vaka kilidi → hayvan FK KEY SHARE tutan oturumla deadlock yok.
#   K0 200006 yalnız hayvan kilidini değiştirir: ACL, DEFINER, search_path ve kalan gövde aynı.
#   K4 dört RPC, hayvan FK KEY SHARE tutan oturumu beklemez.
#   K5 üç RPC, takibi kilitleyip FK KEY SHARE alan oturumla deadlock üretmez.
#   K6 dört RPC işlem boyunca hayvan yazmasını dışlar (R13 sırası).
#   K7 açılış sürerken çıkış bekler, yeni takibi de kapatır.
# KILIT_M5, KILIT_M6=<dosya> 5. ve 6. migration yerine verilir (mutant). Kabul DB'ye yazmaz; kopya sonda silinir.
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
HT_FN="pronamespace = 'public'::regnamespace AND (proname LIKE 'hayvan\_takip\_%' OR proname LIKE '\_hayvan\_takip\_%' OR proname = '_trg_hayvan_cikis_takip_kapat')"
fn_meta() { q "SELECT proname, pg_get_function_arguments(oid), prosecdef, proconfig, proacl, provolatile, prorettype FROM pg_proc WHERE $HT_FN ORDER BY 1, 2"; }
fn_govde() { q "SELECT proname || E'\n' || prosrc FROM pg_proc WHERE $HT_FN ORDER BY 1, oid"; }
meta_once=$(fn_meta); govde_once=$(fn_govde)
{ echo 'BEGIN;'; printf '\\i %s\n' "${KILIT_M6:-$m/20261031200006_hayvan_takip_kilit.sql}"; echo 'COMMIT;'; } | psql "${P[@]}" -d "$db" -v ON_ERROR_STOP=1 -f - >/dev/null || exit 2
meta_sonra=$(fn_meta); govde_sonra=$(fn_govde)
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

# K0: meta aynı; gövdeler yalnız kilit kipinde ayrılır; NO KEY UPDATE 1'den 5'e çıkar.
[ "$meta_once" = "$meta_sonra" ] && meta=ayni || meta=farkli
sonuc K0-meta "$meta" ayni
yalin() { printf '%s\n' "$1" | sed 's/FOR NO KEY UPDATE/FOR UPDATE/'; }
[ "$(yalin "$govde_once")" = "$(yalin "$govde_sonra")" ] && govde=ayni || govde=farkli
sonuc K0-govde "$govde" ayni
sonuc K0-sayi "$(printf '%s\n' "$govde_sonra" | grep -c 'FOR NO KEY UPDATE')" 5

rpc() { # $1 ad, $2 senaryo no
  case "$1" in
    ac)     echo "SELECT public.hayvan_takip_ac('$(id "$2" 1)', 'ZAYIFLAMA') ->> 'ok';" ;;
    kapat)  echo "SELECT public.hayvan_takip_kapat(ARRAY['$(id "$2" 3)']::uuid[]) ->> 'ok';" ;;
    planla) echo "SELECT public.hayvan_takip_muayene_planla('$(id "$2" 3)', CURRENT_DATE + 9) ->> 'ok';" ;;
    sonuc)  echo "SELECT public.hayvan_takip_muayene_sonuc('$(id "$2" 4)', 'KAPANSIN') ->> 'ok';" ;;
  esac
}

n=10
for ad in ac kapat planla sonuc; do
  n=$((n + 1)); kur "$n"
  q "BEGIN; SELECT 1 FROM public.hayvanlar WHERE id = '$(id "$n" 1)' FOR KEY SHARE; SELECT pg_sleep(1); COMMIT;" >/dev/null &
  sleep 0.3
  t0=$(date +%s%N)
  c=$(q "$(rpc "$ad" "$n")")
  gecen=$(( ($(date +%s%N) - t0) / 1000000 )); wait
  [ "$gecen" -lt 500 ] && bekledi=hayir || bekledi="evet(${gecen}ms)"
  sonuc "K4-$ad-bekleme" "$bekledi" hayir
  sonuc "K4-$ad-ok" "$c" true
done

for ad in kapat planla sonuc; do
  n=$((n + 1)); kur "$n"
  cikti_a="$(mktemp -p "${TMPDIR:-$HOME/tmp}")"
  q "BEGIN; SELECT 1 FROM public.hayvan_takip WHERE id = '$(id "$n" 3)' FOR UPDATE; SELECT pg_sleep(0.8);
     SELECT 1 FROM public.hayvanlar WHERE id = '$(id "$n" 1)' FOR KEY SHARE; COMMIT;" >"$cikti_a" 2>&1 &
  sleep 0.3
  b=$(psql "${P[@]}" -d "$db" -c "SET deadlock_timeout = '300ms'; $(rpc "$ad" "$n")" 2>&1); wait
  a=$(cat "$cikti_a"); rm -f "$cikti_a"
  if printf '%s\n%s\n' "$a" "$b" | grep -q 'deadlock detected'; then k5=deadlock; else k5=yok; fi
  sonuc "K5-$ad-deadlock" "$k5" yok
  sonuc "K5-$ad-ok" "$(printf '%s\n' "$b" | tail -1)" true
done

for ad in ac kapat planla sonuc; do
  n=$((n + 1)); kur "$n"
  q "BEGIN; $(rpc "$ad" "$n") SELECT pg_sleep(0.8); COMMIT;" >/dev/null &
  sleep 0.3
  if q "SELECT 1 FROM public.hayvanlar WHERE id = '$(id "$n" 1)' FOR NO KEY UPDATE NOWAIT" | grep -q 'could not obtain lock'; then k6=dislar; else k6=dislamaz; fi
  wait
  sonuc "K6-$ad" "$k6" dislar
done

n=$((n + 1)); kur "$n"
q "BEGIN; $(rpc ac "$n") SELECT pg_sleep(0.8); COMMIT;" >/dev/null &
sleep 0.3
q "UPDATE public.hayvanlar SET durum = 'Ölü' WHERE id = '$(id "$n" 1)'" >/dev/null; wait
sonuc K7-acik-takip "$(q "SELECT count(*) FROM public.hayvan_takip WHERE hayvan_id = '$(id "$n" 1)' AND kapanis_tarihi IS NULL")" 0

exit "$dus"
