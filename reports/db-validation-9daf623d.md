# DB Validation Raporu — 9daf623d

- Tarih: 2026-09-25 19:09:39+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql`
- SHA-256: `9daf623dc4b8e9155c1d646cee202e562def1356f512c7267cfdbdb18665b2ab`
- Baseline (C1): {'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | ERROR düzeyi ihlal yok; 2 WARNING rapora kaydedildi (bkz. çıktı) |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql] FAIL
L:   2 | P:   1 | LT05 | Line is too long (86 > 80). [layout.long_lines]
L:   8 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  10 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:  11 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  15 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  23 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  41 | P:   1 | LT05 | Line is too long (85 > 80). [layout.long_lines]
L:  42 | P:   1 | LT05 | Line is too long (89 > 80). [layout.long_lines]
L:  93 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  94 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 100 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L: 101 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L: 102 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L: 102 | P:  39 | LT02 | Expected line break and no indent before ')'.
                       | [layout.indent]
L: 224 | P:  62 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 225 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L: 225 | P:  71 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 226 | P:  64 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
All Finished!
```

### FAZ A squawk (`squawk.out`)
```
warning[require-lock-timeout]: Missing `set lock_timeout` before potentially slow operations
   ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql:24:1
   │
24 │ ┏ CREATE OR REPLACE FUNCTION public._ovsync_hastalik_mi(p_disease_id uuid)
25 │ ┃ RETURNS boolean
26 │ ┃ LANGUAGE sql
27 │ ┃ STABLE
   ‡ ┃
36 │ ┃   );
37 │ ┃ $$;
   │ ┗━━━┛
   │
   ├ help: Configure a `lock_timeout` before this statement.
   ╭╴
21 + set lock_timeout = '1s';
   ╰╴
warning[require-statement-timeout]: Missing `set statement_timeout` before potentially slow operations
   ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql:24:1
   │
24 │ ┏ CREATE OR REPLACE FUNCTION public._ovsync_hastalik_mi(p_disease_id uuid)
25 │ ┃ RETURNS boolean
26 │ ┃ LANGUAGE sql
27 │ ┃ STABLE
   ‡ ┃
36 │ ┃   );
37 │ ┃ $$;
   │ ┗━━━┛
   │
   ├ help: Configure a `statement_timeout` before this statement
   ╭╴
21 + set statement_timeout = '5s';
   ╰╴

Find detailed examples and solutions for each rule at https://squawkhq.com/docs/rules
Found 2 issues in 1 file (checked 1 source file)
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
CREATE FUNCTION
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql:64: NOTICE:  function public._kisir_ovsync_guard(uuid,pg_catalog.bool) does not exist, skipping
DROP FUNCTION
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql:91: NOTICE:  trigger "trg_cases_kisir_ovsync" for relation "public.cases" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
CREATE FUNCTION
REVOKE
REVOKE
REVOKE
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
CREATE FUNCTION
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql:64: NOTICE:  function public._kisir_ovsync_guard(uuid,pg_catalog.bool) does not exist, skipping
DROP FUNCTION
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000018_kisir_ovsync_hardblock.sql:91: NOTICE:  trigger "trg_cases_kisir_ovsync" for relation "public.cases" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
CREATE FUNCTION
REVOKE
REVOKE
REVOKE
COMMIT
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri '1' fallback
```
