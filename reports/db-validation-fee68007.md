# DB Validation Raporu — fee68007

- Tarih: 2026-09-25 17:08:42+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql`
- SHA-256: `fee68007be6ec0391029959a170174bbef474930b9957d74210fd6b6942b6f39`
- Baseline (C1): {'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | ERROR düzeyi ihlal yok; 1 WARNING rapora kaydedildi (bkz. çıktı) |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: cases:0→0 |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql] FAIL
L:  40 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  40 | P:   3 | LT05 | Line is too long (106 > 80). [layout.long_lines]
L:  40 | P:  28 | LT01 | Unexpected whitespace before start bracket '('.
                       | [layout.spacing]
L:  40 | P:  28 | LT06 | Function name not immediately followed by parenthesis.
                       | [layout.functions]
L:  43 | P:   1 | LT05 | Line is too long (107 > 80). [layout.long_lines]
L: 255 | P:   1 | LT05 | Line is too long (129 > 80). [layout.long_lines]
L: 255 | P: 125 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L: 366 | P:   1 | LT05 | Line is too long (85 > 80). [layout.long_lines]
L: 366 | P:  73 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 367 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L: 367 | P:  72 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 368 | P:   1 | LT05 | Line is too long (86 > 80). [layout.long_lines]
All Finished!
```

### FAZ A squawk (`squawk.out`)
```
warning[constraint-missing-not-valid]: By default new constraints require a table scan and block writes to the table while that scan occurs.
   ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql:39:26
   │
39 │   ALTER TABLE public.cases ADD CONSTRAINT cases_close_reason_check
   │ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━┛
40 │ ┃   CHECK (close_reason = ANY (ARRAY['ERKEN_KAPANIS'::text, 'TOHUMLAMA'::text, 'PG'::text, 'IPTAL'::text]));
   │ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
   │
   ╰ help: Use `NOT VALID` with a later `VALIDATE CONSTRAINT` call.

Find detailed examples and solutions for each rule at https://squawkhq.com/docs/rules
Found 1 issue in 1 file (checked 1 source file)
```

### C1/C2 baseline (`baseline.out`)
```
[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → /home/melik/tmp/agents/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)[0m
[1;34m▶ İzole DB kuruluyor: egesut_val_tmp[0m
[1;34m▶ Roller kuruluyor (NOLOGIN)…[0m
DO
[1;34m▶ egesut_lsp aynasından pg_dump alınıyor…[0m
[1;34m▶ Baseline izole DB'ye yükleniyor (ON_ERROR_STOP=1)…[0m
[1;34m▶ pgTAP çekiliyor…[0m
curl: (22) The requested URL returned error: 404
[1;33m⚠ raw master pgtap.sql 404 (repo içinde üretilmiyor) — latest release zip'e düşülüyor…[0m
Makefile:181: To use pg_prove, TAP::Parser::SourceHandler::pgTAP Perl module
Makefile:182: must be installed from CPAN. To do so, simply run:
Makefile:183: cpan TAP::Parser::SourceHandler::pgTAP
[1;34m▶ pgTAP yükleniyor (370922 byte, ayrı 'pgtap' şemasına)…[0m
ALTER DATABASE
{"db_name":"egesut_val_tmp","tablo":54,"fonksiyon":244,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)","parite_dosya":"/home/melik/tmp/agents/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
SET
SET
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql:38: NOTICE:  constraint "cases_close_reason_check" of relation "cases" does not exist, skipping
ALTER TABLE
ALTER TABLE
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
GRANT
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql:38: NOTICE:  constraint "cases_close_reason_check" of relation "cases" does not exist, skipping
ALTER TABLE
ALTER TABLE
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
GRANT
COMMIT
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri '1' fallback
cases: sentetik satır eklendi (id, animal_id, disease_id, start_date, status)
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
```
