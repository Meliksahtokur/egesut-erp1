# DB Validation Raporu — a8e4414a

- Tarih: 2026-09-27 08:52:04+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql`
- Priors (1): /home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql
- SHA-256: `a8e4414ae1bdfc777a8fc9dc4d20e17e34e5689b199c5062c186aca41be8b2d5`
- Baseline (C1): {'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=54 F=244 V=13, prod T=55 F=255 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=54 F=244 V=13, prod T=55 F=255 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C1.20260925100001_vaka_kalan_gunleri_kaydir.sql | PASS | prior migration hatasız uygulandı |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |
| C1.baseline-restore-data | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 54, 'fonksiyon': 244, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': "bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=54 F=244 V=13, prod T=55 F=255 V=13; refresh_lsp_schema.sh koş)", 'parite_dosya': '/home/melik/tmp/agents/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| priors.C2.20260925100001_vaka_kalan_gunleri_kaydir.sql | PASS | prior migration hatasız uygulandı |
| C2.sentetik-tohum | PASS | etkilenen tablolara sentetik satır eklendi |
| C2.veri-uyumluluk | PASS | sentetik veri üzerinde migration hatasız; unique/fk ihlali yok |

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql'  # prior (C1)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql'  # db=egesut_val_tmp
$ timeout 900 bash '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (data)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260925100001_vaka_kalan_gunleri_kaydir.sql'  # prior (C2)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql'  # C2 db=egesut_val_tmp (tohumlu)
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/toplu-i-lemler-ui-pratik-degil/supabase/migrations/20260927000001_vaka_kalan_gunleri_kaydir_coklu.sql] FAIL
L:  41 | P:   1 | LT05 | Line is too long (97 > 80). [layout.long_lines]
L:  54 | P:   1 | LT05 | Line is too long (100 > 80). [layout.long_lines]
L: 199 | P:   1 | LT05 | Line is too long (81 > 80). [layout.long_lines]
L: 200 | P:   1 | LT05 | Line is too long (97 > 80). [layout.long_lines]
L: 200 | P:  85 | CP02 | Unquoted identifiers must be consistently lower case.
                       | [capitalisation.identifiers]
L: 201 | P:   1 | LT05 | Line is too long (99 > 80). [layout.long_lines]
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
[1;34m▶   Ayna tazeliği: bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=54 F=244 V=13, prod T=55 F=255 V=13; refresh_lsp_schema.sh koş)[0m
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
{"db_name":"egesut_val_tmp","tablo":54,"fonksiyon":244,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"bilinmiyor (ayna sayımı prod'dan farklı — ayna bayat olabilir: yerel T=54 F=244 V=13, prod T=55 F=255 V=13; refresh_lsp_schema.sh koş)","parite_dosya":"/home/melik/tmp/agents/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
REVOKE
GRANT
COMMIT
```

### C2 apply (tohumlu) (`c2_apply.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
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
islem_log: sentetik satır eklendi (id, tip, durum, snapshot)
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
