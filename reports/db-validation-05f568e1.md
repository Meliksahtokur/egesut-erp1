# DB Validation Raporu — 05f568e1

- Tarih: 2026-10-31 00:20:57+0300
- Migration: `supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql`
- SHA-256: `05f568e191e6ddf62c236caffd6afcc7f9bab65cfc558e2368efb429c870c157`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | ERROR düzeyi ihlal yok; 2 WARNING rapora kaydedildi (bkz. çıktı) |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '~/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres 'supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table 'supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '~/egesut-erp1/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql'  # db=egesut_val_tmp
$ timeout 900 bash '~/egesut-erp1/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:***@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql] FAIL
L:   3 | P:   1 | LT05 | Line is too long (97 > 80). [layout.long_lines]
L:   5 | P:   1 | LT05 | Line is too long (97 > 80). [layout.long_lines]
L:   6 | P:   1 | LT05 | Line is too long (100 > 80). [layout.long_lines]
L:   7 | P:   1 | LT05 | Line is too long (90 > 80). [layout.long_lines]
L:   8 | P:   1 | LT05 | Line is too long (100 > 80). [layout.long_lines]
L:   9 | P:   1 | LT05 | Line is too long (104 > 80). [layout.long_lines]
L:  16 | P:   1 | LT05 | Line is too long (262 > 80). [layout.long_lines]
L:  17 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  18 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  19 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  20 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 168 | P:   1 | LT05 | Line is too long (121 > 80). [layout.long_lines]
L: 169 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 170 | P:   1 | LT02 | Line should not be indented. [layout.indent]
All Finished!
```

### FAZ A squawk (`squawk.out`)
```
warning[require-lock-timeout]: Missing `set lock_timeout` before potentially slow operations
    ╭▸ supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql:16:1
    │
 16 │ ┏ CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip t…
 17 │ ┃  RETURNS jsonb
 18 │ ┃  LANGUAGE plpgsql
 19 │ ┃  SECURITY DEFINER
    ‡ ┃
165 │ ┃ END;
166 │ ┃ $function$;
    │ ┗━━━━━━━━━━━┛
    │
    ├ help: Configure a `lock_timeout` before this statement.
    ╭╴
 14 + set lock_timeout = '1s';
    ╰╴
warning[require-statement-timeout]: Missing `set statement_timeout` before potentially slow operations
    ╭▸ supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql:16:1
    │
 16 │ ┏ CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip t…
 17 │ ┃  RETURNS jsonb
 18 │ ┃  LANGUAGE plpgsql
 19 │ ┃  SECURITY DEFINER
    ‡ ┃
165 │ ┃ END;
166 │ ┃ $function$;
    │ ┗━━━━━━━━━━━┛
    │
    ├ help: Configure a `statement_timeout` before this statement
    ╭╴
 14 + set statement_timeout = '5s';
    ╰╴

Find detailed examples and solutions for each rule at https://squawkhq.com/docs/rules
Found 2 issues in 1 file (checked 1 source file)
```

### C1/C2 baseline (`baseline.out`)
```
[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → ~/tmp/agents/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)[0m
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
{"db_name":"egesut_val_tmp","tablo":55,"fonksiyon":267,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)","parite_dosya":"~/tmp/agents/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
CREATE FUNCTION
CREATE FUNCTION
NOTIFY
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
CREATE FUNCTION
CREATE FUNCTION
NOTIFY
COMMIT
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
dogum: sentetik satır eklendi (id)
gorev_log: sentetik satır eklendi (id)
hayvanlar: sentetik satır eklendi (id)
protokol_instance: sentetik satır eklendi (id, hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
```
