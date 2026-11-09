# D0 — Gövde tabanı ve regresyon tabanı (ovsync-tren L-DB)

- Çekim zamanı (UTC): prod+demo md5 `2026-11-09T08:41:24Z` · build.sh başlangıç `2026-11-09T08:41:17Z` · regresyon koşumu `2026-11-09T08:41:39Z`
- Kaynaklar: prod `SB_PROJECT_REF` + demo `SUPABASE_DEMO_REF`, Management API `POST /database/query` `read_only:true` (yalnız SELECT, yazma yok).
  Kanıt gövdeleri: `~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/kanit/fn/<ad>.sql`
  (md5 = ilk ve son `$function$` arasındaki metin, bayt-birebir). Yerel kabul: `egesut_ovsync_kabul` (build.sh sonrası).
- Sorgu: `SELECT p.proname, p.oid::regprocedure::text, md5(p.prosrc) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname = ANY(<16 ad>)`
- Overload: YOK — 3 kaynakta da 16 ad → 16 satır (her ad tek imza). MEASURED
- Sonuç: 16/16 EŞİT (prod = demo = kanit = yerel kabul). DRIFT YOK → `fn/*.sql` yeniden çekilmedi; sonraki görevler kanit/fn gövdesini kullanır. MEASURED
- md5 koruma değeri (RL-2) = "prod md5" sütunu.

## Gövde md5 tablosu

| ad | imza (regprocedure) | prod md5 | demo md5 | kanit md5 | yerel kabul md5 | durum |
|---|---|---|---|---|---|---|
| `_acik_disi_gorev_kur` | `_acik_disi_gorev_kur(text)` | cb7b8182151602505b48615148592b2a | cb7b8182151602505b48615148592b2a | cb7b8182151602505b48615148592b2a | cb7b8182151602505b48615148592b2a | EŞİT |
| `_acik_disi_hedef_ic` | `_acik_disi_hedef_ic(text)` | 5082fc8884d9ad96a8fa4f16d457c9f5 | 5082fc8884d9ad96a8fa4f16d457c9f5 | 5082fc8884d9ad96a8fa4f16d457c9f5 | 5082fc8884d9ad96a8fa4f16d457c9f5 | EŞİT |
| `_ovsync_baslat_gorev_kur` | `_ovsync_baslat_gorev_kur(text,date,text,date)` | 66e46e679f85afada875808607a28dac | 66e46e679f85afada875808607a28dac | 66e46e679f85afada875808607a28dac | 66e46e679f85afada875808607a28dac | EŞİT |
| `_vaka_ac_tek` | `_vaka_ac_tek(text,uuid,text,date)` | f9be42278a02581ade0f55230ea37aee | f9be42278a02581ade0f55230ea37aee | f9be42278a02581ade0f55230ea37aee | f9be42278a02581ade0f55230ea37aee | EŞİT |
| `dogum_kaydet` | `dogum_kaydet(text,date,text,text,text,numeric,text,text)` | 756c56afb83401721521e42e613ab7f9 | 756c56afb83401721521e42e613ab7f9 | 756c56afb83401721521e42e613ab7f9 | 756c56afb83401721521e42e613ab7f9 | EŞİT |
| `gorev_ertele` | `gorev_ertele(uuid,date,time without time zone)` | 2af93dfba299268b912175c628d4b05c | 2af93dfba299268b912175c628d4b05c | 2af93dfba299268b912175c628d4b05c | 2af93dfba299268b912175c628d4b05c | EŞİT |
| `ovsync_baslat_uyarilari` | `ovsync_baslat_uyarilari()` | 869dcfef020a01c6446359d13aa988ed | 869dcfef020a01c6446359d13aa988ed | 869dcfef020a01c6446359d13aa988ed | 869dcfef020a01c6446359d13aa988ed | EŞİT |
| `ovsync_hastalik_gunu_ekle` | `ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text)` | 1765d756f499e3ecc36740e74a65d804 | 1765d756f499e3ecc36740e74a65d804 | 1765d756f499e3ecc36740e74a65d804 | 1765d756f499e3ecc36740e74a65d804 | EŞİT |
| `protokol_iptal` | `protokol_iptal(uuid,boolean,text)` | e5487897bf66b1f8f361792cb4bcf74a | e5487897bf66b1f8f361792cb4bcf74a | e5487897bf66b1f8f361792cb4bcf74a | e5487897bf66b1f8f361792cb4bcf74a | EŞİT |
| `seans_tamamla` | `seans_tamamla(uuid,boolean,text,boolean,text,boolean)` | 4afb2221a7e95235e754b7ff508d0379 | 4afb2221a7e95235e754b7ff508d0379 | 4afb2221a7e95235e754b7ff508d0379 | 4afb2221a7e95235e754b7ff508d0379 | EŞİT |
| `start_first_service_protocol` | `start_first_service_protocol(uuid,boolean)` | 9c7344bbb42e53246f63bcd7999b7525 | 9c7344bbb42e53246f63bcd7999b7525 | 9c7344bbb42e53246f63bcd7999b7525 | 9c7344bbb42e53246f63bcd7999b7525 | EŞİT |
| `tedavi_sablon_uygula` | `tedavi_sablon_uygula(uuid,uuid,date,boolean,text)` | 7cc9e46508c3f4fab10516a5676d026e | 7cc9e46508c3f4fab10516a5676d026e | 7cc9e46508c3f4fab10516a5676d026e | 7cc9e46508c3f4fab10516a5676d026e | EŞİT |
| `tohumlama_bos_ve_devam` | `tohumlama_bos_ve_devam(text,uuid,text,text,numeric,integer,time without time zone,text,boolean)` | ba1ba4bb7b870171e190013d7fc090c8 | ba1ba4bb7b870171e190013d7fc090c8 | ba1ba4bb7b870171e190013d7fc090c8 | ba1ba4bb7b870171e190013d7fc090c8 | EŞİT |
| `tohumlama_gorev_ertele` | `tohumlama_gorev_ertele(uuid,date,time without time zone)` | d9b19df7d182ddd33bc67ccab7318b1e | d9b19df7d182ddd33bc67ccab7318b1e | d9b19df7d182ddd33bc67ccab7318b1e | d9b19df7d182ddd33bc67ccab7318b1e | EŞİT |
| `vaka_kalan_gunleri_kaydir` | `vaka_kalan_gunleri_kaydir(uuid,integer)` | 0f6e319096b3905e56df52dc20bdddc4 | 0f6e319096b3905e56df52dc20bdddc4 | 0f6e319096b3905e56df52dc20bdddc4 | 0f6e319096b3905e56df52dc20bdddc4 | EŞİT |
| `vaka_kalan_gunleri_kaydir_coklu` | `vaka_kalan_gunleri_kaydir_coklu(uuid[],integer)` | 09875ad70b8d98bdd87061738355a964 | 09875ad70b8d98bdd87061738355a964 | 09875ad70b8d98bdd87061738355a964 | 09875ad70b8d98bdd87061738355a964 | EŞİT |

## build.sh

- Komut: `cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash scripts/kabul-db/build.sh` (RL-5: `EGESUT_REPO` verilmedi)
- rc: **0** · son satır: `SONUÇ: TEMİZ — egesut_ovsync_kabul canlı public şemasıyla nesne-düzeyinde eş` (nesne-düzeyi fark 0 satır, süre 14 sn). MEASURED

## Regresyon tabanı (serisiz, migration listesi boş)

- Komut: `( echo 'BEGIN;'; cat supabase/tests/ovsync_pg_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -5`
- psql rc (tail'siz koşum): **3** (ON_ERROR_STOP). Sonuç: **FAIL S1-a** (ilk test bloğu, 2. assert). MEASURED
- Ham son satırlar:

```
ERROR:  FAIL S1-a: beklenen deger=0 birim=bool min=0 max=1 gerçek 1 bool 0 1
BAĞLAM:  PL/pgSQL function pg_temp_0.kb_ok(boolean,text,text,text) line 4 at RAISE
SQL statement "SELECT pg_temp.kb_ok(r.deger = 0 AND r.birim = 'bool' AND r.min_deger = 0 AND r.max_deger = 1,
    'S1-a', 'deger=0 birim=bool min=0 max=1', format('%s %s %s %s', r.deger, r.birim, r.min_deger, r.max_deger))"
PL/pgSQL function inline_code_block line 6 at PERFORM
```

- Neden (INFERRED, `ovsync_pg_kabul.sql:101-104`): S-1, `protokol_ayar.ovsync_pg_kurallari_aktif` için `deger=0` (teslim öncesi varsayılan)
  bekliyor; build.sh `protokol_ayar`'ı prod'dan kopyalıyor ve prod'da bayrak canlı (`deger=1`). Düzeltme bu görevin kapsamı dışı.
- D8 beklentisi: aynı koşum seriyle aynı ilk satırı (`FAIL S1-a … gerçek 1 bool 0 1`) vermeli. Not: koşum S1-a'da durduğu için bu taban
  ovsync_pg_kabul.sql'in geri kalan ~300 assert'ini sınamıyor (regresyon kapsamı fiilen yok) — bkz. D0-report `open_item`.
- Ek ölçüm (bilgi, MEASURED): aynı koşum `BEGIN;` sonrası `UPDATE public.protokol_ayar SET deger=0 WHERE anahtar='ovsync_pg_kurallari_aktif';`
  ile (ROLLBACK'li) S1-a'yı geçiyor, ardından fixture'da düşüyor:
  `ERROR:  FIXTURE: vaka_toplu_ac başarısız: … "mesaj": "PG_KAPI:BLOCK_PREGNANT:{… "karar": "BLOCK_PREGNANT" …}"` (`pg_temp.kb_ovsync_vaka`).
  Yani betik prod'a sonradan gelen PG kapısıyla da eskimiş; taban olarak yalnız yukarıdaki serisiz FAIL S1-a satırı geçerlidir.
