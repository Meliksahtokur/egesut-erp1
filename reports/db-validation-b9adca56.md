# DB Validation Raporu — b9adca56

- Tarih: 2026-09-25 17:08:14+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql`
- SHA-256: `b9adca56ff97a70ed3892a1780f48551a347a722bd37f1fb8196ef9df7deb221`
- Baseline (C1): {'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **FAIL**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
| B.sema-uyum | INCONCLUSIVE | statik çözülemedi (C1'e bırakıldı): gorev_ertele_kural  |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | FAIL | psql hatası ; ayrıntı raporda |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=54 F=244 V=13)', 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C2.veri-uyumluluk | FAIL | tohumlu veri üzerinde apply hatası; ayrıntı raporda |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql] FAIL
L:   5 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:   6 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:   7 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  22 | P:   1 | LT05 | Line is too long (87 > 80). [layout.long_lines]
L:  27 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L:  28 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  30 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  35 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  36 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  38 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  76 | P:   1 | LT05 | Line is too long (155 > 80). [layout.long_lines]
L: 224 | P:   1 | LT05 | Line is too long (100 > 80). [layout.long_lines]
L: 224 | P:  14 | LT01 | Expected single whitespace between 'TABLE' keyword and
                       | start bracket '('. [layout.spacing]
L: 237 | P:  65 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 239 | P:   1 | LT05 | Line is too long (97 > 80). [layout.long_lines]
L: 239 | P:  85 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 240 | P:   1 | LT05 | Line is too long (99 > 80). [layout.long_lines]
L: 241 | P:  65 | CP02 | Unquoted identifiers must be consistently lower case.
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
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql:73: ERROR:  relation "public.gorev_ertele_kural" does not exist
LINE 13:        FROM public.gorev_ertele_kural k
                     ^
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
psql:/home/melik/.herdr/worktrees/egesut-erp1/ovysch-feature-erteleme/supabase/migrations/20260925100004_gorev_ertele_rpcs.sql:73: ERROR:  relation "public.gorev_ertele_kural" does not exist
LINE 13:        FROM public.gorev_ertele_kural k
                     ^
```

### C2 sentetik tohum (`seed.log`)
```
ERROR:  relation "public.farm" does not exist
LINE 1: ... ELSE (SELECT quote_literal(min(f.id)::text) FROM public.far...
                                                             ^
(genel) public.farm yok/boş — farm_id tohum değeri '1' fallback
gorev_log: sentetik satır eklendi (id)
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
```
