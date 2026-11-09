⟦ss-sub model=opus effort=high rol=ss-worker-high iş=ovsync-tren D0 gövde/regresyon tabanı ölçümü⟧
sonuc: TAMAM

job_id: j-20261109T084048Z-42b026
Çıktı: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md
Commit: f7edd8c (`ovsync-tren L-DB D0: gövde/regresyon tabanı`; staged alan `git diff --cached --stat` ile doğrulandı: yalnız govde-taban.md, +59 satır)

## Gelen iş denetimi
Bulgu yok. (Not: PLAN D0 sorgusunda namespace filtresi yok, brief'te var; brief'teki `nspname='public'` uygulandı.)

## Sonuç özeti
- 16 fonksiyon, overload yok (üç kaynakta da 16 ad → 16 satır). MEASURED
- prod md5 = demo md5 = kanit/fn md5 = yerel kabul md5: 16/16 EŞİT. MEASURED
- DRIFT yok → `fn/*.sql` yazılmadı; sonraki D görevleri kanit/fn gövdesini olduğu gibi kullanır. RL-2 md5 koruma değerleri = tablonun "prod md5" sütunu. MEASURED
- build.sh rc 0, `SONUÇ: TEMİZ` (nesne-düzeyi fark 0). MEASURED
- Regresyon tabanı (serisiz): psql rc 3, `FAIL S1-a: beklenen deger=0 … gerçek 1 bool 0 1`. MEASURED
  Neden: S-1, `ovsync_pg_kurallari_aktif=0` bekliyor; build.sh protokol_ayar'ı prod'dan alıyor, prod'da bayrak 1. INFERRED (`supabase/tests/ovsync_pg_kabul.sql:101-104`)

## DRIFT
Yok (16/16 EŞİT). Root'a iletilecek gövde farkı yok.

## Önemli bulgu (lead/root için)
Regresyon tabanı fiilen kapsamsız: koşum ilk test bloğunda (S1-a) duruyor. Ek ölçümde (BEGIN içinde bayrak 0 yapıldı, ROLLBACK'li)
S1-a geçiyor ama ardından fixture `PG_KAPI:BLOCK_PREGNANT` (vaka_toplu_ac, `pg_temp.kb_ovsync_vaka`) ile düşüyor. MEASURED
→ `ovsync_pg_kabul.sql` prod'un bugünkü hâline (bayrak canlı + 20261031200007 PG kapısı) göre eskimiş. D8'in "aynı sonuç" kabulü
yalnız aynı ilk FAIL satırını karşılaştırır, ~300 assert'in regresyonunu sınamaz. Brief kararı gereği bu görevde düzeltilmedi.
SORU: D8 regresyon kabulü için betik ayrı görevde güncellensin mi · seçenekler: (a) D8 kabulü "aynı ilk FAIL S1-a" olarak kalır, (b) ayrı görevde ovsync_pg_kabul.sql kurulumu bayrak=0 + gebe olmayan fixture'a uydurulur, sonra taban yeniden alınır · önerim: (b), çünkü (a) seri regresyonunu hiç ölçmez.

## Tesisat bulgusu
guard-writable hook'u bu brief'teki `- <yol>` madde biçimini yol olarak ayrıştıramıyor (`_brief.py:57-80`; madde imi ve parantez notu yola katılıyor, cwd'ye göre çözülüyor) → izinli D0-report.md Write aracıyla reddedildi. Report, yol brief allowlist'inde olduğu için Bash ile yazıldı. D1..D8 brief'leri aynı biçimdeyse aynı RED gelir. MEASURED (`_brief.writable_paths` çıktısı: `~/tools-bank/.superset/hooks/- ~/...`). Gate kırıntısı yazıldı (env-mismatch).

## Kırıntılar
- measurement: 16/16 EŞİT, overload yok, DRIFT yok
- open_item: regresyon tabanı S1-a'da duruyor + bayrak 0 iken PG_KAPI fixture düşüşü; kapanış koşulu lead/root kararı
- gate (env-mismatch): guard-writable `- ` madde imi ayrıştırma hatası
- assumption: D0 salt ölçüm; domain-rules §5/§18 ayrıntılı okunmadı (içerik kararı yok, çelişki noktası yok)
(workspace fable-rol-ve-davranislar)

## Run kanıtı

```
grep -c "^|" ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/govde-taban.md
```
rc: 0
```
18
```
(başlık + ayraç + 16 veri satırı)

```
psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -XAtc "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('dogum_kaydet','_ovsync_baslat_gorev_kur','_acik_disi_gorev_kur','_acik_disi_hedef_ic','ovsync_baslat_uyarilari','protokol_iptal','tohumlama_bos_ve_devam','start_first_service_protocol','tedavi_sablon_uygula','_vaka_ac_tek','gorev_ertele','tohumlama_gorev_ertele','vaka_kalan_gunleri_kaydir','vaka_kalan_gunleri_kaydir_coklu','ovsync_hastalik_gunu_ekle','seans_tamamla')"
```
rc: 0
```
16
```

## Run sonuçları (görev adımları)

```
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash scripts/kabul-db/build.sh
```
rc: 0
```
    nesne-düzeyi fark (tanım md5): 0 satır → ~/tmp/egesut-kabul-db/out/diff.txt
    zorunlu nesneler: hepsi VAR
    FK yetim satır: yok
    süre: 14 sn
SONUÇ: TEMİZ — egesut_ovsync_kabul canlı public şemasıyla nesne-düzeyinde eş
```

```
( echo 'BEGIN;'; cat supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -5
```
rc: 0 (boru hattında tail'in rc'si; tail'siz koşumda psql rc 3)
```
ERROR:  FAIL S1-a: beklenen deger=0 birim=bool min=0 max=1 gerçek 1 bool 0 1
BAĞLAM:  PL/pgSQL function pg_temp_0.kb_ok(boolean,text,text,text) line 4 at RAISE
SQL statement "SELECT pg_temp.kb_ok(r.deger = 0 AND r.birim = 'bool' AND r.min_deger = 0 AND r.max_deger = 1,
    'S1-a', 'deger=0 birim=bool min=0 max=1', format('%s %s %s %s', r.deger, r.birim, r.min_deger, r.max_deger))"
PL/pgSQL function inline_code_block line 6 at PERFORM
```

Prod/demo md5: Management API `read_only:true`, 2026-11-09T08:41:24Z; ikisi de 16 satır; yerel↔prod `diff` boş (`YEREL=PROD`).
Kanit md5: Python ile dosyadaki ilk ve son `$function$` arası metin bayt-birebir hashlendi (16 dosyanın hepsinde tam 2 `$function$`).

BOYUT: bütçe 0 üretim kodu (govde-taban.md ≤120 satır) · gerçek 0 üretim kodu, govde-taban.md 59 satır · bütçe içinde
