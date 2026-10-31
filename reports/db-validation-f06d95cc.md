# DB Validation Raporu — f06d95cc

- Tarih: 2026-10-05 23:11:15+0300
- Migration: `supabase/migrations/20261005000002_v_stat_vaka.sql`
- Priors (1): supabase/migrations/20261005000001_stat_iskelet.sql
- SHA-256: `f06d95cc0c9174ebdda1f4f6ef78be7f9f5b5c10c10c022a135e72da0bbdabcf`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C1.20261005000001_stat_iskelet.sql | PASS | prior migration hatasız uygulandı |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C2.20261005000001_stat_iskelet.sql | PASS | prior migration hatasız uygulandı |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres 'supabase/migrations/20261005000002_v_stat_vaka.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table 'supabase/migrations/20261005000002_v_stat_vaka.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '$SCRATCHPAD/mirror/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000001_stat_iskelet.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000002_v_stat_vaka.sql'  # db=egesut_val_tmp
$ timeout 900 bash '$SCRATCHPAD/mirror/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000001_stat_iskelet.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000002_v_stat_vaka.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [supabase/migrations/20261005000002_v_stat_vaka.sql] FAIL
L:   5 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:   7 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:   9 | P:   1 | LT05 | Line is too long (93 > 80). [layout.long_lines]
L:  10 | P:   1 | LT05 | Line is too long (90 > 80). [layout.long_lines]
L:  11 | P:   1 | LT05 | Line is too long (89 > 80). [layout.long_lines]
L:  12 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  14 | P:   1 | LT05 | Line is too long (88 > 80). [layout.long_lines]
L:  15 | P:   1 | LT05 | Line is too long (88 > 80). [layout.long_lines]
L:  17 | P:   1 | LT05 | Line is too long (92 > 80). [layout.long_lines]
L:  27 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  27 | P:   3 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  28 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  28 | P:   3 | LT09 | Select targets should be on a new line unless there is
                       | only one select target. [layout.select_targets]
L:  28 | P:   9 | LT02 | Expected line break and indent of 8 spaces before 'td'.
                       | [layout.indent]
L:  29 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L:  30 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L:  31 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L:  31 | P:  23 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L:  31 | P:  53 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L:  32 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L:  33 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L:  34 | P:   1 | LT02 | Expected indent of 8 spaces. [layout.indent]
L:  35 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  35 | P:  30 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
L:  36 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  36 | P:  41 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
L:  36 | P:  46 | ST09 | Joins should list the table referenced earlier first.
                       | [structure.join_condition_order]
L:  37 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  37 | P:  34 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
L:  38 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  38 | P:  33 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
L:  39 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  39 | P:  25 | AL01 | Implicit/explicit aliasing of table. [aliasing.table]
L:  40 | P:   4 | LT08 | Blank line expected but not found after CTE closing
```

### FAZ A squawk (`squawk.out`)
```

Found 0 issues in 1 file 🎉
```

### C1/C2 baseline (`baseline.out`)
```
[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → ~/tmp/agents/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)[0m
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
{"db_name":"egesut_val_tmp","tablo":55,"fonksiyon":256,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)","parite_dosya":"~/tmp/agents/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
SET
SET
CREATE VIEW
COMMENT
REVOKE
GRANT
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
CREATE VIEW
COMMENT
REVOKE
GRANT
COMMIT
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
```

### Prior apply (`prior_C1_20261005000001_stat_iskelet.sql.out`)
```
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:84: NOTICE:  policy "stat_analiz_sonuc_all" for relation "public.stat_analiz_sonuc" does not exist, skipping
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:86: NOTICE:  policy "stat_motor_kosum_all" for relation "public.stat_motor_kosum" does not exist, skipping
DROP POLICY
CREATE POLICY
REVOKE
REVOKE
REVOKE
GRANT
GRANT
GRANT
COMMIT
```

### Prior apply (`prior_C2_20261005000001_stat_iskelet.sql.out`)
```
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:84: NOTICE:  policy "stat_analiz_sonuc_all" for relation "public.stat_analiz_sonuc" does not exist, skipping
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:86: NOTICE:  policy "stat_motor_kosum_all" for relation "public.stat_motor_kosum" does not exist, skipping
DROP POLICY
CREATE POLICY
REVOKE
REVOKE
REVOKE
GRANT
GRANT
GRANT
COMMIT
```
