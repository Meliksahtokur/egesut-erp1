# PART-06 — PostgreSQL / Supabase RPC / trigger / cron zinciri

## 1. RPC → relation/function dependency

**CONFIRMED:** `plpgsql_check` PL/pgSQL static analyzer'dır ve işlenen function içinde kullanılan relation/function/operator listesini `plpgsql_show_dependency_tb()` ile gösterebilir. [S15]

Örnek atlas extractor:

```sql
select *
from plpgsql_show_dependency_tb('public.save_insemination(...)');
```

### Sınır

Resmî README açıkça yalnız statik yazılmış komutların işlendiğini; dynamic SQL `EXECUTE`, temporary table vb. durumların ignore edilebildiğini belirtiyor. [S15]

Bu yüzden dependency edge'ine:

```text
method: plpgsql_check
coverage: static-only
limitations: dynamic_sql_unknown
```

eklenmeli.

## 2. Trigger graph

**CONFIRMED:** PostgreSQL `pg_trigger` kataloğunda trigger'ın bağlı olduğu relation `tgrelid`, çağırdığı function ise `tgfoid` ile tutulur. [S16]

Temel query:

```sql
select
  n.nspname as table_schema,
  c.relname as table_name,
  t.tgname,
  pn.nspname as fn_schema,
  p.proname as fn_name,
  pg_get_triggerdef(t.oid) as trigger_def
from pg_trigger t
join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
join pg_proc p on p.oid=t.tgfoid
join pg_namespace pn on pn.oid=p.pronamespace
where not t.tgisinternal;
```

Sonra her trigger function için `plpgsql_show_dependency_tb()` recursive yürütülebilir.

## 3. `pg_depend` ne kadar işe yarar?

**CONFIRMED:** `pg_depend` database object dependency kayıtlarını tutar; özellikle DROP/CASCADE semantiği için kullanılır. PostgreSQL source notu her mümkün dependency pair'in burada temsil edilmediğini söylüyor. [S17][S38]

Bu nedenle `pg_depend` tek başına “function hangi tabloya SELECT/INSERT yapıyor?” sorusunun tam cevabı değildir. Atlas extractor'da yardımcı metadata olarak kullanılmalı, `plpgsql_check` yerine geçmemeli.

## 4. pg_cron

**CONFIRMED:** `cron.job` aktif işleri; `cron.job_run_details` execution geçmişini verir. pg_cron v1.6.8 8 Eylül 2026'da yayımlanmış. [S18][S39]

Extractor:

```sql
select jobid, jobname, schedule, command, database, username, active
from cron.job;
```

Runtime doğrulama:

```sql
select jobid, status, return_message, start_time, end_time
from cron.job_run_details
where start_time >= :run_window_start
order by start_time;
```

### Cron command parse

`command` içinde:
- `select function(...)`
- inline SQL
- wrapper procedure
olabilir. Function adı parse edilebiliyorsa graph'a bağla; inline SQL için SQL parser/static relation extraction uygula.

## 5. Supabase katmanı

UI tarafındaki `supabase.rpc('fn')` çağrısı PostgREST üzerinden `/rest/v1/rpc/fn` olarak gözlenebilir. Bu URL canonical bridge olarak kullanılmalı.

Node örneği:

```text
ui.action.save
  -> http.post./rest/v1/rpc/save_insemination
  -> db.function.public.save_insemination
```

## 6. Runtime DB evidence

Statik lineage “dokunabilir”; runtime “bu senaryoda dokundu”yu söyler. Demo DB'de pilot için en basit yaklaşım:
- test öncesi ilgili tabloların row-key snapshot'ı,
- aksiyon sonrası diff,
- `created_at` + domain key ile run window korelasyonu.

Daha ileri aşama:
- statement logging/pg_stat_statements yalnız demo DB'de,
- event trigger değil normal DML audit trigger (geçici) — ancak davranışı değiştirebilir,
- logical decoding fazla ağır; ilk pilotta gerekmez.

## DB graph sonucu

Her RPC sayfası şu soruları cevaplamalı:
1. Hangi tabloları okuyabilir/yazabilir?
2. Hangi function'ları çağırır?
3. Yazdığı tablolar üzerinde hangi trigger'lar var?
4. Trigger function başka hangi relation/function'lara gider?
5. Hangi cron job aynı business output'u üretir?
6. Bu pilot run'da gerçekten hangileri çalıştı?
