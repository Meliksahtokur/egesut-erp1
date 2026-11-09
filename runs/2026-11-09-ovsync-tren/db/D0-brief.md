# D0 — Gövde tabanı ve regresyon tabanı ölçümü
job_id: j-20261109T084048Z-42b026

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D0-report.md

## İş
PLAN.md "### D0" bölümünü uygula (ortak kurallar: `~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/ortak.md`).
1. Prod ve demo için salt-okuma (`read_only:true`) `SELECT p.oid::regprocedure, md5(p.prosrc) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname = ANY(<16 ad>)` — 16 ad PLAN.md D0'da. Ayrıca 16'nın her biri için `kanit/fn/<ad>.sql` dosyasından gövde md5'i hesapla (dosyadaki `$function$ … $function$` arası metin = prosrc) ve prod ile karşılaştır.
2. Overload varsa (aynı adla birden çok imza) hepsini satır olarak yaz.
3. Fark (prod≠demo ya da kanit≠prod) varsa satıra `DRIFT` yaz; kanit≠prod ise prod `pg_get_functiondef` gövdesini çek ve `runs/2026-11-09-ovsync-tren/db/fn/<ad>.sql` olarak kaydet (sonraki görevler bunu kullanır).
4. `bash scripts/kabul-db/build.sh` koş (rc'yi kaydet). Sonra kabul DB'sindeki 16 fonksiyonun md5'ini de yerelden oku (`psql … -d egesut_ovsync_kabul`) — yerel = prod olmalı (md5 korumaları kabul DB'sinde tutmalı).
5. Regresyon tabanı: `supabase/tests/ovsync_pg_kabul.sql`'i serisiz koş: `( echo 'BEGIN;'; cat supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -5` — sonuç (OZET n PASS ya da ilk FAIL id + mesaj) kaydet. FAIL olması bu görevde düzeltilecek bir şey değildir; yalnız taban kaydıdır.
6. `govde-taban.md` yaz: tablo (ad, imza, prod md5, demo md5, kanit md5, yerel kabul md5, durum EŞİT/DRIFT), regresyon taban satırı (komut + ham son satırlar), build.sh rc ve çekim zamanı.

## Model/effort
opus / high (ss-worker-high)

## Boyut bütçesi
Üretim kodu yok (ölçüm görevi); govde-taban.md ≤ 120 satır.

## Yazılabilir dosyalar
- ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md
- ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/fn/*.sql (yalnız DRIFT varsa)
- ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D0-report.md

## Kabul
- Tablo ≥16 satır (overload'lar dahil), her satırda 4 md5 + durum.
- Regresyon taban satırı ham çıktıyla.
- DRIFT varsa report'ta ayrı `## DRIFT` bölümü (lead root'a iletir).
- Commit: `git add runs/2026-11-09-ovsync-tren/db/govde-taban.md` (+ varsa fn/*.sql) — mesaj `ovsync-tren L-DB D0: gövde/regresyon tabanı`.

## Run
grep -c "^|" ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md
psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -XAtc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('dogum_kaydet','_ovsync_baslat_gorev_kur','_acik_disi_gorev_kur','_acik_disi_hedef_ic','ovsync_baslat_uyarilari','protokol_iptal','tohumlama_bos_ve_devam','start_first_service_protocol','tedavi_sablon_uygula','_vaka_ac_tek','gorev_ertele','tohumlama_gorev_ertele','vaka_kalan_gunleri_kaydir','vaka_kalan_gunleri_kaydir_coklu','ovsync_hastalik_gunu_ekle','seans_tamamla')"

## Bağımlı
N0 (TAMAM, aeb2a78)

## Review: T0

## Önceden cevaplanmış kararlar
- Prod okuma 2026-11-09 keşif izni kapsamında (salt-okuma). Yazma yok.
- Regresyon tabanı FAIL verirse düzeltme yok, yalnız kayıt (D8 aynı sonucu bekler).
- RL-5: build.sh `EGESUT_REPO` olmadan.
