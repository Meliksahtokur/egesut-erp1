# DB Validation Raporu — f03f1a95

- Tarih: 2026-09-25 15:54:42+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql`
- SHA-256: `f03f1a95a05f3930109922140fc14af7c5be8df92c81044ae2b4271b57d2c741`
- Baseline (C1): {'tablo': 54, 'fonksiyon': 243, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=243 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | ERROR düzeyi ihlal yok; 2 WARNING rapora kaydedildi (bkz. çıktı) |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 243, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=243 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: > gorev_ertele_kural=1; etkilenen tablolar relrowsecurity: gorev_ertele_kural:→1 |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 243, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=243 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql] FAIL
L:   4 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:   8 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  13 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  14 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  46 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  46 | P:  13 | LT01 | Expected only single space before 'text' keyword. Found
                       | '       '. [layout.spacing]
L:  47 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  47 | P:  16 | LT01 | Expected only single space before 'boolean' keyword.
                       | Found '    '. [layout.spacing]
L:  48 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  48 | P:  17 | LT01 | Expected only single space before 'text' keyword. Found
                       | '   '. [layout.spacing]
L:  49 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  50 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  50 | P:  18 | LT01 | Expected only single space before 'integer' keyword.
                       | Found '  '. [layout.spacing]
L:  51 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  51 | P:  18 | LT01 | Expected only single space before 'jsonb' keyword. Found
                       | '  '. [layout.spacing]
L:  52 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  52 | P:  14 | LT01 | Expected only single space before 'timestamptz' keyword.
                       | Found '      '. [layout.spacing]
L:  56 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  56 | P:   3 | LT05 | Line is too long (184 > 80). [layout.long_lines]
L:  58 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  58 | P:   3 | LT05 | Line is too long (86 > 80). [layout.long_lines]
L:  60 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  60 | P:   3 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  62 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  66 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  68 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  68 | P:  17 | LT01 | Expected only single space before 'true' keyword. Found
                       | '          '. [layout.spacing]
L:  68 | P:  32 | LT01 | Expected only single space before quoted literal. Found
                       | '  '. [layout.spacing]
L:  68 | P:  40 | LT01 | Expected only single space before quoted literal. Found
                       | '        '. [layout.spacing]
L:  69 | P:   1 | LT02 | Line should not be indented. [layout.indent]
```

### FAZ A squawk (`squawk.out`)
```
warning[prefer-bigint-over-int]: Using 32-bit integer fields can result in hitting the max `int` limit.
   ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql:49:20
   │
49 │   max_erteleme_gun integer,
   │                    ━━━━━━━
   │
   ├ help: Use 64-bit integer values instead to prevent hitting this limit.
   ╭╴
49 -   max_erteleme_gun integer,
49 +   max_erteleme_gun bigint,
   ╰╴
warning[prefer-bigint-over-int]: Using 32-bit integer fields can result in hitting the max `int` limit.
   ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql:50:20
   │
50 │   asimi_uyari_gun  integer NOT NULL DEFAULT 7,
   │                    ━━━━━━━
   │
   ├ help: Use 64-bit integer values instead to prevent hitting this limit.
   ╭╴
50 -   asimi_uyari_gun  integer NOT NULL DEFAULT 7,
50 +   asimi_uyari_gun  bigint NOT NULL DEFAULT 7,
   ╰╴

Find detailed examples and solutions for each rule at https://squawkhq.com/docs/rules
Found 2 issues in 1 file (checked 1 source file)
```

### C1/C2 baseline (`baseline.out`)
```
[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → /home/melik/tmp/agents/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=54 F=243 V=13)[0m
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
{"db_name":"egesut_val_tmp","tablo":54,"fonksiyon":243,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=54 F=243 V=13)","parite_dosya":"/home/melik/tmp/agents/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
SET
SET
CREATE TABLE
COMMENT
COMMENT
COMMENT
COMMENT
INSERT 0 20
ALTER TABLE
REVOKE
GRANT
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
CREATE TABLE
COMMENT
COMMENT
COMMENT
COMMENT
INSERT 0 20
ALTER TABLE
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
gorev_ertele_kural: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
```
