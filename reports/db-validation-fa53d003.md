# DB Validation Raporu — fa53d003

- Tarih: 2026-09-30 17:03:16+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql`
- SHA-256: `fa53d003dbf4d43081f265695fe883bff96ca41f6b18ceb4769f7d6e360ae79e`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | ERROR düzeyi ihlal yok; 2 WARNING rapora kaydedildi (bkz. çıktı) |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql] FAIL
L:   2 | P:   1 | LT05 | Line is too long (98 > 80). [layout.long_lines]
L:   5 | P:   1 | LT05 | Line is too long (113 > 80). [layout.long_lines]
L:   6 | P:   1 | LT05 | Line is too long (89 > 80). [layout.long_lines]
L:   8 | P:   1 | LT05 | Line is too long (96 > 80). [layout.long_lines]
L:   9 | P:   1 | LT05 | Line is too long (90 > 80). [layout.long_lines]
L:  10 | P:   1 | LT05 | Line is too long (97 > 80). [layout.long_lines]
L:  12 | P:   1 | LT05 | Line is too long (95 > 80). [layout.long_lines]
L:  13 | P:   1 | LT05 | Line is too long (85 > 80). [layout.long_lines]
L:  14 | P:   1 | LT05 | Line is too long (88 > 80). [layout.long_lines]
L:  15 | P:   1 | LT05 | Line is too long (90 > 80). [layout.long_lines]
L:  16 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  17 | P:   1 | LT05 | Line is too long (90 > 80). [layout.long_lines]
L:  20 | P:   1 | LT05 | Line is too long (254 > 80). [layout.long_lines]
L:  20 | P: 249 | CP04 | Boolean/null literals must be consistently upper case.
                       | [capitalisation.literals]
L:  21 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  22 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  23 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  24 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 264 | P:   1 | LT05 | Line is too long (111 > 80). [layout.long_lines]
L: 264 | P:  99 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 265 | P:   1 | LT05 | Line is too long (127 > 80). [layout.long_lines]
All Finished!
```

### FAZ A squawk (`squawk.out`)
```
warning[require-lock-timeout]: Missing `set lock_timeout` before potentially slow operations
    ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql:20:1
    │
 20 │ ┏ CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::tex…
 21 │ ┃  RETURNS jsonb
 22 │ ┃  LANGUAGE plpgsql
 23 │ ┃  SECURITY DEFINER
    ‡ ┃
260 │ ┃ END;
261 │ ┃ $function$;
    │ ┗━━━━━━━━━━━┛
    │
    ├ help: Configure a `lock_timeout` before this statement.
    ╭╴
 20 + set lock_timeout = '1s';
    ╰╴
warning[require-statement-timeout]: Missing `set statement_timeout` before potentially slow operations
    ╭▸ /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000004_tohumlama_gebelik_gorev_kaldir.sql:20:1
    │
 20 │ ┏ CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::tex…
 21 │ ┃  RETURNS jsonb
 22 │ ┃  LANGUAGE plpgsql
 23 │ ┃  SECURITY DEFINER
    ‡ ┃
260 │ ┃ END;
261 │ ┃ $function$;
    │ ┗━━━━━━━━━━━┛
    │
    ├ help: Configure a `statement_timeout` before this statement
    ╭╴
 20 + set statement_timeout = '5s';
    ╰╴

Find detailed examples and solutions for each rule at https://squawkhq.com/docs/rules
Found 2 issues in 1 file (checked 1 source file)
```

### C1/C2 baseline (`baseline.out`)
```
[1;34m▶ FAZ-0 Ortam paritesi (Mgmt API, salt-okunur)…[0m
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → /home/melik/tmp/agents/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)[0m
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
{"db_name":"egesut_val_tmp","tablo":55,"fonksiyon":256,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)","parite_dosya":"/home/melik/tmp/agents/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
CREATE FUNCTION
REVOKE
GRANT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
CREATE FUNCTION
REVOKE
GRANT
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
protokol_instance: sentetik satır eklendi (id, hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
stok_hareket: sentetik satır eklendi (id)
tohumlama: sentetik satır eklendi (id, deneme_sayisi, denemeler)
```
