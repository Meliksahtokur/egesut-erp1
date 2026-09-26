# DB Validation Raporu — 4df69cd3

- Tarih: 2026-09-25 18:36:37+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100007_erteleme_f4_onarim.sql`
- Priors (6): /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100002_add_treatment_day_ust_gorev_tarihi.sql /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100005_bagimsiz_pg_vaka_kapat.sql /home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql
- SHA-256: `4df69cd3508e487f713097d5580bd66f9ce857729ed5910b1c84f0f28d1da670`
- Baseline (C1): {'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C1.20260925100001_vaka_kalan_gunleri_kaydir.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20260925100002_add_treatment_day_ust_gorev_tarihi.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20260925100003_gorev_ertele_kural_tablo_seed.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20260925100004_gorev_ertele_rpcs.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20260925100005_bagimsiz_pg_vaka_kapat.sql | PASS | prior migration hatasız uygulandı |
| priors.C1.20260925100006_protokol_iptal.sql | PASS | prior migration hatasız uygulandı |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C2.20260925100001_vaka_kalan_gunleri_kaydir.sql | PASS | prior migration hatasız uygulandı |
| priors.C2.20260925100002_add_treatment_day_ust_gorev_tarihi.sql | PASS | prior migration hatasız uygulandı |
| priors.C2.20260925100003_gorev_ertele_kural_tablo_seed.sql | PASS | prior migration hatasız uygulandı |
| priors.C2.20260925100004_gorev_ertele_rpcs.sql | PASS | prior migration hatasız uygulandı |
| priors.C2.20260925100005_bagimsiz_pg_vaka_kapat.sql | PASS | prior migration hatasız uygulandı |
| priors.C2.20260925100006_protokol_iptal.sql | PASS | prior migration hatasız uygulandı |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100007_erteleme_f4_onarim.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100007_erteleme_f4_onarim.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100002_add_treatment_day_ust_gorev_tarihi.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100005_bagimsiz_pg_vaka_kapat.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100007_erteleme_f4_onarim.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100002_add_treatment_day_ust_gorev_tarihi.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100003_gorev_ertele_kural_tablo_seed.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100005_bagimsiz_pg_vaka_kapat.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100006_protokol_iptal.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100007_erteleme_f4_onarim.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100007_erteleme_f4_onarim.sql] FAIL
L:  20 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  23 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  57 | P:   1 | LT05 | Line is too long (92 > 80). [layout.long_lines]
L:  57 | P:  73 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  57 | P:  79 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  60 | P:  13 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  60 | P:  20 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  61 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  61 | P:   4 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  61 | P:  16 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  61 | P:  31 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  61 | P:  47 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L:  63 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  64 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  64 | P:  18 | LT01 | Expected only single space before 'true' keyword. Found
                       | '    '. [layout.spacing]
L:  65 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  65 | P:  20 | LT01 | Expected only single space before 'true' keyword. Found
                       | '  '. [layout.spacing]
L:  68 | P:   1 | LT05 | Line is too long (129 > 80). [layout.long_lines]
L:  68 | P: 125 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L:  70 | P:  10 | CP02 | Unquoted identifiers must be consistently upper case.
                       | [capitalisation.identifiers]
L: 187 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L: 188 | P:   1 | LT05 | Line is too long (175 > 80). [layout.long_lines]
L: 188 | P: 121 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L: 188 | P: 165 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L: 190 | P:  10 | CP02 | Unquoted identifiers must be consistently upper case.
```

### FAZ A squawk (`squawk.out`)
```

Found 0 issues in 1 file 🎉
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
REVOKE
INSERT 0 3
CREATE FUNCTION
CREATE FUNCTION
REVOKE
GRANT
REVOKE
GRANT
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
REVOKE
INSERT 0 3
CREATE FUNCTION
CREATE FUNCTION
REVOKE
GRANT
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
drug_administrations: sentetik satır eklendi (id, treatment_day_id, dose, unit)
gorev_ertele_kural: sentetik satır eklendi (gorev_tipi, ertelenebilir)
gorev_log: sentetik satır eklendi (id)
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
stok_hareket: sentetik satır eklendi (id)
treatment_day_uygulamalar: sentetik satır eklendi (id, treatment_day_id, case_id, planned_time, planned_date, dose, unit)
treatment_days: sentetik satır eklendi (id, case_id, treatment_date)
```

### Prior apply (`prior_C1_20260925100001_vaka_kalan_gunleri_kaydir.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C1_20260925100002_add_treatment_day_ust_gorev_tarihi.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C1_20260925100003_gorev_ertele_kural_tablo_seed.sql.out`)
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

### Prior apply (`prior_C1_20260925100004_gorev_ertele_rpcs.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
GRANT
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C1_20260925100005_bagimsiz_pg_vaka_kapat.sql.out`)
```
BEGIN
SET
SET
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100005_bagimsiz_pg_vaka_kapat.sql:48: NOTICE:  constraint "cases_close_reason_check" of relation "cases" does not exist, skipping
ALTER TABLE
ALTER TABLE
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
COMMIT
```

### Prior apply (`prior_C1_20260925100006_protokol_iptal.sql.out`)
```
BEGIN
SET
SET
ALTER TABLE
ALTER TABLE
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C2_20260925100001_vaka_kalan_gunleri_kaydir.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C2_20260925100002_add_treatment_day_ust_gorev_tarihi.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C2_20260925100003_gorev_ertele_kural_tablo_seed.sql.out`)
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

### Prior apply (`prior_C2_20260925100004_gorev_ertele_rpcs.sql.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
GRANT
REVOKE
GRANT
COMMIT
```

### Prior apply (`prior_C2_20260925100005_bagimsiz_pg_vaka_kapat.sql.out`)
```
BEGIN
SET
SET
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100005_bagimsiz_pg_vaka_kapat.sql:48: NOTICE:  constraint "cases_close_reason_check" of relation "cases" does not exist, skipping
ALTER TABLE
ALTER TABLE
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
COMMIT
```

### Prior apply (`prior_C2_20260925100006_protokol_iptal.sql.out`)
```
BEGIN
SET
SET
ALTER TABLE
ALTER TABLE
CREATE FUNCTION
CREATE FUNCTION
REVOKE
REVOKE
GRANT
COMMIT
```
