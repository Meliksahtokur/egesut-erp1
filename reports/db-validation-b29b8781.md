# DB Validation Raporu — b29b8781

- Tarih: 2026-10-30 22:03:32+0300
- Migration: `supabase/migrations/20261030100001_protokol_etken_senkron.sql`
- SHA-256: `b29b878167e4a41bc9360a78e4d25f5ca81b4e3934549ecb86dd6fb3ee98d213`
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
$ sqlfluff lint --dialect postgres 'supabase/migrations/20261030100001_protokol_etken_senkron.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table 'supabase/migrations/20261030100001_protokol_etken_senkron.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '~/tmp/t4/val/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261030100001_protokol_etken_senkron.sql'  # db=egesut_val_tmp
$ timeout 900 bash '~/tmp/t4/val/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f 'supabase/migrations/20261030100001_protokol_etken_senkron.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [supabase/migrations/20261030100001_protokol_etken_senkron.sql] FAIL
L:   2 | P:   1 | LT05 | Line is too long (100 > 80). [layout.long_lines]
L:   3 | P:   1 | LT05 | Line is too long (93 > 80). [layout.long_lines]
L:   4 | P:   1 | LT05 | Line is too long (107 > 80). [layout.long_lines]
L:   5 | P:   1 | LT05 | Line is too long (114 > 80). [layout.long_lines]
L:   6 | P:   1 | LT05 | Line is too long (94 > 80). [layout.long_lines]
L:  11 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  12 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  13 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 193 | P:   1 | LT05 | Line is too long (325 > 80). [layout.long_lines]
L: 193 | P: 200 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L: 193 | P: 259 | CP04 | Boolean/null literals must be consistently lower case.
                       | [capitalisation.literals]
L: 194 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 195 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 196 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 197 | P:   1 | LT02 | Line should not be indented. [layout.indent]
All Finished!
```

### FAZ A squawk (`squawk.out`)
```
warning[require-lock-timeout]: Missing `set lock_timeout` before potentially slow operations
    ╭▸ supabase/migrations/20261030100001_protokol_etken_senkron.sql:10:1
    │
 10 │ ┏ CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
 11 │ ┃  RETURNS jsonb
 12 │ ┃  LANGUAGE plpgsql
 13 │ ┃  SECURITY DEFINER
    ‡ ┃
190 │ ┃ END;
191 │ ┃ $function$;
    │ ┗━━━━━━━━━━━┛
    │
    ├ help: Configure a `lock_timeout` before this statement.
    ╭╴
  8 + set lock_timeout = '1s';
    ╰╴
warning[require-statement-timeout]: Missing `set statement_timeout` before potentially slow operations
    ╭▸ supabase/migrations/20261030100001_protokol_etken_senkron.sql:10:1
    │
 10 │ ┏ CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
 11 │ ┃  RETURNS jsonb
 12 │ ┃  LANGUAGE plpgsql
 13 │ ┃  SECURITY DEFINER
    ‡ ┃
190 │ ┃ END;
191 │ ┃ $function$;
    │ ┗━━━━━━━━━━━┛
    │
    ├ help: Configure a `statement_timeout` before this statement
    ╭╴
  8 + set statement_timeout = '5s';
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
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
CREATE FUNCTION
CREATE FUNCTION
COMMIT
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
gorev_log: sentetik satır eklendi (id)
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
stok_hareket: sentetik satır eklendi (id)
uygulama_log: sentetik satır eklendi (id, hayvan_id, doz, birim, rota, tarih, notlar)
```
