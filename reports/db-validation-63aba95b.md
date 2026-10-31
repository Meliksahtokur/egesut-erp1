# DB Validation Raporu — 63aba95b

- Tarih: 2026-10-06 08:15:36+0300
- Migration: `supabase/migrations/20261006000002_stat_ayikla_tedavi.sql`
- Priors (6): supabase/migrations/20261005000001_stat_iskelet.sql supabase/migrations/20261005000002_v_stat_vaka.sql supabase/migrations/20261005000003_stat_tedavi_ozet.sql supabase/migrations/20261005000004_stat_tedavi_protokol.sql supabase/migrations/20261005000005_stat_protokol_disla.sql supabase/migrations/20261006000001_stat_motor_rol.sql
- SHA-256: `63aba95b849ed71e766c774b5a648bfbfc51e1212ee039fe3ed88bc7f1074e8d`
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
| priors.C1.20261005000002_v_stat_vaka.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20261005000003_stat_tedavi_ozet.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20261005000004_stat_tedavi_protokol.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20261005000005_stat_protokol_disla.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20261006000001_stat_motor_rol.sql | PASS | prior migration hatasız uygulandı |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |

> VERİ UYUŞUMLULUĞU DOĞRULANMADI (data-mode=auto, veri dokan migration deseni saptanmadı: 0 eşleşme).

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres --config '~/tmp/agents/dbval.VISzMKoy/sqlfluff.cfg' 'supabase/migrations/20261006000002_stat_ayikla_tedavi.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table 'supabase/migrations/20261006000002_stat_ayikla_tedavi.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '$SCRATCHPAD/ayna/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000001_stat_iskelet.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000002_v_stat_vaka.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000003_stat_tedavi_ozet.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000004_stat_tedavi_protokol.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261005000005_stat_protokol_disla.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261006000001_stat_motor_rol.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261006000002_stat_ayikla_tedavi.sql'  # db=egesut_val_tmp
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [supabase/migrations/20261006000002_stat_ayikla_tedavi.sql] FAIL
L:   3 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:   4 | P:   1 | LT05 | Line is too long (93 > 80). [layout.long_lines]
L:   5 | P:   1 | LT05 | Line is too long (104 > 80). [layout.long_lines]
L:   6 | P:   1 | LT05 | Line is too long (100 > 80). [layout.long_lines]
L:   8 | P:   1 | LT05 | Line is too long (106 > 80). [layout.long_lines]
L:   9 | P:   1 | LT05 | Line is too long (102 > 80). [layout.long_lines]
L:  10 | P:   1 | LT05 | Line is too long (108 > 80). [layout.long_lines]
L:  11 | P:   1 | LT05 | Line is too long (94 > 80). [layout.long_lines]
L:  22 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:  23 | P:   1 | LT05 | Line is too long (110 > 80). [layout.long_lines]
L:  23 | P:  14 | LT01 | Expected single whitespace between 'TABLE' keyword and
                       | start bracket '('. [layout.spacing]
L:  38 | P:  14 | LT01 | Expected single whitespace between 'TABLE' keyword and
                       | start bracket '('. [layout.spacing]
L:  49 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  49 | P:   3 | LT05 | Line is too long (109 > 80). [layout.long_lines]
L:  50 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  50 | P:   3 | LT05 | Line is too long (109 > 80). [layout.long_lines]
L:  51 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  53 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  53 | P:   3 | LT05 | Line is too long (111 > 80). [layout.long_lines]
L:  54 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  54 | P:   3 | LT05 | Line is too long (106 > 80). [layout.long_lines]
L:  55 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  55 | P:   3 | LT05 | Line is too long (104 > 80). [layout.long_lines]
L:  57 | P:   1 | LT05 | Line is too long (95 > 80). [layout.long_lines]
L:  57 | P:  68 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L:  58 | P:   1 | LT05 | Line is too long (94 > 80). [layout.long_lines]
L:  58 | P:  67 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
All Finished!
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
NOTICE:  database "egesut_val_tmp" does not exist, skipping
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
CREATE FUNCTION
CREATE FUNCTION
COMMENT
COMMENT
REVOKE
REVOKE
GRANT
GRANT
COMMIT
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

### Prior apply (`prior_C1_20261005000002_v_stat_vaka.sql.out`)
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

### Prior apply (`prior_C1_20261005000003_stat_tedavi_ozet.sql.out`)
```
COMMENT
INSERT 0 5
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
COMMIT
```

### Prior apply (`prior_C1_20261005000004_stat_tedavi_protokol.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
CREATE FUNCTION
COMMENT
CREATE FUNCTION
COMMENT
REVOKE
REVOKE
REVOKE
GRANT
GRANT
GRANT
COMMIT
```

### Prior apply (`prior_C1_20261005000005_stat_protokol_disla.sql.out`)
```
SET
SET
CREATE VIEW
COMMENT
REVOKE
GRANT
CREATE FUNCTION
COMMENT
REVOKE
GRANT
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
UPDATE 3
COMMIT
```

### Prior apply (`prior_C1_20261006000001_stat_motor_rol.sql.out`)
```
BEGIN
SET
SET
DO
COMMENT
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
COMMIT
```
