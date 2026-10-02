# K1 / B9 — gebelik_muayene_gorev_uret CURRENT_DATE (UTC) kayma ölçümü

Tarih: 2026-10-02 · Yetki: PROD yalnız SELECT (Management API, curl) · Yazma/DDL/cron değişikliği YOK · Demo'ya dokunulmadı.
Goal: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md (Kalem 1)

## HÜKÜM: KAYMA YOK

Üretici cron 05:10 UTC = 08:10 TR çalışır. Bu saatte UTC günü = TR günüdür; CURRENT_DATE doğru yerel günü verir. Migration yazılmadı.

## Ölçüm tablosu

| # | Ölçüm | Sonuç | Kanıt |
|---|---|---|---|
| 1 | Üretici cron (jobid 16, `gebelik-muayene-daily`) | schedule `10 5 * * *`, active=true, command `SELECT public.gebelik_muayene_gorev_uret(false)` | [OBSERVED S1] |
| 1b | Zamanlayıcı saat dilimi | `cron.timezone=GMT`, `TimeZone=UTC` → schedule UTC'dir | [OBSERVED S2] |
| 1c | UTC→TR dönüşümü | 05:10 UTC + 3 sa = **08:10 TR**. TR yıl boyu UTC+3 (yaz saati yok) | [OBSERVED S1,S2] + [INFERRED TR kalıcı UTC+3, 2016'dan beri] |
| 1d | 00:00–03:00 TR (21:00–24:00 UTC) penceresine düşen cron işi | **0 iş.** Tüm 9 aktif iş UTC saatleri: 00/04/08/12/16/20:00 `*/4` ailesi (0 ve 30. dk), 03:00, her 15 dk, 04:00, 05:00, 05:10, 05:15. En geç gece-TR işi `0 */4` ailesinin 00:00 UTC = 03:00 TR; bu ailenin fonksiyonlarında CURRENT_DATE geçmez (cd=false) | [OBSERVED S1,S3] |
| 1e | Cron'dan çağrılan, CURRENT_DATE içerip yazan diğer iş | Yalnız `sessiz-reconcile-daily` (`0 5 * * *` = 08:00 TR) → `sessiz_hayvanlar_reconcile`: `tamamlanma_tarihi >= CURRENT_DATE-30` ve INSERT `hedef_tarih=CURRENT_DATE`. 08:00 TR'de UTC günü = TR günü; kayma yok | [OBSERVED S3,S6] |
| 2 | `cron.job_run_details` jobid 16 | Toplam 5 koşum (ilk 2026-09-27): hepsi `succeeded`, start_time 05:10:00.15–.25 UTC (= 08:10 TR) — 09-27, 09-28, 09-29, 09-30, 10-01. Saat sapması yok | [OBSERVED S4] |
| 3 | Canlı gövde (pg_get_functiondef) | `CURRENT_DATE` 5 yerde: `bekliyor_gun`, `t.tarih <= CURRENT_DATE - v_esik`, `tamamlanma_tarihi >= (CURRENT_DATE - 30)`, INSERT `hedef_tarih = CURRENT_DATE`. `now()` yalnız dönüş jsonb 'zaman' alanında. Timezone kullanımı yok. SECURITY DEFINER, `search_path=public, pg_temp`, ACL `postgres=X, service_role=X` (anon/authenticated yok) | [OBSERVED S5] |
| 3b | Fonksiyonun başka çağıranı | Başka DB fonksiyonu çağırmıyor; repo js/ içinde çağrı yok; ACL yalnız service_role → kullanıcı eylemiyle tetiklenemez, tek düzenli tetik cron | [OBSERVED S7,S8] + grep (js/ sonuç yok; yalnız migration/doc) |
| 4 | prod `gorev_log` GEBELIK_KONTROL son 30 gün | 52 satır; **fonksiyonun ürettiği (`kaynak LIKE 'GEBELIK-KONTROL-%'`) yalnız 4 satır** (09-27 05:10 ×3, 09-30 05:10 ×1). Kalan 48 satır eski `TOH-…` kaynaklı (+21/+35 g üreticisi; sahip 2026-09-29 kararıyla kaldırıldı) → bu fonksiyonla ilgisiz | [OBSERVED S9,S10] |
| 4b | 4 fonksiyon satırı: hedef_tarih ↔ created_at günü | created_at 05:10:00 UTC = 08:10 TR. `hedef_tarih = UTC günü = TR günü` 4/4 (09-27 ×3, 09-30 ×1) | [OBSERVED S9,S10] |
| 4c | TR günü ≠ UTC günü olan satır | **0 / 52** (son 30 g), **0 / 134** (tüm GEBELIK_KONTROL, 2026-05-22 ilk kayıt) | [OBSERVED S10,S11] |
| 4d | Fonksiyonun hedefi nasıl kuruyor | `hedef_tarih = CURRENT_DATE` (sunucu UTC günü); gövdede ek ofset yok. 08:10 TR'de UTC günü = TR günü → kayma çıkmaz | [OBSERVED S5] + [INFERRED 4b ile tutarlı] |

## Kalan (örtük) risk — kayma değil, uyarı

- Fonksiyon CURRENT_DATE kullandığı sürece **elle** (service_role ile, örn. psql/Management API) TR 00:00–03:00 arasında `gebelik_muayene_gorev_uret(false)` çalıştırılırsa hedef_tarih ve `bekliyor_gun` bir gün geride yazılır. Bugün böyle bir çağrı yok [OBSERVED S4: 5/5 koşum 08:10 TR]; cron saati birisi 00:00–03:00 TR'ye çekerse sorun doğar. [INFERRED]
- `sessiz_hayvanlar_reconcile` için de aynı gözlem geçerli (08:00 TR).
- Öneri (sahip/mimar kararı): migration ZORUNLU DEĞİL. İleride cron saati değişirse veya savunma amaçlı istenirse `((now() AT TIME ZONE 'Europe/Istanbul')::date)` kalıbı (20261001000001 deseni) uygulanabilir; bu turda yazılmadı.
- `job_run_details` yalnız 5 koşum tutuyor (job 2026-09-27'den beri) [OBSERVED S4]; daha eski koşum saati [UNKNOWN] ama cron.job.schedule değişmiş olsa bile 4c'deki 0/134 sapma, geçmişte de kayma olmadığını gösterir (fonksiyon kaynaklı yalnız 4 satır olduğundan geçmiş örneklem küçüktür).

## Koşulan SQL'ler (prod, yalnız SELECT; `curl POST /v1/projects/zqnexqbdfvbhlxzelzju/database/query`)

- S1: `select jobid,jobname,schedule,active,command from cron.job order by jobid`
- S2: `select name,setting from pg_settings where name in ('cron.timezone','TimeZone','cron.use_background_workers')`
- S3: `select j.jobname,j.schedule,p.proname,(pg_get_functiondef(p.oid) ~* 'current_date') as cd, (… ~* 'current_date') and (… ~* '(insert|update)') as cd_yazma from cron.job j join pg_proc p on j.command ilike '%public.'||p.proname||'(%' join pg_namespace n … where nspname='public'`
- S4: `select jobid,runid,status,start_time,end_time,return_message,(start_time at time zone 'Europe/Istanbul') tr_start from cron.job_run_details where jobid=16 order by start_time desc limit 14` ; `select count(*),min(start_time) from cron.job_run_details where jobid=16`
- S5: `select pg_get_functiondef(p.oid), p.prosecdef, p.proconfig, p.proacl from pg_proc p join pg_namespace n … where proname='gebelik_muayene_gorev_uret'`
- S6: `select regexp_matches(pg_get_functiondef(p.oid),'[^\n]*current_date[^\n]*','gi') … proname='sessiz_hayvanlar_reconcile'`
- S7: `select p.proname from pg_proc … where pg_get_functiondef(p.oid) ilike '%gebelik_muayene_gorev_uret%' and p.proname<>'gebelik_muayene_gorev_uret'` → boş
- S8: `select jobname from cron.job where command ilike '%CURRENT_DATE%'` → boş (CURRENT_DATE cron komutunda değil, fonksiyon gövdesinde)
- S9: `select id,hayvan_id,hedef_tarih,created_at,(created_at at time zone 'UTC')::date utc_gun,(created_at at time zone 'Europe/Istanbul')::date tr_gun,… from gorev_log where gorev_tipi='GEBELIK_KONTROL' and created_at > now()-interval '30 days' order by created_at`
- S10: `select count(*) total, count(*) filter (where utc_gun<>tr_gun) tr_ne_utc, count(*) filter (where hedef_tarih=utc_gun) …, count(*) filter (where kaynak like 'GEBELIK-KONTROL-%') … from gorev_log … son 30 gün` → total 52, tr_ne_utc 0, hedef_eq_utc 4, hedef_eq_tr 4, fn_kaynakli 4
- S11: aynı sayım tüm süre → total 134, tr_ne_utc 0, fn_kaynakli 4, min 2026-05-22, max 2026-09-30 05:10 UTC

Migration: yazılmadı (kayma yok). db-validate: koşulmadı (migration yok). git add/commit yapılmadı.

SONUC: KAYMA_YOK
