# DB Validation Raporu — 3a69ea5d

- Tarih: 2026-10-17 22:28:27+0300
- Migration: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql`
- SHA-256: `3a69ea5d75ec89e5b0cd15786271bde76c6177ebc9e3f1d88d4273c96ad4337d`
- Baseline (C1): {'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '/home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} · parite: uyumlu
- Data mode: koşulmadı (migration veri dokmuyor, --data-mode=auto)
- Genel sonuç: **PASS**

## Faz bazlı sonuç tablosu

| Kriter | Sonuç | Not |
|---|---|---|
| A.sqlfluff-parse | PASS | parse hatası yok (stil uyarısı: 0) |
| A.squawk | PASS | varsayılan kurallar (istisna: require-concurrent-index-creation,ban-drop-table) ihlal yok |
| B.sema-uyum | PASS | tüm FROM/JOIN/ALTER/REFERENCES hedefleri biliniyor (ayna ya da migration-içi) |
| C1.baseline-restore-schema | PASS | db=egesut_val_tmp parite=uyumlu meta={'tablo': 55, 'fonksiyon': 267, 'view': 13, 'pgtap_fn': 1085, 'parite_durum': 'uyumlu', 'baseline_kaynak': 'egesut_lsp', 'ayna_tazelik': 'taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)', 'parite_dosya': '/home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt', 'prod_pg': '17.6', 'yerel_pg': '17.6'} |
| C1.migration-apply | PASS | psql ON_ERROR_STOP ile hatasız uygulandı |
| C1.postcheck-nesne | PASS | migration-içi yaratılan tüm nesneler izole DB'de mevcut |
| C1.postcheck-rls | PASS | RLS farkları: yok; etkilenen tablolar relrowsecurity: (yeni tablo ya da aynada yok) |
| C1.ortam-paritesi | PASS | baseline parite_durumu=uyumlu |

> VERİ UYUŞUMLULUĞU DOĞRULANMADI (data-mode=auto, veri dokan migration deseni saptanmadı: 0 eşleşme).

## Uygulanan komutlar

```bash
$ sqlfluff lint --dialect postgres '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql'
$ squawk --exclude=require-concurrent-index-creation,ban-drop-table '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql'
$ psql egesut_lsp: tablo/view/fonksiyon isimleri (information_schema + pg_proc)
$ timeout 900 bash '/home/melik/egesut-erp1/scripts/db-build-baseline.sh' --json --db-url postgres://postgres:val@127.0.0.1:5433/postgres  # (schema)
$ psql -v ON_ERROR_STOP=1 -f '/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql'  # db=egesut_val_tmp
```

## Çıktı parçaları

### FAZ A sqlfluff (`sqlfluff.out`)
```
== [/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql] FAIL
L:   2 | P:   1 | LT05 | Line is too long (87 > 80). [layout.long_lines]
L:   3 | P:   1 | LT05 | Line is too long (84 > 80). [layout.long_lines]
L:  10 | P:   1 | LT05 | Line is too long (82 > 80). [layout.long_lines]
L:  23 | P:   1 | LT05 | Line is too long (83 > 80). [layout.long_lines]
L:  28 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  29 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  30 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  31 | P:   1 | LT02 | Line should not be indented. [layout.indent]
L:  48 | P:   1 | LT05 | Line is too long (85 > 80). [layout.long_lines]
L:  48 | P:  58 | CP02 | Unquoted identifiers must be consistently lower case.
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
[1;34m▶   Parite: uyumlu (prod=17.6 yerel=17.6) → /home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt[0m
[1;34m▶   Ayna tazeliği: taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)[0m
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
{"db_name":"egesut_val_tmp","tablo":55,"fonksiyon":267,"view":13,"pgtap_fn":1085,"parite_durum":"uyumlu","baseline_kaynak":"egesut_lsp","ayna_tazelik":"taze (nesne sayımı prod ile eşleşiyor: T=55 F=267 V=13)","parite_dosya":"/home/melik/tmp/agents/claude-1000/-home-melik--herdr-worktrees-egesut-erp1-istatistik-mod-l/e16a86bb-8b0a-42c2-b12a-2f3f236aa153/scratchpad/parite-egesut_val_tmp.txt","prod_pg":"17.6","yerel_pg":"17.6"}
```

### C1 apply (`apply.out`)
```
BEGIN
SET
SET
CREATE FUNCTION
REVOKE
GRANT
NOTIFY
COMMIT
```
