# DB Validation Raporu — 4d8d5d0b

- Tarih: 2026-09-25 19:09:13+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql`
- SHA-256: `4d8d5d0be89007aec7b7ddea5c57bffe2c30de6bb037cefb783db796ec8bfb92`
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
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql] FAIL
L:   6 | P:   1 | LT05 | Line is too long (90 > 80). [layout.long_lines]
L:   7 | P:   1 | LT05 | Line is too long (86 > 80). [layout.long_lines]
L:   8 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  11 | P:   1 | LT05 | Line is too long (87 > 80). [layout.long_lines]
L:  14 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  18 | P:   1 | LT05 | Line is too long (87 > 80). [layout.long_lines]
L:  21 | P:   1 | LT05 | Line is too long (91 > 80). [layout.long_lines]
L:  27 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  28 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  29 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  30 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  30 | P:  22 | LT02 | Expected line break and no indent before ')'.
                       | [layout.indent]
L: 205 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 205 | P:   2 | LT09 | Select targets should be on a new line unless there is
                       | only one select target. [layout.select_targets]
L: 205 | P:   2 | ST06 | Select wildcards then simple targets before calculations
                       | and aggregates. [structure.column_order]
L: 205 | P:   8 | LT02 | Expected line break and indent of 4 spaces before 'h'.
                       | [layout.indent]
L: 212 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L: 213 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L: 214 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L: 215 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L: 215 | P:  13 | LT05 | Line is too long (131 > 80). [layout.long_lines]
L: 216 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L: 217 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L: 218 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 218 | P:  19 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
L: 219 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 220 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L: 220 | P:  15 | LT01 | Unexpected whitespace before 'SELECT' keyword.
                       | [layout.spacing]
L: 220 | P:  15 | LT02 | Expected line break and indent of 8 spaces before
                       | 'SELECT'. [layout.indent]
L: 220 | P:  23 | CP03 | Function names must be consistently upper case.
                       | [capitalisation.functions]
L: 221 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L: 221 | P:  23 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
```

### FAZ A squawk (`squawk.out`)
```
warning[require-lock-timeout]: Missing `set lock_timeout` before potentially slow operations
    ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql:26:1
    │
 26 │ ┏ CREATE OR REPLACE FUNCTION public._ovsync_baslat_gorev_kur(
 27 │ ┃   p_hayvan_id text,
 28 │ ┃   p_baslangic date,
 29 │ ┃   p_kaynak_ref text,
    ‡ ┃
130 │ ┃ END;
131 │ ┃ $$;
    │ ┗━━━┛
    │
    ├ help: Configure a `lock_timeout` before this statement.
    ╭╴
 23 + set lock_timeout = '1s';
    ╰╴
warning[require-statement-timeout]: Missing `set statement_timeout` before potentially slow operations
    ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-cila-turu/supabase/migrations/20260925000019_kural_gunu_kapisi.sql:26:1
    │
 26 │ ┏ CREATE OR REPLACE FUNCTION public._ovsync_baslat_gorev_kur(
 27 │ ┃   p_hayvan_id text,
 28 │ ┃   p_baslangic date,
 29 │ ┃   p_kaynak_ref text,
    ‡ ┃
130 │ ┃ END;
131 │ ┃ $$;
    │ ┗━━━┛
    │
    ├ help: Configure a `statement_timeout` before this statement
    ╭╴
 23 + set statement_timeout = '5s';
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
CREATE VIEW
REVOKE
REVOKE
GRANT
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
CREATE FUNCTION
CREATE FUNCTION
CREATE VIEW
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
gorev_log: sentetik satır eklendi (id)
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
protokol_instance: sentetik satır eklendi (id, hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
```
