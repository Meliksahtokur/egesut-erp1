# DB Validation Raporu — a84e248d

- Tarih: 2026-09-30 17:51:22+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql`
- SHA-256: `a84e248dca673086c8f6b6f5f13b5a29f546d60da7657014be0dad1d3edbe36d`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 256, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=256 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
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
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql] FAIL
L:   3 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:   6 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:   7 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  14 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  16 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  24 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  26 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  36 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  39 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  50 | P:   1 | LT05 | Line is too long (86 > 80). [layout.long_lines]
L:  67 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:  72 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:  73 | P:   1 | LT05 | Line is too long (85 > 80). [layout.long_lines]
L:  87 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  88 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  89 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  90 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 122 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 123 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 126 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 126 | P:   3 | LT05 | Line is too long (233 > 80). [layout.long_lines]
L: 136 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 137 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 138 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 166 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 167 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 170 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 170 | P:   3 | LT05 | Line is too long (237 > 80). [layout.long_lines]
L: 180 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 181 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 182 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 225 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 226 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 229 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 229 | P:   3 | LT05 | Line is too long (321 > 80). [layout.long_lines]
L: 241 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 242 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 266 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L: 266 | P:   3 | LT05 | Line is too long (196 > 80). [layout.long_lines]
```

### FAZ A squawk (`squawk.out`)
```

Found 0 issues in 1 file 🎉
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
BEGIN
SET
SET
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:120: NOTICE:  trigger "trg_takip_yeni_tohumlama_kapat" for relation "public.tohumlama" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:164: NOTICE:  trigger "trg_takip_pg_olay_kapisi" for relation "public.pg_application_event" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:223: NOTICE:  trigger "trg_takip_ovsync_case_kapisi" for relation "public.cases" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
COMMENT
CREATE FUNCTION
COMMENT
REVOKE
REVOKE
REVOKE
REVOKE
REVOKE
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:120: NOTICE:  trigger "trg_takip_yeni_tohumlama_kapat" for relation "public.tohumlama" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:164: NOTICE:  trigger "trg_takip_pg_olay_kapisi" for relation "public.pg_application_event" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql:223: NOTICE:  trigger "trg_takip_ovsync_case_kapisi" for relation "public.cases" does not exist, skipping
DROP TRIGGER
CREATE TRIGGER
COMMENT
CREATE FUNCTION
COMMENT
CREATE FUNCTION
COMMENT
REVOKE
REVOKE
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
(genel) public.farm yok/boş — farm_id tohum değeri sabit zero-uuid fallback
```
