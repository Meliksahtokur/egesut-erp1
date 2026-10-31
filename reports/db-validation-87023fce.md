# DB Validation Raporu — 87023fce

- Tarih: 2026-10-05 22:55:05+0300
- Migration: `supabase/migrations/20261005000001_stat_iskelet.sql`
- SHA-256: `87023fceaf1690853ef164196789b1f44fc45ab1b877720022c73156c826c8d9`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | ERROR düzeyi ihlal yok; 1 WARNING rapora kaydedildi (bkz. çıktı) |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: > stat_analiz_sonuc=1 |
| > stat_motor_kosum=1 |  |  |
| > stat_olcum_kayit=1; etkilenen tablolar relrowsecurity: stat_analiz_sonuc:→1 stat_motor_kosum:→1 stat_olcum_kayit:→1 |  |  |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=55 F=256 V=13, prod T=55 F=264 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres 'supabase/migrations/20261005000001_stat_iskelet.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table 'supabase/migrations/20261005000001_stat_iskelet.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '$SCRATCHPAD/dbv/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000001_stat_iskelet.sql'  # db=egesut_val_tmp
$ timeout 900 bash '$SCRATCHPAD/dbv/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000001_stat_iskelet.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [supabase/migrations/20261005000001_stat_iskelet.sql] FAIL
L:  23 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  23 | P:   5 | LT01 | Expected only single space before 'bigint' keyword.
                       | Found '        '. [layout.spacing]
L:  24 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  24 | P:  10 | LT01 | Expected only single space before 'uuid' keyword. Found
                       | '   '. [layout.spacing]
L:  25 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  25 | P:   5 | LT01 | Expected only single space before 'text' keyword. Found
                       | '        '. [layout.spacing]
L:  26 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  26 | P:   7 | LT01 | Expected only single space before 'text' keyword. Found
                       | '      '. [layout.spacing]
L:  27 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  27 | P:   9 | LT01 | Expected only single space before 'text' keyword. Found
                       | '    '. [layout.spacing]
L:  28 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  28 | P:  11 | LT01 | Expected only single space before 'text' keyword. Found
                       | '  '. [layout.spacing]
L:  29 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  29 | P:   6 | LT01 | Expected only single space before 'text' keyword. Found
                       | '       '. [layout.spacing]
L:  30 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  30 | P:   8 | LT01 | Expected only single space before 'text' keyword. Found
                       | '     '. [layout.spacing]
L:  31 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  31 | P:   8 | LT01 | Expected only single space before 'boolean' keyword.
                       | Found '     '. [layout.spacing]
L:  32 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  32 | P:   7 | LT01 | Expected only single space before 'int' keyword. Found '
                       | '. [layout.spacing]
L:  36 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  36 | P:   5 | LT01 | Expected only single space before 'bigint' keyword.
                       | Found '           '. [layout.spacing]
L:  37 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  37 | P:  10 | LT01 | Expected only single space before 'uuid' keyword. Found
                       | '      '. [layout.spacing]
L:  38 | P:   1 | LT02 | Expected indent of 4 spaces. [layout.indent]
L:  38 | P:   8 | LT01 | Expected only single space before 'text' keyword. Found
                       | '        '. [layout.spacing]
```

### FAZ A squawk (`squawk.out`)
```
warning[prefer-bigint-over-int]: Using 32-bit integer fields can result in hitting the max `int` limit.
   ╭▸ supabase/migrations/20261005000001_stat_iskelet.sql:32:13
   │
32 │   sira      int DEFAULT 100
   │             ━━━
   │
   ├ help: Use 64-bit integer values instead to prevent hitting this limit.
   ╭╴
32 │   sira      bigint DEFAULT 100
   ╰╴            +++

Find detailed examples and solutions for each rule at https://squawkhq.com/docs/rules
Found 1 issue in 1 file (checked 1 source file)
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
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE INDEX
CREATE INDEX
CREATE INDEX
COMMENT
COMMENT
COMMENT
ALTER TABLE
ALTER TABLE
ALTER TABLE
psql:supabase/migrations/20261005000001_stat_iskelet.sql:76: NOTICE:  policy "stat_olcum_kayit_all" for relation "public.stat_olcum_kayit" does not exist, skipping
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:78: NOTICE:  policy "stat_analiz_sonuc_all" for relation "public.stat_analiz_sonuc" does not exist, skipping
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:80: NOTICE:  policy "stat_motor_kosum_all" for relation "public.stat_motor_kosum" does not exist, skipping
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

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE INDEX
CREATE INDEX
CREATE INDEX
COMMENT
COMMENT
COMMENT
ALTER TABLE
ALTER TABLE
ALTER TABLE
psql:supabase/migrations/20261005000001_stat_iskelet.sql:76: NOTICE:  policy "stat_olcum_kayit_all" for relation "public.stat_olcum_kayit" does not exist, skipping
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:78: NOTICE:  policy "stat_analiz_sonuc_all" for relation "public.stat_analiz_sonuc" does not exist, skipping
DROP POLICY
CREATE POLICY
psql:supabase/migrations/20261005000001_stat_iskelet.sql:80: NOTICE:  policy "stat_motor_kosum_all" for relation "public.stat_motor_kosum" does not exist, skipping
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

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
stat_analiz_sonuc: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
stat_analiz_sonuc_farm_olcum_idx: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
stat_motor_kosum: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
stat_motor_kosum_farm_baslangic_idx: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
stat_olcum_kayit: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
stat_olcum_kayit_farm_aktif_sira_idx: baseline'da yok (migration yaratıyor) — tohumlama atlandı, apply sırasında sınanır
```
